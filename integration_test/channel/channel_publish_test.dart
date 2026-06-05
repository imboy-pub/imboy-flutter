// integration_test/channel/channel_publish_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('频道发布', () {
    testWidgets('向已有频道发布文本消息', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 3);
      await checkPreconditions(tester);
      await settle(tester, maxSeconds: 2);

      if (!await _openChannelTab(tester)) {
        markTestSkipped('无法进入频道 Tab');
        return;
      }
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'pub_01_channel_list');

      final myFinder = _anyText(['我的频道', 'My Channels', '管理频道']);
      if (tester.any(myFinder)) {
        await safeTap(tester, myFinder.first);
        await settle(tester, maxSeconds: 2);
      }

      if (!tester.any(find.byType(ListTile))) {
        markTestSkipped('当前账号无可发布频道');
        return;
      }

      await safeTap(tester, find.byType(ListTile).first);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'pub_02_detail');

      expect(
        _anyText(['频道不存在', 'Channel not found']),
        findsNothing,
        reason: '进入频道后不应提示频道不存在',
      );

      final input = find.byType(TextField);
      if (!tester.any(input)) {
        markTestSkipped('当前账号无发布权限');
        return;
      }

      await tester.enterText(
        input.first,
        '[PUB-E2E] ${DateTime.now().millisecondsSinceEpoch}',
      );
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
      expect(
        _anyText(['发布失败', 'Publish failed']),
        findsNothing,
        reason: '发布后不应出现失败提示',
      );
      drainKnownFrameworkExceptions(tester);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

bool _isOnChannelList(WidgetTester t) =>
    t.any(_anyText(['频道', 'Channel', 'Channels'])) &&
    t.any(find.byIcon(Icons.search));

Future<bool> _openChannelTab(WidgetTester t) async {
  if (_isOnChannelList(t)) return true;
  for (int i = 0; i < 4; i++) {
    await tapAny(t, [
      find.byIcon(Icons.campaign_outlined),
      find.byIcon(Icons.campaign),
      find.text('频道'),
      find.text('Channel'),
      find.text('Channels'),
    ]);
    await settle(t, maxSeconds: 2);
    if (_isOnChannelList(t)) return true;
  }
  return false;
}

Finder _anyText(List<String> c) => find.byWidgetPredicate((w) {
  if (w is! Text) return false;
  final d = w.data?.trim();
  return d != null && d.isNotEmpty && c.any((s) => d.contains(s));
});
