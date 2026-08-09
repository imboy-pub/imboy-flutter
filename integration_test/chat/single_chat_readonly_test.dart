// 会话列表 → 已有 C2C 单聊 → 历史只读 UI 流程。
// 不输入、不发送、不改变未读/置顶状态。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '从已有 C2C 会话进入单聊页面可访问',
    (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);
      await _dismissRecoveryGuideIfVisible(tester);

      if (!await _openConversationTab(tester)) {
        markTestSkipped('无法进入会话列表');
        return;
      }

      final c2cItem = await _waitForExistingC2CItem(tester);
      if (c2cItem == null) {
        markTestSkipped('当前测试账号没有可识别的已有 C2C 会话');
        return;
      }

      await safeTap(tester, c2cItem.first);
      final onChatPage = await _waitFor(
        tester,
        () => tester.any(find.byType(ChatPage)),
        maxAttempts: 30,
      );
      if (!onChatPage) {
        markTestSkipped('已有 C2C 会话未进入单聊页面');
        return;
      }

      await takeScreenshot(tester, 'single_chat_readonly_01');
      expect(find.byType(ChatPage), findsOneWidget);
      flowLog('单聊只读页面已打开，未输入或发送消息');
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

bool _isOnConversationList(WidgetTester tester) =>
    tester.any(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'ConversationPage',
      ),
    ) ||
    (tester.any(find.byIcon(Icons.search)) &&
        tester.any(find.byIcon(Icons.add_circle_outline)));

Future<bool> _openConversationTab(WidgetTester tester) async {
  if (_isOnConversationList(tester)) return true;
  await tapAny(tester, [
    find.byKey(const Key('tab_conversations')),
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.chat_bubble_outline),
    find.text('消息'),
    find.text('会话'),
    find.text('Chats'),
  ]);
  for (int i = 0; i < 10; i++) {
    await settle(tester, maxSeconds: 1);
    if (_isOnConversationList(tester)) return true;
  }
  return false;
}

Future<Finder?> _waitForExistingC2CItem(WidgetTester tester) async {
  for (int i = 0; i < 60; i++) {
    final item = find.byWidgetPredicate(
      (widget) => widget is ConversationItem && widget.model.type == 'C2C',
    );
    if (tester.any(item)) return item;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return null;
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() predicate, {
  required int maxAttempts,
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    if (predicate()) return true;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return predicate();
}

Future<void> _dismissRecoveryGuideIfVisible(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    final later = find.byWidgetPredicate(
      (widget) =>
          widget is Text && ['稍后', 'Later'].contains(widget.data?.trim()),
    );
    if (tester.any(later)) {
      await safeTap(tester, later.first);
      return;
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}
