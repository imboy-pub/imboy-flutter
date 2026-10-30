// integration_test/chat/support/c2c_journey_support.dart
//
// plan-v2.2 §9 J18 系列单设备 C2C 真机旅程共用助手（源自 J18.c）：登录校验、
// 进会话列表、打开指定 C2C、经真实输入链发送/提交文本、等待正向 sent、
// 轮询 toast、按文本定位气泡 widget。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../flows/app_launcher.dart';
import '../../flows/test_utils.dart';

/// 与 e2e_chat_test 相同的会话列表判定（该实现为私有，此处复刻）。
bool isOnConvList(WidgetTester t) =>
    t.any(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'ConversationPage',
      ),
    ) ||
    (t.any(find.byIcon(Icons.search)) &&
        t.any(find.byIcon(Icons.add_circle_outline)));

Future<bool> openConversationTab(WidgetTester t) async {
  if (isOnConvList(t)) return true;
  await tapAny(t, [
    find.byKey(const Key('tab_conversations')),
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.chat_bubble_outline),
    find.text('消息'),
    find.text('会话'),
  ]);
  for (int i = 0; i < 5; i++) {
    await settle(t, maxSeconds: 1);
    if (isOnConvList(t)) return true;
  }
  return false;
}

/// 启动 → 登录校验（账号须等于 [expectedUid] 且不等于 [peerUid]）→ 会话列表
/// → 打开与 [peerUid]/[peerTitle] 的 C2C。返回 ChatPage finder；任一步失败
/// 即 fail（带 [journey] 前缀）。
Future<Finder> openC2CWithPeer(
  WidgetTester t, {
  required String journey,
  required String expectedUid,
  required String peerUid,
  required String peerTitle,
}) async {
  await ensureAppLaunched(t, maxSeconds: 3);
  if (!await checkPreconditions(t)) {
    fail('$journey 前置失败：登录未进入主界面');
  }
  final actualUid = UserRepoLocal.to.currentUid;
  if (actualUid != expectedUid || actualUid == peerUid) {
    fail('登录账号 UID=$actualUid 与授权发送方 $expectedUid 不一致');
  }
  await settle(t, maxSeconds: 2);
  await dismissRecoveryGuide(t);
  await settle(t, maxSeconds: 2);

  if (!await openConversationTab(t)) {
    fail('无法进入会话列表');
  }
  await settle(t, maxSeconds: 2);

  final peerItem = find.byWidgetPredicate(
    (widget) =>
        widget is ConversationItem &&
        widget.model.type == 'C2C' &&
        widget.model.peerId.toString() == peerUid &&
        widget.model.resolvedTitle == peerTitle,
  );
  if (!t.any(peerItem)) {
    fail('会话列表中无目标 $peerTitle (uid=$peerUid) 的 C2C 会话');
  }
  await safeTap(t, peerItem.first);
  await settle(t, maxSeconds: 3);
  final chatPage = find.byType(ChatPage);
  expect(chatPage, findsOneWidget, reason: '应进入聊天页');
  expect(t.widget<ChatPage>(chatPage).peerId, peerUid, reason: '聊天对象必须等于授权目标');
  return chatPage;
}

String textOf(Message m) => m is TextMessage ? m.text : '';

/// 文本含 [marker] 的消息气泡 widget（可读 message.createdAt / status）。
Finder itemContaining(String marker) => find.byWidgetPredicate(
  (w) => w is ChatMessageItem && textOf(w.message).contains(marker),
);

/// 以 [stepMs] 为步长轮询 [finder] 最多 [maxMs]，命中即 true。
Future<bool> pollText(
  WidgetTester t,
  Finder finder, {
  int maxMs = 3000,
  int stepMs = 100,
}) async {
  for (var elapsed = 0; elapsed < maxMs; elapsed += stepMs) {
    if (t.any(finder)) return true;
    await t.pump(Duration(milliseconds: stepMs));
  }
  return t.any(finder);
}

/// 聊天页输入框（ChatInput 内唯一的 CupertinoTextField）。
Finder chatInputField(Finder chatPage) =>
    find.descendant(of: chatPage, matching: find.byType(CupertinoTextField));

bool controllerHas(WidgetTester t, Finder field, String text) =>
    (t.widget<CupertinoTextField>(field).controller?.text ?? '').contains(text);

/// 把输入框内容替换为 [text] 并点发送按钮。不断言列表出现 [text]
/// （编辑态提交时列表不会出现新气泡）。
///
/// 发送后 ChatInput 会 `unfocus()` 关闭输入连接；而 `enterText` 内部的
/// `showKeyboard` 仅在 `focusedEditable` 变化时才 `requestKeyboard()`，同一
/// 字段第二次 `enterText` 会静默写不进去。故先真实点按输入框重建连接，并
/// 校验控制器文本确已写入，未写入则重置 `focusedEditable` 兜底重试一次。
Future<void> submitInput(WidgetTester t, Finder chatPage, String text) async {
  final input = chatInputField(chatPage);
  if (!t.any(input)) {
    fail('聊天页无输入框');
  }
  await t.tap(input.first, warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 300));
  await t.enterText(input.first, text);
  if (!controllerHas(t, input.first, text)) {
    t.binding.focusedEditable = null;
    await t.enterText(input.first, text);
  }
  expect(
    controllerHas(t, input.first, text),
    isTrue,
    reason: '输入框控制器应已写入 $text',
  );
  await t.pump(const Duration(milliseconds: 450));
  await t.pump(const Duration(milliseconds: 100));
  final sent = await tapAny(t, [
    find.byKey(const ValueKey('send_button_inner')),
    find.byKey(const ValueKey('send_button')),
    find.byIcon(CupertinoIcons.arrow_up),
  ]);
  if (!sent) {
    fail('未找到发送按钮，$text 未发出');
  }
  await settle(t, maxSeconds: 2);
}

/// 经真实输入链发出一条新文本消息，并断言它出现在聊天列表。
Future<void> sendTextViaInput(
  WidgetTester t,
  Finder chatPage,
  String text,
) async {
  await submitInput(t, chatPage, text);
  expect(
    find.textContaining(text, findRichText: true),
    findsWidgets,
    reason: '$text 应出现在聊天列表',
  );
}

/// 正向已发送态；域 Message.canRevoke/canEdit 要求 status==sent，服务端 ACK
/// 前 UI status 为 null（渲染上等同 sent，但域校验会拒绝）。
const settledStatuses = {
  MessageStatus.sent,
  MessageStatus.delivered,
  MessageStatus.seen,
};

/// 等待含 [marker] 的消息进入正向已发送态。返回最后观察到的消息对象；
/// 超时仍返回当前对象供诊断。
Future<Message?> waitSent(
  WidgetTester t,
  String marker, {
  int maxSeconds = 10,
}) async {
  Message? last;
  for (var i = 0; i < maxSeconds * 5; i++) {
    final f = itemContaining(marker);
    if (t.any(f)) {
      last = t.widget<ChatMessageItem>(f.first).message;
      if (settledStatuses.contains(last.status)) {
        return last;
      }
    }
    await t.pump(const Duration(milliseconds: 200));
  }
  return last;
}
