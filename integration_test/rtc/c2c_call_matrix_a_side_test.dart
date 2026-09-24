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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_page.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_state_machine.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'rtc_e2e_helpers.dart';

const _connectedHoldSeconds = int.fromEnvironment(
  'TEST_C2C_CONNECTED_HOLD_SECONDS',
);

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

    final app = find.byType(MaterialApp);
    final container = ProviderScope.containerOf(tester.element(app));
    // autoDispose provider：App 内部通常有全局监听保活；显式 listen 双保险。
    // ignore: unused_local_variable
    final keepAlive = container.listen(p2pCallScreenProvider, (_, _) {});

    // ── 1. 从真实通话页呼出：页面负责 offer/信令订阅/joinRoom ───────
    await openCallScreen(
      tester.element(app),
      ContactModel(peerId: int.parse(lkPeerUid), nickname: 'RTC B'),
      {'media': media},
      caller: true,
    );
    final callPage = find.byType(P2pCallScreenPage);
    final pageOpened = await pollUntil(
      () => tester.any(callPage),
      tester: tester,
      timeout: const Duration(seconds: 15),
    );
    expect(pageOpened, isTrue, reason: '主叫通话页未打开');
    final notifier = container.read(p2pCallScreenProvider.notifier);
    flowLog('[A] 真实通话页已打开 media=$media msgId=${notifier.msgId}');

    // ── 2. 等 B ringing（真实 WS 回流；超时 45s）─────────────────────────
    var okRinging = await pollUntil(
      () =>
          container.read(p2pCallScreenProvider).callStatus.phase ==
          CallPhase.ringing,
      tester: tester,
      timeout: const Duration(seconds: 45),
    );
    expect(okRinging, isTrue, reason: '未收到 B 侧 ringing 信令');
    flowLog('[A] 已收到 B 侧 ringing');

    // ── 3. 等 B answer 后由页面自动 joinRoom 并进入 connected ────────
    var okConnected = await pollUntil(
      () =>
          container.read(p2pCallScreenProvider).callStatus.phase ==
              CallPhase.connected &&
          notifier.room?.connectionState == lk.ConnectionState.connected,
      tester: tester,
      timeout: const Duration(seconds: 120),
    );
    expect(okConnected, isTrue, reason: 'B 未接听或双方未进入同一 LiveKit C2C Room（120s）');
    flowLog('[A] answer 已收到，LiveKit Room 已接通');

    // ── 4. 媒体到达：远端 track 订阅（B 侧也会 publish）──────────────────
    final room = notifier.room;
    final remoteTrackSeen =
        room != null &&
        await waitForExpectedRtcMedia(room, media: media, tester: tester);
    if (remoteTrackSeen) {
      flowLog('[A][PASS] $media 媒体已真实发送并到达');
    } else {
      fail(
        '$media 媒体未真实到达（视频必须有 camera track、发送帧、接收帧与非零尺寸；'
        '不得以任意 publication 计绿）',
      );
    }
    flowLog('[A] connected=$okConnected remoteTrack=$remoteTrackSeen');
    await takeScreenshot(tester, 'lk_a_call_connected');
    if (_connectedHoldSeconds > 0) {
      flowLog('[A][READY] 通话页保持 ${_connectedHoldSeconds}s 供人工观察');
      await Future<void>.delayed(Duration(seconds: _connectedHoldSeconds));
      await tester.pump();
    }

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
    final hangup = find.byIcon(CupertinoIcons.phone_down_fill);
    expect(tester.any(hangup), isTrue, reason: '通话页挂断按钮不可用');
    await tester.tap(hangup.last);
    final released = await pollUntil(
      () => !tester.any(callPage) && notifier.room == null,
      tester: tester,
      timeout: const Duration(seconds: 15),
    );
    expect(released, isTrue, reason: '挂断后通话页与 LiveKit Room 必须释放');
    flowLog('[A] 挂断完成，room 已释放');
    await takeScreenshot(tester, 'lk_a_call_ended');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
