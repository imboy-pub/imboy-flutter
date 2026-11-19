// 消息气泡时间戳对比度回归测试（2026-11-19 属主反馈「看不清」）。
//
// 缺陷：web 发送气泡（亮 #1565C0 / 暗 #1D5EC2）内的时间戳此前统一用
// 深色次级文字 @54% alpha —— 深灰叠深蓝，肉眼完全不可读（属主截图标注）。
//
// 合同：时间戳必须按收发分色，且叠到所属气泡底色后满足 WCAG 2.1 AA
// （小字号正文 ≥4.5:1）。接收侧维持次级灰（surface 底）。
//
// 运行：flutter test test/unit_test/page/chat/message_bubble_timestamp_contrast_test.dart

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/widget/message_bubble_style.dart';
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

/// alpha 前景叠不透明背景后的合成色
Color _composite(Color fg, Color bg) => Color.fromARGB(
  255,
  ((fg.r * 255 * fg.a) + (bg.r * 255 * (1 - fg.a))).round(),
  ((fg.g * 255 * fg.a) + (bg.g * 255 * (1 - fg.a))).round(),
  ((fg.b * 255 * fg.a) + (bg.b * 255 * (1 - fg.a))).round(),
);

void main() {
  final lightTheme = AppTheme.getLightTheme();
  final darkTheme = AppTheme.getDarkTheme();

  /// 在提供主题的上下文中取时间戳实际渲染色
  Future<Color> resolveColor(
    WidgetTester tester,
    ThemeData theme,
    bool isSentByMe,
  ) async {
    late Color color;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            color = MessageBubbleStyle.getTimestampStyle(
              context: context,
              isSentByMe: isSentByMe,
            ).color!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return color;
  }

  group('时间戳对比度（WCAG 2.1 AA ≥4.5:1）', () {
    testWidgets('亮色发送气泡：时间戳 vs primaryDark', (tester) async {
      final fg = await resolveColor(tester, lightTheme, true);
      final bg = AppColors.lightSentMessageBackground;
      final ratio = _contrastRatio(_composite(fg, bg), bg);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '蓝色发送气泡内时间戳必须可读（修复前深灰@54% 远低于 AA）',
      );
    });

    testWidgets('暗色发送气泡：时间戳 vs darkSentMessageBackground', (tester) async {
      final fg = await resolveColor(tester, darkTheme, true);
      final bg = AppColors.darkSentMessageBackground;
      final ratio = _contrastRatio(_composite(fg, bg), bg);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: '暗色发送气泡同合同');
    });

    testWidgets('亮色接收气泡：次级灰达标', (tester) async {
      final fg = await resolveColor(tester, lightTheme, false);
      final bg = AppColors.lightReceivedMessageBackground;
      final ratio = _contrastRatio(_composite(fg, bg), bg);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    testWidgets('暗色接收气泡：次级灰达标', (tester) async {
      final fg = await resolveColor(tester, darkTheme, false);
      final bg = AppColors.darkReceivedMessageBackground;
      final ratio = _contrastRatio(_composite(fg, bg), bg);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  });
}
