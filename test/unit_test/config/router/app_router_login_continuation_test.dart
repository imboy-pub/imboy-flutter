import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/router/app_router.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _target = '/organization/995101/member/995012?tab=workspaces#membership';
const _contextKey = ValueKey('auth-redirect-context');

Future<GoRouter> _setup(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await StorageService.init();
  final previousFlags = Map<String, dynamic>.from(AppFeatureRegistry.snapshot);
  final router = createAppRouter(
    navigatorKeyOverride: GlobalKey<NavigatorState>(),
  );
  await tester.pumpWidget(const MaterialApp(home: SizedBox(key: _contextKey)));
  addTearDown(() async {
    router.dispose();
    AppFeatureRegistry.replaceSnapshotForTest(previousFlags);
  });
  return router;
}

Future<String?> _redirect(
  WidgetTester tester,
  GoRouter router,
  String location,
) async {
  final uri = Uri.parse(location);
  final result = await router.configuration.topRedirect(
    tester.element(find.byKey(_contextKey)),
    GoRouterState(
      router.configuration,
      uri: uri,
      matchedLocation: uri.path,
      fullPath: uri.path,
      pathParameters: const {},
      pageKey: ValueKey(location),
    ),
  );
  // Flush production notification timers after disposing their context.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpWidget(const MaterialApp(home: SizedBox(key: _contextKey)));
  return result;
}

Future<void> _login() =>
    StorageService.to.setString(Keys.currentUid, 'synthetic').then((_) {});

void main() {
  for (final landing in ['/bottom_navigation', '/web_shell']) {
    testWidgets('企业直达链接登录后经$landing恢复一次且保留query/fragment', (tester) async {
      final router = await _setup(tester);
      expect(await _redirect(tester, router, _target), '/sign_in');
      await _login();
      expect(await _redirect(tester, router, '/sign_in'), isNull);
      expect(await _redirect(tester, router, landing), _target);
      expect(await _redirect(tester, router, _target), isNull);
      expect(await _redirect(tester, router, landing), isNull);
    });
  }
  testWidgets('登录后恢复的关闭项目仍被功能守卫拒绝且无循环', (tester) async {
    final router = await _setup(tester);
    const target = '/workspace/100/projects/200?section=tasks';
    AppFeatureRegistry.replaceSnapshotForTest({'project': false});
    expect(await _redirect(tester, router, target), '/sign_in');
    await _login();
    expect(await _redirect(tester, router, '/bottom_navigation'), target);
    expect(await _redirect(tester, router, target), '/bottom_navigation');
    expect(await _redirect(tester, router, '/bottom_navigation'), isNull);
  });
  testWidgets('公共登录页和默认首页不会成为待恢复目标', (tester) async {
    final router = await _setup(tester);
    expect(await _redirect(tester, router, '/welcome'), isNull);
    expect(await _redirect(tester, router, '/sign_in'), isNull);
    expect(await _redirect(tester, router, '/bottom_navigation'), '/sign_in');
    await _login();
    expect(await _redirect(tester, router, '/web_shell'), isNull);
  });
  for (final target in [
    'https://invalid.example/organization/10',
    '//invalid.example/organization/10',
  ]) {
    testWidgets('不保存外部或协议相对目标$target', (tester) async {
      final router = await _setup(tester);
      expect(await _redirect(tester, router, target), '/sign_in');
      await _login();
      expect(await _redirect(tester, router, '/bottom_navigation'), isNull);
    });
  }
  testWidgets('待恢复地址仅属于其路由实例', (tester) async {
    final router = await _setup(tester);
    final other = createAppRouter(
      navigatorKeyOverride: GlobalKey<NavigatorState>(),
    );
    addTearDown(other.dispose);
    expect(await _redirect(tester, router, _target), '/sign_in');
    await _login();
    expect(await _redirect(tester, other, '/web_shell'), isNull);
    expect(await _redirect(tester, router, '/web_shell'), _target);
  });
  testWidgets('个人标签直达query在登录后保留', (tester) async {
    final router = await _setup(tester);
    const target = '/bottom_navigation?index=2';
    expect(await _redirect(tester, router, target), '/sign_in');
    await _login();
    expect(await _redirect(tester, router, '/bottom_navigation'), target);
    expect(await _redirect(tester, router, target), isNull);
  });
  for (final landing in ['/bottom_navigation', '/web_shell', '/chat_shell']) {
    for (final entry in {'2': 2, '99': 99, '-1': -1, 'invalid': 0}.entries) {
      testWidgets('个人深链 index=${entry.key} 经 $landing 一次恢复并归一', (tester) async {
        final router = await _setup(tester);
        final target = '/bottom_navigation?index=${entry.key}#synthetic-tab';
        expect(await _redirect(tester, router, target), '/sign_in');
        await _login();
        final restored = await _redirect(tester, router, landing);
        expect(restored, target);
        for (final tabs in [3, 4]) {
          final expected = entry.value.clamp(0, tabs - 1);
          expect(
            resolveInitialIndex(Uri.parse(restored!).queryParameters, tabs),
            expected,
          );
        }
        expect(await _redirect(tester, router, target), isNull);
        expect(await _redirect(tester, router, landing), isNull);
      });
    }
  }
}
