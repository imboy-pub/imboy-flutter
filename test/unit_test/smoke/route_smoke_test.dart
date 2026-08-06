// 全页面路由烟雾测试 / Route smoke test
//
// 遍历 route_registry.dart 的全部路由：
//   - active     → go() 渲染并断言无同步异常（不崩溃、不红屏、不 Page not found）
//   - quarantine → skip（仍显示在报告中，避免漏测被静默隐藏）
// 另含「注册表完整性守卫」：断言注册表覆盖 router 全部 route name。
//
// 运行 / Run:
//   flutter test test/smoke/route_smoke_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/config/router/app_router.dart';

import 'route_registry.dart';
import 'smoke_test_harness.dart';

void main() {
  setUpAll(() {
    installSmokeHttpOverrides();
  });

  setUp(() async {
    await prepareSmokeEnv();
  });

  group('路由烟雾测试 / Route smoke test', () {
    for (final route in smokeRoutes) {
      if (isQuarantined(route)) {
        final reason =
            route.skipReason ??
            '异步泄漏名单：留 pending timer，与无头烟雾测试不兼容，'
                '应由 integration_test 覆盖';
        testWidgets(
          '[quarantine] ${route.name} — $reason',
          (tester) async {},
          skip: true,
        );
        continue;
      }

      testWidgets('${route.name} (${route.location}) 可渲染不崩溃', (tester) async {
        final error = await renderRoute(tester, route);
        expect(
          error,
          isNull,
          reason: '路由 ${route.name} (${route.location}) 渲染抛异常: $error',
        );
      });
    }
  });

  group('注册表完整性 / Registry integrity', () {
    testWidgets('注册表覆盖 router 全部路由 / registry covers all routes', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(goRouterProvider);
      final actual = <String>{};
      void walk(List<RouteBase> routes) {
        for (final r in routes) {
          if (r is GoRoute && r.name != null) actual.add(r.name!);
          walk(r.routes);
        }
      }

      walk(router.configuration.routes);

      final registered = smokeRoutes.map((e) => e.name).toSet();
      final missing = actual.difference(registered);
      final extra = registered.difference(actual);

      expect(
        missing,
        isEmpty,
        reason: '以下路由未登记进 route_registry.dart: $missing',
      );
      expect(extra, isEmpty, reason: '注册表存在 router 中不存在的多余路由（可能已被删除）: $extra');
    });
  });
}
