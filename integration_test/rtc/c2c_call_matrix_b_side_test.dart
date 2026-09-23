// integration_test/rtc/c2c_call_matrix_b_side_test.dart
//
// LK-TEST-01 · c2c 语音/视频呼叫矩阵 · 被叫 B 侧（真机）。
//
// 链路：B 登录并保持 WS 在线 → 等 A 的 offer（来电全屏 IncomingCallView）→
// 接听（answer 信令 + joinRoom c2c）→ 双端媒体到达（remote track）→
// 等 A 挂断（bye）→ 资源释放。覆盖：被叫拒绝（第二用例）与晚到信令
// 容忍（重复 answer 幂等在 A 侧由 provider 闩保证，本侧验证 accept 后
// 通话页稳定）。
//
// 编排：先起本测试（B 侧等待来电），再起 A 侧。
// 运行（真机 B）：
//   flutter test integration_test/rtc/c2c_call_matrix_b_side_test.dart \
//     -d <B serial> --dart-define=APP_ENV=local \
//     --dart-define=API_BASE_URL_OVERRIDE=http://192.168.x.x:19880 \
//     --dart-define=WS_URL_OVERRIDE=ws://192.168.x.x:19880/api/v1/ws \
//     --dart-define=TEST_PHONE=<B账号> --dart-define=TEST_PASSWORD=<B密码> \
//     --dart-define=TEST_EXPECTED_UID=<B uid> --dart-define=PEER_UID=<A uid> \
//     --dart-define=LK_RTC_MEDIA=video --dart-define=LK_RTC_RUN=true \
//     --dart-define=LK_RTC_B_CASE=accept   # accept | decline
//
// 前置：两台真机；A/B 本地合成账号互为好友；后端+LiveKit 为
// rtc_e2e_test.sh KEEP=1 产物。任一设备不在线 → BLOCKED_DEVICE。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/webrtc/enum.dart';
import 'package:imboy/page/chat/p2p_call_screen/incoming_call_view.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

import 'rtc_e2e_helpers.dart';

const _bCase = String.fromEnvironment('LK_RTC_B_CASE', defaultValue: 'accept');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('c2c 呼叫矩阵 B 侧: 来电→接听/拒绝→媒体/信令回收', (tester) async {
    if (!requireTwoDeviceSetup(tester, 'c2c-b-side')) return;
    if (lkPeerUid.isEmpty) {
      markTestSkipped('c2c-b-side: 需 PEER_UID');
      return;
    }
    installPluginErrorFilter();
    if (!await ensureLoggedInAndIdle(tester)) return;

    final actualUid = UserRepoLocal.to.currentUid;
    if (actualUid != lkExpectedUid) {
      fail('本机 uid=$actualUid 与 TEST_EXPECTED_UID=$lkExpectedUid 不符');
    }

    // ── 1. 等来电（IncomingCallView 由真实 WS offer 触发，60s 铃窗）──────
    final incoming = find.byType(IncomingCallView);
    var okIncoming = await pollUntil(
      () => tester.any(incoming),
      timeout: const Duration(seconds: 240),
      onTick: (p) => flowLog('[B] 等待来电…$p'),
    );
    expect(okIncoming, isTrue, reason: '240s 内未收到 A 的来电（offer 信令未达）');
    await takeScreenshot(tester, 'lk_b_incoming');

    if (_bCase == 'decline') {
      // ── 拒绝路径：tap 拒绝 → 弹窗关闭 → A 侧应收到 busy ────────────────
      final declineBtn = find.text('拒绝');
      if (!tester.any(declineBtn)) {
        markTestSkipped('来电视图按钮文案与预期不符（locale 差异）');
        return;
      }
      await tester.tap(declineBtn);
      await settle(tester, maxSeconds: 3);
      var closed = await pollUntil(
        () => !tester.any(incoming),
        timeout: const Duration(seconds: 10),
      );
      expect(closed, isTrue, reason: '拒绝后来电视图应关闭');
      flowLog('[B] 已拒绝（busy 信令已发）');
      return;
    }

    // ── 2. 接听：tap 接听 → answer 信令 → joinRoom c2c → Room 接通 ──────
    final answerBtn = find.text('接听');
    if (!tester.any(answerBtn)) {
      markTestSkipped('来电视图按钮文案与预期不符（locale 差异）');
      return;
    }
    await tester.tap(answerBtn);
    await settle(tester, maxSeconds: 5);

    // accept 后 app 通过 overlay 挂 P2pCallScreenPage；provider 进入连接。
    // 给 overlay 帧时间后取 container。
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    // autoDispose provider：App 内部通常有全局监听保活；显式 listen 双保险。
    // ignore: unused_local_variable
    final keepAlive = container.listen(p2pCallScreenProvider, (_, _) {});
    final notifier = container.read(p2pCallScreenProvider.notifier);

    // 媒体真值（假绿修复）：只认 ICE 真值 room.connectionState==connected；
    // provider.connected 可能早于 ICE 建立，不再作为通过判据（仅辅助日志）。
    var okConnected = await pollUntil(
      () => notifier.room?.connectionState == lk.ConnectionState.connected,
      timeout: const Duration(seconds: 45),
      onTick: (p) => flowLog('[B] 等待媒体接通…$p'),
    );
    final roomConnected =
        notifier.room?.connectionState == lk.ConnectionState.connected;
    flowLog(
      '[B] roomConnected=$roomConnected stateConnected=${container.read(p2pCallScreenProvider).connected}',
    );
    expect(
      okConnected,
      isTrue,
      reason:
          '接听后 45s 未接通——ICE 真值 room.connectionState 必须 connected'
          '（joinRoom/LiveKit；provider 状态不单独计绿）',
    );

    // ── 3. 媒体到达：远端 track（A 的发布）───────────────────────────────
    var remoteTrackSeen = false;
    final room = notifier.room;
    if (room != null) {
      remoteTrackSeen = room.remoteParticipants.values.any(
        (p) => p.trackPublications.isNotEmpty,
      );
      if (!remoteTrackSeen) {
        final listener = room.createListener();
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
      flowLog('[B][PASS] 已订阅 A 的 track');
    } else {
      fail(
        '未订阅到 A 的 track（Required：双端真实发布/订阅是 LK-TEST-01 验收项，'
        '不得以 DEGRADED 计绿；媒体权限缺失属环境问题，修复授权后重跑）',
      );
    }
    await takeScreenshot(tester, 'lk_b_call_connected');

    // ── 4. 等 A 挂断（bye 信令 → callStateBye → 页面收尾）───────────────
    final states = <WebRTCCallState>[];
    notifier.onCallStateChange = (s, state) {
      flowLog('[B] callState=$state');
      states.add(state);
    };
    var okBye = await pollUntil(
      () => states.contains(WebRTCCallState.callStateBye),
      timeout: const Duration(seconds: 120),
      onTick: (p) => flowLog('[B] 通话中…等 A 挂断 $p'),
    );
    expect(okBye, isTrue, reason: '120s 内未收到 A 的 bye');
    flowLog('[B] 收到 bye，通话结束');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
