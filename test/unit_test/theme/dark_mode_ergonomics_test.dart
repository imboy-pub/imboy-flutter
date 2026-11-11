import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/config/chat_theme_config.dart';
import 'package:imboy/theme/default/theme.dart';

void main() {
  group('Dark Mode Ergonomics & Contrast Contract', () {
    test('主文本与次要文本消除刺眼光晕并保持清晰主次层级与 WCAG AA 对比度', () {
      // 1. 防光晕：主文本不使用刺眼的 #FFFFFF，且对比度不过度极化（< 18:1）同时远超 AAA（≥ 12:1）
      expect(AppColors.darkTextPrimary, isNot(const Color(0xFFFFFFFF)));
      final primaryContrastOnSurface = AppColors.getContrastRatio(
        AppColors.darkTextPrimary,
        AppColors.darkSurface,
      );
      expect(primaryContrastOnSurface, greaterThanOrEqualTo(12.0));
      expect(primaryContrastOnSurface, lessThan(18.0));

      // 2. 次要文本真正退后：与主文本存在显著明度差，但仍满足 WCAG AA (≥ 4.5:1)
      final secondaryContrastOnSurface = AppColors.getContrastRatio(
        AppColors.darkTextSecondary,
        AppColors.darkSurface,
      );
      final secondaryContrastOnElevated = AppColors.getContrastRatio(
        AppColors.darkTextSecondary,
        AppColors.darkSurfaceGroupedTertiary,
      );
      expect(secondaryContrastOnSurface, greaterThanOrEqualTo(4.5));
      expect(secondaryContrastOnElevated, greaterThanOrEqualTo(4.5));
      expect(
        primaryContrastOnSurface - secondaryContrastOnSurface,
        greaterThanOrEqualTo(6.0),
        reason: '主文本与次要文本对比度差值应 ≥ 6.0，避免整屏文字一样亮造成视觉疲劳',
      );
    });

    test('暗色表面色阶遵循 Apple HIG 中性递进，非 OLED 默认不使用纯黑 #000000', () {
      expect(AppColors.darkBackground, isNot(const Color(0xFF000000)));
      expect(
        AppColors.darkBackground.computeLuminance(),
        lessThan(AppColors.darkSurface.computeLuminance()),
      );
      expect(
        AppColors.darkSurface.computeLuminance(),
        lessThan(AppColors.darkSurfaceContainer.computeLuminance()),
      );
      expect(
        AppColors.darkSurfaceContainer.computeLuminance(),
        lessThan(AppColors.darkSurfaceContainerHighest.computeLuminance()),
      );

      final darkTheme = AppTheme.getDarkTheme();
      expect(
        darkTheme.colorScheme.onSurfaceVariant,
        AppColors.darkTextSecondary,
      );
      expect(
        darkTheme.cupertinoOverrideTheme?.scaffoldBackgroundColor,
        AppColors.darkSurfaceGrouped,
      );
    });

    test('暗色聊天气泡抑制高明度眩光且保持 AA 可读性与背景层次', () {
      final sentContrast = AppColors.getContrastRatio(
        AppColors.sentMessageText,
        AppColors.darkSentMessageBackground,
      );
      expect(
        sentContrast,
        greaterThanOrEqualTo(4.5),
        reason: '暗色发送气泡文字对比度需达 WCAG AA (≥ 4.5:1)',
      );

      final receivedContrast = AppColors.getContrastRatio(
        AppColors.darkReceivedMessageText,
        AppColors.darkReceivedMessageBackground,
      );
      expect(
        receivedContrast,
        greaterThanOrEqualTo(10.0),
        reason: '暗色接收气泡文字需保持清晰可读',
      );

      // 接收气泡与暗色聊天画布 (darkSurface) 必须有可感知的明度阶差，不能融为一体
      expect(
        AppColors.darkReceivedMessageBackground.computeLuminance(),
        greaterThan(AppColors.darkSurface.computeLuminance()),
      );

      final chatTheme = ChatThemeConfig.getChatTheme(isDark: true);
      expect(chatTheme.colors.surface, AppColors.darkSurface);
      expect(chatTheme.colors.onSurface, AppColors.darkTextPrimary);
      expect(
        chatTheme.colors.surfaceContainer,
        AppColors.darkReceivedMessageBackground,
      );
    });

    test('朋友圈/社交暗色强调色 (wechatBlueDark) 在卡片与评论气泡表面满足 WCAG AA', () {
      final linkDark = AppColors.getWechatBlue(Brightness.dark);
      expect(
        AppColors.getContrastRatio(linkDark, AppColors.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        AppColors.getContrastRatio(
          linkDark,
          AppColors.darkSurfaceGroupedTertiary,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
