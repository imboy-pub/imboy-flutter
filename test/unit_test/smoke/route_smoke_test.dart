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
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/app_core/routing/route_feature_guard.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:imboy/service/message.dart';

import 'route_registry.dart';
import 'smoke_test_harness.dart';

void main() {
  setUpAll(() {
    installSmokeHttpOverrides();
    // 应用级单例归套件所有，页面卸载不应销毁它。
    MessageService.instance;
  });

  tearDownAll(() => MessageService.instance.dispose());

  setUp(() async {
    await prepareSmokeEnv();
  });

  group('路由烟雾测试 / Route smoke test', () {
    for (final route in smokeRoutes) {
      if (isQuarantined(route) &&
          !const bool.fromEnvironment('SMOKE_INCLUDE_QUARANTINED')) {
        final reason =
            route.skipReason ??
            '尚未恢复：平台依赖或生命周期缺陷，'
                '见 docs/reference/route-smoke-coverage.md';
        testWidgets(
          '[quarantine] ${route.name} — $reason',
          (tester) async {},
          skip: true,
        );
        continue;
      }

      testWidgets('${route.name} (${route.location}) 可渲染不崩溃', (tester) async {
        if (route.name.startsWith('live_room_')) mockSmokeVideoRenderer();
        final error = await renderRoute(tester, route);
        // 编译期清单未收录的特性（如 phase1_delivery 关闭的 channel 子特性）
        // 会被 RouteFeatureGuard 重定向到兜底页：重定向是受控契约而非崩溃，
        // 按当前编译清单推导预期；未被门禁拦截的路由仍要求完整渲染。
        final blocked = RouteFeatureGuard.checkBlocked(
          isLoggedIn: true,
          currentPath: route.location,
        );
        if (blocked != null) {
          expect(
            error,
            isA<StateError>(),
            reason:
                '路由 ${route.name} (${route.location}) 应被门禁重定向: '
                '$blocked，实际错误: $error',
          );
          expect(error.toString(), contains('got /bottom_navigation'));
          return;
        }
        expect(
          error,
          isNull,
          reason: '路由 ${route.name} (${route.location}) 渲染抛异常: $error',
        );
      });
    }
  });

  for (final name in ['moment_feed', 'channel_detail']) {
    testWidgets('disabled $name entry cannot certify target rendering', (
      tester,
    ) async {
      addTearDown(() => PersistentMessageQueue.to.dispose());
      final manifest = AppManifestService.manifest!;
      AppManifestService.replaceForTest({
        ...manifest.toMap(),
        'app_entries': <String>[],
      });
      addTearDown(() => AppManifestService.replaceForTest(manifest.toMap()));
      final route = smokeRoutes.singleWhere((route) => route.name == name);
      final error = await renderRoute(tester, route);
      PersistentMessageQueue.to.dispose();
      expect(error, isA<StateError>());
      expect(error.toString(), contains('got /bottom_navigation'));
    });
  }

  for (final name in ['qrcode_group', 'qrcode_channel', 'feedback_detail']) {
    testWidgets('missing $name extra cannot certify placeholder rendering', (
      tester,
    ) async {
      final route = smokeRoutes.singleWhere((route) => route.name == name);
      final error = await renderRoute(
        tester,
        SmokeRoute(name: route.name, location: route.location),
      );
      expect(error, isA<StateError>());
    });
  }

  group('controlled alias terminal contract', () {
    testWidgets('explicit target renders the real detail page', (tester) async {
      final route = smokeRoutes.singleWhere(
        (route) => route.name == 'talk_record_card_locator',
      );
      expect(await renderRoute(tester, route), isNull);
    });
    testWidgets('missing declaration keeps strict entry-path expectation', (
      tester,
    ) async {
      final error = await renderRoute(
        tester,
        const SmokeRoute(
          name: 'talk_record_card_locator',
          location: '/talk-records/9001',
        ),
      );
      expect(error, isA<StateError>());
    });
    testWidgets('wrong terminal name cannot certify redirect', (tester) async {
      final error = await renderRoute(
        tester,
        const SmokeRoute(
          name: 'talk_record_card_locator',
          location: '/talk-records/9001',
          expectedLocation: '/talk_record/detail/9001',
          expectedRouteName: 'settings',
        ),
      );
      expect(error, isA<StateError>());
    });
    testWidgets('matching substitute route still requires the detail widget', (
      tester,
    ) async {
      final error = await renderRoute(
        tester,
        const SmokeRoute(
          name: 'talk_record_card_locator',
          location: '/settings',
          expectedLocation: '/settings',
          expectedRouteName: 'settings',
        ),
      );
      expect(error, isA<StateError>());
    });
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
      const optionalRouteNames = <String, Set<String>>{
        'moment': {
          'moment_feed',
          'moment_create',
          'moment_notify',
          'moment_detail',
        },
        'location': {'people_nearby', 'map_location_picker'},
        'channel': {
          'qrcode_channel',
          'channel_list',
          'channel_create',
          'channel_detail',
          'channel_edit',
          'channel_compose',
          'channel_admins',
          'channel_subscribers',
          'channel_article',
          'channel_comments',
        },
        'channel_discover': {'channel_discover'},
        'channel_invitation': {'channel_invitations'},
        'channel_order': {'channel_orders', 'channel_order_detail'},
        'group_vote': {'group_vote', 'group_vote_detail'},
        'group_schedule': {'group_schedule', 'group_schedule_detail'},
        'group_task': {'group_task', 'group_task_detail'},
      };
      final excluded = <String>{
        for (final entry in optionalRouteNames.entries)
          if (!compiledProductFeatures.contains(entry.key)) ...entry.value,
      };
      expect(
        actual.intersection(excluded),
        isEmpty,
        reason: 'Excluded feature routes must not be registered',
      );
      final extra = registered.difference(actual);
      expect(
        extra,
        excluded,
        reason: 'Only explicitly compiled-out routes may be absent',
      );

      expect(
        missing,
        isEmpty,
        reason: '以下路由未登记进 route_registry.dart: $missing',
      );
    });
  });
}
