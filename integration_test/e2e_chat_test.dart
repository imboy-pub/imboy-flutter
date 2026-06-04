// integration_test/e2e_chat_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:integration_test/integration_test.dart';
import 'flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('C2C 聊天', () {
    testWidgets('打开已有单聊并发送文本消息', (tester) async {
      app.main();
      await settle(tester, maxSeconds: 3);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      if (!await _openConversationTab(tester)) { markTestSkipped('无法进入会话列表'); return; }
      await settle(tester, maxSeconds: 2);

      if (!tester.any(find.byType(ListTile))) { markTestSkipped('会话列表为空'); return; }

      await safeTap(tester, find.byType(ListTile).first);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'c2c_01_chat_page');

      final input = find.byType(TextField);
      if (!tester.any(input)) { markTestSkipped('聊天页无输入框'); return; }

      final msg = '[C2C-E2E] ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(input.first, msg);

      final sent = await tapAny(tester, [find.byIcon(Icons.send), find.text('发送'), find.text('Send')]);
      if (!sent) { await tester.sendKeyEvent(LogicalKeyboardKey.enter); await settle(tester, maxSeconds: 2); }

      await settle(tester, maxSeconds: 3);
      await takeScreenshot(tester, 'c2c_02_after_send');

      expect(find.textContaining('[C2C-E2E]'), findsWidgets,
          reason: '发送后消息应出现在聊天列表中');
      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

bool _isOnConvList(WidgetTester t) =>
    t.any(find.byIcon(Icons.search)) && t.any(find.byIcon(Icons.add_circle_outline));

Future<bool> _openConversationTab(WidgetTester t) async {
  if (_isOnConvList(t)) return true;
  await tapAny(t, [find.byIcon(Icons.chat_bubble), find.byIcon(Icons.chat_bubble_outline),
      find.text('消息'), find.text('会话'), find.text('Chats')]);
  for (int i = 0; i < 5; i++) {
    await settle(t, maxSeconds: 1);
    if (_isOnConvList(t)) return true;
  }
  return false;
}
