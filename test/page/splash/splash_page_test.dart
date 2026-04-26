import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/splash/splash_page.dart';

/// SplashPage 响应式 logo + Hero 锚点 + 品牌元素契约测试
///
/// 关键挑战：SplashPage 在 initState 调 _checkAuth()，1400ms 后 `context.go` 跳转。
/// 测试用 GoRouter stub 提供 /welcome 和 /bottom_navigation 路由（接收跳转），
/// 仅 pump() 一帧验证初始渲染（不 pumpAndSettle 避免触发跳转 + 避免 pending timer）。
GoRouter _stubRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(
        path: '/welcome',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('welcome stub'))),
      ),
      GoRoute(
        path: '/bottom_navigation',
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('home stub'))),
      ),
    ],
  );
}

Future<void> _pumpSplash(
  WidgetTester tester, {
  required Size size,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
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

/// 测试主体断言后调用，让 _checkAuth 的 1400ms Future.delayed timer
/// + context.go 跳转完成（避免 "Pending timers" 失败）
Future<void> _drainSplashTimer(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  group('SplashPage responsive logo', () {
    testWidgets('iPhone SE (320×568): logo size = 320 * 0.55 = 176', (
      tester,
    ) async {
      await _pumpSplash(tester, size: const Size(320, 568));

      final logo = tester.widget<Image>(find.byType(Image));
      expect(logo.width, closeTo(176, 0.5));
      expect(logo.height, closeTo(176, 0.5));
      await _drainSplashTimer(tester);
    });

    testWidgets('iPhone 14 (390×844): logo size = 390 * 0.55 ≈ 214.5', (
      tester,
    ) async {
      await _pumpSplash(tester, size: const Size(390, 844));

      final logo = tester.widget<Image>(find.byType(Image));
      expect(logo.width, closeTo(214.5, 0.5));
      expect(logo.height, closeTo(214.5, 0.5));
      await _drainSplashTimer(tester);
    });

    testWidgets('iPad portrait (768×1024): logo capped at 240', (
      tester,
    ) async {
      await _pumpSplash(tester, size: const Size(768, 1024));

      final logo = tester.widget<Image>(find.byType(Image));
      expect(logo.width, 240);
      expect(logo.height, 240);
      await _drainSplashTimer(tester);
    });

    testWidgets('iPad landscape (1024×768): logo capped at 240', (
      tester,
    ) async {
      await _pumpSplash(tester, size: const Size(1024, 768));

      final logo = tester.widget<Image>(find.byType(Image));
      expect(logo.width, 240);
      expect(logo.height, 240);
      await _drainSplashTimer(tester);
    });
  });

  group('SplashPage brand anchors', () {
    testWidgets('renders Hero with kBrandLogoHeroTag for relay to Welcome', (
      tester,
    ) async {
      await _pumpSplash(tester, size: const Size(390, 844));

      final heroes = tester.widgetList<Hero>(find.byType(Hero));
      final hasBrandHero = heroes.any((h) => h.tag == 'imboy_brand_logo');
      expect(hasBrandHero, isTrue);
      await _drainSplashTimer(tester);
    });

    testWidgets('loads logo from assets/images/imboy_logo0.png', (
      tester,
    ) async {
      await _pumpSplash(tester, size: const Size(390, 844));

      final image = tester.widget<Image>(find.byType(Image));
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, 'assets/images/imboy_logo0.png');
      await _drainSplashTimer(tester);
    });

    testWidgets('renders "ImBoy" wordmark with w700 + letterSpacing 0.5', (
      tester,
    ) async {
      await _pumpSplash(tester, size: const Size(390, 844));

      final wordmark = tester.widget<Text>(find.text('ImBoy'));
      expect(wordmark.style?.fontSize, 36);
      expect(wordmark.style?.fontWeight, FontWeight.w700);
      expect(wordmark.style?.letterSpacing, 0.5);
      expect(wordmark.style?.color, Colors.white);
      expect(wordmark.style?.shadows, isNull);
      await _drainSplashTimer(tester);
    });

    testWidgets('renders "DEV" badge in debug mode', (tester) async {
      await _pumpSplash(tester, size: const Size(390, 844));
      expect(find.text('DEV'), findsOneWidget);
      await _drainSplashTimer(tester);
    });
  });
}
