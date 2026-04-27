import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/splash/splash_page.dart';

/// Test-only fake — injected via `tester.platformDispatcher.accessibilityFeaturesTestValue`
/// so `MediaQuery.disableAnimationsOf` reflects the system "Reduce Motion" state.
///
/// Injecting via `MediaQuery` widget does NOT work here because `MaterialApp.router`
/// rebuilds its own `MediaQuery.fromView`, which reads `accessibilityFeatures` from
/// `PlatformDispatcher` and overrides any ancestor `MediaQuery` widget.
class _DisableAnimFeatures implements ui.AccessibilityFeatures {
  const _DisableAnimFeatures();
  @override
  bool get accessibleNavigation => false;
  @override
  bool get boldText => false;
  @override
  bool get disableAnimations => true;
  @override
  bool get highContrast => false;
  @override
  bool get invertColors => false;
  @override
  bool get onOffSwitchLabels => false;
  @override
  bool get reduceMotion => true;
  @override
  bool get supportsAnnounce => false;
}

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

    testWidgets(
      'iPhone Pro Max (430×932): short side ≤ 600 → cap 240 (phone tier)',
      (tester) async {
        await _pumpSplash(tester, size: const Size(430, 932));

        // 430 * 0.55 = 236.5 < 240 cap → uses 236.5
        final logo = tester.widget<Image>(find.byType(Image));
        expect(logo.width, closeTo(236.5, 0.5));
        expect(logo.height, closeTo(236.5, 0.5));
        await _drainSplashTimer(tester);
      },
    );

    testWidgets(
      'iPad portrait (768×1024): short side > 600 → tablet cap 320 (was 240)',
      (tester) async {
        await _pumpSplash(tester, size: const Size(768, 1024));

        // P1-7: 768 > 600 breakpoint → cap raised to 320 to avoid
        // "logo too small" feeling on tablet form factor
        final logo = tester.widget<Image>(find.byType(Image));
        expect(logo.width, 320);
        expect(logo.height, 320);
        await _drainSplashTimer(tester);
      },
    );

    testWidgets(
      'iPad Pro 12.9 landscape (1366×1024): short side 1024 > 600 → cap 320',
      (tester) async {
        await _pumpSplash(tester, size: const Size(1366, 1024));

        // 1024 * 0.55 = 563.2 > 320 cap → cap kicks in
        final logo = tester.widget<Image>(find.byType(Image));
        expect(logo.width, 320);
        expect(logo.height, 320);
        await _drainSplashTimer(tester);
      },
    );
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

  // ── P0-4 hold duration tiers ─────────────────────────────────────────
  group('SplashPage hold duration tiers', () {
    test(
      'Returning users get strictly shorter hold than first-time / logged-out',
      () {
        expect(
          kSplashMinHoldReturning < kSplashMinHoldNew,
          isTrue,
          reason: 'Returning-user hold MUST be shorter (high-frequency UX)',
        );
      },
    );

    test(
      'Returning hold ≥ 800ms — must still cover Hero flight + brand glance',
      () {
        // Hero RectTween flight ≈ 300ms, plus minimal brand glance ≈ 500ms.
        // Below 800ms users see logo "flash and go" — perceived as broken.
        expect(
          kSplashMinHoldReturning.inMilliseconds,
          greaterThanOrEqualTo(800),
        );
      },
    );

    test(
      'First-time hold ≥ 950ms — must cover slogan fade-in end (delay 550ms + dur 400ms)',
      () {
        // slogan animation ends at 550 + 400 = 950ms. Cutting earlier = animation
        // janks mid-flight. Reduce Motion still reaches end state instantly,
        // so the floor is for the default-animation path.
        expect(kSplashMinHoldNew.inMilliseconds, greaterThanOrEqualTo(950));
      },
    );

    test('First-time hold ≤ 2000ms — guard against accidental long-hold regressions', () {
      // Anything beyond 2s feels like a frozen launch — protect against
      // a future "let's bump it for breathing room" misstep.
      expect(kSplashMinHoldNew.inMilliseconds, lessThanOrEqualTo(2000));
    });
  });

  // ── P0-2 accessibility: Semantics scoping + Reduce Motion ────────────
  group('SplashPage accessibility', () {
    testWidgets(
      'Logo and DEV badge are wrapped in ExcludeSemantics so VoiceOver only '
      'reads wordmark + slogan + security',
      (tester) async {
        await _pumpSplash(tester, size: const Size(390, 844));

        // Logo's ExcludeSemantics lives inside the Hero subtree.
        // (Wordmark conveys 'ImBoy' textually; logo image stays decorative.)
        expect(
          find.descendant(
            of: find.byType(Hero),
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
          reason: 'Logo image must be excluded from a11y tree',
        );

        // DEV badge: ExcludeSemantics is the immediate ancestor of the text.
        expect(
          find.ancestor(
            of: find.text('DEV'),
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
          reason: 'DEV badge (debug-only noise) must be excluded',
        );

        // wordmark / slogan / security must NOT be excluded (read naturally).
        expect(
          find.ancestor(
            of: find.text('ImBoy'),
            matching: find.byType(ExcludeSemantics),
          ),
          findsNothing,
          reason: 'Wordmark "ImBoy" is the sole brand-name announcement',
        );

        await _drainSplashTimer(tester);
      },
    );

    testWidgets(
      'Default (no Reduce Motion): 5 Animate widgets — atmosphere breathing '
      '+ 4 staged entrance (logo / wordmark / slogan / security)',
      (tester) async {
        await _pumpSplash(tester, size: const Size(390, 844));

        // P1-6 added the atmosphere breathing layer (loop reverse fade
        // 0.85 ↔ 1.0), bringing total Animate count from 4 → 5.
        expect(find.byType(Animate), findsNWidgets(5));
        await _drainSplashTimer(tester);
      },
    );

    testWidgets(
      'Reduce Motion enabled: skips all Animate wrappers, renders end states '
      'directly (Image / Text widgets still present, animations gone)',
      (tester) async {
        // Inject system-level disableAnimations=true via platformDispatcher.
        // MediaQuery.disableAnimationsOf reads from there, so MaterialApp's
        // internally-rebuilt MediaQuery will pick it up.
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const _DisableAnimFeatures();
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );

        await _pumpSplash(tester, size: const Size(390, 844));

        // Zero Animate wrappers — every staged entrance is short-circuited.
        expect(
          find.byType(Animate),
          findsNothing,
          reason: 'Reduce Motion must short-circuit flutter_animate chains',
        );

        // Brand surface still visually intact (terminal state rendered):
        expect(find.byType(Image), findsOneWidget);
        expect(find.text('ImBoy'), findsOneWidget);

        await _drainSplashTimer(tester);
      },
    );
  });
}
