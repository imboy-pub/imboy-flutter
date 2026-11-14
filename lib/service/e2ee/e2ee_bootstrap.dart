/// E2EE 协议注册引导（ADR 02 §2.2）。
///
/// 这是唯一 import 具体协议实现的地方——业务层（E2EEService）只跟
/// [E2eeProtocolRegistry] 抽象对话。[ensureRegistered] 幂等，可在启动序列
/// （AppInitializer）或首次 encrypt/decrypt 前调用，保证 resolve 前已注册。
///
/// MLS 不注册（ADR 02 §8 占位；`all()` 因此不含 mls）。
library;

import 'package:flutter/foundation.dart';
import 'package:synchronized/synchronized.dart';

import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/megolm_protocol.dart';
import 'package:imboy/service/e2ee/olm_protocol.dart';
import 'package:imboy/service/e2ee/policy_gate.dart';
import 'package:imboy/service/e2ee/rsa_legacy_protocol.dart';

class E2eeBootstrap {
  const E2eeBootstrap._();

  static bool _registered = false;

  /// 幂等注册 olm / megolm / rsa-oaep 三套件。重复调用无副作用。
  static void ensureRegistered() {
    if (_registered) return;
    E2eeProtocolRegistry.register(OlmProtocol());
    E2eeProtocolRegistry.register(MegolmProtocol());
    E2eeProtocolRegistry.register(RsaLegacyProtocol()); // 仅 decrypt
    _registered = true;
  }

  static final _initializationLock = Lock();
  static String? _initializedUid;
  static int? _initializedGeneration;
  static final _initializedProtocols = <String>{};

  /// 注册 **并** 初始化三套件（BUG#72）。
  ///
  /// `initialize` 此前在整个项目里**零调用点**——三个实现都写好了，但没人调。
  /// 后果是 `OlmProtocol._selfUid` 永远为 null，一旦服务端把
  /// `e2ee_mode` 打开，第一条单聊消息就抛
  /// `Bad state: OlmProtocol not initialized (missing self uid)`，
  /// 全站单聊直接不可用（2026-08-04 生产实测）。
  ///
  /// 成功套件按会话缓存；失败可重试。发送仅要求其使用的套件，
  /// 默认调用仍隔离可选套件失败，以兼容历史解密。
  static Future<void> ensureReady({ProtocolSuite? requiredSuite}) async {
    ensureRegistered();
    final repo = UserRepoLocal.to;
    final uid = repo.currentUid;
    final generation = repo.sessionGeneration;
    if (uid.isEmpty && requiredSuite == null) return;
    await _initializationLock.synchronized(() async {
      _requireCurrentSession(uid, generation);
      if (_initializedUid != uid || _initializedGeneration != generation) {
        _initializedUid = uid;
        _initializedGeneration = generation;
        _initializedProtocols.clear();
      }
      if (requiredSuite != null &&
          _initializedProtocols.contains(requiredSuite.protocol)) {
        return;
      }
      if (requiredSuite == null &&
          E2eeProtocolRegistry.registered().every(
            (impl) => _initializedProtocols.contains(impl.suite.protocol),
          )) {
        return;
      }
      await _initializePending(uid, generation);
      if (requiredSuite != null &&
          !_initializedProtocols.contains(requiredSuite.protocol)) {
        throw const E2eeSecurityException('e2ee_protocol_not_ready');
      }
    });
  }

  static void _requireCurrentSession(String uid, int generation) {
    final repo = UserRepoLocal.to;
    if (uid.isEmpty ||
        repo.isClearingSession ||
        repo.currentUid != uid ||
        !repo.isCurrentSession(generation)) {
      throw const E2eeSecurityException('outbound_session_changed');
    }
  }

  static Future<void> _initializePending(String uid, int generation) async {
    final String deviceId = await DeviceExt.did;
    _requireCurrentSession(uid, generation);
    for (final impl in E2eeProtocolRegistry.registered()) {
      if (_initializedProtocols.contains(impl.suite.protocol)) continue;
      try {
        await impl.initialize(userId: uid, deviceId: deviceId);
        _requireCurrentSession(uid, generation);
        _initializedProtocols.add(impl.suite.protocol);
      } on Object catch (e) {
        debugPrint(
          '[E2eeBootstrap] initialize ${impl.suite.protocol} failed: ${e.runtimeType}',
        );
      }
      _requireCurrentSession(uid, generation);
    }
  }

  /// 仅测试用：标记指定用户已完成协议初始化，避免平台集成测试触发网络注册。
  ///
  /// 这只跳过 Olm identity 的远端注册，不替代协议注册；需要实际验证 Olm
  /// 初始化的测试仍应调用 [ensureReady]，而不应使用此入口。
  static void debugMarkReadyForTest(String uid) {
    ensureRegistered();
    for (final impl in E2eeProtocolRegistry.registered()) {
      if (impl is OlmProtocol) {
        impl.debugMarkReadyForTest(uid);
      }
    }
    _initializedUid = uid;
    _initializedGeneration = UserRepoLocal.to.sessionGeneration;
    _initializedProtocols
      ..clear()
      ..addAll(const ['olm', 'megolm', 'rsa-oaep']);
  }

  /// 仅测试用：重置引导标志 + 清空注册表。
  static void resetForTest() {
    _registered = false;
    _initializedUid = null;
    _initializedGeneration = null;
    _initializedProtocols.clear();
    E2eeProtocolRegistry.resetForTest();
  }
}
