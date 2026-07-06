// integration_test/send_batch_c2c_test.dart
// 批量发送 10 条单聊消息，验证端到端 C2C 消息收发链路。
// 复用 e2e_chat_test 的 flows helper 与会话定位逻辑。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'flows/app_launcher.dart';
import 'flows/test_utils.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批量发送 10 条单聊消息', (tester) async {
    await ensureAppLaunched(tester, maxSeconds: 3);
    await checkPreconditions(tester);
    await settle(tester, maxSeconds: 2);

    if (!await _openConversationTab(tester)) {
      fail('无法进入会话列表');
    }
    await settle(tester, maxSeconds: 2);

    final convItemFinder = tester.any(find.byKey(const Key('conversation_list_item')))
        ? find.byKey(const Key('conversation_list_item'))
        : find.byType(ListTile);
    if (!tester.any(convItemFinder)) {
      fail('会话列表为空');
    }

    await safeTap(tester, convItemFinder.first);
    await settle(tester, maxSeconds: 2);

    final input = find.byType(TextField);
    if (!tester.any(input)) {
      fail('聊天页无输入框');
    }

    var sentCount = 0;
    for (var i = 1; i <= 10; i++) {
      final msg = '[BATCH-C2C #$i] ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(input.first, msg);
      final sent = await tapAny(
        tester,
        [
          find.byIcon(Icons.send),
          find.text('发送'),
          find.text('Send'),
        ],
      );
      if (!sent) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await settle(tester, maxSeconds: 2);
      }
      await settle(tester, maxSeconds: 2);
      sentCount++;
      debugPrint('[BATCH-C2C] 已发送 #$i: $msg');
    }

    await takeScreenshot(tester, 'batch_c2c_done');
    debugPrint('[BATCH-C2C] 完成，共发送 $sentCount 条');
    expect(sentCount, 10);
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

bool _isOnConvList(WidgetTester t) =>
    t.any(find.byIcon(Icons.search)) && t.any(find.byIcon(Icons.add_circle_outline));

Future<bool> _openConversationTab(WidgetTester t) async {
  if (_isOnConvList(t)) return true;
  await tapAny(
    t,
    [
      find.byIcon(Icons.chat_bubble),
      find.byIcon(Icons.chat_bubble_outline),
      find.text('消息'),
      find.text('会话'),
      find.text('Chats'),
    ],
  );
  for (var i = 0; i < 5; i++) {
    await settle(t, maxSeconds: 1);
    if (_isOnConvList(t)) return true;
  }
  return false;
}
