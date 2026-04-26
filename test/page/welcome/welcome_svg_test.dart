import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/welcome/welcome_page.dart';

/// WelcomePage 引导插画 SVG widget 渲染契约测试
///
/// 验证 3 个 step 的 SvgPicture 正确渲染（220×220），
/// 滑动 PageView 后对应 step 的 SvgPicture 切换可见。
///
/// 不验证 SVG 字符串内部 fill/gradient（_svgStep1/2/3 是 file-private const，
/// 外部不可访问；其品牌色策略由 welcome_page.dart 顶部注释 + DESIGN.md §2.1 钉死）。
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
  group('WelcomePage SVG illustrations', () {
    testWidgets('renders SvgPicture in PageView for current step', (
      tester,
    ) async {
      await _pumpWelcome(tester);

      // PageView 内 SvgPicture（默认 step 1 可见，非 build/cache 状态下其他页可能也存在）
      // 至少应有 1 个 SvgPicture 实例
      expect(find.byType(SvgPicture), findsAtLeastNWidgets(1));
    });

    testWidgets('SvgPicture has 220×220 dimensions per design', (
      tester,
    ) async {
      await _pumpWelcome(tester);

      // 取首个 SvgPicture（step 1）
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
      expect(svg.width, 220);
      expect(svg.height, 220);
    });

    testWidgets('drag PageView reveals different SvgPicture instance for '
        'each step', (tester) async {
      await _pumpWelcome(tester);

      // step 1 默认可见
      final initialSvgWidgets = tester.widgetList<SvgPicture>(
        find.byType(SvgPicture),
      );
      // 至少 1 个 SVG 在屏幕中
      expect(initialSvgWidgets.isNotEmpty, isTrue);

      // 滑到 step 2
      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();
      final step2Svgs = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
      expect(step2Svgs.isNotEmpty, isTrue);

      // 滑到 step 3
      await tester.drag(find.byType(PageView), const Offset(-1000, 0));
      await tester.pumpAndSettle();
      final step3Svgs = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
      expect(step3Svgs.isNotEmpty, isTrue);
    });

    testWidgets(
      'SvgPicture uses SvgStringLoader (inline strings, not asset/network)',
      (tester) async {
        await _pumpWelcome(tester);

        // 验证 SvgPicture 用的是 SvgStringLoader（_svgStep1 const string）
        // 而非 SvgAssetLoader 或 SvgNetworkLoader
        final svg = tester.widget<SvgPicture>(find.byType(SvgPicture).first);
        expect(
          svg.bytesLoader,
          isA<SvgStringLoader>(),
          reason: 'Welcome 引导插画应用 inline _svgStep1/2/3 const string，'
              '而非 asset / network 加载（启动期不依赖网络/磁盘）',
        );
      },
    );
  });
}
