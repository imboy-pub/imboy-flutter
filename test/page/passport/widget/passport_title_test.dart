import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/passport/widget/passport_title.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// PassportTitle widget 契约测试
///
/// 该 widget 是 Splash → Welcome → SignIn Hero 接力链的终点，
/// 视觉与品牌策略变更（color/字重/letterSpacing）必须有测试钉死。
///
/// 覆盖范围：
///   - Hero tag 接力（kBrandLogoHeroTag = 'imboy_brand_logo'）
///   - Wordmark "IMBoy" 渲染（IM + Boy 拆分以 RichText 实现，分别用 brand / textPrimary 色）
///   - Slogan "Simple · Secure · Reliable" 渲染
///   - Logo Image 资产路径正确（assets/images/imboy_logo0.png）
///   - color 参数覆盖 brand 色（影响 logo 投影 + IM 文字色，不影响 Boy / slogan）
///   - 默认 color 为 [AppColors.primary]
/// 在页面上找到 'IMBoy' wordmark 对应的 RichText
///
/// Material/Text 内部也用 RichText 实现，[find.byType(RichText)] 会找到多个。
/// 这里通过 root TextSpan.text == 'IM' 精确定位 PassportTitle 自己的 RichText。
RichText _findIMBoyRichText(WidgetTester tester) {
  final candidates = tester.widgetList<RichText>(find.byType(RichText));
  return candidates.firstWhere((rt) {
    final span = rt.text;
    return span is TextSpan && span.text == 'IM';
  });
}

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
      // logo 56×56（DESIGN.md 登录页 hero 元素尺寸）
      expect(image.width, 56);
      expect(image.height, 56);
    });

    testWidgets('renders wordmark "IMBoy" via RichText (IM + Boy parts)', (
      tester,
    ) async {
      await pump(tester);

      // RichText 由 'IM' + 'Boy' 两段 TextSpan 组成
      final richText = _findIMBoyRichText(tester);
      final root = richText.text as TextSpan;
      expect(root.text, 'IM');
      expect(root.children, hasLength(1));
      final boyPart = root.children!.first as TextSpan;
      expect(boyPart.text, 'Boy');
    });

    testWidgets('renders slogan "Simple · Secure · Reliable"', (tester) async {
      await pump(tester);
      expect(find.text('Simple · Secure · Reliable'), findsOneWidget);
    });

    testWidgets('"IM" uses brand color (default = AppColors.primary)', (
      tester,
    ) async {
      await pump(tester);

      final richText = _findIMBoyRichText(tester);
      final imSpan = richText.text as TextSpan;
      expect(imSpan.style?.color, AppColors.primary);
      expect(imSpan.style?.fontWeight, FontWeight.w700);
      expect(imSpan.style?.letterSpacing, 1.2);
    });

    testWidgets('"Boy" uses lightTextPrimary (not brand color)', (
      tester,
    ) async {
      await pump(tester);

      final richText = _findIMBoyRichText(tester);
      final root = richText.text as TextSpan;
      final boySpan = root.children!.first as TextSpan;
      expect(boySpan.style?.color, AppColors.lightTextPrimary);
      // 与 IM 同字重保持品牌字号一致
      expect(boySpan.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('color parameter overrides "IM" text color', (tester) async {
      const customColor = Color(0xFFFF6B00);
      await pump(tester, color: customColor);

      final richText = _findIMBoyRichText(tester);
      final imSpan = richText.text as TextSpan;
      expect(imSpan.style?.color, customColor);

      // 'Boy' 不受 color 参数影响（保持品牌固定色）
      final boySpan = imSpan.children!.first as TextSpan;
      expect(boySpan.style?.color, AppColors.lightTextPrimary);
    });

    testWidgets('logo container box shadow uses brand color at 18% alpha', (
      tester,
    ) async {
      const customColor = Color(0xFFFF6B00);
      await pump(tester, color: customColor);

      // 找出 logo 圆形 Container（shape: circle 是唯一识别器）
      final containers = tester.widgetList<Container>(find.byType(Container));
      final logoContainer = containers.firstWhere(
        (c) => (c.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      );
      final decoration = logoContainer.decoration as BoxDecoration;
      final shadow = decoration.boxShadow!.first;

      // 18% alpha brand 投影
      expect(
        (shadow.color.a * 100).round(),
        18,
        reason: 'logo shadow alpha should be ~18%',
      );
      expect(shadow.blurRadius, 16);
      expect(shadow.offset, const Offset(0, 4));
    });

    testWidgets('slogan letterSpacing is 2.0 (DESIGN.md cleanup target)', (
      tester,
    ) async {
      await pump(tester);

      final sloganText = tester.widget<Text>(
        find.text('Simple · Secure · Reliable'),
      );
      expect(sloganText.style?.letterSpacing, 2.0);
      expect(sloganText.style?.fontWeight, FontWeight.w500);
      expect(sloganText.style?.fontSize, 14);
    });
  });
}
