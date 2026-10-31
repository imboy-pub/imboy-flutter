// integration_test/chat/j18a_send_retry_test.dart
//
// plan-v2.2 §9 J18.a（C2C/C2G 发送场景：发送失败后重试 → 失败可见、重试
// 同逻辑消息不重复）真机旅程，C2C 分支：
//   ① 登录 demo_alice → 打开与 demo_bob 的 C2C（harness 同 J18.d）
//   ② 测试内显式断开 WS（WebSocketService.closeSocket(permanent: true)，
//      无自动重连干扰，不依赖宿主 adb reverse 时序）
//   ③ WS 断开期间发送 marker 文本 → 观察消息进入非正向态（失败可见）
//   ④ 恢复 WS（openSocket）→ 经手动重试按钮（长按菜单「重试」）或离线
//      队列自动补发 → 消息进入正向已发送态
//   ⑤ 终态断言：恰好一条 marker 气泡（重试不重复）+ 稳定 id + 再观察期
//      内无第二气泡
//
// 与 j18d 同源 harness；运行契约（dart-define）见文件尾部注释。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_events.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peerUid = String.fromEnvironment('PEER_UID');
const _peerTitle = String.fromEnvironment('PEER_TITLE');

const _markerPrefix = '[J18A-RETRY]';

String _statusOf(WidgetTester t, String marker) {
  final f = itemContaining(marker);
  if (!t.any(f)) return '<no-item>';
  return t.widget<ChatMessageItem>(f.first).message.status?.toString() ??
      '<null>';
}

bool _settled(WidgetTester t, String marker) {
  final f = itemContaining(marker);
  if (!t.any(f)) return false;
  return settledStatuses.contains(
    t.widget<ChatMessageItem>(f.first).message.status,
  );
}

Future<bool> _waitSocketConnected(WidgetTester t, {int maxSeconds = 30}) async {
  var connected = false;
  final sub = AppEventBus.on<WebSocketStatusChangedEvent>().listen((e) {
    if (e.status == 'connected') connected = true;
  });
  try {
    for (var i = 0; i < maxSeconds * 2 && !connected; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
  } finally {
    await sub.cancel();
  }
  return connected;
}

Future<void> _retryViaMenu(WidgetTester t, String marker) async {
  final bubble = find.textContaining(marker, findRichText: true);
  expect(bubble, findsWidgets, reason: 'marker 气泡应在列表');
  await t.longPress(bubble.first);
  await settle(t, maxSeconds: 2);
  final retryAction = find.text('重试');
  final seen = t.any(retryAction);
  debugPrint('J18A retry-button-in-menu=$seen');
  if (!seen) {
    // 无手动重试按钮：产品走离线队列自动补发路径；点空白处关闭菜单。
    debugPrint('J18A no manual retry button; fallback to auto-resend path');
    await t.tapAt(const Offset(20, 120));
    await settle(t, maxSeconds: 1);
    return;
  }
  await safeTap(t, retryAction.first);
  await settle(t, maxSeconds: 2);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J18.a C2C：WS 断开发送失败可见，重试后同逻辑消息恰好一条', (tester) async {
    if (_expectedUid.isEmpty || _peerUid.isEmpty || _peerTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、PEER_UID、PEER_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    final chatPage = await openC2CWithPeer(
      tester,
      journey: 'J18.a',
      expectedUid: _expectedUid,
      peerUid: _peerUid,
      peerTitle: _peerTitle,
    );

    final nonce = DateTime.now().millisecondsSinceEpoch;
    final marker = '$_markerPrefix $nonce';

    // ② 显式断开 WS（permanent：不调度自动重连，窗口完全由测试控制）。
    await WebSocketService.to.closeSocket(permanent: true);
    await settle(tester, maxSeconds: 2);
    debugPrint('J18A socket closed before send');

    // ③ 断连期间发送。
    await sendTextViaInput(tester, chatPage, marker);
    await settle(tester, maxSeconds: 3);

    // ④ 失败可见：10s 内不得进入正向已发送态；记录 status 演化。
    var settledWhileOffline = false;
    var statuses = <String>[];
    for (var i = 0; i < 50; i++) {
      final s = _statusOf(tester, marker);
      if (statuses.isEmpty || statuses.last != s) {
        statuses.add(s);
        debugPrint('J18A offline status[$i]=$s');
      }
      settledWhileOffline = _settled(tester, marker);
      if (settledWhileOffline) break;
      await tester.pump(const Duration(milliseconds: 200));
    }
    await takeScreenshot(tester, 'j18a_01_offline_send');
    expect(
      settledWhileOffline,
      isFalse,
      reason: 'WS 断开期间消息不得进入正向已发送态（status 序列=$statuses）',
    );
    expect(
      tester.any(find.textContaining(marker, findRichText: true)),
      isTrue,
      reason: '失败/待发消息必须对本人可见（失败可见性）',
    );

    // ⑤ 恢复 WS 并等待重连。
    await WebSocketService.to.openSocket(from: 'j18a-test');
    final reconnected = await _waitSocketConnected(tester, maxSeconds: 30);
    debugPrint('J18A reconnected=$reconnected');
    expect(reconnected, isTrue, reason: 'openSocket 后 30s 内应恢复连接');

    // ⑥ 重试（手动按钮优先，缺失则观察自动补发）。
    await _retryViaMenu(tester, marker);
    final sent = await waitSent(tester, marker, maxSeconds: 40);
    await takeScreenshot(tester, 'j18a_02_after_retry');
    if (sent == null || !_settled(tester, marker)) {
      fail('重试后 40s 未进入正向已发送态（status=${_statusOf(tester, marker)}）');
    }
    final finalId = sent.id;
    expect(finalId, isNotEmpty, reason: '重试成功后应有稳定消息 id');

    // ⑦ 重试不重复：恰好一条 marker 气泡，且再观察 10s 不出现第二条。
    final oneBubble = itemContaining(marker).evaluate().length;
    debugPrint('J18A bubbles-after-retry=$oneBubble finalId=$finalId');
    expect(oneBubble, 1, reason: '重试必须复用同一条消息，不得产生重复气泡（实际 $oneBubble 条）');
    await settle(tester, maxSeconds: 10);
    expect(
      itemContaining(marker).evaluate().length,
      1,
      reason: '再观察 10s 后仍应恰好一条（终态无重复）',
    );
    expect(_settled(tester, marker), isTrue, reason: '终态应保持正向已发送态');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}

/*
运行（真机 MRD-AL00，设备 id XWE6R19916004085）：

  adb reverse tcp:9800 tcp:9800

  flutter test integration_test/chat/j18a_send_retry_test.dart \
    -d XWE6R19916004085 \
    --dart-define=APP_ENV=local_office \
    --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
    --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
    --dart-define=TEST_PHONE=demo_alice \
    --dart-define=TEST_PASSWORD=<pwd> \
    --dart-define=TEST_EXPECTED_UID=<alice-uid> \
    --dart-define=PEER_UID=<bob-uid> \
    --dart-define=PEER_TITLE=演示用户Bob \
    --dart-define=TEST_ALLOW_BUSINESS_WRITES=true

fixture 前置：demo_alice/demo_bob 互为好友（与 J18.c/d/e 同源合成库）。
*/
