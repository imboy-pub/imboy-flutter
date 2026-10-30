// integration_test/chat/j18d_edit_window_test.dart
//
// plan-v2.2 §9 J18.d（本人可编辑消息：编辑成功/拒绝分别 → 编辑态/已编辑/
// 失败恢复准确）真机旅程：登录 demo_alice → 打开与 demo_bob 的 C2C →
//   ① 发送 OLD、FRESH 两条本人文本消息
//   ② FRESH 等正向 sent → 长按 →「编辑」→ 编辑态：输入框预填原文 →
//      替换为「原文 EDITED」→ 发送 → message_edit_ack 回流 → 断言同一条
//      气泡文本变为新文本、未产生新气泡、输入框已清空（成功分支）
//   ③ 真实等待 OLD 龄超出服务端编辑窗（fixture：合成 daemon
//      msg_edit_window_seconds=SERVER_EDIT_WINDOW_SECONDS，默认 60）；客户端
//      15 分钟门控仍放行 → 长按 OLD →「编辑」→ 预填 → 替换为「原文 EDITED」
//      → 发送 → 关联出站请求和入站拒绝；产品侧尚未处理错误，最终明确失败。
//
// 两层时限：客户端 chat_page_utils.canEditMessage / 域 Message.editWindow
// 15 分钟（菜单门控）；后端 msg_c2c_logic.erl msg_edit_window_ms() 读 env
// msg_edit_window_seconds（默认 86400），本旅程以 fixture 把后端窗调短以在
// 单设备上真实触发"客户端放行、服务端拒绝"分支。
//
// 已知缺口（仅记录，不作硬断言）：is_edited 无 UI 消费者（无「已编辑」标记）；
// 客户端无 message_edit_error 处理（拒绝无失败提示）。
//
// 前置（fixture 在测试外完成）：后端本地 daemon 绑定合成库；
// demo_alice/demo_bob 互为好友；
//   IMBOYENV=local _rel/imboy/bin/imboy eval \
//     'application:set_env(imboy, msg_edit_window_seconds, 60).'
//
// 运行：
//   flutter test integration_test/chat/j18d_edit_window_test.dart \
//     -d <real_device_id> \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//     --dart-define=TEST_PHONE=demo_alice \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     --dart-define=TEST_EXPECTED_UID=<alice-uid> \
//     --dart-define=PEER_UID=<bob-uid> \
//     --dart-define=PEER_TITLE=演示用户Bob \
//     --dart-define=SERVER_EDIT_WINDOW_SECONDS=60 \
//     --dart-define=TEST_ALLOW_BUSINESS_WRITES=true

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peerUid = String.fromEnvironment('PEER_UID');
const _peerTitle = String.fromEnvironment('PEER_TITLE');
const _serverEditWindowSeconds = int.fromEnvironment(
  'SERVER_EDIT_WINDOW_SECONDS',
  defaultValue: 60,
);

const _oldPrefix = '[J18D-OLD]';
const _freshPrefix = '[J18D-FRESH]';
const _editedSuffix = ' EDITED';

/// 长按含 [marker] 的本人文本气泡 →「编辑」→ 断言进入编辑态（输入框预填原文）。
Future<void> _enterEditMode(
  WidgetTester t,
  Finder chatPage,
  String marker,
) async {
  final bubble = find.textContaining(marker, findRichText: true);
  expect(bubble, findsWidgets, reason: '$marker 应在列表');
  await t.scrollUntilVisible(
    bubble.first,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await settle(t, maxSeconds: 1);
  await t.longPress(bubble.first);
  await settle(t, maxSeconds: 2);
  final editAction = find.text('编辑');
  expect(editAction, findsWidgets, reason: '本人 15 分钟内文本消息长按菜单应有「编辑」');
  await safeTap(t, editAction.first);

  final input = chatInputField(chatPage);
  var prefilled = false;
  for (var i = 0; i < 20 && !prefilled; i++) {
    prefilled = t.any(input) && controllerHas(t, input.first, marker);
    if (!prefilled) await t.pump(const Duration(milliseconds: 100));
  }
  expect(prefilled, isTrue, reason: '进入编辑态后输入框应预填原文 $marker');
}

String _bubbleText(WidgetTester t, String marker) =>
    textOf(t.widget<ChatMessageItem>(itemContaining(marker).first).message);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J18.d 本人文本消息：窗口内编辑生效，服务端超窗拒绝后原文保留', (tester) async {
    if (_expectedUid.isEmpty || _peerUid.isEmpty || _peerTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、PEER_UID、PEER_TITLE');
    }
    if (_serverEditWindowSeconds <= 0 || _serverEditWindowSeconds >= 840) {
      fail('SERVER_EDIT_WINDOW_SECONDS 必须大于 0 且小于 840');
    }
    if (!requireBusinessWriteAuthorization()) return;
    final chatPage = await openC2CWithPeer(
      tester,
      journey: 'J18.d',
      expectedUid: _expectedUid,
      peerUid: _peerUid,
      peerTitle: _peerTitle,
    );

    final nonce = DateTime.now().millisecondsSinceEpoch;
    final oldMarker = '$_oldPrefix $nonce';
    final freshMarker = '$_freshPrefix $nonce';

    // ① OLD 先发（稍后做服务端拒绝），FRESH 后发。
    await sendTextViaInput(tester, chatPage, oldMarker);
    final oldMsg = await waitSent(tester, oldMarker);
    if (oldMsg == null || oldMsg.createdAt == null) {
      fail('OLD 消息未进入列表或无 createdAt（status=${oldMsg?.status}）');
    }
    expect(settledStatuses, contains(oldMsg.status));
    expect(oldMsg.id, isNotEmpty);
    final oldCreatedMs = oldMsg.createdAt!.millisecondsSinceEpoch;
    debugPrint(
      'J18D old createdAtMs=$oldCreatedMs status=${oldMsg.status} '
      'ntpOffsetMs=${NtpHelper.offset} serverWindowS=$_serverEditWindowSeconds',
    );

    await sendTextViaInput(tester, chatPage, freshMarker);
    final freshMsg = await waitSent(tester, freshMarker);
    if (freshMsg == null) {
      fail('FRESH 消息未进入列表');
    }
    expect(freshMsg.id, isNotEmpty);
    expect(freshMsg.id, isNot(oldMsg.id));
    expect(
      settledStatuses.contains(freshMsg.status),
      isTrue,
      reason: '编辑前消息须已进入正向已发送态，实际 status=${freshMsg.status}',
    );

    // ② 成功分支：编辑态 → 提交 → ack 回流 → 同一气泡文本更新。
    await _enterEditMode(tester, chatPage, freshMarker);
    final freshEdited = '$freshMarker$_editedSuffix';
    await submitInput(tester, chatPage, freshEdited);
    var applied = false;
    for (var i = 0; i < 20 && !applied; i++) {
      await settle(tester, maxSeconds: 1);
      applied = tester.any(
        find.textContaining(freshEdited, findRichText: true),
      );
    }
    await takeScreenshot(tester, 'j18d_01_fresh_edited');
    expect(applied, isTrue, reason: '编辑 ack 回流后气泡应于 20s 内显示新文本');
    expect(
      itemContaining(freshMarker).evaluate().length,
      1,
      reason: '编辑不应产生新气泡：含 FRESH marker 的文本气泡应恰好 1 条',
    );
    expect(
      _bubbleText(tester, freshMarker),
      freshEdited,
      reason: '同一条气泡的文本应逐字等于新文本',
    );
    expect(
      tester.widget<ChatMessageItem>(itemContaining(freshMarker)).message.id,
      freshMsg.id,
    );
    expect(
      tester
          .widget<CupertinoTextField>(chatInputField(chatPage).first)
          .controller
          ?.text,
      isEmpty,
      reason: '编辑提交后输入框应清空（退出编辑态）',
    );
    final editedMarkerVisible = tester.any(
      find.textContaining('已编辑', findRichText: true),
    );
    debugPrint('J18D editedMarkerVisible=$editedMarkerVisible');

    // ③ 拒绝分支：真实等待 OLD 龄超出服务端窗（+5s 裕量），客户端门控仍放行。
    final deadline = oldCreatedMs + _serverEditWindowSeconds * 1000 + 5000;
    var now = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
      'J18D waiting ${deadline - now}ms for OLD to leave server window',
    );
    while (now < deadline) {
      await settle(tester, maxSeconds: 5);
      now = DateTime.now().millisecondsSinceEpoch;
    }
    final oldTextBefore = _bubbleText(tester, oldMarker);
    expect(oldTextBefore, oldMarker, reason: '前置：OLD 原文应与发送内容一致');

    await _enterEditMode(tester, chatPage, oldMarker);
    final oldEdited = '$oldMarker$_editedSuffix';
    final generation = UserRepoLocal.to.sessionGeneration;
    final requestIds = <String>{};
    final errors = <Map<String, dynamic>>[];
    final outgoing = AppEventBus.on<WebSocketMessageSendRequestEvent>().listen((
      event,
    ) {
      if (event.sessionGeneration != generation) return;
      Object? decoded;
      try {
        decoded = jsonDecode(event.message);
      } on FormatException {
        return;
      }
      if (decoded is! Map ||
          decoded['action'] != 'message_edit' ||
          decoded['type'] != 'C2C' ||
          decoded['from']?.toString() != _expectedUid ||
          decoded['to']?.toString() != _peerUid) {
        return;
      }
      final payload = decoded['payload'];
      final e2ee = decoded['e2ee'];
      final target = payload is Map
          ? payload['original_msg_id']
          : e2ee is Map
          ? e2ee['edit_of']
          : null;
      if (target?.toString() == oldMsg.id &&
          decoded['id'] is String &&
          (decoded['id'] as String).isNotEmpty) {
        requestIds.add(decoded['id'] as String);
      }
    });
    final incoming = AppEventBus.on<WebSocketMessageReceivedEvent>().listen((
      event,
    ) {
      if (UserRepoLocal.to.currentUid == _expectedUid &&
          UserRepoLocal.to.isCurrentSession(generation) &&
          !UserRepoLocal.to.isClearingSession &&
          event.type == 'C2C' &&
          event.data['action'] == 'message_edit_error') {
        errors.add(event.data);
      }
    });
    bool matches(Map<String, dynamic> error) {
      final payload = error['payload'];
      return requestIds.contains(error['id']) &&
          error['from']?.toString() == _expectedUid &&
          error['to']?.toString() == _peerUid &&
          payload is Map &&
          payload['original_msg_id']?.toString() == oldMsg.id &&
          payload['code'] == 409;
    }

    try {
      await submitInput(tester, chatPage, oldEdited);
      for (var i = 0; i < 100 && !errors.any(matches); i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    } finally {
      await outgoing.cancel();
      await incoming.cancel();
    }
    expect(UserRepoLocal.to.currentUid, _expectedUid);
    expect(UserRepoLocal.to.isCurrentSession(generation), isTrue);
    expect(requestIds, hasLength(1), reason: '必须关联唯一的 OLD 编辑请求');
    final matchingErrors = errors.where(matches);
    expect(matchingErrors, isNotEmpty, reason: '必须收到对应请求的服务端超窗拒绝');
    final failToastSeen = await pollText(
      tester,
      find.textContaining('编辑失败'),
      maxMs: 3000,
    );
    var oldApplied = false;
    for (var i = 0; i < 10 && !oldApplied; i++) {
      await settle(tester, maxSeconds: 1);
      oldApplied = tester.any(
        find.textContaining(oldEdited, findRichText: true),
      );
    }
    await takeScreenshot(tester, 'j18d_02_old_rejected');
    debugPrint('J18D reject failToastSeen=$failToastSeen');
    expect(oldApplied, isFalse, reason: '服务端超窗拒绝后 OLD 不得显示为已编辑文本（10s）');
    expect(itemContaining(oldMarker), findsOneWidget, reason: 'OLD 原文气泡应保留');
    expect(
      _bubbleText(tester, oldMarker),
      oldMarker,
      reason: '拒绝后 OLD 文本应与原文逐字一致（失败恢复准确）',
    );
    expect(
      tester.widget<ChatMessageItem>(itemContaining(oldMarker)).message.id,
      oldMsg.id,
    );
    expect(
      tester
          .widget<CupertinoTextField>(chatInputField(chatPage).first)
          .controller
          ?.text,
      isEmpty,
      reason: '拒绝后应退出编辑态、输入框清空',
    );
    drainKnownFrameworkExceptions(tester);
    fail(
      '已检查原始回包，但客户端尚未处理编辑错误及其重试终态；'
      'SERVER_EDIT_WINDOW_SECONDS 也不能证明服务端实际配置',
    );
  }, timeout: const Timeout(Duration(minutes: 8)));
}
