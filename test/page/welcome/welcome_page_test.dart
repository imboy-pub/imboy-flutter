import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/welcome/welcome_page.dart';

/// WelcomePage widget test
///
/// 覆盖：
///   - 品牌锚点：顶部 Logo (28×28) + 'ImBoy' wordmark
///   - Hero tag 接力（kBrandLogoHeroTag = 'imboy_brand_logo'）
///   - 引导步骤切换：3 个 step，PageView 滑动同步 indicator
///   - 按钮文案动态切换："下一步" / "开始使用"
///   - Skip 按钮跳转 /sign_in
///   - 语言选择器渲染（图标 + 当前语言名）
GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/welcome',
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomePage()),
      GoRoute(
        path: '/sign_in',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('sign in stub'))),
      ),
    ],
  );
}

Future<void> _pumpWelcome(WidgetTester tester) async {
  // 充足画布避免溢出
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
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
  await tester.pumpAndSettle();
}

void main() {
  group('WelcomePage brand anchors', () {
    testWidgets('renders top brand logo (28×28) + "ImBoy" wordmark', (
      tester,
    ) async {
      await _pumpWelcome(tester);

      // 顶部 logo 28×28
      final images = tester.widgetList<Image>(find.byType(Image));
      final brandLogo = images.firstWhere(
        (img) =>
            (img.image as AssetImage?)?.assetName ==
                'assets/images/imboy_logo0.png' &&
            img.width == 28,
      );
      expect(brandLogo.height, 28);
      expect(brandLogo.fit, BoxFit.contain);

      // wordmark "ImBoy"
      expect(find.text('ImBoy'), findsOneWidget);
    });

    testWidgets('renders Hero with kBrandLogoHeroTag for relay from Splash', (
      tester,
    ) async {
      await _pumpWelcome(tester);

      final heroes = tester.widgetList<Hero>(find.byType(Hero));
      final hasBrandHero = heroes.any((h) => h.tag == 'imboy_brand_logo');
      expect(
        hasBrandHero,
        isTrue,
        reason: 'WelcomePage top logo must wrap in Hero(tag: kBrandLogoHeroTag) '
            'as relay middle of Splash → Welcome → SignIn animation',
      );
    });
  });

  group('WelcomePage onboarding steps', () {
    testWidgets('initially shows step 1 with "下一步" button', (tester) async {
      await _pumpWelcome(tester);

      // PageView 默认在 page 0：显示 step1Title（默认 zhCn locale）
      expect(find.text('简单连接'), findsOneWidget);

      // 按钮文字 = "下一步"（非末尾页）
      expect(find.text('下一步'), findsOneWidget);
      expect(find.text('开始使用'), findsNothing);

      // Skip 按钮可见
      expect(find.text('跳过'), findsOneWidget);
    });

    testWidgets('on last page (step 3): button text is "开始使用", '
        'no "跳过" link', (tester) async {
      await _pumpWelcome(tester);

      // 滑动 PageView 到 step 3（page index = 2）
      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();

      // 末尾页按钮变成 "开始使用"
      expect(find.text('开始使用'), findsOneWidget);
      expect(find.text('下一步'), findsNothing);

      // Skip 链接已隐藏（末尾页不需要 skip）
      expect(find.text('跳过'), findsNothing);
    });
  });

  group('WelcomePage navigation', () {
    testWidgets('skip button navigates to /sign_in', (tester) async {
      await _pumpWelcome(tester);

      // 点击 "跳过"
      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();

      // 已跳到 stub /sign_in
      expect(find.text('sign in stub'), findsOneWidget);
    });

    testWidgets('"下一步" tap on first page advances to step 2', (
      tester,
    ) async {
      await _pumpWelcome(tester);
      expect(find.text('简单连接'), findsOneWidget);

      // 点击 "下一步" 跳到 step 2
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // step1 不再可见（PageView 滑走）；step2 标题（i18n step2Title）变可见
      // step2 文本不锁定具体内容（只验证 step1 滑走）
      expect(find.text('简单连接'), findsNothing);
    });

    testWidgets('"开始使用" tap on last page navigates to /sign_in', (
      tester,
    ) async {
      await _pumpWelcome(tester);

      // 滑到 step 3
      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();

      // 点击 "开始使用"
      await tester.tap(find.text('开始使用'));
      await tester.pumpAndSettle();

      expect(find.text('sign in stub'), findsOneWidget);
    });
  });

  group('WelcomePage language selector', () {
    testWidgets('renders language selector with icon + chevron', (
      tester,
    ) async {
      await _pumpWelcome(tester);

      // language icon 图标应可见（顶部右侧选择器）
      expect(find.byIcon(Icons.language), findsOneWidget);
      // 下拉箭头图标可见
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });
  });
}
