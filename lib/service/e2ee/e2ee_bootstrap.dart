/// E2EE 协议注册引导（ADR 02 §2.2）。
///
/// 这是唯一 import 具体协议实现的地方——业务层（E2EEService）只跟
/// [E2eeProtocolRegistry] 抽象对话。[ensureRegistered] 幂等，可在启动序列
/// （AppInitializer）或首次 encrypt/decrypt 前调用，保证 resolve 前已注册。
///
/// MLS 不注册（ADR 02 §8 占位；`all()` 因此不含 mls）。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/megolm_protocol.dart';
import 'package:imboy/service/e2ee/olm_protocol.dart';
import 'package:imboy/service/e2ee/rsa_legacy_protocol.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/safety_number_service.dart';

class E2eeBootstrap {
  const E2eeBootstrap._();

  static bool _registered = false;

  /// AC-15 信任生命周期常驻接线的安装标志。
  static bool _trustWiringInstalled = false;
  static List<StreamSubscription<void>>? _trustSubscriptions;

  /// 幂等注册 olm / megolm / rsa-oaep 三套件。重复调用无副作用。
  static void ensureRegistered() {
    if (_registered) return;
    E2eeProtocolRegistry.register(OlmProtocol());
    E2eeProtocolRegistry.register(MegolmProtocol());
    E2eeProtocolRegistry.register(RsaLegacyProtocol()); // 仅 decrypt
    _registered = true;
  }

  /// AC-15：安装信任生命周期常驻订阅（幂等）。
  ///
  /// 对端身份换钥 / 信任撤销的 S2C 事件在 `message_s2c` 已被转换为
  /// AppEventBus 事件（E2EEPeerKeyChangedEvent / E2EETrustChangedEvent），
  /// 并完成密钥缓存清理与 Olm 会话驱逐；本接线补上**本地安全码信任标记**
  /// 的同步失效——否则「已验证」标记会在换钥后静默沿用（C01 后端
  /// identity_version 推进 → 客户端本地信任必须跟着过期）。
  static Future<void> ensureTrustWiring() async {
    if (_trustWiringInstalled) return;
    _trustWiringInstalled = true;

    final subs = <StreamSubscription<void>>[];

    // 换钥（e2ee_key_changed）：对端某设备 identity key 变更。
    // 语义：该 peer 的聚合安全码必然变化，旧「已验证」立即失效。
    subs.add(
      AppEventBus.on<E2EEPeerKeyChangedEvent>().listen((event) {
        unawaitedFn(
          SafetyNumberService.invalidateTrust(event.uid, 'peer_key_changed'),
        );
      }),
    );

    // 信任撤销（e2ee_trust_changed → revoked/unverified）：只有本机是
    // actor、目标是其他用户时，本地对该 peer 的验证标记才随之失效
    // （与 message_s2c._handleE2EETrustChanged 的驱逐范围判定一致）。
    subs.add(
      AppEventBus.on<E2EETrustChangedEvent>().listen((event) {
        if (event.toState == 'verified') return;
        final currentUid = _currentUidOrEmpty();
        if (currentUid.isEmpty) return;
        if (event.actorUid == currentUid && event.targetUid != currentUid) {
          unawaitedFn(
            SafetyNumberService.invalidateTrust(
              event.targetUid,
              'trust_${event.toState}',
            ),
          );
        }
      }),
    );

    _trustSubscriptions = subs;
  }

  static String _currentUidOrEmpty() {
    try {
      return UserRepoLocal.to.currentUid;
    } on Object {
      return '';
    }
  }

  /// fire-and-forget 辅助：后台信任失效失败只留痕，不打断事件流。
  static void unawaitedFn(Future<void> future) {
    future.catchError((Object e) {
      debugPrint('[E2eeBootstrap] trust invalidation failed: ${e.runtimeType}');
    });
  }

  /// 仅测试用：拆除信任接线订阅。
  static void resetTrustWiringForTest() {
    _trustWiringInstalled = false;
    final subs = _trustSubscriptions;
    _trustSubscriptions = null;
    if (subs != null) {
      for (final s in subs) {
        // cancel 返回 Future，测试拆卸无需等待（进程内事件流即将销毁）
        s.cancel();
      }
    }
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
    // AC-15：协议引导的同时安装信任生命周期常驻接线（幂等）。
    unawaitedFn(Future.sync(ensureTrustWiring));

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
          '[E2eeBootstrap] initialize ${impl.suite.protocol} failed: ${e.runtimeType}',
        );
      }
    }
    _initializedUid = uid;
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
  }

  /// 仅测试用：重置引导标志 + 清空注册表。
  static void resetForTest() {
    _registered = false;
    _initializedUid = null;
    resetTrustWiringForTest();
    E2eeProtocolRegistry.resetForTest();
  }
}
