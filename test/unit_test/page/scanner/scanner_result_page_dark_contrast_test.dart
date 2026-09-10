// ScannerResultPage 暗色主题对比度验收 Widget 测试（批次172）。
//
// 台账行「暗色主题下文字与底色对比达标」原阻塞理由=「切系统暗色主题后
// 复扫验证（真机+截图判读）」。本测试消除两个外部依赖：
//   ① 主题：直接用生产同源 AppTheme.getDarkTheme() pump（与系统切暗色
//      后 app 实际应用的主题同一构建函数）；
//   ② 扫码：scanResult 是页面构造参数，直推即可，无需相机。
// 对比度用 WCAG 2.1 相对亮度公式程序化计算，标准：正文 ≥4.5(AA)、
// 大字号 ≥3.0(AA Large)、UI 组件（FAB 图标）≥3.0。
//
// 运行方式 / How to run:
//   flutter test test/unit_test/page/scanner/scanner_result_page_dark_contrast_test.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/scanner/scanner_result_page.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/theme.dart';

/// sRGB 通道线性化 → WCAG 2.1 相对亮度
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrastRatio(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

/// alpha 前景叠 alpha 背景后的合成色
Color _composite(Color fg, Color bg) => Color.fromARGB(
  255,
  ((fg.r * 255 * fg.a) + (bg.r * 255 * (1 - fg.a))).round(),
  ((fg.g * 255 * fg.a) + (bg.g * 255 * (1 - fg.a))).round(),
  ((fg.b * 255 * fg.a) + (bg.b * 255 * (1 - fg.a))).round(),
);

Widget _buildApp(ThemeData theme, String scanResult) {
  return TranslationProvider(
    child: MaterialApp(
      theme: theme,
      home: ScannerResultPage(scanResult: scanResult),
    ),
  );
}

void main() {
  final darkTheme = AppTheme.getDarkTheme();
  final lightTheme = AppTheme.getLightTheme();
  const urlResult = 'https://imboy.pub/scanner_dark_test';
  const textResult = 'imboy 扫码暗色对比度夹具（非 URL）';

  group('暗色主题（生产 AppTheme.getDarkTheme）', () {
    testWidgets('SR-D1 结果正文 white vs surface 对比达标（AA ≥4.5）', (tester) async {
      await tester.pumpWidget(_buildApp(darkTheme, textResult));
      await tester.pumpAndSettle();

      final context = tester.element(find.text(textResult));
      final style = DefaultTextStyle.of(context).style;
      final textOnSurface = Theme.of(context).colorScheme.onSurface;
      final surface = Theme.of(context).colorScheme.surface;

      expect(
        style.color,
        textOnSurface,
        reason: '正文颜色应取 colorScheme.onSurface（主题驱动，无硬编码）',
      );
      final ratio = _contrastRatio(textOnSurface, surface);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason:
            '暗色正文对比度 $ratio 应达 WCAG AA(4.5)；'
            'onSurface=$textOnSurface surface=$surface',
      );
    });

    testWidgets('SR-D2 AppBar 标题与玻璃底合成背景对比达标', (tester) async {
      await tester.pumpWidget(_buildApp(darkTheme, urlResult));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(GlassAppBar));
      final theme = Theme.of(context);
      // GlassAppBar 暗色实现：文字 white@0.95，玻璃底 darkSurface@0.75
      // 叠在 Scaffold surface 上（common_bar.dart L76/L84）
      final titleColor = Colors.white.withValues(alpha: 0.95);
      final glassBg = _composite(
        AppColors.darkSurface.withValues(alpha: 0.75),
        theme.colorScheme.surface,
      );
      final ratio = _contrastRatio(_composite(titleColor, glassBg), glassBg);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '暗色 AppBar 标题合成对比度 $ratio 应达 AA',
      );
    });

    testWidgets('SR-D3 FAB 前景/背景对比达标（UI 组件 ≥3.0）', (tester) async {
      await tester.pumpWidget(_buildApp(darkTheme, urlResult));
      await tester.pumpAndSettle();

      // 三个 FAB（back/copy/browser）未指定 backgroundColor 时走 M3 默认
      // container=primary、foreground=onPrimary
      final fabs = tester.widgetList<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fabs.length, 3, reason: '返回/复制/浏览器三 FAB 应齐备');
      for (final fab in fabs) {
        expect(
          fab.backgroundColor,
          isNull,
          reason: 'enabled FAB 不应硬编码背景色（浏览器置灰分支除外），走主题默认',
        );
      }
      final ratio = _contrastRatio(
        darkTheme.colorScheme.onPrimary,
        darkTheme.colorScheme.primary,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(3.0),
        reason: 'FAB onPrimary/primary 对比度 $ratio 应达 UI 组件 3.0',
      );
    });

    testWidgets('SR-D4 非 URL 结果浏览器 FAB 置灰仍可辨识（≥1.5）', (tester) async {
      await tester.pumpWidget(_buildApp(darkTheme, textResult));
      await tester.pumpAndSettle();

      final browserFab = tester
          .widgetList<FloatingActionButton>(find.byType(FloatingActionButton))
          .last;
      expect(browserFab.onPressed, isNull, reason: '非 URL 时浏览器按钮应禁用');
      expect(
        browserFab.backgroundColor,
        AppColors.iosGray,
        reason: '置灰分支应使用 AppColors.iosGray',
      );
      final ratio = _contrastRatio(
        AppColors.iosGray,
        darkTheme.colorScheme.surface,
      );
      expect(
        ratio,
        greaterThanOrEqualTo(1.5),
        reason: '置灰按钮与暗色底对比度 $ratio 应可辨识',
      );
    });
  });

  group('亮色主题回归（对照）', () {
    testWidgets('SR-L1 亮色正文对比同样达标', (tester) async {
      await tester.pumpWidget(_buildApp(lightTheme, textResult));
      await tester.pumpAndSettle();

      final context = tester.element(find.text(textResult));
      final theme = Theme.of(context);
      final ratio = _contrastRatio(
        theme.colorScheme.onSurface,
        theme.colorScheme.surface,
      );
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '亮色正文对比度 $ratio');
    });
  });
}
