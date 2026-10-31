// integration_test/chat/j18a_c2g_send_retry_test.dart
//
// plan-v2.2 §9 J18.a C2G 分支（群发送场景：发送失败后重试 → 失败可见、
// 重试同逻辑消息不重复）真机旅程，独立单用例脚本（仓库惯例：一脚本一
// 用例，避免同进程第二用例的入口状态残留）：
//   ① 登录 demo_alice → 会话列表 → 打开 J19C_DISSOLVE_GROUP 的 C2G
//   ② 测试内显式断开 WS（closeSocket(permanent:true)）
//   ③ WS 断开期间发送 marker → 非正向态（失败可见）
//   ④ openSocket 恢复 → 离线队列自动补发 → 正向已发送态
//   ⑤ 终态：恰好一条 marker 气泡 + 再观察期无重复
//
// fixture（已落合成库）：group 120619900000000003 'J19C_DISSOLVE_GROUP'
// （alice role=4 群主在群内 + 世代行 + timeline 种子 j19cfix0000001）。

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _groupId = String.fromEnvironment('TEST_GROUP_ID');
const _groupTitle = String.fromEnvironment('TEST_GROUP_TITLE');

const _markerPrefix = '[J18A-C2G-RETRY]';

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J18.a C2G：WS 断开发送失败可见，重试后同逻辑消息恰好一条', (tester) async {
    if (_expectedUid.isEmpty || _groupId.isEmpty || _groupTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、TEST_GROUP_ID、TEST_GROUP_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J18.a C2G 前置失败：登录未进入主界面');
    }
    if (UserRepoLocal.to.currentUid != _expectedUid) {
      fail('登录账号 UID=${UserRepoLocal.to.currentUid} 与授权操作者 $_expectedUid 不一致');
    }
    await settle(tester, maxSeconds: 2);
    await dismissRecoveryGuide(tester);
    await settle(tester, maxSeconds: 2);

    // 会话列表 → 目标群 C2G 会话。
    if (!await openConversationTab(tester)) {
      fail('无法进入会话列表');
    }
    await settle(tester, maxSeconds: 2);
    final groupItem = find.byWidgetPredicate(
      (widget) =>
          widget is ConversationItem &&
          widget.model.type == 'C2G' &&
          widget.model.peerId.toString() == _groupId,
    );
    var itemSeen = false;
    for (var i = 0; i < 20 && !itemSeen; i++) {
      itemSeen = tester.any(groupItem);
      if (!itemSeen) await settle(tester, maxSeconds: 1);
    }
    if (!itemSeen) {
      final all = tester.widgetList<ConversationItem>(
        find.byType(ConversationItem),
      );
      for (final m in all) {
        debugPrint(
          'J18A-C2G item peerId=${m.model.peerId} type=${m.model.type} '
          'title=${m.model.resolvedTitle}',
        );
      }
      fail('会话列表中无目标群 $_groupTitle (gid=$_groupId) 的 C2G 会话（fixture 缺失？）');
    }
    await safeTap(tester, groupItem.first);
    await settle(tester, maxSeconds: 3);
    final chatPage = find.byType(ChatPage);
    expect(chatPage, findsOneWidget, reason: '应进入群聊页');
    expect(
      tester.widget<ChatPage>(chatPage).peerId,
      _groupId,
      reason: '聊天对象必须等于目标群',
    );

    final nonce = DateTime.now().millisecondsSinceEpoch;
    final marker = '$_markerPrefix $nonce';

    // 断开 WS（permanent：无自动重连，窗口完全由测试控制）。
    await WebSocketService.to.closeSocket(permanent: true);
    await settle(tester, maxSeconds: 2);
    debugPrint('J18A-C2G socket closed before send');

    // 断连期间发送。
    await sendTextViaInput(tester, chatPage, marker);
    await settle(tester, maxSeconds: 3);
    var settledWhileOffline = false;
    for (var i = 0; i < 50 && !settledWhileOffline; i++) {
      settledWhileOffline = _settled(tester, marker);
      if (!settledWhileOffline) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }
    await takeScreenshot(tester, 'j18a_c2g_01_offline_send');
    expect(settledWhileOffline, isFalse, reason: 'WS 断开期间群消息不得进入正向已发送态');
    expect(
      tester.any(find.textContaining(marker, findRichText: true)),
      isTrue,
      reason: '失败/待发的群消息必须对本人可见',
    );

    // 恢复 WS → 自动补发。
    await WebSocketService.to.openSocket(from: 'j18a-c2g-test');
    final reconnected = await _waitSocketConnected(tester, maxSeconds: 30);
    debugPrint('J18A-C2G reconnected=$reconnected');
    expect(reconnected, isTrue, reason: 'openSocket 后 30s 内应恢复连接');
    final sent = await waitSent(tester, marker, maxSeconds: 40);
    await takeScreenshot(tester, 'j18a_c2g_02_after_retry');
    if (sent == null || !_settled(tester, marker)) {
      fail('群消息重试后 40s 未进入正向已发送态（status=${_statusOf(tester, marker)}）');
    }
    expect(
      itemContaining(marker).evaluate().length,
      1,
      reason: '群消息重试必须复用同一条消息，不得产生重复气泡',
    );
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
