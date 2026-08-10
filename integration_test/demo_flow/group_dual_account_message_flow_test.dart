// P0 群聊双账号消息闭环：复用已确认包含两个测试账号的测试群。
//
// 写入生产测试群属于受控业务写入，必须显式传入
// TEST_ALLOW_DUAL_GROUP_PROD_WRITES=true；本测试不创建、删除或修改群资料。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/model/message_model.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _groupId = String.fromEnvironment('TEST_GROUP_ID', defaultValue: '');
const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '',
);
const _dualRole = String.fromEnvironment(
  'TEST_DUAL_ROLE',
  defaultValue: 'receiver',
);
const _runId = String.fromEnvironment('TEST_DUAL_RUN_ID', defaultValue: '');
const _testWsUrl = String.fromEnvironment('TEST_WS_URL', defaultValue: '');
const _messageWaitSeconds = int.fromEnvironment(
  'TEST_MESSAGE_WAIT_SECONDS',
  defaultValue: 180,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '双账号 C2G 消息发送、接收和重进闭环',
    (tester) async {
      if (!_requireAuthorization()) return;

      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;

      final actualUid = UserRepoLocal.to.currentUid;
      if (_expectedUid.isNotEmpty && actualUid != _expectedUid) {
        markTestSkipped('当前 App 登录 UID 与目标账号不一致，拒绝向错误账号发送群消息');
        return;
      }

      await _ensureTestWebSocket(tester);
      if (!await _openConversationTab(tester)) {
        markTestSkipped('无法进入会话列表');
        return;
      }

      final groupConversation = await _waitForGroupConversation(tester);
      if (!await _enterGroupChat(tester, groupConversation)) return;
      if (!await _waitForChatPage(tester)) {
        try {
          if (groupConversation != null) {
            await tester.tapAt(tester.getCenter(groupConversation.first));
          }
          await settle(tester, maxSeconds: 1);
        } catch (_) {}
        if (!await _waitForChatPage(tester)) {
          markTestSkipped('目标 C2G 会话未进入聊天页面');
          return;
        }
      }

      final senderMarker = 'P0-GROUP-DUAL-A-$_runId';
      final receiverMarker = 'P0-GROUP-DUAL-B-$_runId';

      if (_dualRole == 'sender') {
        await _sendText(tester, senderMarker);
        await _waitForOutgoingAck(senderMarker);
        await _waitForMarker(tester, receiverMarker);
        await _assertLocalMessage(senderMarker);
        await _assertLocalMessage(receiverMarker);
      } else {
        await _waitForMarker(tester, senderMarker);
        await _assertLocalMessage(senderMarker);
        await _sendText(tester, receiverMarker);
        await _waitForOutgoingAck(receiverMarker);
        await _assertLocalMessage(receiverMarker);
      }

      expect(find.textContaining(senderMarker), findsWidgets);
      expect(find.textContaining(receiverMarker), findsWidgets);

      await _leaveChatPage(tester);
      await settle(tester, maxSeconds: 3);
      if (!await _openConversationTab(tester)) {
        fail('群聊发送/回复后无法回到会话列表');
      }
      final reopened = await _waitForGroupConversation(tester);
      if (!await _enterGroupChat(tester, reopened)) {
        fail('重进时无法重新进入目标 C2G 会话');
      }
      if (!await _waitForChatPage(tester)) fail('重进时未进入群聊页面');
      await _waitForMarker(tester, senderMarker);
      await _waitForMarker(tester, receiverMarker);
      await _assertLocalMessage(senderMarker);
      await _assertLocalMessage(receiverMarker);

      flowLog('群聊双账号消息闭环通过：$_dualRole，双方各一条，ACK、跨设备收发和重进回读完成');
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

bool _requireAuthorization() {
  const allowed = String.fromEnvironment(
    'TEST_ALLOW_DUAL_GROUP_PROD_WRITES',
    defaultValue: 'false',
  );
  if (allowed.toLowerCase() != 'true') {
    markTestSkipped(
      '群聊双账号测试会写入测试群，需显式设置 TEST_ALLOW_DUAL_GROUP_PROD_WRITES=true',
    );
    return false;
  }
  if (!FlowConfig.hasCredentials ||
      _groupId.isEmpty ||
      _runId.isEmpty ||
      _testWsUrl.isEmpty) {
    markTestSkipped('缺少测试群、账号、WebSocket 或 TEST_DUAL_RUN_ID');
    return false;
  }
  if (!{'sender', 'receiver'}.contains(_dualRole)) {
    markTestSkipped('TEST_DUAL_ROLE 只能是 sender 或 receiver');
    return false;
  }
  return true;
}

Future<void> _ensureTestWebSocket(WidgetTester tester) async {
  await StorageService.to.setString(Keys.wsUrl, _testWsUrl);
  for (var i = 0; i < 120; i++) {
    if (WebSocketService.to.status == SocketStatus.connected) {
      flowLog('群聊双账号测试 WebSocket 已连接');
      return;
    }
    if (WebSocketService.to.status == SocketStatus.disconnected) {
      await WebSocketService.to.openSocket(
        from: 'group_dual_account_flow_test',
      );
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  fail('群聊双账号测试 WebSocket 未在 60 秒内建立，拒绝继续发送消息');
}

bool _isConversationList(WidgetTester tester) =>
    tester.any(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'ConversationPage',
      ),
    ) ||
    (tester.any(find.byIcon(Icons.search)) &&
        tester.any(find.byIcon(Icons.add_circle_outline)));

Future<bool> _openConversationTab(WidgetTester tester) async {
  if (_isConversationList(tester)) return true;
  await tapAny(tester, [
    find.byKey(const Key('tab_conversations')),
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.chat_bubble_outline),
    find.text('消息'),
    find.text('会话'),
    find.text('Chats'),
  ]);
  for (var i = 0; i < 20; i++) {
    await settle(tester, maxSeconds: 1);
    if (_isConversationList(tester)) return true;
  }
  return false;
}

Future<Finder?> _waitForGroupConversation(WidgetTester tester) async {
  final target = find.byWidgetPredicate(
    (widget) =>
        widget is ConversationItem &&
        widget.model.type == 'C2G' &&
        widget.model.peerId.toString() == _groupId,
  );
  for (var i = 0; i < 120; i++) {
    if (tester.any(target)) return target;
    if (i == 20) _logVisibleGroupConversations(tester);
    await tester.pump(const Duration(milliseconds: 500));
  }
  _logVisibleGroupConversations(tester);
  return null;
}

Future<bool> _enterGroupChat(WidgetTester tester, Finder? conversation) async {
  if (conversation != null) {
    await safeTap(tester, conversation.first);
    return true;
  }

  // 某些账号有群成员关系，但服务端尚未生成 conversation/mine 项。
  // 只读核对群详情和成员后，直接走现有 ChatPage，不创建会话或群。
  final detail = await GroupApi().detail(gid: _groupId);
  final memberPayload = await GroupMemberApi().page(
    gid: _groupId,
    page: 1,
    size: 50,
  );
  final memberIds = _asList(
    memberPayload,
  ).map(_readMemberId).whereType<String>().toSet();
  if (!memberIds.containsAll(const {'50', '4'})) {
    markTestSkipped('目标群未确认同时包含 117/118 两个测试账号，拒绝发送群消息');
    return false;
  }

  final title = _readTitle(detail);
  final navigatorFinder = find.byType(Navigator);
  if (!tester.any(navigatorFinder)) {
    markTestSkipped('App 未找到根 Navigator，无法进入目标群聊天页');
    return false;
  }
  final navigator = Navigator.of(
    tester.element(navigatorFinder.first),
    rootNavigator: true,
  );
  navigator.push<void>(
    CupertinoPageRoute<void>(
      builder: (_) => ChatPage(
        type: 'C2G',
        peerId: _groupId,
        peerTitle: title.isEmpty ? '测试群' : title,
        peerAvatar: '',
        peerSign: '',
        options: {'memberCount': memberIds.length},
      ),
    ),
  );
  await settle(tester, maxSeconds: 2);
  flowLog('未找到 conversation/mine 项，已通过现有 ChatPage 直接进入已核对成员的测试群');
  return true;
}

List<dynamic> _asList(dynamic value) {
  if (value is List) return value;
  if (value is Map) {
    final nested = value['list'] ?? value['items'] ?? value['data'];
    return nested is List ? nested : const [];
  }
  return const [];
}

String? _readMemberId(dynamic value) {
  if (value is! Map) return null;
  final id =
      (value['uid'] ?? value['user_id'] ?? value['id'])?.toString() ?? '';
  return id.isEmpty ? null : id;
}

String _readTitle(dynamic value) {
  if (value is! Map) return '';
  return (value['title'] ?? value['name'])?.toString() ?? '';
}

void _logVisibleGroupConversations(WidgetTester tester) {
  final items = tester
      .widgetList<ConversationItem>(find.byType(ConversationItem))
      .where((item) => item.model.type == 'C2G')
      .map((item) => '${item.model.peerId}:${item.model.title}')
      .toList(growable: false);
  flowLog('当前可见 C2G 会话（仅诊断）: ${items.join(', ')}');
}

Future<bool> _waitForChatPage(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    if (tester.any(find.byType(ChatPage)) ||
        tester.any(find.byKey(const Key('chat_message_input'))) ||
        tester.any(find.byKey(const Key('send_button')))) {
      return true;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  return false;
}

Future<void> _sendText(WidgetTester tester, String marker) async {
  final input = find.byKey(const Key('chat_message_input'));
  if (!tester.any(input)) fail('群聊页面没有消息输入框');
  await tester.enterText(input, marker);
  await settle(tester, maxSeconds: 1);
  final sent = await tapAny(tester, [
    find.byKey(const Key('send_button')),
    find.byKey(const Key('send_button_inner')),
    find.byIcon(Icons.send),
  ]);
  if (!sent) fail('未找到群消息发送按钮');
  await _waitForMarker(tester, marker);
}

Future<void> _waitForOutgoingAck(String marker) async {
  for (var i = 0; i < 120; i++) {
    final rows = await SqliteService.to.query(
      MessageRepo.c2gTable,
      columns: MessageRepo.defaultColumns,
      where: '${MessageRepo.payload} LIKE ?',
      whereArgs: ['%$marker%'],
      orderBy: '${MessageRepo.createdAt} DESC',
      limit: 10,
    );
    for (final row in rows) {
      if (!'${row[MessageRepo.payload]}'.contains(marker)) continue;
      final rawStatus = row[MessageRepo.status];
      final status = rawStatus is int ? rawStatus : int.tryParse('$rawStatus');
      if (status == IMBoyMessageStatus.error) {
        fail('群消息进入 error，未获得服务端 ACK：$marker');
      }
      if (status == IMBoyMessageStatus.sent ||
          status == IMBoyMessageStatus.delivered ||
          status == IMBoyMessageStatus.seen) {
        flowLog('群消息服务端 ACK 已反映到本地：$marker，status=$status');
        return;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail('群消息未在 60 秒内反映服务端 ACK：$marker');
}

Future<void> _assertLocalMessage(String marker) async {
  final rows = await SqliteService.to.query(
    MessageRepo.c2gTable,
    columns: MessageRepo.defaultColumns,
    where: '${MessageRepo.payload} LIKE ?',
    whereArgs: ['%$marker%'],
    orderBy: '${MessageRepo.createdAt} DESC',
    limit: 10,
  );
  expect(
    rows.any((row) => '${row[MessageRepo.payload]}'.contains(marker)),
    isTrue,
    reason: '本地群消息表未找到 $marker',
  );
}

Future<void> _leaveChatPage(WidgetTester tester) async {
  final tapped = await tapAny(tester, [
    find.byType(CupertinoNavigationBarBackButton),
    find.byIcon(Icons.arrow_back),
  ]);
  if (!tapped) await tester.binding.handlePopRoute();
}

Future<void> _waitForMarker(WidgetTester tester, String marker) async {
  for (var i = 0; i < _messageWaitSeconds * 2; i++) {
    if (tester.any(find.textContaining(marker))) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
  fail('等待群消息超时：$marker');
}
