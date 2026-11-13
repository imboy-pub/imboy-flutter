import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/config/chat_theme_config.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:imboy/theme/providers/theme_provider.dart';

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

    test('暗色骨架屏 Shimmer 扫光色采用低明度深灰，消除加载媒体时的白闪眩光', () {
      final baseDark = AppColors.getShimmerBase(Brightness.dark);
      final highlightDark = AppColors.getShimmerHighlight(Brightness.dark);
      expect(baseDark.computeLuminance(), lessThan(0.05));
      expect(highlightDark.computeLuminance(), lessThan(0.08));
      expect(
        highlightDark.computeLuminance(),
        greaterThan(baseDark.computeLuminance()),
      );
    });
  });
  group('发送气泡前景按实际主题分流', () {
    for (final isDark in [false, true]) {
      final expected = isDark ? AppColors.sentMessageText : Colors.white;
      test('${isDark ? '暗色' : '浅色'}真实聊天主题保持正确发送前景', () {
        for (final eyeCare in [false, true]) {
          final theme = ChatThemeConfig.getChatThemeWithScale(
            isDark: isDark,
            isEyeCareMode: eyeCare,
            fontScale: 1.5,
          );
          expect(theme.colors.onPrimary, expected);
          expect(
            theme.colors.primary,
            isDark
                ? AppColors.darkSentMessageBackground
                : AppColors.lightSentMessageBackground,
          );
        }
      });

      test('${isDark ? '暗色' : '浅色'}真实ThemeNotifier返回对应发送文本色', () async {
        SharedPreferences.setMockInitialValues({
          'theme_follow_system': false,
          'theme_is_dark_mode': false,
        });
        final container = ProviderContainer();
        final subscription = container.listen(themeProvider, (_, _) {});
        addTearDown(container.dispose);
        addTearDown(subscription.close);
        final notifier = container.read(themeProvider.notifier);
        await notifier.detectDynamicColorSupport();
        await notifier.loadThemePreference();
        await container.pump();
        await notifier.toggleTheme(isDark: isDark, duration: Duration.zero);
        expect(
          notifier.currentTheme.brightness,
          isDark ? Brightness.dark : Brightness.light,
        );
        expect(notifier.getChatColor('sentMessageText'), expected);
      });
    }
  });
}
