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
