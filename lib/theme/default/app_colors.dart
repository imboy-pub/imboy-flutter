import 'dart:math';
import 'package:flutter/material.dart';

/// 应用统一颜色管理类
/// 提供亮色和暗色主题的所有颜色定义
class AppColors {
  // 私有构造函数，防止实例化
  AppColors._();

  /// 主色 - Material 3 Primary - Blue 600
  static const Color primary = Color(0xFF2474E5);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color primaryContainer = Color(0xFFBBDEFB);
  static const Color onPrimaryContainer = Color(0xFF0D47A1);

  /// Primary 蓝底上的前景色（白）。用于主按钮内的图标/进度指示器等。
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color tagAccent = Color(0xFF649BEC);
  static const Color slateText = Color(0xFF64748B);
  static const Color slateMuted = Color(0xFFCBD5E1);

  static const Color splashGradientStart = Color(0xFF42A5F5);
  static const Color splashGradientStartDark = Color(0xFF1E3A8A);
  static const Color splashGradientMidDark = Color(0xFF172554);
  static const Color splashGradientEndDark = Color(0xFF0F1729);

  // ============ 叠加层 / 透明色 ============
  /// 全透明（黑底，0x00000000）。用于 WebView 背景等需"无色"语义处。
  static const Color transparent = Color(0x00000000);

  /// 白色高光叠加层（splash atmosphere 等）。8% / 12% 白。
  static const Color overlayLight = Color(0x14FFFFFF);
  static const Color overlayLightStrong = Color(0x1FFFFFFF);

  /// 白色全透明（0x00FFFFFF）。用于"白色高光 → 透明"的渐变末端。
  /// ⚠️ 不可用 [transparent]（黑底透明）替代，否则白→黑插值会出灰边。
  static const Color overlayWhiteTransparent = Color(0x00FFFFFF);

  // ============ 组件辅助色（shimmer / tag，保原值零视觉变更） ============
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
  static const Color tagBackground = Color(0xFFF8F8F8);

  // ============ 钱包卡片渐变色 ============
  static const Color walletCardGradientLightEnd = Color(0xFF1E40AF);
  static const Color walletCardGradientDarkStart = Color(0xFF1E3A8A);
  static const Color walletCardGradientDarkEnd = Color(0xFF1E1B4B);

  // ============ Material 3 次要色系统 ============
  static const Color secondary = Color(0xFF5C6BC0);
  static const Color secondaryContainer = Color(0xFFE8EAF6);
  static const Color onSecondaryContainer = Color(0xFF1A237E);

  // ============ Material 3 第三色系统 ============
  static const Color tertiary = Color(0xFF00ACC1);
  static const Color tertiaryContainer = Color(0xFFB2EBF2);
  static const Color onTertiaryContainer = Color(0xFF006064);

  // ============ 亮色主题 ============
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF3C3C43);
  static const Color lightTextDisabled = Color(0xFFC7C7CC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF9FAFB);
  static const Color lightSurfaceContainer = Color(0xFFF3F4F6);
  static const Color lightSurfaceContainerLow = Color(0xFFF9FAFB);
  static const Color lightPageBackground = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerHighest = Color(0xFFE6E0E9);
  static const Color lightCardBackground = Colors.white;
  static const Color lightDivider = Color(0xFFC6C6C8);
  static const Color lightBorder = Color(0xFFE5E5E5);
  static const Color lightAppBarBackground = Color(0xFFEDEDED);
  static const Color lightError = Color(0xFFFF3B30);
  static const Color lightErrorContainer = Color(0xFFFFDAD6);
  static const Color lightOnErrorContainer = Color(0xFF410002);

  // ============ 暗色主题 ============
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFEBEBF5);
  static const Color darkTextDisabled = Color(0xFF48484A);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurfaceVariant = Color(0xFF111827);
  static const Color darkSurfaceContainer = Color(0xFF111827);
  static const Color darkSurfaceContainerHighest = Color(0xFF1F2937);
  static const Color darkCardBackground = darkSurfaceContainer;
  static const Color darkDivider = Color(0xFF38383A);
  static const Color darkBorder = Color(0xFF606060);
  static const Color darkAppBarBackground = darkSurfaceContainer;
  static const Color darkError = Color(0xFFFF453A);
  static const Color darkErrorContainer = Color(0xFF4A0E0E);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);

  // ============ 聊天相关颜色 ============
  static const Color lightSentMessageBackground = primary;
  static const Color lightReceivedMessageBackground = Color(0xFFFFFFFF);
  static const Color darkSentMessageBackground = Color(0xFF42A5F5);
  static const Color darkReceivedMessageBackground = Color(0xFF2A2A2A);
  static const Color sentMessageText = Colors.white;
  static const Color lightReceivedMessageText = Color(0xFF000000);
  static const Color darkReceivedMessageText = Color(0xFFFFFFFF);

  // ============ 状态与指示器 ============
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF006C9A);
  static const Color onlineIndicator = Color(0xFF4CAF50);
  static const Color offlineIndicator = Color(0xFF999999);
  static const Color unreadBadgeBackground = Color(0xFFE53E3E);
  static const Color unreadBadgeText = Colors.white;
  static const Color messageDelivered = success;
  static const Color messageRead = primary;
  static const Color messageFailed = Color(0xFFE53E3E);

  // ============ iOS 语义色 ============
  static const Color iosBlue = Color(0xFF007AFF);
  static const Color iosBlueDark = Color(0xFF0A84FF);
  static const Color iosRed = Color(0xFFFF3B30);
  static const Color iosRedDark = Color(0xFFFF453A);
  static const Color iosGreen = Color(0xFF34C759);
  static const Color iosGreenDark = Color(0xFF30D158);
  static const Color iosOrange = Color(0xFFFF9500);
  static const Color iosOrangeDark = Color(0xFFFF9F0A);
  static const Color iosYellow = Color(0xFFFFCC00);
  static const Color iosYellowDark = Color(0xFFFFD60A);
  static const Color iosPurple = Color(0xFF5856D6);
  static const Color iosPurpleDark = Color(0xFF6E6CE0);
  static const Color iosSkyBlue = Color(0xFF5AC8FA);
  static const Color iosSkyBlueDark = Color(0xFF64D2FF);
  static const Color iosPink = Color(0xFFFF2D55);
  static const Color iosPinkDark = Color(0xFFFF375F);
  static const Color iosTeal = Color(0xFF00C896);
  static const Color iosGray = Color(0xFF8E8E93);
  static const Color iosGray2 = Color(0xFFAEAEB2);
  static const Color iosGray3 = Color(0xFFC7C7CC);
  static const Color iosGray3Dark = Color(0xFF48484A);
  static const Color iosGray4 = Color(0xFFD1D1D6);
  static const Color iosGray5 = Color(0xFFE5E5EA);
  static const Color iosGray6 = Color(0xF2F2F7FF);
  static const Color iosSeparator = Color(0xFFC6C6C8);
  static const Color iosSeparatorDark = Color(0xFF38383A);

  static const Color lightSurfaceGrouped = Color(0xFFF2F2F7);
  static const Color darkSurfaceGrouped = Color(0xFF1C1C1E);
  static const Color darkSurfaceGroupedOled = Color(0xFF000000);
  static const Color darkSurfaceGroupedTertiary = Color(0xFF2C2C2E);

  // ============ OLED 纯黑模式 ============
  static const Color oledBackground = Color(0xFF000000);
  static const Color oledSurface = Color(0xFF000000);
  static const Color oledSurfaceContainer = Color(0xFF0A0A0A);
  static const Color oledSurfaceContainerHighest = Color(0xFF1A1A1A);
  static const Color oledCardBackground = oledSurfaceContainer;
  static const Color oledAppBarBackground = oledSurfaceContainer;
  static const Color oledReceivedMessageBackground = Color(0xFF1A1A1A);
  static const Color oledDivider = Color(0xFF2A2A2A);
  static const Color oledBorder = Color(0xFF404040);

  // ============ 深色模式增强 ============
  static const Color eyeCareBackground = Color(0xFF1A1612);
  static const Color eyeCareSurface = Color(0xFF1A1612);
  static const Color eyeCareTextPrimary = Color(0xFFE8E0D6);
  static const Color eyeCareTextSecondary = Color(0xFFD0C8BE);

  // ============ Chat Web 风格颜色 ============
  static const Color chatWebSecondaryLight = Color(0xFF667781);
  static const Color chatWebSecondaryDark = Color(0xFF8696A0);
  static const Color chatWebBrand = Color(0xFF00A884);
  static const Color chatWebBackgroundLight = Color(0xFFF0F2F5);
  static const Color chatWebBackgroundDark = Color(0xFF202C33);
  static const Color chatWebSurfaceDark = Color(0xFF2A3942);
  static const Color chatWebDividerLight = Color(0xFFE9EDEF);
  static const Color chatWebDividerDark = Color(0xFF3B4A54);
  static const Color chatWebSurfaceDarkest = Color(0xFF111B21);

  // ============ Material Info 蓝 ============
  static const Color infoBlueContainer = Color(0xFFE1F5FE);
  static const Color infoBlue = Color(0xFF0277BD);

  // ============ 聊天壁纸渐变色 ============
  static const Color chatWallpaperBlueLightStart = Color(0xFF64B5F6);
  // chatWallpaperBlueLightEnd → splashGradientStart (0xFF42A5F5)
  static const Color chatWallpaperPurpleLightStart = Color(0xFFBA68C8);
  static const Color chatWallpaperPurpleLightEnd = Color(0xFFAB47BC);

  // ============ 第三方品牌色 ============
  static const Color wechatBlue = Color(0xFF576B95);

  // ============ 语义色补充 ============
  static const Color successBackground = Color(0xFFE8F5E9);
  static const Color deepNavy = Color(0xFF01579B);
  static const Color upgradeBackground = Color(0xFF333130);
  static const Color iosTertiaryLabel = Color(0xFF545458);
  static const Color lightNearBlack = Color(0xFF1A1A1A);
  static const Color neutralGray = Color(0xFF999999);

  // ============ 透明度变体 ============
  static Color get primaryAlpha10 => primary.withValues(alpha: 0.1);
  static Color get primaryAlpha20 => primary.withValues(alpha: 0.2);
  static Color get primaryAlpha30 => primary.withValues(alpha: 0.3);
  static Color get primaryAlpha50 => primary.withValues(alpha: 0.5);

  // ============ 兼容性语义方法 ============
  static Color getIosBlue(Brightness b) =>
      b == Brightness.dark ? iosBlueDark : iosBlue;
  static Color getIosRed(Brightness b) =>
      b == Brightness.dark ? iosRedDark : iosRed;
  static Color getIosGreen(Brightness b) =>
      b == Brightness.dark ? iosGreenDark : iosGreen;
  static Color getIosSeparator(Brightness b) =>
      b == Brightness.dark ? iosSeparatorDark : iosSeparator;

  static Color get textSecondary => lightTextSecondary;

  static Color getTextColor(Brightness b, {bool isSecondary = false}) {
    if (b == Brightness.dark) {
      return isSecondary ? darkTextSecondary : darkTextPrimary;
    }
    return isSecondary ? lightTextSecondary : lightTextPrimary;
  }

  static Color getBackgroundColor(Brightness b) =>
      b == Brightness.dark ? darkBackground : lightBackground;
  static Color getSurfaceColor(Brightness b) =>
      b == Brightness.dark ? darkSurface : lightSurface;
  static Color getDividerColor(Brightness b) =>
      b == Brightness.dark ? darkDivider : lightDivider;

  static Color getSurfaceGrouped(Brightness b, {bool isOLEDMode = false}) {
    if (b == Brightness.light) return lightSurfaceGrouped;
    return isOLEDMode ? darkSurfaceGroupedOled : darkSurfaceGrouped;
  }

  static Color getDarkBackground(bool isOLED, Brightness b) {
    if (b == Brightness.light) return lightBackground;
    return isOLED ? oledBackground : darkBackground;
  }

  static Color getDarkSurface(bool isOLED, Brightness b) {
    if (b == Brightness.light) return lightSurface;
    return isOLED ? oledSurface : darkSurface;
  }

  static Color getDarkSurfaceContainer(bool isOLED, Brightness b) {
    if (b == Brightness.light) return lightSurfaceContainer;
    return isOLED ? oledSurfaceContainer : darkSurfaceContainer;
  }

  static Color getEyeCareBackground(bool isEyeCare, Brightness b) {
    if (b == Brightness.light) return lightBackground;
    return isEyeCare ? eyeCareBackground : darkBackground;
  }

  static Color getEyeCareTextColor(
    bool isEyeCare,
    Brightness b, {
    bool isSecondary = false,
  }) {
    if (b == Brightness.light) {
      return isSecondary ? lightTextSecondary : lightTextPrimary;
    }
    if (isEyeCare) {
      return isSecondary ? eyeCareTextSecondary : eyeCareTextPrimary;
    }
    return isSecondary ? darkTextSecondary : darkTextPrimary;
  }

  static Color getChatBubbleBackground(bool isSent, bool isOLED, Brightness b) {
    if (b == Brightness.light) {
      return isSent
          ? lightSentMessageBackground
          : lightReceivedMessageBackground;
    }
    if (isSent) return darkSentMessageBackground;
    return isOLED
        ? oledReceivedMessageBackground
        : darkReceivedMessageBackground;
  }

  /// 接收方气泡在浅色主题下的细分隔线；发送方或暗色返回 null（无边框）。
  static Border? getReceivedBubbleDivider(bool isSent, Brightness b) {
    if (isSent || b == Brightness.dark) return null;
    return Border.all(color: iosGray5, width: 0.5);
  }

  // === 聊天消息媒体与装饰色（2026-06-25 chat UI 优化 token 化） ===
  // 集中管理 builder 内易硬编码的纯色基底，避免裸 Colors.white/Colors.black/Color(0x)。

  /// 红包气泡柔和红
  static const Color redPacketColor = Color(0xFFFA5151);

  /// 媒体遮罩白：叠在视频/图片缩略图上的播放钮、时长标签、骨架屏底色等
  static const Color mediaScrimWhite = Color(0xFFFFFFFF);

  /// 媒体遮罩黑：视频底部渐变 scrim 与时长标签底色
  static const Color mediaScrimBlack = Color(0xFF000000);

  /// 错误占位浅底（≈ Colors.grey[200]）
  static const Color placeholderSurfaceLight = Color(0xFFEEEEEE);

  /// 错误占位深底（≈ Colors.grey[800]）
  static const Color placeholderSurfaceDark = Color(0xFF424242);

  /// 10% 白高光（≈ Colors.white10）
  static const Color overlayWhite10 = Color(0x1AFFFFFF);

  static double getContrastRatio(Color c1, Color c2) {
    double l1 = _getLuminance(c1), l2 = _getLuminance(c2);
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
  }

  static double _getLuminance(Color c) {
    double r = _linear(c.r), g = _linear(c.g), b = _linear(c.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double _linear(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
}
