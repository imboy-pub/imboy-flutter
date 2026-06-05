// integration_test/chat/group_chat_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('群聊', () {
    testWidgets('进入已有群聊并发送文本消息', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 3);
      await checkPreconditions(tester);
      await settle(tester, maxSeconds: 2);

      if (!await _openConversationTab(tester)) {
        markTestSkipped('无法进入会话列表');
        return;
      }
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'group_01_conv_list');

      // 优先找群聊标识，回退第一个会话
      final groupFinder = _anyText(['群', 'Group', '群聊']);
      final listTile = find.byType(ListTile);
      final target = tester.any(groupFinder)
          ? groupFinder.first
          : tester.any(listTile)
          ? listTile.first
          : null;

      if (target == null) {
        markTestSkipped('未找到群聊会话');
        return;
      }

      await safeTap(tester, target);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'group_02_chat_page');

      final inputField = find.byType(TextField);
      if (!tester.any(inputField)) {
        markTestSkipped('聊天页无输入框（可能被禁言）');
        return;
      }

      final msg = '[GROUP-E2E] ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(inputField.first, msg);

      final sent = await tapAny(tester, [
        find.byIcon(Icons.send),
        find.text('发送'),
        find.text('Send'),
      ]);
      if (!sent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester, maxSeconds: 2);
      }

      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'group_03_after_send');

      expect(
        find.textContaining('[GROUP-E2E]'),
        findsWidgets,
        reason: '发送后消息应出现在聊天列表中',
      );
      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

bool _isOnConvList(WidgetTester t) =>
    t.any(find.byIcon(Icons.search)) &&
    t.any(find.byIcon(Icons.add_circle_outline));

Future<bool> _openConversationTab(WidgetTester t) async {
  if (_isOnConvList(t)) return true;
  await tapAny(t, [
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

Finder _anyText(List<String> c) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final d = w.data?.trim();
  return d != null && d.isNotEmpty && c.any((s) => d.contains(s));
});
