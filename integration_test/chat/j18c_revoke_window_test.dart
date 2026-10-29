// integration_test/chat/j18c_revoke_window_test.dart
//
// plan-v2.2 §9 J18.c（本人消息：允许/过期撤回分别 → 时限真实，撤回失败
// 保留合法状态）真机旅程：登录 demo_alice → 打开与 demo_bob 的 C2C →
//   ① 发送 OLD marker（稍后在窗口外做过期撤回）
//   ② 发送 FRESH marker，等状态离开 sending → 长按 →「撤回」→ 断言 FRESH
//      原文消失、出现「撤回了一条消息」占位（允许分支）
//   ③ 从 OLD 气泡 widget 读真实 createdAt，按 kDefaultRevokeWindowMs 真实
//      等待到窗口外（不改时钟、不改常量）
//   ④ 长按 OLD → 菜单仍有「撤回」（入口门控只看作者）→ 点击 → 断言出现
//      「超过 2 分钟，无法撤回」，OLD 原文仍在、占位数不增（过期分支）
//
// 时限两层一致：客户端 message_revoke_policy.dart kDefaultRevokeWindowMs=120s
// 在发网络前短路；后端 msg_c2c_logic.erl REVOKE_TIMEOUT_MS=120000。
//
// 前置（fixture 在测试外完成）：后端本地 daemon 绑定合成库；
// demo_alice/demo_bob 互为好友。
//
// 运行：
//   flutter test integration_test/chat/j18c_revoke_window_test.dart \
//     -d <real_device_id> \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//     --dart-define=TEST_PHONE=demo_alice \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     --dart-define=TEST_EXPECTED_UID=<alice-uid> \
//     --dart-define=PEER_UID=<bob-uid> \
//     --dart-define=PEER_TITLE=演示用户Bob \
//     --dart-define=TEST_ALLOW_BUSINESS_WRITES=true

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/message_revoke_policy.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peerUid = String.fromEnvironment('PEER_UID');
const _peerTitle = String.fromEnvironment('PEER_TITLE');

const _oldPrefix = '[J18C-OLD]';
const _freshPrefix = '[J18C-FRESH]';

/// 撤回占位文案（自己撤回 = messageWasWithdrawn，他人 = 带昵称前缀）。
const _revokedPlaceholder = '撤回了一条消息';

/// 与 e2e_chat_test 相同的会话列表判定（该实现为私有，此处复刻）。
bool _isOnConvList(WidgetTester t) =>
    t.any(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'ConversationPage',
      ),
    ) ||
    (t.any(find.byIcon(Icons.search)) &&
        t.any(find.byIcon(Icons.add_circle_outline)));

Future<bool> _openConversationTab(WidgetTester t) async {
  if (_isOnConvList(t)) return true;
  await tapAny(t, [
    find.byKey(const Key('tab_conversations')),
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.chat_bubble_outline),
    find.text('消息'),
    find.text('会话'),
  ]);
  for (int i = 0; i < 5; i++) {
    await settle(t, maxSeconds: 1);
    if (_isOnConvList(t)) return true;
  }
  return false;
}

String _textOf(Message m) => m is TextMessage ? m.text : '';

/// 文本含 [marker] 的消息气泡 widget（可读 message.createdAt / status）。
Finder _itemContaining(String marker) => find.byWidgetPredicate(
  (w) => w is ChatMessageItem && _textOf(w.message).contains(marker),
);

int _revokedCount(WidgetTester t) => find
    .textContaining(_revokedPlaceholder, findRichText: true)
    .evaluate()
    .length;

/// 以 [stepMs] 为步长轮询 [finder] 最多 [maxMs]，命中即 true。
Future<bool> _pollText(
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

bool _controllerHas(WidgetTester t, Finder field, String text) =>
    (t.widget<CupertinoTextField>(field).controller?.text ?? '').contains(text);

/// 经真实输入框 + 发送按钮链发出一条文本消息。
///
/// 发送后 ChatInput 会 `unfocus()` 关闭输入连接；而 `enterText` 内部的
/// `showKeyboard` 仅在 `focusedEditable` 变化时才 `requestKeyboard()`，同一
/// 字段第二次 `enterText` 会静默写不进去。故先真实点按输入框重建连接，并
/// 校验控制器文本确已写入，未写入则重置 `focusedEditable` 兜底重试一次。
Future<void> _sendText(WidgetTester t, Finder chatPage, String text) async {
  final input = find.descendant(
    of: chatPage,
    matching: find.byType(CupertinoTextField),
  );
  if (!t.any(input)) {
    fail('聊天页无输入框');
  }
  await t.tap(input.first, warnIfMissed: false);
  await t.pump(const Duration(milliseconds: 300));
  await t.enterText(input.first, text);
  if (!_controllerHas(t, input.first, text)) {
    t.binding.focusedEditable = null;
    await t.enterText(input.first, text);
  }
  expect(
    _controllerHas(t, input.first, text),
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
  expect(
    find.textContaining(text, findRichText: true),
    findsWidgets,
    reason: '$text 应出现在聊天列表',
  );
}

/// 正向已发送态；域 Message.canRevoke 要求 status==sent，服务端 ACK 前 UI
/// status 为 null（渲染上等同 sent，但域校验会拒绝撤回）。
const _settledStatuses = {
  MessageStatus.sent,
  MessageStatus.delivered,
  MessageStatus.seen,
};

/// 等待含 [marker] 的消息进入正向已发送态。返回最后观察到的消息对象；
/// 超时仍返回当前对象供诊断。
Future<Message?> _waitSent(
  WidgetTester t,
  String marker, {
  int maxSeconds = 10,
}) async {
  Message? last;
  for (var i = 0; i < maxSeconds * 5; i++) {
    final f = _itemContaining(marker);
    if (t.any(f)) {
      last = t.widget<ChatMessageItem>(f.first).message;
      if (_settledStatuses.contains(last.status)) {
        return last;
      }
    }
    await t.pump(const Duration(milliseconds: 200));
  }
  return last;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J18.c 本人消息：窗口内撤回成功，窗口外撤回被拒且原文保留', (tester) async {
    if (_expectedUid.isEmpty || _peerUid.isEmpty || _peerTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、PEER_UID、PEER_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J18.c 前置失败：登录未进入主界面');
    }
    final actualUid = UserRepoLocal.to.currentUid;
    if (actualUid != _expectedUid || actualUid == _peerUid) {
      fail('登录账号 UID=$actualUid 与授权发送方 $_expectedUid 不一致');
    }
    await settle(tester, maxSeconds: 2);
    await dismissRecoveryGuide(tester);
    await settle(tester, maxSeconds: 2);

    if (!await _openConversationTab(tester)) {
      fail('无法进入会话列表');
    }
    await settle(tester, maxSeconds: 2);

    final peerItem = find.byWidgetPredicate(
      (widget) =>
          widget is ConversationItem &&
          widget.model.type == 'C2C' &&
          widget.model.peerId.toString() == _peerUid &&
          widget.model.resolvedTitle == _peerTitle,
    );
    if (!tester.any(peerItem)) {
      fail('会话列表中无目标 $_peerTitle (uid=$_peerUid) 的 C2C 会话');
    }
    await safeTap(tester, peerItem.first);
    await settle(tester, maxSeconds: 3);
    final chatPage = find.byType(ChatPage);
    expect(chatPage, findsOneWidget, reason: '应进入聊天页');
    expect(
      tester.widget<ChatPage>(chatPage).peerId,
      _peerUid,
      reason: '聊天对象必须等于授权目标',
    );

    final nonce = DateTime.now().millisecondsSinceEpoch;
    final oldMarker = '$_oldPrefix $nonce';
    final freshMarker = '$_freshPrefix $nonce';

    // ① OLD：先发，记录其真实 createdAt（NTP 校时后的发送时刻）。
    await _sendText(tester, chatPage, oldMarker);
    final oldMsg = await _waitSent(tester, oldMarker);
    if (oldMsg == null || oldMsg.createdAt == null) {
      fail('OLD 消息未进入列表或无 createdAt（status=${oldMsg?.status}）');
    }
    final oldCreatedMs = oldMsg.createdAt!.millisecondsSinceEpoch;
    debugPrint(
      'J18C old createdAtMs=$oldCreatedMs status=${oldMsg.status} '
      'ntpOffsetMs=${NtpHelper.offset} deviceNowMs=$nonce',
    );

    // ② FRESH：发送 → 等 sent → 长按 →「撤回」→ 允许分支。
    await _sendText(tester, chatPage, freshMarker);
    final freshMsg = await _waitSent(tester, freshMarker);
    if (freshMsg == null) {
      fail('FRESH 消息未进入列表');
    }
    expect(
      _settledStatuses.contains(freshMsg.status),
      isTrue,
      reason:
          '撤回前消息须已进入正向已发送态（域规则要求 status==sent），'
          '实际 status=${freshMsg.status}',
    );
    final revokedBeforeFresh = _revokedCount(tester);

    await tester.longPress(
      find.textContaining(freshMarker, findRichText: true).first,
    );
    await settle(tester, maxSeconds: 2);
    final revokeAction = find.text('撤回');
    expect(revokeAction, findsWidgets, reason: '本人消息长按菜单应有「撤回」');
    // 直接 tap + 短 pump：toast（EasyLoading）仅存活约 2s，safeTap 自带的
    // settle 会在轮询开始前把它等没。
    await tester.tap(revokeAction.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    final successToastSeen = await _pollText(tester, find.text('撤回成功'));
    debugPrint('J18C fresh revokeSuccessToastSeen=$successToastSeen');

    // 终态：原文消失、占位 +1（message_revoke_ack 回流后替换气泡）。
    var freshGone = false;
    for (var i = 0; i < 30 && !freshGone; i++) {
      await settle(tester, maxSeconds: 1);
      freshGone = !tester.any(
        find.textContaining(freshMarker, findRichText: true),
      );
    }
    await takeScreenshot(tester, 'j18c_01_fresh_revoked');
    expect(freshGone, isTrue, reason: '窗口内撤回后 FRESH 原文应于 30s 内从列表消失');
    // 占位由 FutureBuilder 异步补齐昵称后渲染，轮询而非单次采样。
    var placeholderShown = false;
    for (var i = 0; i < 10 && !placeholderShown; i++) {
      placeholderShown = _revokedCount(tester) > revokedBeforeFresh;
      if (!placeholderShown) await settle(tester, maxSeconds: 1);
    }
    expect(
      placeholderShown,
      isTrue,
      reason: '窗口内撤回后应出现「$_revokedPlaceholder」占位',
    );

    // ③ 真实等待：以 OLD 的真实 createdAt 与设备本地时钟（revokeMessage 的
    // nowMs 同源）计算，超出 kDefaultRevokeWindowMs 再加 3s 裕量。
    final deadline = oldCreatedMs + kDefaultRevokeWindowMs + 3000;
    var now = DateTime.now().millisecondsSinceEpoch;
    debugPrint(
      'J18C waiting ${deadline - now}ms for OLD to leave revoke window',
    );
    while (now < deadline) {
      await settle(tester, maxSeconds: 5);
      now = DateTime.now().millisecondsSinceEpoch;
    }
    expect(
      canRevokeMessage(createdAtMs: oldCreatedMs, nowMs: now),
      isFalse,
      reason: '前置：OLD 必须已超出撤回窗口（age=${now - oldCreatedMs}ms）',
    );

    // ④ OLD：长按 → 菜单仍有「撤回」→ 点击 → 过期分支。
    final oldBubble = find.textContaining(oldMarker, findRichText: true);
    expect(oldBubble, findsWidgets, reason: '等待期间 OLD 原文应仍在列表');
    await tester.scrollUntilVisible(
      oldBubble.first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, maxSeconds: 1);
    await tester.longPress(oldBubble.first);
    await settle(tester, maxSeconds: 2);
    final revokeActionOld = find.text('撤回');
    expect(
      revokeActionOld,
      findsWidgets,
      reason: '入口门控只看作者：过期本人消息的长按菜单仍应有「撤回」',
    );
    await tester.tap(revokeActionOld.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    final expiredToastSeen = await _pollText(
      tester,
      find.textContaining('无法撤回'),
    );
    await takeScreenshot(tester, 'j18c_02_old_expired_toast');
    expect(
      expiredToastSeen,
      isTrue,
      reason: '过期撤回应即时提示「超过 2 分钟，无法撤回」（客户端短路，不发网络）',
    );
    await settle(tester, maxSeconds: 3);
    expect(
      find.textContaining(oldMarker, findRichText: true),
      findsWidgets,
      reason: '过期撤回失败后 OLD 原文应保留（合法状态）',
    );
    // 合法状态 = OLD 仍是文本气泡，未被转成撤回占位（_itemContaining 只匹配
    // TextMessage）。不用占位计数：懒加载列表滚动后视口外占位不再构建。
    expect(
      _itemContaining(oldMarker),
      findsOneWidget,
      reason: '过期撤回不得把 OLD 转成撤回占位',
    );
    await takeScreenshot(tester, 'j18c_03_old_retained');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
