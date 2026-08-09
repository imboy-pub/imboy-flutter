// P0 Demo Flow：频道发现 → 推荐列表/空态（只读）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/page/channel/channel_discover_page.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'P0 频道发现可读取推荐频道或空态（只读）',
    (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);

      final navigatorFinder = find.byType(Navigator).first;
      if (!tester.any(navigatorFinder)) {
        markTestSkipped('App 未找到根 Navigator');
        return;
      }

      final navigator = Navigator.of(
        tester.element(navigatorFinder),
        rootNavigator: true,
      );
      final route = navigator.push<void>(
        CupertinoPageRoute<void>(builder: (_) => const ChannelDiscoverPage()),
      );

      expect(
        await _waitFor(
          tester,
          () => tester.any(find.byType(ChannelDiscoverPage)),
        ),
        isTrue,
        reason: '频道发现页应挂载',
      );
      expect(
        await _waitFor(
          tester,
          () =>
              !tester.any(find.byType(ShimmerList)) &&
              (tester.any(find.byType(ListTile)) ||
                  tester.any(find.byType(NoDataView))),
        ),
        isTrue,
        reason: '频道发现页应结束加载并显示列表或空态',
      );

      flowLog(
        'P0 频道发现 Demo Flow：ListTile=${find.byType(ListTile).evaluate().length}',
      );
      if (navigator.canPop()) navigator.pop();
      await route;
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<bool> _waitFor(WidgetTester tester, bool Function() predicate) async {
  for (int i = 0; i < 40; i++) {
    if (predicate()) return true;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return predicate();
}
