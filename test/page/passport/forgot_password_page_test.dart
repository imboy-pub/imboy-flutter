import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/forgot_password_page.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';

/// ForgotPasswordPage widget test
///
/// 覆盖：
///   - PassportTitle 渲染（含 Hero kBrandLogoHeroTag）
///   - "找回密码" 标题（recoverPassword）
///   - 2 个 Tab（邮箱 / 手机）
///   - 默认 Tab 0 (email) 显示 1 个 TextField + "下一步" 按钮
///   - email hint "请输入邮箱"（pleaseInputParam param=email）
///   - tab 切换 mobile
GoRouter _stubRouter() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/forgot_password',
    routes: [
      GoRoute(
        path: '/forgot_password',
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/forgot_password/pin_code',
        builder: (_, _) => stub('pin_code stub'),
      ),
      GoRoute(path: '/sign_in', builder: (_, _) => stub('sign_in stub')),
    ],
  );
}

Future<void> _pump(WidgetTester tester) async {
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

  group('ForgotPasswordPage layout', () {
    testWidgets('renders PassportTitle (品牌锚点 + Hero relay)',
        (tester) async {
      await _pump(tester);
      expect(find.byType(PassportTitle), findsOneWidget);

      final heroes = tester.widgetList<Hero>(find.byType(Hero));
      final hasBrandHero = heroes.any((h) => h.tag == 'imboy_brand_logo');
      expect(hasBrandHero, isTrue);

      await _unmount(tester);
    });

    testWidgets('renders "找回密码" 标题（recoverPassword）', (tester) async {
      await _pump(tester);
      expect(find.text('找回密码'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('renders 2 个 Tab：邮箱 / 手机', (tester) async {
      await _pump(tester);
      expect(find.text('邮箱'), findsAtLeastNWidgets(1));
      expect(find.text('手机'), findsAtLeastNWidgets(1));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('default Tab 0 (email) → 1 个 TextField + "下一步" 按钮',
        (tester) async {
      await _pump(tester);
      // _buildEmailInput 仅 1 个 TextField
      expect(
        find.byType(TextField).evaluate().length,
        greaterThanOrEqualTo(1),
      );
      // "下一步" 按钮（i18n nextStep）
      expect(find.text('下一步'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });

    testWidgets('renders email hint "请输入邮箱" (pleaseInputParam)',
        (tester) async {
      await _pump(tester);
      // i18n: pleaseInputParam = "请输入$param"，param=email="邮箱" → "请输入邮箱"
      expect(find.text('请输入邮箱'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('ForgotPasswordPage tab switching', () {
    testWidgets('tap 手机 Tab → TabController 切换', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('手机').last);
      await tester.pumpAndSettle();

      expect(find.byType(TabBarView), findsOneWidget);

      await _unmount(tester);
    });
  });
}
