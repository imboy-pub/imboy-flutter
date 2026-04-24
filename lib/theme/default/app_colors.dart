import 'dart:math';
import 'package:flutter/material.dart';

/// 应用统一颜色管理类
/// 提供亮色和暗色主题的所有颜色定义
class AppColors {
  // 私有构造函数，防止实例化
  AppColors._();

  /// 主色 - Material 3 Primary - Blue 600
  /// 颜色值：#2474E5
  static const Color primary = Color(0xFF2474E5);


  /// 主色 - 浅色版本 - Material 3 Primary Light - Blue 50
  static const Color primaryLight = Color(0xFFE3F2FD);

  /// 主色 - 深色版本 - Material 3 Primary Dark - Blue 700
  static const Color primaryDark = Color(0xFF1565C0);

  /// 主色容器背景 - Material 3 Primary Container
  static const Color primaryContainer = Color(0xFFBBDEFB);

  /// 主色容器上的文本 - Material 3 On Primary Container
  static const Color onPrimaryContainer = Color(0xFF0D47A1);

  // ============ Material 3 次要色系统 ============
  /// 次要色 - Material 3 Secondary - Indigo 400
  static const Color secondary = Color(0xFF5C6BC0);

  /// 次要色容器 - Material 3 Secondary Container
  static const Color secondaryContainer = Color(0xFFE8EAF6);

  /// 次要色容器上的文本 - Material 3 On Secondary Container
  static const Color onSecondaryContainer = Color(0xFF1A237E);

  // ============ Material 3 第三色系统 ============
  /// 第三色 - Material 3 Tertiary - Cyan 600
  /// 优化理由：使用青色调增加视觉丰富度，与蓝色主色调和谐搭配
  static const Color tertiary = Color(0xFF00ACC1);

  /// 第三色容器 - Material 3 Tertiary Container
  static const Color tertiaryContainer = Color(0xFFB2EBF2);

  /// 第三色容器上的文本 - Material 3 On Tertiary Container
  static const Color onTertiaryContainer = Color(0xFF006064);

  // ============ Material 3 亮色主题颜色系统 ============
  /// 亮色主题 - 主要文本颜色 - Material 3 On Surface
  static const Color lightTextPrimary = Color(0xFF1D1B20);

  /// 亮色主题 - 次要文本颜色 - Material 3 On Surface Variant
  static const Color lightTextSecondary = Color(0xFF49454F);

  /// 亮色主题 - 禁用文本颜色
  static const Color lightTextDisabled = Color(0xFF999999);

  /// 亮色主题 - 表面颜色 - Material 3 Surface
  static const Color lightSurface = Colors.white;

  /// 亮色主题 - 背景颜色 - Material 3 Background
  ///
  /// 建议：新代码使用 [lightSurface]（Background 与 Surface 在当前实现中相同）。
  static const Color lightBackground = Colors.white;

  /// 亮色主题 - 表面变体 - Material 3 Surface Variant
  static const Color lightSurfaceVariant = Color(0xFFE7E0EC);

  /// 亮色主题 - 表面容器 - Material 3 Surface Container (微信风格浅灰)
  static const Color lightSurfaceContainer = Color(0xFFEDEDED);

  /// 亮色主题 - 表面容器最高 - Material 3 Surface Container Highest
  static const Color lightSurfaceContainerHighest = Color(0xFFE6E0E9);

  /// 亮色主题 - 卡片背景
  ///
  /// 建议：新代码使用 [lightSurface] 或 [lightSurfaceContainer]。
  static const Color lightCardBackground = Colors.white;

  /// 亮色主题 - 分割线颜色 - Material 3 Outline Variant
  static const Color lightDivider = Color(0xFFE5E5E5);

  /// 亮色主题 - 边框颜色 - Material 3 Outline
  static const Color lightBorder = Color(0xFFE5E5E5);

  /// 亮色主题 - AppBar背景（微信风格浅灰）
  static const Color lightAppBarBackground = Color(0xFFEDEDED);

  /// 亮色主题 - 错误颜色 - Material 3 Error
  static const Color lightError = Color(0xFFBA1A1A);

  /// 亮色主题 - 错误容器 - Material 3 Error Container
  static const Color lightErrorContainer = Color(0xFFFFDAD6);

  /// 亮色主题 - 错误容器上的文本 - Material 3 On Error Container
  static const Color lightOnErrorContainer = Color(0xFF410002);

  // ============ Material 3 暗色主题颜色系统 ============
  /// 暗色主题 - 主要文本颜色 - Material 3 On Surface
  static const Color darkTextPrimary = Color(0xFFF0F0F0);

  /// 暗色主题 - 次要文本颜色 - Material 3 On Surface Variant
  static const Color darkTextSecondary = Color(0xFFD0D0D0);

  /// 暗色主题 - 禁用文本颜色
  static const Color darkTextDisabled = Color(0xFF808080);

  /// 暗色主题 - 表面颜色 - Material 3 Surface
  static const Color darkSurface = Color(0xFF121212);

  /// 暗色主题 - 背景颜色 - Material 3 Background
  ///
  /// 建议：新代码使用 [darkSurface]（Background 与 Surface 在当前实现中相同）。
  static const Color darkBackground = Color(0xFF121212);

  /// 暗色主题 - 表面变体 - Material 3 Surface Variant
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);

  /// 暗色主题 - 表面容器 - Material 3 Surface Container
  static const Color darkSurfaceContainer = Color(0xFF1E1E1E);

  /// 暗色主题 - 表面容器最高 - Material 3 Surface Container Highest
  static const Color darkSurfaceContainerHighest = Color(0xFF2A2A2A);

  /// 暗色主题 - 卡片背景
  ///
  /// 建议：新代码使用 [darkSurfaceContainer]。
  static const Color darkCardBackground = darkSurfaceContainer;

  /// 暗色主题 - 分割线颜色 - Material 3 Outline Variant
  static const Color darkDivider = Color(0xFF404040);

  /// 暗色主题 - 边框颜色 - Material 3 Outline
  static const Color darkBorder = Color(0xFF606060);

  /// 暗色主题 - AppBar背景（使用Surface Container）
  static const Color darkAppBarBackground = darkSurfaceContainer;

  /// 暗色主题 - 错误颜色 - Material 3 Error
  static const Color darkError = Color(0xFFFF6B6B);

  /// 暗色主题 - 错误容器 - Material 3 Error Container
  static const Color darkErrorContainer = Color(0xFF4A0E0E);

  /// 暗色主题 - 错误容器上的文本 - Material 3 On Error Container
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);

  // ============ 聊天相关颜色 ============
  /// 发送消息气泡背景 - 亮色主题
  /// 优化理由：使用主色确保白色文字的可读性，旧值 primaryLight 过浅
  static const Color lightSentMessageBackground = primary;

  /// 接收消息气泡背景 - 亮色主题
  static const Color lightReceivedMessageBackground = Color(0xFFFFFFFF);

  /// 发送消息气泡背景 - 暗色主题
  /// 优化理由：深色模式下使用醒目但舒适的蓝色，保持视觉识别度
  static const Color darkSentMessageBackground = Color(0xFF42A5F5);

  /// 接收消息气泡背景 - 暗色主题
  static const Color darkReceivedMessageBackground = Color(0xFF2A2A2A);

  /// 发送消息文本颜色
  static const Color sentMessageText = Colors.white;

  /// 接收消息文本颜色 - 亮色主题
  static const Color lightReceivedMessageText = lightTextPrimary;

  /// 接收消息文本颜色 - 暗色主题
  static const Color darkReceivedMessageText = darkTextPrimary;

  // ============ 状态颜色 ============
  /// 成功状态颜色
  /// 优化理由：使用更明确的绿色
  static const Color success = Color(0xFF2E7D32);

  /// 警告状态颜色
  /// 优化理由：提高辨识度的橙色
  static const Color warning = Color(0xFFF57C00);

  /// 信息状态颜色
  /// 优化理由：更专业的蓝色
  static const Color info = Color(0xFF006C9A);

  // ============ 功能性颜色 ============
  /// 在线状态指示器
  /// 优化理由：使用 Material Design 标准绿色，更积极、易识别
  static const Color onlineIndicator = Color(0xFF4CAF50);

  /// 离线状态指示器
  static const Color offlineIndicator = Color(0xFF999999);

  /// 未读消息计数背景
  static const Color unreadBadgeBackground = Color(0xFFE53E3E);

  /// 未读消息计数文本
  static const Color unreadBadgeText = Colors.white;

  // ============ 消息状态颜色 ============
  /// 消息已送达状态
  static const Color messageDelivered = success;

  /// 消息已读状态
  static const Color messageRead = primary;

  /// 消息发送失败状态
  static const Color messageFailed = Color(0xFFE53E3E);

  // ============ 透明度变体 ============
  /// 主色 - 10% 透明度
  static Color get primaryAlpha10 => primary.withValues(alpha: 0.1);

  /// 主色 - 20% 透明度
  static Color get primaryAlpha20 => primary.withValues(alpha: 0.2);

  /// 主色 - 30% 透明度
  static Color get primaryAlpha30 => primary.withValues(alpha: 0.3);

  /// 主色 - 50% 透明度
  static Color get primaryAlpha50 => primary.withValues(alpha: 0.5);

  // ============ 渐变色支持 ============
  /// 主色调渐变
  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 暗色主题主色调渐变
  static LinearGradient get darkPrimaryGradient => const LinearGradient(
    colors: [primaryDark, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ============ 便捷访问属性 ============
  /// 次要文本颜色 - 根据当前主题自动选择
  static Color get textSecondary {
    // 这里可以通过 Get.isDarkMode 或其他方式获取当前主题
    // 暂时返回亮色主题的次要文本颜色，后续可以优化
    return lightTextSecondary;
  }

  // ============ 工具方法 ============
  /// 根据主题亮度获取对应的文本颜色
  static Color getTextColor(Brightness brightness, {bool isSecondary = false}) {
    if (brightness == Brightness.dark) {
      return isSecondary ? darkTextSecondary : darkTextPrimary;
    } else {
      return isSecondary ? lightTextSecondary : lightTextPrimary;
    }
  }

  /// 根据主题亮度获取对应的背景颜色
  static Color getBackgroundColor(Brightness brightness) {
    return brightness == Brightness.dark ? darkBackground : lightBackground;
  }

  /// 根据主题亮度获取对应的表面颜色
  static Color getSurfaceColor(Brightness brightness) {
    return brightness == Brightness.dark ? darkSurface : lightSurface;
  }

  /// 根据主题亮度获取对应的分割线颜色
  static Color getDividerColor(Brightness brightness) {
    return brightness == Brightness.dark ? darkDivider : lightDivider;
  }

  // ============ iOS 系统语义色系统 ============
  // 参考 Apple Human Interface Guidelines / UIColor Standard Colors
  // 详见 imboyapp/DESIGN.md 第 2 章「色彩系统」
  //
  // 使用规则（双蓝策略）：
  //   - 品牌识别位置（Logo、Tab 选中、主按钮、发送气泡）→ 使用 primary (#2474E5)
  //   - iOS 系统语义位置（链接、Nav 文字按钮、取消按钮、Switch）→ 使用 iosBlue (#007AFF)
  //   - 破坏性操作（删除、退出登录）→ 必须使用 iosRed

  /// iOS 系统蓝 - 亮色
  /// 用途：链接文本、Cell 时间标签、Nav 取消/完成按钮、Switch 开启态、Picker
  static const Color iosBlue = Color(0xFF007AFF);

  /// iOS 系统蓝 - 暗色（+ 明度增强）
  static const Color iosBlueDark = Color(0xFF0A84FF);

  /// iOS 系统红 - 亮色
  /// 用途：破坏性操作（删除、退出、解散群）、错误状态、未读 Badge
  static const Color iosRed = Color(0xFFFF3B30);

  /// iOS 系统红 - 暗色
  static const Color iosRedDark = Color(0xFFFF453A);

  /// iOS 系统绿 - 亮色
  /// 用途：在线指示器、成功状态、Switch 开启态（可选）
  static const Color iosGreen = Color(0xFF34C759);

  /// iOS 系统绿 - 暗色
  static const Color iosGreenDark = Color(0xFF30D158);

  /// iOS 系统橙 - 亮色
  /// 用途：警告状态、重要提示
  static const Color iosOrange = Color(0xFFFF9500);

  /// iOS 系统橙 - 暗色
  static const Color iosOrangeDark = Color(0xFFFF9F0A);

  /// iOS 系统黄 - 亮色
  /// 用途：高亮提示、强调信息
  static const Color iosYellow = Color(0xFFFFCC00);

  /// iOS 系统黄 - 暗色
  static const Color iosYellowDark = Color(0xFFFFD60A);

  // iOS 中性灰阶（6 级，从浅到深命名与 Apple 保持一致）
  /// iOS Gray - 最常用次级文字色
  static const Color iosGray = Color(0xFF8E8E93);

  /// iOS Gray 2
  static const Color iosGray2 = Color(0xFFAEAEB2);

  /// iOS Gray 3 - 分隔线默认色（亮色模式）
  static const Color iosGray3 = Color(0xFFC7C7CC);

  /// iOS Gray 4
  static const Color iosGray4 = Color(0xFFD1D1D6);

  /// iOS Gray 5 - InsetGrouped 列表内分隔线
  static const Color iosGray5 = Color(0xFFE5E5EA);

  /// iOS Gray 6 - 分组列表页背景（关键！）
  /// 等同于 lightSurfaceGrouped
  static const Color iosGray6 = Color(0xFFF2F2F7);

  /// iOS Separator - 亮色模式 Cell 分隔线（Apple 官方）
  static const Color iosSeparator = Color(0xFFC6C6C8);

  /// iOS Separator - 暗色模式 Cell 分隔线
  static const Color iosSeparatorDark = Color(0xFF38383A);

  // ============ iOS 风格分组列表背景 ============
  /// 亮色主题 - 分组列表页背景（iOS Settings 风格）
  /// 与 lightSurfaceContainer (#EDEDED 微信风) 并存，新页面可选择此值获得 iOS 观感
  static const Color lightSurfaceGrouped = Color(0xFFF2F2F7);

  /// 暗色主题 - 分组列表页背景（非 OLED）
  static const Color darkSurfaceGrouped = Color(0xFF1C1C1E);

  /// 暗色主题 - 分组列表页背景（OLED 纯黑）
  static const Color darkSurfaceGroupedOled = Color(0xFF000000);

  // ============ iOS 语义色工具方法 ============
  /// 根据主题亮度获取 iOS 系统蓝
  static Color getIosBlue(Brightness brightness) {
    return brightness == Brightness.dark ? iosBlueDark : iosBlue;
  }

  /// 根据主题亮度获取 iOS 系统红（破坏性操作用）
  static Color getIosRed(Brightness brightness) {
    return brightness == Brightness.dark ? iosRedDark : iosRed;
  }

  /// 根据主题亮度获取 iOS 系统绿
  static Color getIosGreen(Brightness brightness) {
    return brightness == Brightness.dark ? iosGreenDark : iosGreen;
  }

  /// 根据主题亮度获取 iOS 风格分隔线
  static Color getIosSeparator(Brightness brightness) {
    return brightness == Brightness.dark ? iosSeparatorDark : iosSeparator;
  }

  /// 根据主题亮度与 OLED 模式获取分组列表背景
  static Color getSurfaceGrouped(Brightness brightness, {bool isOLEDMode = false}) {
    if (brightness == Brightness.light) {
      return lightSurfaceGrouped;
    }
    return isOLEDMode ? darkSurfaceGroupedOled : darkSurfaceGrouped;
  }

  // ============ OLED 优化的纯黑模式颜色系统 ============
  /// OLED 优化的纯黑背景 - 节省电量，提升对比度
  static const Color oledBackground = Color(0xFF000000);

  /// OLED 模式 - 表面颜色（纯黑）
  static const Color oledSurface = Color(0xFF000000);

  /// OLED 模式 - 表面容器（极深灰）
  static const Color oledSurfaceContainer = Color(0xFF0A0A0A);

  /// OLED 模式 - 表面容器最高（深灰）
  static const Color oledSurfaceContainerHighest = Color(0xFF1A1A1A);

  /// OLED 模式 - 卡片背景
  static const Color oledCardBackground = oledSurfaceContainer;

  /// OLED 模式 - AppBar背景
  static const Color oledAppBarBackground = oledSurfaceContainer;

  /// OLED 模式 - 接收消息气泡背景
  static const Color oledReceivedMessageBackground = Color(0xFF1A1A1A);

  /// OLED 模式 - 分割线颜色（更暗）
  static const Color oledDivider = Color(0xFF2A2A2A);

  /// OLED 模式 - 边框颜色
  static const Color oledBorder = Color(0xFF404040);

  // ============ 深色模式增强功能 ============
  /// 护眼模式 - 减蓝光的暖色调背景
  static const Color eyeCareBackground = Color(0xFF1A1612);

  /// 护眼模式 - 暖色调表面
  static const Color eyeCareSurface = Color(0xFF1A1612);

  /// 护眼模式 - 暖色调文本
  static const Color eyeCareTextPrimary = Color(0xFFE8E0D6);

  /// 护眼模式 - 暖色调次要文本
  static const Color eyeCareTextSecondary = Color(0xFFD0C8BE);

  // ============ 深色模式工具方法 ============
  /// 根据OLED模式获取对应的背景颜色
  /// [isOLEDMode] 是否启用OLED模式
  /// [brightness] 主题亮度
  static Color getDarkBackground(bool isOLEDMode, Brightness brightness) {
    if (brightness == Brightness.light) {
      return lightBackground;
    }
    return isOLEDMode ? oledBackground : darkBackground;
  }

  /// 根据OLED模式获取对应的表面颜色
  /// [isOLEDMode] 是否启用OLED模式
  /// [brightness] 主题亮度
  static Color getDarkSurface(bool isOLEDMode, Brightness brightness) {
    if (brightness == Brightness.light) {
      return lightSurface;
    }
    return isOLEDMode ? oledSurface : darkSurface;
  }

  /// 根据OLED模式获取对应的表面容器颜色
  /// [isOLEDMode] 是否启用OLED模式
  /// [brightness] 主题亮度
  static Color getDarkSurfaceContainer(bool isOLEDMode, Brightness brightness) {
    if (brightness == Brightness.light) {
      return lightSurfaceContainer;
    }
    return isOLEDMode ? oledSurfaceContainer : darkSurfaceContainer;
  }

  /// 根据护眼模式获取对应的背景颜色
  /// [isEyeCareMode] 是否启用护眼模式
  /// [brightness] 主题亮度
  static Color getEyeCareBackground(bool isEyeCareMode, Brightness brightness) {
    if (brightness == Brightness.light) {
      return lightBackground;
    }
    return isEyeCareMode ? eyeCareBackground : darkBackground;
  }

  /// 根据护眼模式获取对应的文本颜色
  /// [isEyeCareMode] 是否启用护眼模式
  /// [brightness] 主题亮度
  /// [isSecondary] 是否为次要文本
  static Color getEyeCareTextColor(
    bool isEyeCareMode,
    Brightness brightness, {
    bool isSecondary = false,
  }) {
    if (brightness == Brightness.light) {
      return isSecondary ? lightTextSecondary : lightTextPrimary;
    }
    if (isEyeCareMode) {
      return isSecondary ? eyeCareTextSecondary : eyeCareTextPrimary;
    }
    return isSecondary ? darkTextSecondary : darkTextPrimary;
  }

  /// 根据聊天气泡类型和深色模式选项获取背景颜色
  /// [isSent] 是否为发送的消息
  /// [isOLEDMode] 是否启用OLED模式
  /// [brightness] 主题亮度
  static Color getChatBubbleBackground(
    bool isSent,
    bool isOLEDMode,
    Brightness brightness,
  ) {
    if (brightness == Brightness.light) {
      return isSent
          ? lightSentMessageBackground
          : lightReceivedMessageBackground;
    }
    if (isSent) {
      return darkSentMessageBackground;
    }
    return isOLEDMode
        ? oledReceivedMessageBackground
        : darkReceivedMessageBackground;
  }

  /// 检查颜色对比度是否符合WCAG标准
  /// [foreground] 前景色
  /// [background] 背景色
  /// [level] WCAG等级 ('AA' 或 'AAA')
  static bool checkContrastRatio(
    Color foreground,
    Color background, {
    String level = 'AA',
  }) {
    final double ratio = _calculateContrastRatio(foreground, background);
    final double requiredRatio = level == 'AAA' ? 7.0 : 4.5;
    return ratio >= requiredRatio;
  }

  /// 计算两个颜色之间的对比度
  /// [color1] 颜色1
  /// [color2] 颜色2
  static double _calculateContrastRatio(Color color1, Color color2) {
    final double l1 = _getRelativeLuminance(color1);
    final double l2 = _getRelativeLuminance(color2);
    final double lighter = l1 > l2 ? l1 : l2;
    final double darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// 获取颜色的相对亮度
  /// [color] 颜色
  static double _getRelativeLuminance(Color color) {
    final double r = _getLinearRGB((color.r * 255.0).round() / 255.0);
    final double g = _getLinearRGB((color.g * 255.0).round() / 255.0);
    final double b = _getLinearRGB((color.b * 255.0).round() / 255.0);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// 获取线性RGB值
  /// [value] RGB值（0-1）
  static double _getLinearRGB(double value) {
    if (value <= 0.03928) {
      return value / 12.92;
    } else {
      return pow((value + 0.055) / 1.055, 2.4).toDouble();
    }
  }
}
