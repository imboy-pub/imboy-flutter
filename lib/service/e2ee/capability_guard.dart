/// S6: Capability 降级检测（防协议降级攻击，ADR 08 T2）
///
/// 原理：记录每台对端设备的历史最高协商协议等级（High-Water Mark）。
/// 后续协商若结果低于 HWM，说明对端能力"缩减"——可能是：
/// - 合法场景：对端卸载了 Olm 库、降级客户端版本
/// - 攻击场景：MITM 伪造低能力 capability 强制降级到弱加密
///
/// 策略：fail-closed。检测到降级立即抛 [CapabilityDowngradeException]，
/// UI 层展示告警，用户显式确认后方可覆写 HWM 继续通信。
library;

import 'package:imboy/service/e2ee/capability_negotiator.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';

/// 协议降级异常。UI 层应展示安全告警并让用户选择：
/// 1. 确认降级（对端确实换了低版本客户端）→ 调用 [CapabilityGuard.confirmDowngrade]
/// 2. 拒绝通信（疑似攻击）→ 不发送
class CapabilityDowngradeException implements Exception {
  CapabilityDowngradeException({
    required this.peerUid,
    required this.peerDeviceId,
    required this.previousProtocol,
    required this.attemptedProtocol,
  });

  final String peerUid;
  final String peerDeviceId;
  final String previousProtocol;
  final String attemptedProtocol;

  @override
  String toString() =>
      'CapabilityDowngradeException: $peerUid:$peerDeviceId '
      '$previousProtocol → $attemptedProtocol (downgrade rejected)';
}

/// 协商等级降级守护。
///
/// 依赖 [CryptoStore] 持久化 HWM，依赖 [CapabilityNegotiator.securityRank]
/// 确定协议安全等级排序（index 越小越安全）。
class CapabilityGuard {
  CapabilityGuard(this._store);

  final CryptoStore _store;

  /// 获取协议在 securityRank 中的等级索引。
  /// 未知协议返回极大值（视为最低安全等级，fail-closed 保守）。
  int _rank(String protocol) {
    final idx = CapabilityNegotiator.securityRank.indexOf(protocol);
    return idx < 0 ? 0x7FFFFFFFFFFFFFFF : idx;
  }

  /// 记录 HWM（首次协商或升级时调用）。
  Future<void> recordHighWaterMark({
    required String peerUid,
    required String peerDeviceId,
    required String protocol,
  }) async {
    await _store.persistCapabilityHwm(
      peerUid: peerUid,
      peerDeviceId: peerDeviceId,
      protocol: protocol,
    );
  }

  /// 加载 HWM。无记录返回 null。
  Future<String?> loadHighWaterMark({
    required String peerUid,
    required String peerDeviceId,
  }) async {
    return _store.loadCapabilityHwm(
      peerUid: peerUid,
      peerDeviceId: peerDeviceId,
    );
  }

  /// 核心守护：协商完成后调用，检测是否降级。
  ///
  /// - 无 HWM（首次）→ 记录并通过
  /// - 新等级 >= HWM（升级/不变）→ 更新 HWM 并通过
  /// - 新等级 < HWM（降级）→ 抛 [CapabilityDowngradeException]
  Future<void> enforceNoDowngrade({
    required String peerUid,
    required String peerDeviceId,
    required String negotiatedProtocol,
  }) async {
    final hwm = await loadHighWaterMark(
      peerUid: peerUid,
      peerDeviceId: peerDeviceId,
    );

    if (hwm == null) {
      // 首次：记录 HWM
      await recordHighWaterMark(
        peerUid: peerUid,
        peerDeviceId: peerDeviceId,
        protocol: negotiatedProtocol,
      );
      return;
    }

    final hwmRank = _rank(hwm);
    final newRank = _rank(negotiatedProtocol);

    if (newRank <= hwmRank) {
      // 升级或不变（rank 越小越安全）：更新 HWM
      if (newRank < hwmRank) {
        await recordHighWaterMark(
          peerUid: peerUid,
          peerDeviceId: peerDeviceId,
          protocol: negotiatedProtocol,
        );
      }
      return;
    }

    // 降级：fail-closed
    throw CapabilityDowngradeException(
      peerUid: peerUid,
      peerDeviceId: peerDeviceId,
      previousProtocol: hwm,
      attemptedProtocol: negotiatedProtocol,
    );
  }

  /// 用户显式确认降级（对端确实换了低版本客户端）。
  /// 覆写 HWM 为新协议，后续通信恢复正常。
  Future<void> confirmDowngrade({
    required String peerUid,
    required String peerDeviceId,
    required String newProtocol,
  }) async {
    await recordHighWaterMark(
      peerUid: peerUid,
      peerDeviceId: peerDeviceId,
      protocol: newProtocol,
    );
  }
}

/// 固定套件不兼容（显式兼容错误，C02）。
///
/// 旧端（只支持 rsa-oaep）或能力声明缺失的对端不满足 scope 的固定套件
/// 要求时抛出。调用方必须把该设备标记为**无法加密投递**：
/// 不回退明文（retry_plaintext_guard 同源语义）、不静默降级、不假装成功。
class FixedSuiteIncompatibleException implements Exception {
  FixedSuiteIncompatibleException({
    required this.scope,
    required this.requiredSuite,
    required this.peerDeviceId,
    required this.peerProtocols,
  });

  final String scope;
  final String requiredSuite;
  final String peerDeviceId;
  final Set<String> peerProtocols;

  @override
  String toString() =>
      'FixedSuiteIncompatibleException: peer=$peerDeviceId scope=$scope '
      'requires $requiredSuite but peer only supports {${peerProtocols.join(',')}} '
      '(explicit refusal: no plaintext fallback, no silent downgrade)';
}

/// C02 固定套件策略：把「发送链不做运行时套件协商」的结构性决策固化为
/// 显式 API。
///
/// 决策依据（协议规范 §8.2, 2026-09-08 验证）：
/// - C2C 固定 Olm fan-out（chat_network_service 逐设备加密）；
/// - C2G 固定 Megolm（群会话）；
/// - RSA-OAEP 是 decrypt-only legacy 套件（encrypt 直接抛
///   UnsupportedError，ADR 02 §5.2 防降级），**永不**作为任何 scope 的
///   可发送套件。
///
/// 因此防降级不依赖运行时协商结果——攻击者（服务端/MITM）伪造低能力
/// capability 声明无法使发送链降级，因为发送链不消费 capability。
/// 本策略在对端能力校验维度提供同一事实的显式 fail-closed 入口：
/// 对端（旧端）不支持 scope 固定套件 → 显式错误，而非降级或明文。
///
/// manifest 协商路径（[CapabilityNegotiator.negotiateWithManifest]）保留为
/// 已测纯函数，供后续接线判断（C07 范围）；两条路径的套件常量同源于
/// [ProtocolSuite]，不会漂移。
class FixedSuitePolicy {
  const FixedSuitePolicy._();

  /// scope（与 [E2eeContext.scope] 同约定）→ 固定套件短名。
  ///
  /// 未知 scope 抛 [ArgumentError]（fail-closed：不猜测、不默认）。
  static String requiredSuiteFor(String scope) {
    switch (scope) {
      case 'c2c':
        return ProtocolSuite.olm.protocol;
      case 'c2g':
        return ProtocolSuite.megolm.protocol;
      default:
        throw ArgumentError(
          'unknown scope "$scope": fixed suite policy only covers c2c/c2g '
          '(fail-closed, no default suite)',
        );
    }
  }

  /// 校验对端能力声明满足 scope 的固定套件要求；不满足抛
  /// [FixedSuiteIncompatibleException]（显式兼容错误）。
  ///
  /// 典型负例：旧端 `peerProtocols = {'rsa-oaep'}` 对 `scope: 'c2c'`
  /// （required=olm）→ 显式拒绝。空能力集合同样拒绝（fail-closed）。
  static void enforcePeerSupportsRequired({
    required String scope,
    required String peerDeviceId,
    required Set<String> peerProtocols,
  }) {
    final required = requiredSuiteFor(scope);
    if (!peerProtocols.contains(required)) {
      throw FixedSuiteIncompatibleException(
        scope: scope,
        requiredSuite: required,
        peerDeviceId: peerDeviceId,
        peerProtocols: peerProtocols,
      );
    }
  }
}
