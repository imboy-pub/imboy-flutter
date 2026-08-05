/// E2EE 协议注册引导（ADR 02 §2.2）。
///
/// 这是唯一 import 具体协议实现的地方——业务层（E2EEService）只跟
/// [E2eeProtocolRegistry] 抽象对话。[ensureRegistered] 幂等，可在启动序列
/// （AppInitializer）或首次 encrypt/decrypt 前调用，保证 resolve 前已注册。
///
/// MLS 不注册（ADR 02 §8 占位；`all()` 因此不含 mls）。
library;

import 'package:flutter/foundation.dart';

import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/megolm_protocol.dart';
import 'package:imboy/service/e2ee/olm_protocol.dart';
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

  /// 已完成 [E2eeSessionProtocol.initialize] 的用户；换账号时需重新初始化。
  static String? _initializedUid;

  /// 注册 **并** 初始化三套件（BUG#72）。
  ///
  /// `initialize` 此前在整个项目里**零调用点**——三个实现都写好了，但没人调。
  /// 后果是 `OlmProtocol._selfUid` 永远为 null，一旦服务端把
  /// `e2ee_mode` 打开，第一条单聊消息就抛
  /// `Bad state: OlmProtocol not initialized (missing self uid)`，
  /// 全站单聊直接不可用（2026-08-04 生产实测）。
  ///
  /// 幂等：同一 uid 只初始化一次；换账号（uid 变化）会重新初始化。
  static Future<void> ensureReady() async {
    ensureRegistered();

    final String uid = UserRepoLocal.to.currentUid;
    if (uid.isEmpty) return; // 未登录：没有身份可初始化，留给登录后再调
    if (_initializedUid == uid) return;

    final String deviceId = await DeviceExt.did;
    for (final impl in E2eeProtocolRegistry.registered()) {
      try {
        await impl.initialize(userId: uid, deviceId: deviceId);
      } on Object catch (e) {
        // 单个套件初始化失败不应拖垮其它套件（如 Megolm 失败不该挡住 Olm）；
        // 真正的失败会在 encrypt 时以明确异常暴露，这里只留痕。
        debugPrint(
          '[E2eeBootstrap] initialize ${impl.suite.protocol} failed: $e',
        );
      }
    }
    _initializedUid = uid;
  }

  /// 仅测试用：重置引导标志 + 清空注册表。
  static void resetForTest() {
    _registered = false;
    _initializedUid = null;
    E2eeProtocolRegistry.resetForTest();
  }
}
