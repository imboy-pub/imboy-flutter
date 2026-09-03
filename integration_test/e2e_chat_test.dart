// integration_test/e2e_chat_test.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';
import 'flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '',
);
const _peerUid = String.fromEnvironment('PEER_UID', defaultValue: '');
const _peerTitle = String.fromEnvironment('PEER_TITLE', defaultValue: '');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('C2C 聊天', () {
    testWidgets('打开已有单聊并发送文本消息', (tester) async {
      if (_expectedUid.isEmpty || _peerUid.isEmpty || _peerTitle.isEmpty) {
        markTestSkipped('需显式 TEST_EXPECTED_UID、PEER_UID 和 PEER_TITLE');
        return;
      }
      if (!requireBusinessWriteAuthorization()) return;
      await ensureAppLaunched(tester, maxSeconds: 3);
      if (!await checkPreconditions(tester)) return;
      final actualUid = UserRepoLocal.to.currentUid;
      if (actualUid != _expectedUid || actualUid == _peerUid) {
        fail('登录账号 UID=$actualUid 与授权发送方 $_expectedUid 不一致，或目标为自己');
      }
      await settle(tester, maxSeconds: 2);
      // 全新环境首次登录会弹 E2EE 恢复指南，「稍后」关掉避免挡住会话列表。
      await dismissRecoveryGuide(tester);
      await settle(tester, maxSeconds: 2);

      if (!await _openConversationTab(tester)) {
        markTestSkipped('无法进入会话列表');
        return;
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
        fail('会话列表中无显式目标 $_peerTitle (uid=$_peerUid) 的 C2C 会话');
      }

      await safeTap(tester, peerItem.first);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'c2c_01_chat_page');
      final chatPage = find.byType(ChatPage);
      expect(chatPage, findsOneWidget, reason: '点击目标会话后应进入聊天页');
      expect(
        tester.widget<ChatPage>(chatPage).peerId,
        _peerUid,
        reason: '实际聊天对象 UID 必须等于显式授权目标',
      );
      expect(tester.widget<ChatPage>(chatPage).type, 'C2C');
      expect(tester.widget<ChatPage>(chatPage).peerTitle, _peerTitle);

      final input = find.descendant(
        of: chatPage,
        matching: find.byType(CupertinoTextField),
      );
      if (!tester.any(input)) {
        fail('聊天页无输入框');
      }

      final msg = '[C2C-E2E] ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(input.first, msg);
      // 输入非空后发送按钮经 ValueListenableBuilder + AnimatedSwitcher
      // （300ms）才挂载（key=send_button）；不 pump 时按钮尚未构建，tapAny
      // 全部落空退化到键盘回车（真机软键盘无效），表现为"输入框未清空"。
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump(const Duration(milliseconds: 100));

      final sent = await tapAny(tester, [
        find.byKey(const ValueKey('send_button_inner')),
        find.byKey(const ValueKey('send_button')),
        find.byIcon(CupertinoIcons.arrow_up),
        find.text('发送'),
        find.text('Send'),
      ]);
      if (!sent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester, maxSeconds: 2);
      }

      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'c2c_02_after_send');

      final inputTexts = tester
          .widgetList<EditableText>(
            find.descendant(of: chatPage, matching: find.byType(EditableText)),
          )
          .map((widget) => widget.controller.text);
      expect(
        inputTexts.any((text) => text.contains(msg)),
        isFalse,
        reason: '发送后输入框必须清空',
      );
      expect(
        find.textContaining(msg, findRichText: true),
        findsWidgets,
        reason: '发送后消息应出现在聊天列表中',
      );
      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

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
    find.text('Chats'),
  ]);
  for (int i = 0; i < 5; i++) {
    await settle(t, maxSeconds: 1);
    if (_isOnConvList(t)) return true;
  }
  return false;
}
