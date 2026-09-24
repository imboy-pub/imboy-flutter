// integration_test/rtc/c2c_call_matrix_a_side_test.dart
//
// LK-TEST-01 · c2c 语音/视频呼叫矩阵 · 主叫 A 侧（真机）。
//
// 链路：A 登录 → 驱动 P2pCallScreenNotifier 发 offer 信令（真实 WS 发送）→
// 收 B ringing → 收 B answer → connect(joinRoom kind=c2c → LiveKit Room)→
// 双端媒体到达（remote track 订阅）→ 静音/摄像头切换 → 挂断 → 资源释放。
//
// 编排：先起 B 侧（c2c_call_matrix_b_side_test.dart），再起本测试。
// 运行（真机 A，示例 Android）：
//   flutter test integration_test/rtc/c2c_call_matrix_a_side_test.dart \
//     -d XWE6R19916004085 \
//     --dart-define=APP_ENV=local \
//     --dart-define=API_BASE_URL_OVERRIDE=http://192.168.x.x:19880 \
//     --dart-define=WS_URL_OVERRIDE=ws://192.168.x.x:19880/api/v1/ws \
//     --dart-define=TEST_PHONE=<A账号> --dart-define=TEST_PASSWORD=<A密码> \
//     --dart-define=TEST_EXPECTED_UID=<A uid> --dart-define=PEER_UID=<B uid> \
//     --dart-define=LK_RTC_MEDIA=video --dart-define=LK_RTC_RUN=true
//
// 前置：两台真机（Android XWE6R19916004085 / iPhone 00008140-...，任一不在线
// 则整组标 BLOCKED_DEVICE）；后端为本地 imboy 节点 + 本地 LiveKit（rtc_e2e_test.sh
// KEEP=1 产出）；A/B 为本地合成账号且互为好友。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:xid/xid.dart';

import 'rtc_e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('c2c 呼叫矩阵 A 侧: 呼出→响铃→接通→媒体→静音/翻转→挂断释放', (tester) async {
    if (!requireTwoDeviceSetup(tester, 'c2c-a-side')) return;
    if (lkPeerUid.isEmpty) {
      markTestSkipped('c2c-a-side: 需 PEER_UID');
      return;
    }
    installPluginErrorFilter();
    final media = lkMedia == 'audio' ? 'audio' : 'video';
    if (!await ensureLoggedInAndIdle(tester)) return;

    final actualUid = UserRepoLocal.to.currentUid;
    if (actualUid != lkExpectedUid) {
      fail('本机 uid=$actualUid 与 TEST_EXPECTED_UID=$lkExpectedUid 不符');
    }

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    // autoDispose provider：App 内部通常有全局监听保活；显式 listen 双保险。
    // ignore: unused_local_variable
    final keepAlive = container.listen(p2pCallScreenProvider, (_, _) {});
    final notifier = container.read(p2pCallScreenProvider.notifier);

    final msgId = (Xid()).toString();
    final session = WebRTCSession(peerId: lkPeerUid, sid: 'a-$msgId');
    notifier.initSession(
      newSession: session,
      newMedia: media,
      isCaller: true,
      newMsgId: msgId,
    );

    // ── 1. 呼出（真实信令，经 AppEventBus → WS）───────────────────────────
    final callStates = <WebRTCCallState>[];
    notifier.onCallStateChange = (s, state) {
      flowLog('[A] callState=$state');
      callStates.add(state);
    };
    await notifier.invitePeer(msgId: msgId, peer: lkPeerUid, media: media);
    flowLog('[A] offer 已发送 msgId=$msgId media=$media');

    // ── 2. 等 B ringing（真实 WS 回流；超时 45s）─────────────────────────
    var okRinging = await pollUntil(
      () => callStates.contains(WebRTCCallState.callStateRinging),
      timeout: const Duration(seconds: 45),
    );
    expect(okRinging, isTrue, reason: '未收到 B 侧 ringing 信令');

    // ── 3. 等 B answer → connect 成功────────────────────────────────────
    var okAnswer = await pollUntil(
      () => callStates.contains(WebRTCCallState.callStateAnswered),
      timeout: const Duration(seconds: 90),
    );
    expect(okAnswer, isTrue, reason: 'B 未接听（90s）');

    // 防悬挂：connect 竞速 60s（对端/权限异常时给出阶段结论而非盲等）。
    bool connectOk;
    try {
      connectOk = await notifier
          .connect(peerId: lkPeerUid)
          .timeout(const Duration(seconds: 60));
    } on Exception catch (e) {
      flowLog('[A] connect exception: $e');
      connectOk = false;
    }
    // 媒体真值：provider.connected 要等 setMicrophoneEnabled 完成；无权限
    // 设备会悬挂，故以 room.connectionState 为准（provider 状态为辅）。
    var roomConnected = await pollUntil(
      () => notifier.room?.connectionState == lk.ConnectionState.connected,
      timeout: const Duration(seconds: 30),
    );
    var okConnected = await pollUntil(
      () => container.read(p2pCallScreenProvider).connected,
      timeout: const Duration(seconds: 5),
    );
    flowLog(
      '[A] connectOk=$connectOk roomConnected=$roomConnected stateConnected=$okConnected',
    );
    expect(
      roomConnected,
      isTrue,
      reason:
          'joinRoom(c2c)/LiveKit 媒体未接通——ICE 真值 room.connectionState 必须 '
          'connected（connectOk=$connectOk stateConnected=$okConnected 仅为辅助；'
          '假绿修复：connect() 返回值/provider 状态不再单独计绿）',
    );

    // ── 4. 媒体到达：远端 track 订阅（B 侧也会 publish）──────────────────
    var remoteTrackSeen = false;
    final room = notifier.room;
    if (room != null) {
      remoteTrackSeen = room.remoteParticipants.values.any(
        (p) => p.trackPublications.isNotEmpty,
      );
      if (!remoteTrackSeen) {
        // B 接通后 track 需要秒级传播；轮询 30s。
        var listener = room.createListener();
        final got = Completer<void>();
        listener.on<lk.TrackSubscribedEvent>((_) {
          if (!got.isCompleted) got.complete();
        });
        remoteTrackSeen = await got.future
            .timeout(const Duration(seconds: 30))
            .then((_) => true)
            .catchError((_) => false);
        await listener.dispose();
      }
    }
    if (remoteTrackSeen) {
      flowLog('[A][PASS] remote track 已订阅（B 侧发布成功）');
    } else {
      fail(
        '未订阅到远端 track（Required：双端真实发布/订阅是 LK-TEST-01 验收项，'
        '不得以 DEGRADED 计绿；B 侧媒体权限缺失属环境问题，修复授权后重跑）',
      );
    }
    flowLog('[A] connected=$okConnected remoteTrack=$remoteTrackSeen');
    await takeScreenshot(tester, 'lk_a_call_connected');

    // ── 5. 静音 / 摄像头切换（状态断言 + 不抛错）─────────────────────────
    await notifier.turnMicrophone();
    expect(
      container.read(p2pCallScreenProvider).micOff,
      isTrue,
      reason: '静音后 micOff 应为 true',
    );
    await notifier.turnMicrophone();
    expect(
      container.read(p2pCallScreenProvider).micOff,
      isFalse,
      reason: '取消静音后 micOff 应为 false',
    );
    if (media == 'video') {
      final before = container.read(p2pCallScreenProvider).isFrontCamera;
      await notifier.switchCamera();
      expect(
        container.read(p2pCallScreenProvider).isFrontCamera != before,
        isTrue,
        reason: '前后摄像头切换应翻转 isFrontCamera',
      );
      await notifier.turnCamera();
      expect(
        container.read(p2pCallScreenProvider).cameraOff,
        isTrue,
        reason: '关闭摄像头后 cameraOff 应为 true',
      );
      await notifier.turnCamera();
    }

    // ── 6. 挂断 → 资源释放────────────────────────────────────────────────
    notifier.sendBye(msgId);
    await notifier.cleanUpP2P();
    expect(notifier.room, isNull, reason: '挂断后 LiveKit Room 必须释放');
    flowLog('[A] 挂断完成，room 已释放');
    await takeScreenshot(tester, 'lk_a_call_ended');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
