// 频道发现只读演示：验证推荐频道读取与无数据空态，不订阅、不付费、不进入详情页。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/page/channel/channel_discover_page.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '频道发现页可读取推荐频道或显示空态',
    (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      final navigatorFinder = find.byType(Navigator).first;
      if (!tester.any(navigatorFinder)) {
        markTestSkipped('App 未找到 Navigator，跳过频道发现只读页');
        return;
      }

      final navigatorState = Navigator.of(
        tester.element(navigatorFinder),
        rootNavigator: true,
      );
      final routeResult = navigatorState.push<void>(
        CupertinoPageRoute<void>(builder: (_) => const ChannelDiscoverPage()),
      );

      final mounted = await _waitFor(
        tester,
        () => tester.any(find.byType(ChannelDiscoverPage)),
        maxAttempts: 30,
      );
      expect(mounted, isTrue, reason: '频道发现页应成功挂载');
      expect(find.byType(Scaffold), findsWidgets);

      final loaded = await _waitFor(
        tester,
        () =>
            !tester.any(find.byType(ShimmerList)) &&
            (tester.any(find.byType(ListTile)) ||
                tester.any(find.byType(NoDataView))),
        maxAttempts: 40,
      );
      expect(loaded, isTrue, reason: '频道发现页应结束加载并显示列表或空态');

      final resultCount = find.byType(ListTile).evaluate().length;
      if (resultCount > 0) {
        flowLog('频道发现只读通过：推荐频道列表已显示（ListTile=$resultCount）');
      } else {
        expect(find.byType(NoDataView), findsWidgets);
        flowLog('频道发现只读通过：当前账号暂无公开推荐频道，空态正常显示');
      }

      if (navigatorState.canPop()) navigatorState.pop();
      await settle(tester, maxSeconds: 1);
      await routeResult;
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
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
