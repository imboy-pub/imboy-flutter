import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 应用主题扩展类
/// 定义自定义颜色、样式常量和聊天相关颜色
///
/// 这个扩展类提供了 Flutter 标准主题之外的自定义样式配置，
/// 包括聊天界面颜色、徽章颜色、间距常量等。
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  // ==================== 聊天相关颜色 ====================

  /// 聊天气泡颜色（发送的消息）
  final Color chatBubbleColorSent;

  /// 聊天气泡颜色（接收的消息）
  final Color chatBubbleColorReceived;

  /// 聊天气泡文本颜色（发送的消息）
  final Color chatBubbleTextColorSent;

  /// 聊天气泡文本颜色（接收的消息）
  final Color chatBubbleTextColorReceived;

  /// 聊天输入框背景颜色
  final Color chatInputBackgroundColor;

  /// 聊天输入框边框颜色
  final Color chatInputBorderColor;

  /// 聊天时间戳文本颜色
  final Color chatTimestampColor;

  /// 聊天状态图标颜色
  final Color chatStatusIconColor;

  // ==================== 徽章和通知颜色 ====================

  /// 未读消息徽章背景颜色
  final Color unreadBadgeColor;

  /// 未读消息徽章文本颜色
  final Color unreadBadgeTextColor;

  /// 在线状态指示器颜色
  final Color onlineStatusColor;

  /// 离线状态指示器颜色
  final Color offlineStatusColor;

  /// 忙碌状态指示器颜色
  final Color busyStatusColor;

  // ==================== 功能性颜色 ====================

  /// 成功状态颜色
  final Color successColor;

  /// 警告状态颜色
  final Color warningColor;

  /// 信息状态颜色
  final Color infoColor;

  /// 分割线颜色
  final Color dividerColor;

  /// 阴影颜色
  final Color shadowColor;

  /// 覆盖层颜色（如模态框背景）
  final Color overlayColor;

  // ==================== 间距和尺寸常量 ====================

  /// 标准内边距
  final EdgeInsets standardPadding;

  /// 紧凑内边距
  final EdgeInsets compactPadding;

  /// 宽松内边距
  final EdgeInsets loosePadding;

  /// 标准外边距
  final EdgeInsets standardMargin;

  /// 紧凑外边距
  final EdgeInsets compactMargin;

  /// 宽松外边距
  final EdgeInsets looseMargin;

  /// 标准圆角半径
  final double standardBorderRadius;

  /// 小圆角半径
  final double smallBorderRadius;

  /// 大圆角半径
  final double largeBorderRadius;

  /// 聊天气泡圆角半径
  final double chatBubbleBorderRadius;

  /// 标准阴影
  final List<BoxShadow> standardShadow;

  /// 轻微阴影
  final List<BoxShadow> lightShadow;

  /// 重阴影
  final List<BoxShadow> heavyShadow;

  const AppThemeExtension({
    // 聊天相关颜色
    required this.chatBubbleColorSent,
    required this.chatBubbleColorReceived,
    required this.chatBubbleTextColorSent,
    required this.chatBubbleTextColorReceived,
    required this.chatInputBackgroundColor,
    required this.chatInputBorderColor,
    required this.chatTimestampColor,
    required this.chatStatusIconColor,

    // 徽章和通知颜色
    required this.unreadBadgeColor,
    required this.unreadBadgeTextColor,
    required this.onlineStatusColor,
    required this.offlineStatusColor,
    required this.busyStatusColor,

    // 功能性颜色
    required this.successColor,
    required this.warningColor,
    required this.infoColor,
    required this.dividerColor,
    required this.shadowColor,
    required this.overlayColor,

    // 间距和尺寸常量
    required this.standardPadding,
    required this.compactPadding,
    required this.loosePadding,
    required this.standardMargin,
    required this.compactMargin,
    required this.looseMargin,
    required this.standardBorderRadius,
    required this.smallBorderRadius,
    required this.largeBorderRadius,
    required this.chatBubbleBorderRadius,
    required this.standardShadow,
    required this.lightShadow,
    required this.heavyShadow,
  });

  /// 创建亮色主题扩展
  static AppThemeExtension light() {
    return AppThemeExtension(
      // 聊天相关颜色
      chatBubbleColorSent: AppColors.primaryGreen,
      chatBubbleColorReceived: AppColors.lightCardBackground,
      chatBubbleTextColorSent: Colors.white,
      chatBubbleTextColorReceived: AppColors.lightTextPrimary,
      chatInputBackgroundColor: AppColors.lightSurface,
      chatInputBorderColor: AppColors.lightBorder,
      chatTimestampColor: AppColors.lightTextDisabled,
      chatStatusIconColor: AppColors.lightTextDisabled,

      // 徽章和通知颜色
      unreadBadgeColor: AppColors.primaryGreen,
      unreadBadgeTextColor: Colors.white,
      onlineStatusColor: const Color(0xFF4CAF50), // 绿色
      offlineStatusColor: AppColors.lightTextDisabled,
      busyStatusColor: const Color(0xFFFF9800), // 橙色
      // 功能性颜色
      successColor: const Color(0xFF4CAF50), // 绿色
      warningColor: const Color(0xFFFF9800), // 橙色
      infoColor: AppColors.info,
      dividerColor: AppColors.lightBorder,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      overlayColor: Colors.black.withValues(alpha: 0.5),

      // 间距和尺寸常量
      standardPadding: const EdgeInsets.all(16.0),
      compactPadding: const EdgeInsets.all(8.0),
      loosePadding: const EdgeInsets.all(24.0),
      standardMargin: const EdgeInsets.all(16.0),
      compactMargin: const EdgeInsets.all(8.0),
      looseMargin: const EdgeInsets.all(24.0),
      standardBorderRadius: 8.0,
      smallBorderRadius: 4.0,
      largeBorderRadius: 16.0,
      chatBubbleBorderRadius: 12.0,

      // 阴影
      standardShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
      lightShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
      heavyShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// 创建暗色主题扩展
  static AppThemeExtension dark() {
    return AppThemeExtension(
      // 聊天相关颜色
      chatBubbleColorSent: AppColors.primaryGreenLight,
      chatBubbleColorReceived: AppColors.darkCardBackground,
      chatBubbleTextColorSent: Colors.black,
      chatBubbleTextColorReceived: AppColors.darkTextPrimary,
      chatInputBackgroundColor: AppColors.darkSurface,
      chatInputBorderColor: AppColors.darkBorder,
      chatTimestampColor: AppColors.darkTextDisabled,
      chatStatusIconColor: AppColors.darkTextDisabled,

      // 徽章和通知颜色
      unreadBadgeColor: AppColors.primaryGreenLight,
      unreadBadgeTextColor: Colors.black,
      onlineStatusColor: const Color(0xFF66BB6A), // 亮绿色
      offlineStatusColor: AppColors.darkTextDisabled,
      busyStatusColor: const Color(0xFFFFB74D), // 亮橙色
      // 功能性颜色
      successColor: const Color(0xFF66BB6A), // 亮绿色
      warningColor: const Color(0xFFFFB74D), // 亮橙色
      infoColor: AppColors.info,
      dividerColor: AppColors.darkBorder,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      overlayColor: Colors.black.withValues(alpha: 0.7),

      // 间距和尺寸常量（与亮色主题相同）
      standardPadding: const EdgeInsets.all(16.0),
      compactPadding: const EdgeInsets.all(8.0),
      loosePadding: const EdgeInsets.all(24.0),
      standardMargin: const EdgeInsets.all(16.0),
      compactMargin: const EdgeInsets.all(8.0),
      looseMargin: const EdgeInsets.all(24.0),
      standardBorderRadius: 8.0,
      smallBorderRadius: 4.0,
      largeBorderRadius: 16.0,
      chatBubbleBorderRadius: 12.0,

      // 阴影（暗色主题下更明显）
      standardShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
      lightShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
      heavyShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  ThemeExtension<AppThemeExtension> copyWith({
    // 聊天相关颜色
    Color? chatBubbleColorSent,
    Color? chatBubbleColorReceived,
    Color? chatBubbleTextColorSent,
    Color? chatBubbleTextColorReceived,
    Color? chatInputBackgroundColor,
    Color? chatInputBorderColor,
    Color? chatTimestampColor,
    Color? chatStatusIconColor,

    // 徽章和通知颜色
    Color? unreadBadgeColor,
    Color? unreadBadgeTextColor,
    Color? onlineStatusColor,
    Color? offlineStatusColor,
    Color? busyStatusColor,

    // 功能性颜色
    Color? successColor,
    Color? warningColor,
    Color? infoColor,
    Color? dividerColor,
    Color? shadowColor,
    Color? overlayColor,

    // 间距和尺寸常量
    EdgeInsets? standardPadding,
    EdgeInsets? compactPadding,
    EdgeInsets? loosePadding,
    EdgeInsets? standardMargin,
    EdgeInsets? compactMargin,
    EdgeInsets? looseMargin,
    double? standardBorderRadius,
    double? smallBorderRadius,
    double? largeBorderRadius,
    double? chatBubbleBorderRadius,
    List<BoxShadow>? standardShadow,
    List<BoxShadow>? lightShadow,
    List<BoxShadow>? heavyShadow,
  }) {
    return AppThemeExtension(
      // 聊天相关颜色
      chatBubbleColorSent: chatBubbleColorSent ?? this.chatBubbleColorSent,
      chatBubbleColorReceived:
          chatBubbleColorReceived ?? this.chatBubbleColorReceived,
      chatBubbleTextColorSent:
          chatBubbleTextColorSent ?? this.chatBubbleTextColorSent,
      chatBubbleTextColorReceived:
          chatBubbleTextColorReceived ?? this.chatBubbleTextColorReceived,
      chatInputBackgroundColor:
          chatInputBackgroundColor ?? this.chatInputBackgroundColor,
      chatInputBorderColor: chatInputBorderColor ?? this.chatInputBorderColor,
      chatTimestampColor: chatTimestampColor ?? this.chatTimestampColor,
      chatStatusIconColor: chatStatusIconColor ?? this.chatStatusIconColor,

      // 徽章和通知颜色
      unreadBadgeColor: unreadBadgeColor ?? this.unreadBadgeColor,
      unreadBadgeTextColor: unreadBadgeTextColor ?? this.unreadBadgeTextColor,
      onlineStatusColor: onlineStatusColor ?? this.onlineStatusColor,
      offlineStatusColor: offlineStatusColor ?? this.offlineStatusColor,
      busyStatusColor: busyStatusColor ?? this.busyStatusColor,

      // 功能性颜色
      successColor: successColor ?? this.successColor,
      warningColor: warningColor ?? this.warningColor,
      infoColor: infoColor ?? this.infoColor,
      dividerColor: dividerColor ?? this.dividerColor,
      shadowColor: shadowColor ?? this.shadowColor,
      overlayColor: overlayColor ?? this.overlayColor,

      // 间距和尺寸常量
      standardPadding: standardPadding ?? this.standardPadding,
      compactPadding: compactPadding ?? this.compactPadding,
      loosePadding: loosePadding ?? this.loosePadding,
      standardMargin: standardMargin ?? this.standardMargin,
      compactMargin: compactMargin ?? this.compactMargin,
      looseMargin: looseMargin ?? this.looseMargin,
      standardBorderRadius: standardBorderRadius ?? this.standardBorderRadius,
      smallBorderRadius: smallBorderRadius ?? this.smallBorderRadius,
      largeBorderRadius: largeBorderRadius ?? this.largeBorderRadius,
      chatBubbleBorderRadius:
          chatBubbleBorderRadius ?? this.chatBubbleBorderRadius,
      standardShadow: standardShadow ?? this.standardShadow,
      lightShadow: lightShadow ?? this.lightShadow,
      heavyShadow: heavyShadow ?? this.heavyShadow,
    );
  }

  @override
  ThemeExtension<AppThemeExtension> lerp(
    ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) return this;

    return AppThemeExtension(
      // 聊天相关颜色
      chatBubbleColorSent: Color.lerp(
        chatBubbleColorSent,
        other.chatBubbleColorSent,
        t,
      )!,
      chatBubbleColorReceived: Color.lerp(
        chatBubbleColorReceived,
        other.chatBubbleColorReceived,
        t,
      )!,
      chatBubbleTextColorSent: Color.lerp(
        chatBubbleTextColorSent,
        other.chatBubbleTextColorSent,
        t,
      )!,
      chatBubbleTextColorReceived: Color.lerp(
        chatBubbleTextColorReceived,
        other.chatBubbleTextColorReceived,
        t,
      )!,
      chatInputBackgroundColor: Color.lerp(
        chatInputBackgroundColor,
        other.chatInputBackgroundColor,
        t,
      )!,
      chatInputBorderColor: Color.lerp(
        chatInputBorderColor,
        other.chatInputBorderColor,
        t,
      )!,
      chatTimestampColor: Color.lerp(
        chatTimestampColor,
        other.chatTimestampColor,
        t,
      )!,
      chatStatusIconColor: Color.lerp(
        chatStatusIconColor,
        other.chatStatusIconColor,
        t,
      )!,

      // 徽章和通知颜色
      unreadBadgeColor: Color.lerp(
        unreadBadgeColor,
        other.unreadBadgeColor,
        t,
      )!,
      unreadBadgeTextColor: Color.lerp(
        unreadBadgeTextColor,
        other.unreadBadgeTextColor,
        t,
      )!,
      onlineStatusColor: Color.lerp(
        onlineStatusColor,
        other.onlineStatusColor,
        t,
      )!,
      offlineStatusColor: Color.lerp(
        offlineStatusColor,
        other.offlineStatusColor,
        t,
      )!,
      busyStatusColor: Color.lerp(busyStatusColor, other.busyStatusColor, t)!,

      // 功能性颜色
      successColor: Color.lerp(successColor, other.successColor, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      infoColor: Color.lerp(infoColor, other.infoColor, t)!,
      dividerColor: Color.lerp(dividerColor, other.dividerColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      overlayColor: Color.lerp(overlayColor, other.overlayColor, t)!,

      // 间距和尺寸常量（使用线性插值）
      standardPadding: EdgeInsets.lerp(
        standardPadding,
        other.standardPadding,
        t,
      )!,
      compactPadding: EdgeInsets.lerp(compactPadding, other.compactPadding, t)!,
      loosePadding: EdgeInsets.lerp(loosePadding, other.loosePadding, t)!,
      standardMargin: EdgeInsets.lerp(standardMargin, other.standardMargin, t)!,
      compactMargin: EdgeInsets.lerp(compactMargin, other.compactMargin, t)!,
      looseMargin: EdgeInsets.lerp(looseMargin, other.looseMargin, t)!,
      standardBorderRadius: lerpDouble(
        standardBorderRadius,
        other.standardBorderRadius,
        t,
      )!,
      smallBorderRadius: lerpDouble(
        smallBorderRadius,
        other.smallBorderRadius,
        t,
      )!,
      largeBorderRadius: lerpDouble(
        largeBorderRadius,
        other.largeBorderRadius,
        t,
      )!,
      chatBubbleBorderRadius: lerpDouble(
        chatBubbleBorderRadius,
        other.chatBubbleBorderRadius,
        t,
      )!,

      // 阴影（简单处理，使用当前值）
      standardShadow: t < 0.5 ? standardShadow : other.standardShadow,
      lightShadow: t < 0.5 ? lightShadow : other.lightShadow,
      heavyShadow: t < 0.5 ? heavyShadow : other.heavyShadow,
    );
  }
}

/// 便捷扩展方法，用于快速访问 AppThemeExtension
extension AppThemeExtensionHelper on BuildContext {
  /// 获取当前的 AppThemeExtension
  AppThemeExtension? get appThemeExtension =>
      Theme.of(this).extension<AppThemeExtension>();

  /// 获取聊天气泡颜色（发送）
  Color get chatBubbleColorSent =>
      appThemeExtension?.chatBubbleColorSent ?? AppColors.primaryGreen;

  /// 获取聊天气泡颜色（接收）
  Color get chatBubbleColorReceived =>
      appThemeExtension?.chatBubbleColorReceived ??
      AppColors.lightCardBackground;

  /// 获取未读徽章颜色
  Color get unreadBadgeColor =>
      appThemeExtension?.unreadBadgeColor ?? AppColors.primaryGreen;

  /// 获取在线状态颜色
  Color get onlineStatusColor =>
      appThemeExtension?.onlineStatusColor ?? const Color(0xFF4CAF50);

  /// 获取成功状态颜色
  Color get successColor =>
      appThemeExtension?.successColor ?? const Color(0xFF4CAF50);

  /// 获取警告状态颜色
  Color get warningColor =>
      appThemeExtension?.warningColor ?? const Color(0xFFFF9800);

  /// 获取标准内边距
  EdgeInsets get standardPadding =>
      appThemeExtension?.standardPadding ?? const EdgeInsets.all(16.0);

  /// 获取紧凑内边距
  EdgeInsets get compactPadding =>
      appThemeExtension?.compactPadding ?? const EdgeInsets.all(8.0);

  /// 获取标准圆角半径
  double get standardBorderRadius =>
      appThemeExtension?.standardBorderRadius ?? 8.0;

  /// 获取聊天气泡圆角半径
  double get chatBubbleBorderRadius =>
      appThemeExtension?.chatBubbleBorderRadius ?? 12.0;

  /// 获取标准阴影
  List<BoxShadow> get standardShadow =>
      appThemeExtension?.standardShadow ??
      [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
}
