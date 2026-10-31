// J16.a：真实设置 UI 建隐藏 mute 占位 → 宿主发送首条真实 WS 消息。
// 必填 dart-define：TEST_EXPECTED_UID、TEST_PEER_ID、TEST_SYNTHETIC_PEER=true、
// TEST_FIRST_MESSAGE_ID（宿主预留的唯一 Xid）、TEST_ALLOW_BUSINESS_WRITES=true。
// 使用 flows 的显式非生产环境与登录参数；不清数据，重复运行需换全新合成 peer。
// 宿主先 seed 合成用户（无历史/离线消息），看到 J16A_FIRST_READY 后才投递
// from=TEST_PEER_ID、to=TEST_EXPECTED_UID、id=TEST_FIRST_MESSAGE_ID 的真实消息。
// 宿主须通过正常后端发送/路由链且满足当前 E2EE 策略，禁止客户端伪造事件。
// 测试保留新消息与占位结果，不清理、不修改其他 peer；失败后也不删除。

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peerId = String.fromEnvironment('TEST_PEER_ID');
const _syntheticPeer = bool.fromEnvironment('TEST_SYNTHETIC_PEER');
const _messageId = String.fromEnvironment('TEST_FIRST_MESSAGE_ID');
const _receiveSeconds = int.fromEnvironment(
  'TEST_FIRST_MESSAGE_TIMEOUT_SECONDS',
  defaultValue: 120,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('J16.a 隐藏占位首条真实 WS 消息恢复可见且保留 mute', (tester) async {
    _validateConfig();
    if (!requireBusinessWriteAuthorization()) return;
    final generation = await _prepare(tester);
    await _createHiddenPlaceholder(tester, generation);
    await _receiveFirstMessage(tester, generation);
    _assertOwner(generation);
    flowLog('J16A_FIRST_PASS uid=$_expectedUid peer=$_peerId id=$_messageId');
  }, timeout: const Timeout(Duration(minutes: 6)));
}

void _validateConfig() {
  final uid = RegExp(r'^[1-9][0-9]*$');
  if (!_syntheticPeer ||
      !uid.hasMatch(_expectedUid) ||
      !uid.hasMatch(_peerId) ||
      _expectedUid == _peerId ||
      !RegExp(r'^[0-9a-v]{20}$').hasMatch(_messageId) ||
      _receiveSeconds < 10 ||
      _receiveSeconds > 180) {
    fail(
      '需显式、不同的 TEST_EXPECTED_UID/TEST_PEER_ID、'
      'TEST_SYNTHETIC_PEER=true、TEST_FIRST_MESSAGE_ID（20 位 Xid）；'
      '等待秒数须在 10..180。仅允许宿主新建的独立合成 peer。',
    );
  }
}

void _assertOwner(int generation) {
  final user = UserRepoLocal.to;
  expect(user.isLoggedIn, isTrue, reason: '操作者必须保持登录');
  expect(user.currentUid, _expectedUid, reason: '账号不得漂移');
  expect(user.isCurrentSession(generation), isTrue, reason: '登录代际不得改变');
  expect(user.isAuthTransitioning, isFalse, reason: '不可处于认证过渡窗');
  expect(user.isClearingSession, isFalse, reason: '不可正在清理账号');
}

Finder _peerItem() => find.byWidgetPredicate(
  (widget) =>
      widget is ConversationItem &&
      widget.model.type == 'C2C' &&
      widget.model.peerId == _peerId,
);

Future<void> _waitFor(
  WidgetTester tester,
  int generation,
  Future<bool> Function() predicate,
  String reason, {
  int seconds = 15,
}) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < Duration(seconds: seconds)) {
    _assertOwner(generation);
    final matched = await predicate();
    _assertOwner(generation);
    if (matched) return;
    // 使用真实时间给 SQLCipher、网络与宿主投递让路，不只推进测试时钟。
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('J16.a 超时：$reason');
}

Future<void> _requirePristine() async {
  expect(
    await ConversationRepo().findByPeerId('C2C', _peerId),
    isNull,
    reason: '合成 peer 已有本地会话（含隐藏行）；禁止覆盖，请换新 peer',
  );
  expect(
    await MessageRepo(tableName: MessageRepo.c2cTable)
        .countMessagesWithUser(_peerId),
    0,
    reason: '合成 peer 已有本地消息；禁止删除或复用',
  );
  expect(
    await MessageRepo(tableName: MessageRepo.c2cTable).find(_messageId),
    isNull,
    reason: '预留消息 ID 已存在，请换新 ID',
  );
}

Future<int> _prepare(WidgetTester tester) async {
  await ensureAppLaunched(tester, maxSeconds: 3);
  if (!await checkPreconditions(tester)) fail('J16.a 前置失败：未进入登录主界面');
  final generation = UserRepoLocal.to.sessionGeneration;
  _assertOwner(generation);
  await dismissRecoveryGuide(tester);
  await dismissUpgradeDialog(tester);
  await dismissE2eeBackupSetupPage(tester);
  expect(await openConversationTab(tester), isTrue, reason: '必须进入会话列表');
  await settle(tester, maxSeconds: 2);
  _assertOwner(generation);
  await _requirePristine();
  _assertOwner(generation);
  expect(_peerItem(), findsNothing, reason: '初始无合成 peer 空会话');
  return generation;
}

Future<void> _createHiddenPlaceholder(
  WidgetTester tester,
  int generation,
) async {
  // 生产设置路由可安全直达；不打开 ChatPage，避免其初始化创建会话。
  final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
  unawaited(router.push<void>('/chat_setting/$_peerId'));
  final page = find.byType(ChatSettingPage);
  await _waitFor(tester, generation, () async => tester.any(page), '设置页未出现');
  expect(tester.widget<ChatSettingPage>(page).peerId, _peerId);
  expect(tester.widget<ChatSettingPage>(page).type, 'C2C');
  final muteSwitch = find
      .descendant(of: page, matching: find.byType(CupertinoSwitch))
      .first;
  await _waitFor(
    tester,
    generation,
    () async =>
        tester.any(muteSwitch) &&
        tester.widget<CupertinoSwitch>(muteSwitch).onChanged != null,
    '免打扰未就绪',
  );
  expect(tester.widget<CupertinoSwitch>(muteSwitch).value, isFalse);
  // 设置页异步加载完成后再检查一次；已有数据绝不通过开关覆盖。
  await _requirePristine();
  _assertOwner(generation);
  final label = find.descendant(
    of: page,
    matching: find.text(t.common.muteNotifications),
  );
  expect(await safeTap(tester, label), isTrue, reason: '必须点真实免打扰 UI');
  await _waitFor(tester, generation, () async {
    final row = await ConversationRepo().findByPeerId('C2C', _peerId);
    return row?.isMuted == 1 && row?.isShow == 0 && row?.lastMsgId == '';
  }, 'UI 开启后应产生隐藏 mute 占位');
  router.pop();
  await settle(tester, maxSeconds: 2);
  expect(isOnConvList(tester), isTrue, reason: '返回真实会话列表');
  expect(_peerItem(), findsNothing, reason: '隐藏占位不能产生可见空会话');
}

Future<void> _receiveFirstMessage(WidgetTester tester, int generation) async {
  final repo = ConversationRepo();
  final messages = MessageRepo(tableName: MessageRepo.c2cTable);
  var armed = false;
  var earlyMessage = false;
  var received = false;
  // 仅订阅生产 WS 传输事件；不 fire 事件、不调用入站处理器、不注入 provider。
  final incoming = AppEventBus.on<WebSocketMessageReceivedEvent>().listen((e) {
    if (e.type != 'C2C' ||
        e.data['from']?.toString() != _peerId ||
        e.data['to']?.toString() != _expectedUid) {
      return;
    }
    if (!armed) earlyMessage = true;
    if (armed && e.data['id']?.toString() == _messageId) received = true;
  });
  try {
    await _waitFor(
      tester,
      generation,
      () async => WebSocketService.to.status == SocketStatus.connected,
      '真实 WS 未连接',
    );
    final row = await repo.findByPeerId('C2C', _peerId);
    expect(row?.isShow, 0);
    expect(row?.isMuted, 1);
    expect(row?.lastMsgId, '');
    expect(
      await messages.countMessagesWithUser(_peerId),
      0,
      reason: 'READY 前不允许宿主提前投递',
    );
    expect(earlyMessage, isFalse, reason: 'READY 前已收到目标消息，请换全新 peer');
    expect(_peerItem(), findsNothing, reason: 'READY 前无可见空会话');
    _assertOwner(generation);
    armed = true;
    flowLog('J16A_FIRST_READY uid=$_expectedUid peer=$_peerId id=$_messageId');
    await _waitFor(
      tester,
      generation,
      () async => received,
      '未观察到指定 from/to/id 的真实 WS 入站',
      seconds: _receiveSeconds,
    );
    await _assertFirstMessage(tester, generation);
  } finally {
    await incoming.cancel();
  }
}

Future<void> _assertFirstMessage(WidgetTester tester, int generation) async {
  final repo = ConversationRepo();
  final messages = MessageRepo(tableName: MessageRepo.c2cTable);
  await _waitFor(tester, generation, () async {
    final message = await messages.find(_messageId);
    final row = await repo.findByPeerId('C2C', _peerId);
    return message?.fromId == _peerId &&
        message?.toId == _expectedUid &&
        message?.conversationUk3 ==
            ConversationUk3Generator.generate(
              type: 'C2C',
              currentUserId: _expectedUid,
              peerId: _peerId,
            ) &&
        row?.lastMsgId == _messageId &&
        row?.isShow == 1 &&
        row?.isMuted == 1 &&
        tester.any(_peerItem());
  }, '首消息应落库、恢复 is_show=1、保留 is_muted=1 并自动出现在列表');
  expect(_peerItem(), findsOneWidget);
  final model = tester.widget<ConversationItem>(_peerItem()).model;
  expect(model.isShow, 1);
  expect(model.isMuted, 1);
  expect(model.lastMsgId, _messageId);
  expect(
    await messages.countMessagesWithUser(_peerId),
    1,
    reason: '本次受控旅程必须恰有一条首消息',
  );
}
