import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 聊天主题配置类
/// 专门用于配置聊天界面的主题，与 flutter_chat_core 完美集成
class ChatThemeConfig {
  ChatThemeConfig._();

  /// 获取聊天主题（根据当前系统主题自动适配）
  static ChatTheme get chatTheme {
    // 注意：此静态 getter 无法访问 BuildContext
    // 请使用 getChatThemeWithScale 并传入 context 参数
    return getChatTheme(
      isDark: false, // 默认使用亮色主题
    );
  }

  /// 获取指定模式的聊天主题
  static ChatTheme getChatTheme({
    bool isDark = false,
    bool isOLEDMode = false,
    bool isEyeCareMode = false,
  }) {
    if (isDark) {
      return _buildDarkChatTheme(
        isOLEDMode: isOLEDMode,
        isEyeCareMode: isEyeCareMode,
      );
    } else {
      return _buildLightChatTheme(isEyeCareMode: isEyeCareMode);
    }
  }

  /// 根据 FontSizeOption 获取聊天主题
  static ChatTheme getChatThemeFromOption(
    FontSizeOption option, {
    bool isDark = false,
    bool isOLEDMode = false,
    bool isEyeCareMode = false,
    BuildContext? context,
  }) {
    return getChatThemeWithScale(
      fontScale: option.scale,
      isDark: isDark,
      isOLEDMode: isOLEDMode,
      isEyeCareMode: isEyeCareMode,
      context: context,
    );
  }

  /// 获取支持字体缩放的聊天主题
  static ChatTheme getChatThemeWithScale({
    double fontScale = 1.0,
    bool isDark = false,
    bool isOLEDMode = false,
    bool isEyeCareMode = false,
    BuildContext? context,
  }) {
    if (isDark) {
      return _buildDarkChatTheme(
        fontScale: fontScale,
        isOLEDMode: isOLEDMode,
        isEyeCareMode: isEyeCareMode,
        context: context,
      );
    } else {
      return _buildLightChatTheme(
        fontScale: fontScale,
        isEyeCareMode: isEyeCareMode,
        context: context,
      );
    }
  }

  /// 从 ThemeData 创建聊天主题
  static ChatTheme fromThemeData(ThemeData themeData) {
    return ChatTheme.fromThemeData(themeData);
  }

  /// 构建亮色聊天主题 - Material 3适配
  static ChatTheme _buildLightChatTheme({
    double fontScale = 1.0,
    bool isEyeCareMode = false,
    BuildContext? context,
  }) {
    // 根据护眼模式动态调整颜色
    final backgroundColor = isEyeCareMode
        ? AppColors.getEyeCareBackground(isEyeCareMode, Brightness.light)
        : AppColors.lightSurface;
    final textColor = isEyeCareMode
        ? AppColors.getEyeCareTextColor(isEyeCareMode, Brightness.light)
        : AppColors.lightTextPrimary;

    return ChatTheme(
      colors: ChatColors(
        // DESIGN.md 双蓝策略：发送气泡用品牌蓝
        primary: AppColors.lightSentMessageBackground,
        onPrimary: AppColors.sentMessageText,

        // 表面颜色系统 - 支持护眼模式
        surface: backgroundColor, // 动态背景色
        onSurface: textColor, // 动态文本色
        // 接收消息气泡背景 - 走 AppColors token
        surfaceContainer: AppColors.lightReceivedMessageBackground,
        surfaceContainerLow: AppColors.lightSurfaceContainer,
        surfaceContainerHigh: AppColors.lightCardBackground,
      ),
      typography: _buildChatTypography(
        isDark: false,
        isEyeCareMode: isEyeCareMode,
        fontScale: fontScale,
        context: context,
      ),
      // DESIGN.md 第 9.1 章：聊天气泡圆角 20pt
      shape: AppRadius.borderRadiusLarge,
    );
  }

  /// 构建暗色聊天主题 - Material 3适配
  static ChatTheme _buildDarkChatTheme({
    double fontScale = 1.0,
    bool isOLEDMode = false,
    bool isEyeCareMode = false,
    BuildContext? context,
  }) {
    // 根据OLED模式和护眼模式动态调整颜色
    final backgroundColor = AppColors.getDarkBackground(
      isOLEDMode,
      Brightness.dark,
    );
    final surfaceColor = AppColors.getDarkSurface(isOLEDMode, Brightness.dark);
    final containerColor = AppColors.getDarkSurfaceContainer(
      isOLEDMode,
      Brightness.dark,
    );
    final textColor = isEyeCareMode
        ? AppColors.getEyeCareTextColor(isEyeCareMode, Brightness.dark)
        : const Color(0xFFE6E0E9);

    return ChatTheme(
      colors: ChatColors(
        // DESIGN.md 双蓝策略：暗色发送气泡用品牌蓝变体（非 Material 3 绿色）
        primary: AppColors.darkSentMessageBackground,
        onPrimary: AppColors.sentMessageText,

        // 暗色表面系统，支持 OLED 优化
        surface: backgroundColor, // 动态背景色
        onSurface: textColor, // 动态文本色
        // 接收气泡背景 - OLED 优化感知
        surfaceContainer: isOLEDMode
            ? AppColors.oledReceivedMessageBackground
            : AppColors.darkReceivedMessageBackground,
        surfaceContainerLow: surfaceColor,
        surfaceContainerHigh: containerColor,
      ),
      typography: _buildChatTypography(
        isDark: true,
        isOLEDMode: isOLEDMode,
        isEyeCareMode: isEyeCareMode,
        fontScale: fontScale,
        context: context,
      ),
      // DESIGN.md 第 9.1 章：聊天气泡圆角 20pt
      shape: AppRadius.borderRadiusLarge,
    );
  }

  /// 构建聊天字体配置 - Material 3字体排版系统
  static ChatTypography _buildChatTypography({
    bool isDark = false,
    bool isOLEDMode = false,
    bool isEyeCareMode = false,
    double fontScale = 1.0,
    BuildContext? context,
  }) {
    // 根据模式动态调整文本颜色
    final textColor = isDark
        ? (isEyeCareMode
              ? AppColors.getEyeCareTextColor(isEyeCareMode, Brightness.dark)
              : const Color(0xFFE6E0E9)) // Material 3 On Surface Dark
        : (isEyeCareMode
              ? AppColors.getEyeCareTextColor(isEyeCareMode, Brightness.light)
              : const Color(0xFF1C1B1F)); // Material 3 On Surface Light
    final secondaryTextColor = isDark
        ? const Color(0xFFCAC4D0) // Material 3 On Surface Variant Dark
        : const Color(0xFF49454F); // Material 3 On Surface Variant Light

    // 应用安全的字体缩放
    final safeScale = FontScaleCalculator.getSafeScale(fontScale);

    return ChatTypography(
      // Material 3 Body Large - 消息内容
      bodyLarge: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          16, // Material 3 Body Large 标准大小
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.5, // Material 3推荐行高
        letterSpacing: 0.5, // Material 3字母间距
      ),
      // Material 3 Body Medium - 辅助文本
      bodyMedium: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          14, // Material 3 Body Medium 标准大小
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400,
        color: textColor,
        height: 1.43, // Material 3推荐行高
        letterSpacing: 0.25, // Material 3字母间距
      ),
      // Material 3 Body Small - 小号文本
      bodySmall: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          12, // Material 3 Body Small 标准大小
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w400,
        color: secondaryTextColor,
        height: 1.33, // Material 3推荐行高
        letterSpacing: 0.4, // Material 3字母间距
      ),
      // Material 3 Title Small - 用户名
      labelLarge: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          14, // Material 3 Title Small 标准大小
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w500, // Material 3推荐字重
        color: textColor,
        height: 1.43, // Material 3推荐行高
        letterSpacing: 0.1, // Material 3字母间距
      ),
      // Material 3 Label Medium - 中等标签
      labelMedium: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          12, // Material 3 Label Medium 标准大小
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w500, // Material 3推荐字重
        color: textColor,
        height: 1.33, // Material 3推荐行高
        letterSpacing: 0.5, // Material 3字母间距
      ),
      // Material 3 Label Small - 时间戳
      labelSmall: TextStyle(
        fontSize: FontScaleCalculator.calculateScaledSize(
          11, // Material 3 Label Small 标准大小
          safeScale,
          context: context,
        ),
        fontWeight: FontWeight.w500, // Material 3推荐字重
        color: secondaryTextColor,
        height: 1.45, // Material 3推荐行高
        letterSpacing: 0.5, // Material 3字母间距
      ),
    );
  }

  /// 验证聊天主题的可访问性
  ///
  /// [chatTheme] 要验证的聊天主题
  /// 返回不符合可访问性标准的样式名称列表
  static List<String> validateChatThemeAccessibility(ChatTheme chatTheme) {
    final issues = <String>[];

    final styles = {
      'bodyLarge': chatTheme.typography.bodyLarge,
      'bodyMedium': chatTheme.typography.bodyMedium,
      'bodySmall': chatTheme.typography.bodySmall,
      'labelLarge': chatTheme.typography.labelLarge,
      'labelMedium': chatTheme.typography.labelMedium,
      'labelSmall': chatTheme.typography.labelSmall,
    };

    styles.forEach((name, style) {
      if (style.fontSize != null &&
          !FontScaleCalculator.isAccessibleSize(style.fontSize!)) {
        issues.add(name);
      }
    });

    return issues;
  }

  /// 使用 copyWith 方法动态调整现有聊天主题的字体大小
  ///
  /// [baseChatTheme] 基础聊天主题
  /// [fontScale] 字体缩放比例
  /// [context] 构建上下文（可选）
  static ChatTheme scaleChatTheme(
    ChatTheme baseChatTheme,
    double fontScale, {
    BuildContext? context,
  }) {
    final safeScale = FontScaleCalculator.getSafeScale(fontScale);

    final scaledTypography = ChatTypography(
      bodyLarge: baseChatTheme.typography.bodyLarge.copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseChatTheme.typography.bodyLarge.fontSize ?? 16,
          safeScale,
          context: context,
        ),
      ),
      bodyMedium: baseChatTheme.typography.bodyMedium.copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseChatTheme.typography.bodyMedium.fontSize ?? 14,
          safeScale,
          context: context,
        ),
      ),
      bodySmall: baseChatTheme.typography.bodySmall.copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseChatTheme.typography.bodySmall.fontSize ?? 12,
          safeScale,
          context: context,
        ),
      ),
      labelLarge: baseChatTheme.typography.labelLarge.copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseChatTheme.typography.labelLarge.fontSize ?? 14,
          safeScale,
          context: context,
        ),
      ),
      labelMedium: baseChatTheme.typography.labelMedium.copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseChatTheme.typography.labelMedium.fontSize ?? 12,
          safeScale,
          context: context,
        ),
      ),
      labelSmall: baseChatTheme.typography.labelSmall.copyWith(
        fontSize: FontScaleCalculator.calculateScaledSize(
          baseChatTheme.typography.labelSmall.fontSize ?? 12,
          safeScale,
          context: context,
        ),
      ),
    );

    return baseChatTheme.copyWith(typography: scaledTypography);
  }
}

/// 聊天主题扩展方法
extension ChatThemeExtension on BuildContext {
  /// 快速获取聊天主题
  ChatTheme get chatTheme => ChatThemeConfig.chatTheme;

  /// 快速获取支持字体缩放的聊天主题
  ChatTheme getChatThemeWithScale(double fontScale) {
    return ChatThemeConfig.getChatThemeWithScale(
      fontScale: fontScale,
      isDark: ThemeManager.instance.isDarkMode,
      context: this,
    );
  }

  /// 快速获取基于 FontSizeOption 的聊天主题
  ChatTheme getChatThemeFromOption(FontSizeOption option) {
    return ChatThemeConfig.getChatThemeFromOption(
      option,
      isDark: ThemeManager.instance.isDarkMode,
      context: this,
    );
  }
}
