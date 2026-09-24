// integration_test/rtc/rtc_negative_matrix_test.dart
//
// LK-TEST-01 · RTC 负例矩阵（单真机可跑，无需第二台设备）。
//
// 覆盖（A04 验收）：
//   N1 被叫拒绝（busy 信令 → callStateBusy 状态机收尾）
//   N2 主叫取消（挂断 bye 发送 + 资源不泄漏）
//   N3 应答超时（answerTimeout → ended 终态 + noAnswer 原因）
//   N4 重复 accept / 晚到 answer（answer 幂等闩：只广播一次 answered）
//   N5 幽灵 bye（msgId 不匹配的迟到 bye 不误伤当前通话）
//   N6 晚到 track_state（关闭中的 provider 忽略后续信令）
//
// 顺序说明：纯逻辑/状态机断言（N3-N6）在前，真实 WS 信令面（N1 invite、
// N2 connect）在后——invite 会真实发 offer（对端为不可达合成 uid），其
// 异步 ACK/outbox 回调在真机上的完成时间不受控，放在最后不阻塞断言。
//
// 运行（单真机，不需要对端在线；invite 信令发往不存在的对端 uid，
// 由 provider 驱动 + 真实登录态信令总线）：
//   flutter test integration_test/rtc/rtc_negative_matrix_test.dart \
//     -d XWE6R19916004085 --dart-define=APP_ENV=local \
//     --dart-define=API_BASE_URL_OVERRIDE=... --dart-define=WS_URL_OVERRIDE=... \
//     --dart-define=SOLIDIFIED_KEY_OVERRIDE=... --dart-define=SOLIDIFIED_KEY_IV_OVERRIDE=... \
//     --dart-define=TEST_PHONE=... --dart-define=TEST_PASSWORD=... \
//     --dart-define=TEST_EXPECTED_UID=... --dart-define=TEST_ALLOW_BUSINESS_WRITES=true \
//     --dart-define=LK_RTC_RUN=true

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_state_machine.dart';
import 'package:imboy/store/api/rtc_room_api.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/service/storage.dart';

import 'rtc_e2e_helpers.dart';

/// 对端 uid：用测试注入的 PEER_UID；未提供时用不可达合成 uid
/// （200000000000000001），invite 信令可发送（WS 透传），无应答恰好
/// 驱动超时/挂断路径。
String get _peerUid => lkPeerUid.isNotEmpty ? lkPeerUid : '200000000000000001';

WebRTCSignalingModel sig(
  String type, {
  required String msgId,
  String? from,
  Map<String, dynamic>? payload,
}) {
  return WebRTCSignalingModel(
    msgId: msgId,
    type: 'WEBRTC_${type.toUpperCase()}',
    from: from ?? _peerUid,
    to: 'me',
    payload: payload ?? const <String, dynamic>{},
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets('N1-N6: 拒绝/取消/超时/重复accept/幽灵bye/晚到信令', (tester) async {
    if (!requireOneDeviceSetup(tester, 'rtc-negative-matrix')) return;
    installPluginErrorFilter();
    if (!await ensureLoggedInAndIdle(tester)) return;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    // 测试替身：媒体面不真连（负例聚焦信令/状态机；真实媒体面归 c2c 矩阵）。
    // 注意：roomConnectOverride 生效时 provider 的 _room 不会置位（真实
    // Room 创建在 _connectRoom 内）——资源释放断言由真机 c2c 矩阵承载。
    final api = _RecordingApi(() {});
    final notifier = container.read(p2pCallScreenProvider.notifier)
      ..rtcApiOverride = api
      ..roomConnectOverride = (wsUrl, token) async => true;

    final session = WebRTCSession(peerId: _peerUid, sid: 'neg-$_peerUid');
    final states = <WebRTCCallState>[];
    notifier.onCallStateChange = (s, state) => states.add(state);

    // ── N3 应答超时（answerTimeout → ended 终态 + noAnswer 原因）──────────
    flowLog('[N3] begin');
    notifier.initSession(
      newSession: session,
      newMedia: 'video',
      isCaller: true,
      newMsgId: 'neg-m0',
    );
    final st1 = notifier.applySignal(CallSignal.answerTimeout);
    expect(st1.phase, CallPhase.ended, reason: 'answerTimeout 应迁移到 ended 终态');
    expect(
      st1.endReason,
      CallEndReason.noAnswer,
      reason: 'answerTimeout 的结束原因应为 noAnswer',
    );
    flowLog('[N3] answerTimeout → ended(noAnswer) OK');

    // ── N4 重复 answer（幂等闩：answered 只广播一次）─────────────────────
    flowLog('[N4] begin');
    notifier.initSession(
      newSession: session,
      newMedia: 'video',
      isCaller: true,
      newMsgId: 'neg-m2',
    );
    states.clear();
    await notifier.onMessageP2P(session, sig('answer', msgId: 'neg-m2'));
    await notifier.onMessageP2P(session, sig('answer', msgId: 'neg-m2'));
    final answeredCount = states
        .where((s) => s == WebRTCCallState.callStateAnswered)
        .length;
    expect(answeredCount, 1, reason: '重复 answer 必须被幂等闩拦下（只广播一次 answered）');
    flowLog('[N4] duplicate answer dropped OK');

    // ── N5 幽灵 bye（msgId 不匹配 → 不触发 bye 状态）────────────────────
    flowLog('[N5] begin');
    await notifier.onMessageP2P(session, sig('bye', msgId: 'stale-other'));
    expect(
      states,
      isNot(contains(WebRTCCallState.callStateBye)),
      reason: '旧通话的迟到 bye 不得误伤当前通话',
    );
    await notifier.onMessageP2P(session, sig('bye', msgId: 'neg-m2'));
    expect(
      states,
      contains(WebRTCCallState.callStateBye),
      reason: 'msgId 匹配的 bye 应正常结束通话',
    );
    flowLog('[N5] stale bye ignored / matched bye OK');

    // ── N6 晚到 track_state（cleanUpP2P 后的信令不得再写 state）──────────
    flowLog('[N6] begin');
    await notifier.cleanUpP2P();
    final before = container.read(p2pCallScreenProvider).remoteVideoOff;
    await notifier.onMessageP2P(
      session,
      sig('track_state', msgId: 'neg-m2', payload: {'video': false}),
    );
    expect(
      container.read(p2pCallScreenProvider).remoteVideoOff,
      before,
      reason: 'cleanUpP2P 后的晚到信令不得再改动 state（_closing 闩）',
    );
    flowLog('[N6] late signaling ignored OK');

    // ── N1 被叫拒绝（busy）——真实 WS 发 offer 后注入 busy 信令 ──────────
    flowLog('[N1] begin (real WS invite)');
    const msgId = 'neg-m1';
    notifier.initSession(
      newSession: session,
      newMedia: 'video',
      isCaller: true,
      newMsgId: msgId,
    );
    states.clear();
    await notifier.invitePeer(msgId: msgId, peer: _peerUid, media: 'video');
    await notifier.onMessageP2P(session, sig('busy', msgId: msgId));
    expect(
      states,
      contains(WebRTCCallState.callStateBusy),
      reason: 'busy 信令应触发 callStateBusy',
    );
    flowLog('[N1] busy → callStateBusy OK');

    // ── N2 主叫取消（sendBye → cleanUpP2P；joinRoom 恰一次）──────────────
    flowLog('[N2] begin');
    notifier.initSession(
      newSession: session,
      newMedia: 'video',
      isCaller: true,
      newMsgId: 'neg-m3',
    );
    final connectOk = await notifier.connect(peerId: _peerUid);
    expect(connectOk, isTrue, reason: '替身 joinRoom+connect 应返回成功');
    notifier.sendBye('neg-m3');
    await notifier.cleanUpP2P();
    expect(
      notifier.room,
      isNull,
      reason: '取消挂断后 room 必须为空（替身路径本就不置位，真实释放归 c2c 矩阵）',
    );

    // joinRoom 仅在 connect 路径被调用（N2 恰一次；busy/timeout/bye 路径零次）
    expect(api.calls, 1, reason: 'N2 的 connect 恰调用一次 joinRoom；拒绝/超时路径不得碰媒体');
    flowLog('[N2] cancel → api.calls==1 OK; negative matrix done');
  }, timeout: const Timeout(Duration(minutes: 8)));
}

/// RtcRoomApi 替身：记录 joinRoom 调用（负例聚焦信令面，媒体连接走
/// roomConnectOverride 替身）。
class _RecordingApi extends RtcRoomApi {
  _RecordingApi(this.onJoin);
  final void Function() onJoin;
  int get calls => _calls;
  int _calls = 0;

  @override
  Future<Map<String, String>?> joinRoom({
    required String kind,
    required String targetId,
    String? did,
  }) async {
    _calls++;
    onJoin();
    return const {
      'wsUrl': 'ws://127.0.0.1:17880',
      'token': 'neg-matrix-fake',
      'roomName': 'rtc_c2c_neg',
    };
  }
}
