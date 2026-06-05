// integration_test/channel/channel_subscribed_detail_consistency_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../flows/app_launcher.dart';
import 'package:integration_test/integration_test.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('频道订阅详情一致性', () {
    testWidgets('已订阅频道详情页数据正常显示', (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 3);
      await checkPreconditions(tester);
      await settle(tester, maxSeconds: 2);

      if (!await _openChannelTab(tester)) {
        markTestSkipped('无法进入频道 Tab');
        return;
      }
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'consist_01_list');

      if (!tester.any(find.byType(ListTile))) {
        markTestSkipped('已订阅列表为空，无法验证一致性');
        return;
      }

      // 记录列表第一项的频道名
      String? channelName;
      final tile = tester.widget<ListTile>(find.byType(ListTile).first);
      if (tile.title is Text) channelName = (tile.title as Text).data?.trim();

      await safeTap(tester, find.byType(ListTile).first);
      await settle(tester, maxSeconds: 2);
      await takeScreenshot(tester, 'consist_02_detail');

      expect(
        _anyText(['频道不存在', 'Channel not found']),
        findsNothing,
        reason: '已订阅频道详情不应提示频道不存在',
      );

      if (channelName != null && channelName.isNotEmpty) {
        expect(
          find.textContaining(channelName),
          findsWidgets,
          reason: '详情页应显示与列表一致的频道名称',
        );
      }

      expect(find.byType(Scaffold), findsWidgets, reason: '频道详情页应有 Scaffold');
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
