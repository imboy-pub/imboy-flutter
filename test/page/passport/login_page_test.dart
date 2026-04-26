import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/login_page.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';

/// LoginPage widget test
///
/// 覆盖：
///   - 渲染 PassportTitle 品牌锚点（含 Hero kBrandLogoHeroTag）
///   - 3 个 Tab：账号 / 手机 / 邮箱
///   - 默认在第 0 个 Tab（账号登录）渲染输入框
///   - "忘记密码？" 链接渲染
///   - tab 切换 → TabBarView 切换
GoRouter _stubRouter() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/sign_in',
    routes: [
      GoRoute(path: '/sign_in', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/forgot_password',
        builder: (_, _) => stub('forgot stub'),
      ),
      GoRoute(path: '/sign_up', builder: (_, _) => stub('sign_up stub')),
    ],
  );
}

Future<void> _pump(WidgetTester tester) async {
  // LoginPage 渲染含 BezierContainer + 表单 + Tab + button，需充足画布
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: _stubRouter()),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
  });

  tearDownAll(() {
    IMBoyCacheManager.debugLogEnabled = true;
  });

  group('LoginPage layout', () {
    testWidgets('renders PassportTitle (品牌锚点 + Hero relay)',
        (tester) async {
      await _pump(tester);

      expect(find.byType(PassportTitle), findsOneWidget);
      // Hero tag 接力起点（welcome → 此处）
      final heroes = tester.widgetList<Hero>(find.byType(Hero));
      final hasBrandHero = heroes.any((h) => h.tag == 'imboy_brand_logo');
      expect(hasBrandHero, isTrue);

      await _unmount(tester);
    });

    testWidgets('renders 3 个 Tab：账号 / 手机 / 邮箱', (tester) async {
      await _pump(tester);

      // i18n: account / mobile / email
      expect(find.text('账号'), findsAtLeastNWidgets(1));
      expect(find.text('手机'), findsAtLeastNWidgets(1));
      expect(find.text('邮箱'), findsAtLeastNWidgets(1));

      // 至少 1 个 TabBar
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('renders "忘记密码？" 链接', (tester) async {
      await _pump(tester);
      expect(find.text('忘记密码？'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('renders 登录按钮（i18n buttonLogin="登录"）', (tester) async {
      await _pump(tester);
      // 默认 Tab 0（账号）展示登录按钮
      expect(find.text('登录'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });
  });

  group('LoginPage tab switching', () {
    testWidgets('default Tab 0 → 账号 + 密码 输入框可见', (tester) async {
      await _pump(tester);

      // 默认账号 Tab，至少 2 个 TextField（账号 + 密码）
      expect(
        find.byType(TextField).evaluate().length,
        greaterThanOrEqualTo(2),
        reason: '账号 Tab 应有账号 + 密码 2 个 TextField',
      );

      await _unmount(tester);
    });

    testWidgets('tap mobile Tab → TabController 切换', (tester) async {
      await _pump(tester);

      // tap "手机" tab（找最里层 Tab widget 上的 text）
      await tester.tap(find.text('手机').last);
      await tester.pumpAndSettle();

      // 切换后页面仍能渲染（不抛错）
      expect(find.byType(TabBarView), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('tap email Tab → TabController 切换', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('邮箱').last);
      await tester.pumpAndSettle();

      expect(find.byType(TabBarView), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('LoginPage navigation', () {
    testWidgets('tap 忘记密码 → /forgot_password', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('忘记密码？'));
      await tester.pumpAndSettle();

      expect(find.text('forgot stub'), findsOneWidget);

      await _unmount(tester);
    });
  });
}
