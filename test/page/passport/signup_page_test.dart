import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/passport/signup_page.dart';
import 'package:imboy/page/passport/widget/passport_title.dart';

/// SignupPage widget test
///
/// 覆盖：
///   - PassportTitle 渲染（含 Hero kBrandLogoHeroTag 接力）
///   - 2 个 Tab（邮箱 / 手机）
///   - "已经有账号了？" + "登录" 链接
///   - "下一步" 按钮渲染
///   - tap 登录链接 → /sign_in
///   - tab 切换交互
GoRouter _stubRouter() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/sign_up',
    routes: [
      GoRoute(path: '/sign_up', builder: (_, _) => const SignupPage()),
      GoRoute(path: '/sign_in', builder: (_, _) => stub('sign_in stub')),
    ],
  );
}

Future<void> _pump(WidgetTester tester) async {
  // SignupPage 内含 BezierContainer + PassportTitle + 2 TextField + Tab + button
  // 需充足画布
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1400);
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

  group('SignupPage layout', () {
    testWidgets('renders PassportTitle (品牌锚点 + Hero relay)',
        (tester) async {
      await _pump(tester);
      expect(find.byType(PassportTitle), findsOneWidget);

      // Hero tag 接力
      final heroes = tester.widgetList<Hero>(find.byType(Hero));
      final hasBrandHero = heroes.any((h) => h.tag == 'imboy_brand_logo');
      expect(hasBrandHero, isTrue);

      await _unmount(tester);
    });

    testWidgets('renders 2 个 Tab：邮箱 / 手机', (tester) async {
      await _pump(tester);

      // i18n: email="邮箱" / mobile="手机"
      expect(find.text('邮箱'), findsAtLeastNWidgets(1));
      expect(find.text('手机'), findsAtLeastNWidgets(1));

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(TabBarView), findsOneWidget);

      await _unmount(tester);
    });

    testWidgets('renders "已经有账号了？" + "登录" 链接', (tester) async {
      await _pump(tester);
      // i18n: siginQ="已经有账号了？" / login="登录"
      expect(find.text('已经有账号了？'), findsOneWidget);
      expect(find.text('登录'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });

    testWidgets('renders "下一步" button (i18n nextStep)', (tester) async {
      await _pump(tester);
      // 默认 Tab 0 (email register) 显示 nextStep button
      expect(find.text('下一步'), findsAtLeastNWidgets(1));
      await _unmount(tester);
    });
  });

  group('SignupPage email tab (default Tab 0)', () {
    testWidgets('default Tab 0 → 至少 3 个 TextField (昵称 + 邮箱 + 密码)',
        (tester) async {
      await _pump(tester);

      // _buildEmailRegister: nickname + email + password 三个 TextField
      expect(
        find.byType(TextField).evaluate().length,
        greaterThanOrEqualTo(3),
      );

      await _unmount(tester);
    });

    testWidgets('renders 昵称 hint (nicknameHint)', (tester) async {
      await _pump(tester);
      // i18n: nicknameHint = "请输入昵称"
      expect(find.text('请输入昵称'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('renders 邮箱 hint (passport.hintEmail)', (tester) async {
      await _pump(tester);
      // i18n: passport.hintEmail = "请输入邮箱"
      expect(find.text('请输入邮箱'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('SignupPage tab switching', () {
    testWidgets('tap 手机 Tab → TabController 切换', (tester) async {
      await _pump(tester);

      await tester.tap(find.text('手机').last);
      await tester.pumpAndSettle();

      // 切换后 TabBarView 仍渲染
      expect(find.byType(TabBarView), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('SignupPage navigation', () {
    testWidgets('tap "登录" 链接 → /sign_in', (tester) async {
      await _pump(tester);

      // 点击底部"登录"链接（避免与 Tab 冲突，用 last 取第二处）
      // 实际页面只有一处 "登录" 字（底部链接）；Tab 是 "邮箱" 和 "手机" 不含 "登录"
      await tester.tap(find.text('登录'));
      await tester.pumpAndSettle();

      expect(find.text('sign_in stub'), findsOneWidget);

      await _unmount(tester);
    });
  });
}
