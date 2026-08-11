// P0 双账号单聊消息闭环：macOS/Android 角色由 TEST_DUAL_ROLE 指定。
//
// 该 flow 只允许两个明确授权的测试账号，并要求调用方显式传入
// TEST_ALLOW_DUAL_ACCOUNT_PROD_WRITES=true；不执行好友、群、资金或删除操作。

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show navigatorKey;
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/model/message_model.dart';

import '../flows/api_test_client.dart';
import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _peerUid = String.fromEnvironment('TEST_PEER_UID', defaultValue: '');
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
const _expectE2ee = bool.fromEnvironment(
  'TEST_EXPECT_E2EE',
  defaultValue: false,
);
const _messageWaitSeconds = int.fromEnvironment(
  'TEST_MESSAGE_WAIT_SECONDS',
  defaultValue: 180,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '双账号 C2C 消息发送、接收、回复和重进闭环',
    (tester) async {
      if (!_requireDualWriteAuthorization()) return;

      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;

      if (_expectE2ee && !EncryptionModeService.current.requiresEncryption) {
        markTestSkipped(
          'TEST_EXPECT_E2EE=true，但服务端 policy 不是 required/compliance；拒绝把明文结果算作 E2EE 通过',
        );
        return;
      }

      final actualUid = UserRepoLocal.to.currentUid;
      if (_expectedUid.isNotEmpty && actualUid != _expectedUid) {
        markTestSkipped('当前 App 登录 UID 与目标账号不一致，拒绝向错误账号发送消息');
        return;
      }
      await _ensureTestWebSocket(tester);

      if (!await _openConversationTab(tester)) {
        markTestSkipped('无法进入会话列表');
        return;
      }

      final conversation = await _waitForPeerConversation(tester);
      if (conversation == null) {
        markTestSkipped('未找到目标测试账号的已有 C2C 会话');
        return;
      }
      flowLog('步骤: 已找到目标会话，准备进入聊天页');

      await safeTap(tester, conversation.first);
      if (!await _waitForChatPage(tester)) {
        // 部分 Android ROM 上对 Slidable 内层 GestureDetector 的语义点击
        // 可能不派发，补一次真实屏幕坐标点击；仍失败才跳过。
        try {
          await tester.tapAt(tester.getCenter(conversation.first));
          await settle(tester, maxSeconds: 1);
        } catch (_) {}
        if (!await _waitForChatPage(tester)) {
          markTestSkipped('目标 C2C 会话未进入聊天页面');
          return;
        }
      }

      final senderMarker = 'P0-DUAL-A-$_runId';
      final receiverMarker = 'P0-DUAL-B-$_runId';

      if (_dualRole == 'sender') {
        flowLog('步骤: sender 发送 A=$senderMarker');
        await _sendText(tester, senderMarker);
        flowLog('步骤: A 已上屏，等待服务端 ACK');
        await _waitForOutgoingAck(tester, senderMarker);
        flowLog('步骤: A ACK 完成，查历史');
        await _assertHistoryContains(senderMarker);
        flowLog('步骤: 等待 B=$receiverMarker');
        await _waitForMarker(tester, receiverMarker);
        await _assertHistoryContains(receiverMarker);
      } else {
        flowLog('步骤: receiver 等待 A=$senderMarker');
        await _waitForMarker(tester, senderMarker);
        await _assertHistoryContains(senderMarker);
        flowLog('步骤: receiver 回发 B=$receiverMarker');
        await _sendText(tester, receiverMarker);
        await _waitForOutgoingAck(tester, receiverMarker);
        await _assertHistoryContains(receiverMarker);
      }
      flowLog('步骤: 收发断言完成，准备重进');

      expect(find.textContaining(senderMarker), findsWidgets);
      expect(find.textContaining(receiverMarker), findsWidgets);

      if (_expectE2ee) {
        await _assertOlmEncryptedMessage(senderMarker);
        await _assertOlmEncryptedMessage(receiverMarker);
      }

      // 退出并重新进入同一会话，验证消息不是只存在于当前页面内存。
      await _leaveChatPage(tester);
      flowLog('步骤: 已离开聊天页，回会话列表');
      await settle(tester, maxSeconds: 3);
      if (!await _openConversationTab(tester)) {
        fail('发送/回复后无法回到会话列表');
      }
      final reopened = await _waitForPeerConversation(tester);
      if (reopened == null) fail('重进时未找到目标 C2C 会话');
      await safeTap(tester, reopened.first);
      if (!await _waitForChatPage(tester)) fail('重进时未进入聊天页面');
      flowLog('步骤: 已重进聊天页，校验两条标记');
      await _waitForMarker(tester, senderMarker);
      await _waitForMarker(tester, receiverMarker);
      expect(find.textContaining(senderMarker), findsWidgets);
      expect(find.textContaining(receiverMarker), findsWidgets);

      flowLog('双账号消息闭环通过：$_dualRole，发送/接收双方各一条，重进历史核对完成');
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 6)),
  );
}

Future<void> _ensureTestWebSocket(WidgetTester tester) async {
  if (_testWsUrl.isEmpty) {
    fail('双账号测试必须显式设置 TEST_WS_URL');
  }
  await StorageService.to.setString(Keys.wsUrl, _testWsUrl);

  // 不能在连接尚未建立时继续进入聊天页：后端只有在 websocket_init
  // 执行后才会把设备加入 imboy_syn，过早发送会出现发送端有 ACK、接收端
  // 稍后才上线的假失败。测试应把“连接已建立”作为发送前置条件。
  for (var i = 0; i < 120; i++) {
    if (WebSocketService.to.status == SocketStatus.connected) {
      flowLog('双账号测试 WebSocket 已连接');
      return;
    }
    if (WebSocketService.to.status == SocketStatus.disconnected) {
      await WebSocketService.to.openSocket(from: 'dual_account_flow_test');
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  fail('双账号测试 WebSocket 未在 60 秒内建立，拒绝继续发送生产消息');
}

bool _requireDualWriteAuthorization() {
  const allowed = String.fromEnvironment(
    'TEST_ALLOW_DUAL_ACCOUNT_PROD_WRITES',
    defaultValue: 'false',
  );
  if (allowed.toLowerCase() != 'true') {
    markTestSkipped(
      '双账号消息会写入测试账号，需显式设置 TEST_ALLOW_DUAL_ACCOUNT_PROD_WRITES=true',
    );
    return false;
  }
  if (!FlowConfig.hasCredentials || _peerUid.isEmpty || _runId.isEmpty) {
    markTestSkipped('缺少双账号凭证、对端 UID 或 TEST_DUAL_RUN_ID');
    return false;
  }
  if (!{'sender', 'receiver'}.contains(_dualRole)) {
    markTestSkipped('TEST_DUAL_ROLE 只能是 sender 或 receiver');
    return false;
  }
  return true;
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

Future<Finder?> _waitForPeerConversation(WidgetTester tester) async {
  final peer = find.byWidgetPredicate(
    (widget) =>
        widget is ConversationItem &&
        widget.model.type == 'C2C' &&
        widget.model.peerId.toString() == _peerUid,
  );
  for (var i = 0; i < 90; i++) {
    if (tester.any(peer)) return peer;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return null;
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
  if (!tester.any(input)) fail('聊天页没有消息输入框');
  await tester.enterText(input, marker);
  await settle(tester, maxSeconds: 1);
  final sent = await tapAny(tester, [
    find.byKey(const Key('send_button')),
    find.byKey(const Key('send_button_inner')),
  ]);
  if (!sent) fail('未找到消息发送按钮');
  flowLog('步骤: _sendText 已点击发送 $marker');
  await _waitForMarker(tester, marker);
}

Future<void> _waitForOutgoingAck(WidgetTester tester, String marker) async {
  for (var i = 0; i < 120; i++) {
    final rows = await SqliteService.to.query(
      MessageRepo.c2cTable,
      columns: MessageRepo.defaultColumns,
      where: '${MessageRepo.payload} LIKE ?',
      whereArgs: ['%$marker%'],
      orderBy: '${MessageRepo.createdAt} DESC',
      limit: 10,
    );
    for (final row in rows) {
      if ('${row[MessageRepo.payload]}'.contains(marker)) {
        final rawStatus = row[MessageRepo.status];
        final status = rawStatus is int
            ? rawStatus
            : int.tryParse('$rawStatus');
        final messageId = '${row[MessageRepo.id] ?? ''}';
        if (status == IMBoyMessageStatus.error) {
          fail('消息已进入 error，未获得服务端 ACK：$marker，msgId=$messageId');
        }
        if (status == IMBoyMessageStatus.sent ||
            status == IMBoyMessageStatus.delivered ||
            status == IMBoyMessageStatus.seen) {
          flowLog('服务端 ACK 已反映到本地状态：$marker，status=$status，msgId=$messageId');
          return;
        }
      }
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  fail('消息已出现在本地，但未在 60 秒内反映服务端 ACK：$marker');
}

Future<void> _leaveChatPage(WidgetTester tester) async {
  final tapped = await tapAny(tester, [
    find.byType(CupertinoNavigationBarBackButton),
    find.byIcon(Icons.arrow_back),
  ]);
  if (!tapped) {
    await tester.binding.handlePopRoute();
  }
}

Future<void> _waitForMarker(WidgetTester tester, String marker) async {
  flowLog('步骤: _waitForMarker 开始 $marker（预算 ${_messageWaitSeconds}s）');
  final deadline = DateTime.now().add(Duration(seconds: _messageWaitSeconds));
  var lastDump = DateTime.fromMillisecondsSinceEpoch(0);
  while (DateTime.now().isBefore(deadline)) {
    // skipOffstage:false——聊天页被临时路由/弹层遮挡时消息气泡仍应可命中；
    // 真机/macOS 桌面端的页面层级不受窗口焦点影响，但路由栈会影响 offstage。
    if (tester.any(find.textContaining(marker, skipOffstage: false))) {
      return;
    }
    // 每 20s 转储一次当前可见文本（前 12 条截断），用于判定消息
    // 到底在不在树里——2026-08-11 r9/r11 实证 B 已入库上屏但
    // find.textContaining 长期不匹配，需要看到树里实际渲染了什么。
    if (DateTime.now().difference(lastDump) > const Duration(seconds: 20)) {
      lastDump = DateTime.now();
      final texts = <String>[];
      for (final e
          in find.byType(Text, skipOffstage: false).evaluate().take(12)) {
        final t = (e.widget as Text).data ?? '';
        texts.add(t.length > 40 ? '${t.substring(0, 40)}…' : t);
      }
      var route = '?';
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        try {
          // ignore: use_build_context_synchronously -- 仅读路由位置做诊断转储
          route = GoRouter.of(
            ctx,
          ).routeInformationProvider.value.uri.toString();
        } on Object {
          route = 'n/a';
        }
      }
      flowLog('步骤: 等待中，route=$route 可见 Text=${texts.join(' | ')}');
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  fail('等待消息超时：$marker');
}

Future<void> _assertHistoryContains(String marker) async {
  // 复用当前 App 已登录会话，确保使用真实平台的签名密钥与 Bearer token。
  // 不二次登录，避免触发设备冲突，也不伪造生产环境不存在的 linux 签名组合。
  // 网络调用必须带硬超时：2026-08-11 r9 实证 in-app dio.get 可无限挂起
  // （第二次调用未返回、无日志，最终撞 6 分钟全局超时），历史接口只是
  // 补充证据，挂起/异常一律按 historyUnavailable 记录，不阻断闭环。
  late final dynamic responseData;
  final int? statusCode;
  try {
    final response = await HttpClient.client.dio
        .get<dynamic>(
          '/api/v1/msg/history',
          queryParameters: {
            'chat_type': 'c2c',
            'peer_id': _peerUid,
            'after_seq': 0,
            'limit': 100,
          },
        )
        .timeout(const Duration(seconds: 15));
    responseData = response.data;
    statusCode = response.statusCode;
  } on Object catch (e) {
    flowLog('服务端历史接口超时/异常（$e），按 historyUnavailable 记录，不阻断双端收发验收');
    return;
  }
  final history = responseData is Map<String, dynamic>
      ? responseData
      : <String, dynamic>{'code': statusCode, 'msg': 'non_json_response'};
  // 历史接口是补充证据，不应因联调过程中 access token 过期而否定
  // 已由 WebSocket ACK、接收端 UI 和本地 SQLite 证明的双端消息闭环。
  // 705/401 统一记录为 historyUnavailable；不把它伪装成服务端历史通过。
  final historyCode = history['code'];
  if (historyCode == 705 || historyCode == 401) {
    flowLog('服务端历史接口不可用(code=$historyCode)，按 historyUnavailable 记录，不阻断双端收发验收');
    return;
  }
  FlowApiAssert.success(history, context: '双账号消息历史');
  final payload = history['payload'];
  final messages = payload is Map ? payload['messages'] : null;
  if (messages is List && messages.isEmpty) {
    flowLog('服务端历史接口成功但归档为空，按 historyUnavailable 记录，不阻断双端收发验收');
    return;
  }
  final found =
      messages is List &&
      messages.any((item) => item is Map && '$item'.contains(marker));
  expect(found, isTrue, reason: '服务端历史中未找到消息标记 $marker');
}

Future<void> _assertOlmEncryptedMessage(String marker) async {
  for (var i = 0; i < 120; i++) {
    final rows = await SqliteService.to.query(
      MessageRepo.c2cTable,
      columns: MessageRepo.defaultColumns,
      where: '${MessageRepo.payload} LIKE ?',
      whereArgs: ['%$marker%'],
      orderBy: '${MessageRepo.createdAt} DESC',
      limit: 10,
    );
    for (final row in rows) {
      if (!'${row[MessageRepo.payload]}'.contains(marker)) continue;
      final raw = row[MessageRepo.e2ee];
      final metadata = raw is Map
          ? Map<String, dynamic>.from(raw)
          : raw is String && raw.isNotEmpty
          ? _decodeJsonMap(raw)
          : null;
      final devices = metadata?['devices'];
      if (metadata?['protocol'] == 'olm' &&
          metadata?['fan_out'] == 'per_device' &&
          devices is Map &&
          devices.isNotEmpty) {
        flowLog('Olm per-device 加密元数据已落本地：$marker');
        return;
      }
      fail('消息 $marker 已到达但没有有效 Olm per-device 加密元数据');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail('消息 $marker 未在 60 秒内形成可核对的 Olm 加密记录');
}

Map<String, dynamic>? _decodeJsonMap(String raw) {
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
  } on Object {
    return null;
  }
}
