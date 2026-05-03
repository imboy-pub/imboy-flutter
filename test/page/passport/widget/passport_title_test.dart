import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/passport/widget/passport_title.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// PassportTitle widget 契约测试
///
/// 覆盖范围：
///   - Hero tag 接力（kBrandLogoHeroTag = 'imboy_brand_logo'）
///   - Wordmark "IMBoy" 渲染（brand color + w700）
///   - Slogan "Simple · Secure · Reliable" 渲染
///   - Logo Image 资产路径正确
///   - color 参数覆盖 brand 色
///   - 默认 color 为 [AppColors.primary]

void main() {
  Future<void> pump(WidgetTester tester, {Color? color}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: PassportTitle(color: color)),
        ),
      ),
    );
    await tester.pump();
  }

  group('PassportTitle', () {
    testWidgets('renders Hero with kBrandLogoHeroTag', (tester) async {
      await pump(tester);

      final heroes = tester.widgetList<Hero>(find.byType(Hero));
      final hasBrandHero = heroes.any((h) => h.tag == 'imboy_brand_logo');
      expect(
        hasBrandHero,
        isTrue,
        reason: 'PassportTitle must wrap logo in Hero(tag: kBrandLogoHeroTag) '
            'for Splash → Welcome → SignIn relay',
      );
    });

    testWidgets('loads logo from assets/images/imboy_logo0.png', (
      tester,
    ) async {
      await pump(tester);

      final image = tester.widget<Image>(find.byType(Image));
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, 'assets/images/imboy_logo0.png');
      expect(image.width, 44);
      expect(image.height, 44);
    });

    testWidgets('renders wordmark "IMBoy" with brand color', (tester) async {
      await pump(tester);

      final text = tester.widget<Text>(find.text('IMBoy'));
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.style?.color, AppColors.primary);
      expect(text.style?.letterSpacing, 1.2);
    });

    testWidgets('renders slogan "Simple · Secure · Reliable"', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Simple · Secure · Reliable'), findsOneWidget);
    });

    testWidgets('color parameter overrides wordmark color', (tester) async {
      const customColor = Color(0xFFFF6B00);
      await pump(tester, color: customColor);

      final text = tester.widget<Text>(find.text('IMBoy'));
      expect(text.style?.color, customColor);
    });

    testWidgets('logo container has circle decoration with box shadow', (
      tester,
    ) async {
      const customColor = Color(0xFFFF6B00);
      await pump(tester, color: customColor);

      final containers = tester.widgetList<Container>(find.byType(Container));
      final logoContainer = containers.firstWhere(
        (c) => (c.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      );
      final decoration = logoContainer.decoration as BoxDecoration;
      expect(decoration.color, customColor);
      final shadow = decoration.boxShadow!.first;
      // 8% alpha brand shadow
      expect(
        (shadow.color.a * 100).round(),
        8,
        reason: 'logo shadow alpha should be 8%',
      );
      expect(shadow.blurRadius, 8);
      expect(shadow.offset, const Offset(0, 2));
    });

    testWidgets('slogan has letterSpacing 2.0 and w500', (tester) async {
      await pump(tester);

      final sloganText = tester.widget<Text>(
        find.text('Simple · Secure · Reliable'),
      );
      expect(sloganText.style?.letterSpacing, 2.0);
      expect(sloganText.style?.fontWeight, FontWeight.w500);
      expect(sloganText.style?.fontSize, 13);
    });
  });
}
