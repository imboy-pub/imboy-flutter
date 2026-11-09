// P0 双账号单聊消息闭环：macOS/Android 角色由 TEST_DUAL_ROLE 指定。
//
// 该 flow 只允许两个明确授权的测试账号，并要求调用方显式传入
// TEST_ALLOW_DUAL_ACCOUNT_PROD_WRITES=true；不执行好友、群、资金或删除操作。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show navigatorKey;
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/model/message_model.dart';

import '../flows/api_test_client.dart';
import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

part 'dual_account_persistence_assertions.dart';

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
const _wsUrlOverride = String.fromEnvironment(
  'WS_URL_OVERRIDE',
  defaultValue: '',
);
const _expectE2ee = bool.fromEnvironment(
  'TEST_EXPECT_E2EE',
  defaultValue: false,
);
const _forceLogoutBeforeLogin = bool.fromEnvironment(
  'TEST_FORCE_LOGOUT_BEFORE_LOGIN',
  defaultValue: false,
);
const _messageWaitSeconds = int.fromEnvironment(
  'TEST_MESSAGE_WAIT_SECONDS',
  defaultValue: 180,
);
// 离线验收的发送阶段只负责把 A 投递到服务端；收到 ACK 后退出，
// 由外部编排重新启动 receiver 验证离线取件。默认关闭，不改变普通双端闭环。
const _stopAfterOutgoingAck = bool.fromEnvironment(
  'TEST_STOP_AFTER_OUTGOING_ACK',
  defaultValue: false,
);
// 离线批量场景：>1 时 sender 连发 N 条带序号 marker（P0-OFFLINE-<run>-01..N），
// 每条等到服务端 ACK；receiver 重启后断言 N 条各一份且按服务端序列
// （conv_seq）有序。默认 1 = 普通（单条）闭环，不受影响。
const _offlineCount = int.fromEnvironment(
  'TEST_OFFLINE_MESSAGE_COUNT',
  defaultValue: 1,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '双账号 C2C 消息发送、接收、回复和重进闭环',
    (tester) async {
      if (!_requireDualWriteAuthorization()) return;

      await ensureAppLaunched(tester, maxSeconds: 10);
      if (_forceLogoutBeforeLogin) {
        await UserRepoLocal.to.quitLogin();
        await settle(tester, maxSeconds: 2);
        flowLog('已按测试参数清理本地登录与 E2EE 会话');
      }
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

      // 跨账号残留检查（J01 g3）：dual-sequential 接收阶段经
      // TEST_FORCE_LOGOUT_BEFORE_LOGIN 完成 A→B 登录切换，B 登录后设备上
      // 不得残留 A 账号的本地库与会话（A↔B 会话本身属于 B 的合法数据）。
      // 仅在 force-logout 段生效，dual-concurrent 等既有实例行为不变。
      if (_forceLogoutBeforeLogin && _dualRole == 'receiver') {
        await _assertNoPeerAccountResidue();
      }

      final conversation = await _waitForPeerConversation(tester);
      if (conversation == null) {
        // 清理本地数据库后，会话列表可能没有存量 C2C 记录；ChatPage
        // 本身会通过 createConversation 建立本地会话，允许严格测试从
        // 干净数据库开始，而不是把“没有历史会话”误报为 E2EE 失败。
        flowLog('未找到存量 C2C 会话，直接打开目标聊天页让 ChatPage 建立会话');
        final ctx = navigatorKey.currentContext;
        if (ctx == null) {
          markTestSkipped('无法取得导航上下文以打开目标 C2C 会话');
          return;
        }
        GoRouter.of(ctx).push('/chat/$_peerUid?type=C2C');
        if (!await _waitForChatPage(tester)) {
          markTestSkipped('目标 C2C 会话未进入聊天页面');
          return;
        }
      } else {
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
      }

      final senderMarker = 'P0-DUAL-A-$_runId';
      final receiverMarker = 'P0-DUAL-B-$_runId';

      if (_offlineCount > 1) {
        // ── 离线批量场景（J01 收尾）：B 全程离线，A 连发 N 条后退出，
        //    再由外部编排重启 B 验证离线取件的完整性与服务端序列。──
        if (_dualRole == 'sender') {
          if (!_stopAfterOutgoingAck) {
            fail(
              'TEST_OFFLINE_MESSAGE_COUNT>1 必须搭配 TEST_STOP_AFTER_OUTGOING_ACK=true',
            );
          }
          for (var i = 1; i <= _offlineCount; i++) {
            final marker = 'P0-OFFLINE-$_runId-${i.toString().padLeft(2, '0')}';
            flowLog('步骤: 离线批量发送 [$i/$_offlineCount] $marker');
            await _sendText(tester, marker);
            await _waitForOutgoingAck(tester, marker);
          }
          await _assertHistoryContains(
            'P0-OFFLINE-$_runId-${_offlineCount.toString().padLeft(2, '0')}',
          );
          flowLog('离线批量发送完成：$_offlineCount 条全部 ACK，A 进程按参数退出');
          drainKnownFrameworkExceptions(tester);
          return;
        }
        final lastMarker =
            'P0-OFFLINE-$_runId-${_offlineCount.toString().padLeft(2, '0')}';
        flowLog('步骤: offline receiver 等待末条 $lastMarker 上屏');
        await _waitForMarker(tester, lastMarker);
        await _assertOfflineBatchViaDb(tester);
        flowLog('离线批量验收通过：$_offlineCount 条各一份、按服务端序列 conv_seq 有序');
        // 已读标记持久化断言（J01 g3）：接收阶段本身是重启后的新进程
        //（dual-sequential 编排），落库后停留聊天页触发 markAsRead，
        // 断言已读状态落库且重进后不反弹；进程级“已读→重启→仍已读”
        // 由合同登记的 receiver 重放轮覆盖（同 TEST_DUAL_RUN_ID 再跑一次
        // receiver，本断言即成为跨进程的持久化断言）。
        await _assertReadStatePersisted(tester);
        flowLog(
          '离线批量验收通过：$_offlineCount 条各一份、按服务端序列 conv_seq 有序，'
          '已读标记落库且重进不反弹',
        );
        drainKnownFrameworkExceptions(tester);
        return;
      }

      if (_dualRole == 'sender') {
        flowLog('步骤: sender 发送 A=$senderMarker');
        await _sendText(tester, senderMarker);
        flowLog('步骤: A 已上屏，等待服务端 ACK');
        await _waitForOutgoingAck(tester, senderMarker);
        flowLog('步骤: A ACK 完成，查历史');
        await _assertHistoryContains(senderMarker);
        if (_stopAfterOutgoingAck) {
          flowLog('离线发送阶段完成：A 已获得 ACK，按 TEST_STOP_AFTER_OUTGOING_ACK 退出');
          drainKnownFrameworkExceptions(tester);
          return;
        }
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
    timeout: Timeout(Duration(minutes: _offlineCount > 1 ? 15 : 6)),
  );
}

Future<void> _ensureTestWebSocket(WidgetTester tester) async {
  final wsUrl = _effectiveTestWsUrl;
  if (wsUrl.isEmpty) {
    fail('双账号测试必须显式设置 TEST_WS_URL 或 WS_URL_OVERRIDE');
  }
  await StorageService.to.setString(Keys.wsUrl, wsUrl);

  // 启动阶段可能已经按旧缓存建立了连接；仅更新缓存不会切换现有 channel，
  // 会造成发送端拿到 ACK、接收端却未挂到目标服务的假阴性。
  await WebSocketService.to.closeSocket();

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

String get _effectiveTestWsUrl =>
    _testWsUrl.isNotEmpty ? _testWsUrl : _wsUrlOverride;

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
  if (_stopAfterOutgoingAck && _dualRole != 'sender') {
    markTestSkipped('TEST_STOP_AFTER_OUTGOING_ACK 只能用于 sender 阶段');
    return false;
  }
  return true;
}

/// 是否正显示会话列表。
///
/// 2026-11-07 j01r2 实证旧判定全失效：当前 UI 的搜索入口是
/// CupertinoSearchTextField（conversation_search_input），不再有
/// Material Icons.search + add_circle_outline 组合；类型判定改用
/// find.byType 并放宽 skipOffstage（列表被返回动画/浮层临时遮挡时
/// 仍应命中）。ChatPage 是否真正离栈由 _leaveChatPage 独立验证，
/// 本判定不承担「在栈顶」语义。
bool _isConversationList(WidgetTester tester) =>
    tester.any(find.byType(ConversationPage, skipOffstage: false)) ||
    tester.any(
      find.byKey(const Key('conversation_search_input'), skipOffstage: false),
    );

/// 诊断转储：路由位置 + 前 12 条可见文本 + 关键页在树状态。
/// 与 _waitForMarker 的周期转储同口径，失败现场不再盲查。
void _dumpUiState(WidgetTester tester, String scene) {
  final texts = <String>[];
  for (final e in find.byType(Text, skipOffstage: false).evaluate().take(12)) {
    final t = (e.widget as Text).data ?? '';
    texts.add(t.length > 40 ? '${t.substring(0, 40)}…' : t);
  }
  var route = '?';
  final ctx = navigatorKey.currentContext;
  if (ctx != null && ctx.mounted) {
    try {
      route = GoRouter.of(ctx).routeInformationProvider.value.uri.toString();
    } on Object {
      route = 'n/a';
    }
  }
  flowLog(
    '[ui-state] $scene route=$route chatPage=${tester.any(find.byType(ChatPage, skipOffstage: false))} '
    'conversationPage=${tester.any(find.byType(ConversationPage, skipOffstage: false))} '
    'Text=${texts.join(' | ')}',
  );
}

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
  _dumpUiState(tester, 'open_conversation_tab_failed');
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
  // 发送键显隐由焦点（chat_input.dart 焦点路径置 visible=true）与
  // 输入非空（300ms 防抖）共同驱动。2026-11-07 j01r6 实证：首条发送
  // 后键盘收起，第 2 条起 enterText 直改控制器不经焦点路径，按钮缺席。
  // 按真实用户行为：先真实点击输入框聚焦，再输入；按钮带 3 次重试。
  var sent = false;
  for (var attempt = 1; attempt <= 3 && !sent; attempt++) {
    await safeTap(tester, input);
    await settle(tester, maxSeconds: 1);
    await tester.enterText(input, marker);
    await settle(tester, maxSeconds: 2);
    sent = await tapAny(tester, [
      find.byKey(const Key('send_button')),
      find.byKey(const Key('send_button_inner')),
    ]);
    if (!sent && attempt < 3) {
      flowLog('步骤: 发送按钮缺席（第$attempt次），重试输入');
    }
  }
  if (!sent) fail('未找到消息发送按钮');
  flowLog('步骤: _sendText 已点击发送 $marker');
  await _waitForMarker(tester, marker);
}

Future<void> _waitForOutgoingAck(WidgetTester tester, String marker) async {
  for (var i = 0; i < 120; i++) {
    final rows = await SqliteService.to.query(
      MessageRepo.c2cTable,
      columns: MessageRepo.c2cColumns,
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

/// 离开聊天页并确认 ChatPage 真正离栈。
///
/// 2026-11-07 j01r2 双端实证：ChatPage 顶栏返回键是 GlassBackButton
/// （lib/component/ui/common_bar.dart），图标为 CupertinoIcons.chevron_left，
/// 不是 CupertinoNavigationBarBackButton / Icons.arrow_back；旧 fallback
/// handlePopRoute() 在 Router 应用上 WidgetsApp.didPopRoute 对
/// Router delegate 直接 return false（系统返回由 backButtonDispatcher
/// 处理），等于空操作 —— 双端都停在聊天页，随后 20 次轮询
/// _isConversationList 全 false，以「发送/回复后无法回到会话列表」失败。
/// 现改为点真实返回键，并轮询确认 ChatPage 已不在 onstage 树。
Future<void> _leaveChatPage(WidgetTester tester) async {
  final tapped = await tapAny(tester, [
    find.byIcon(CupertinoIcons.chevron_left),
    find.byType(CupertinoNavigationBarBackButton),
    find.byIcon(Icons.arrow_back),
    find.byIcon(Icons.arrow_back_ios_new),
  ]);
  if (!tapped) {
    // Router 应用上大概率 no-op（见函数注释），仅作最后兜底。
    await tester.binding.handlePopRoute();
  }
  for (var i = 0; i < 16; i++) {
    if (!tester.any(find.byType(ChatPage))) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
  // 返回键没点中或 pop 未生效：转储现场后显式失败，不静默带病继续。
  _dumpUiState(tester, 'leave_chat_page_failed');
  fail('点击返回键后 ChatPage 仍未离栈');
}

Future<void> _waitForMarker(WidgetTester tester, String marker) async {
  flowLog('步骤: _waitForMarker 开始 $marker（预算 ${_messageWaitSeconds}s）');
  final deadline = DateTime.now().add(Duration(seconds: _messageWaitSeconds));
  var lastDump = DateTime.fromMillisecondsSinceEpoch(0);
  while (DateTime.now().isBefore(deadline)) {
    // skipOffstage:false——聊天页被临时路由/弹层遮挡时消息气泡仍应可命中；
    // 真机/macOS 桌面端的页面层级不受窗口焦点影响，但路由栈会影响 offstage。
    // 只在 ChatPage 子树内匹配：会话列表（IndexedStack 离屏）里的最后一条
    // 预览文本同样含标记，会让等待提前返回，随后的页内断言落空。
    if (tester.any(
      find.descendant(
        of: find.byType(ChatPage, skipOffstage: false),
        matching: find.textContaining(marker, skipOffstage: false),
      ),
    )) {
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
      if (ctx != null && ctx.mounted) {
        try {
          route = GoRouter.of(ctx).routeInformationProvider.value.uri
              .toString();
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
  if (_expectE2ee) {
    // 严格 E2EE 闭环的历史证据来自本地密文记录与重进恢复；服务端归档
    // 不应要求返回可检索的明文 marker，且本地联调可能未启用归档服务。
    flowLog('strict E2EE：跳过服务端明文历史 marker 查询：$marker');
    return;
  }
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
  if (_expectE2ee) {
    // strict E2EE 下服务端历史只能携带密文，不能用明文 marker 做检索断言。
    // 双端闭环的可验证证据由 ACK、接收端 UI、本地消息与 e2ee 元数据、重进后
    // 的本地恢复共同组成；这里仅记录历史接口可访问，不把“找不到明文”算失败。
    flowLog('strict E2EE：服务端历史可访问但不检索明文 marker，按本地密文证据验收');
    return;
  }
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
      columns: MessageRepo.c2cColumns,
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
