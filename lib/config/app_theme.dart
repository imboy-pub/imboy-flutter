import 'package:flutter/material.dart';
import 'package:get/get.dart';

// 1. 定义基础颜色接口
abstract class BaseThemeColors {
  Color get bgColor;
  Color get primaryColor;
  Color get onPrimaryColor;
  Color get inputTextColor;
  Color get inputFillColor;
}

// 2. 实现浅色主题颜色
class LightThemeColors implements BaseThemeColors {
  @override
  final Color bgColor = const Color(0xFFF8F8F8);

  @override
  final Color primaryColor = const Color(0xFFECECEC);

  @override
  final Color onPrimaryColor = const Color(0xFF444444);

  @override
  final Color inputTextColor = const Color(0xFF0A190C);

  @override
  final Color inputFillColor = const Color(0xFFFFFFFF);
}

// 3. 实现深色主题颜色
class DarkThemeColors implements BaseThemeColors {
  @override
  final Color bgColor = const Color(0xFF282828);

  @override
  final Color primaryColor = const Color(0xFF1A1A1A);

  @override
  final Color onPrimaryColor = const Color(0xFFD0D0D0);

  @override
  final Color inputTextColor = const Color(0xFFFFFFFF);

  @override
  final Color inputFillColor = const Color(0xFF2C2C2C);
}

// 4. 聊天相关颜色
class ChatColors {
  static const sendMessageBg = Color(0xFFB2EC72);
  static const sentMessageText = Color(0xFF131D0D);
  static const receivedMessageText = Color(0xFFFFFFFF);
  static const receivedMessageBg = Color(0xFF303030);
  static const inputFill = Color(0xFFDCDCDC);
}

// 5. 创建MaterialColor工具函数
MaterialColor createMaterialColor(Color color) {
  final swatch = <int, Color>{};
  final int r = (color.r * 255.0).round() & 0xff;
  final int g = (color.g * 255.0).round() & 0xff;
  final int b = (color.b * 255.0).round() & 0xff;

  final strengths = <double>[.05];
  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }

  for (final strength in strengths) {
    final ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.toARGB32(), swatch);
}

// 6. 创建颜色方案
final _lightColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.light,
  seedColor: Colors.black,
  primary: LightThemeColors().primaryColor,
  onPrimary: LightThemeColors().onPrimaryColor,
  primaryContainer: LightThemeColors().primaryColor.withValues(alpha: 0.8),
  onPrimaryContainer: Colors.black54,
  surface: LightThemeColors().bgColor,
  onSurface: Colors.black54,
  error: Colors.red,
  onError: Colors.white,
);

final _darkColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.dark,
  seedColor: Colors.black,
  primary: DarkThemeColors().primaryColor,
  onPrimary: DarkThemeColors().onPrimaryColor,
  primaryContainer: DarkThemeColors().primaryColor.withValues(alpha: 0.8),
  onPrimaryContainer: Colors.black54,
  surface: DarkThemeColors().bgColor,
  onSurface: Colors.white70,
  error: Colors.red,
  onError: Colors.white,
);

// 7. 主题创建函数
ThemeData createAppTheme(bool isDark) {
  final BaseThemeColors colors = isDark
      ? DarkThemeColors()
      : LightThemeColors();

  return ThemeData(
    brightness: isDark ? Brightness.dark : Brightness.light,
    platform: TargetPlatform.iOS,
    useMaterial3: true,
    primarySwatch: createMaterialColor(colors.primaryColor),
    colorScheme: isDark ? _darkColorScheme : _lightColorScheme,
  );
}

// 8. 导出的主题实例
final ThemeData lightTheme = createAppTheme(false);
final ThemeData darkTheme = createAppTheme(true);

// 9. 全局间距和线宽
const mainSpace = 10.0;
final double mainLineWidth = Get.isDarkMode ? 0.5 : 1.0;

// 10. 文本样式
class AppTextStyles {
  static TextStyle navAppBarTitle(BuildContext context, {bool isBold = true}) {
    final theme = Theme.of(context);
    return TextStyle(
      color: theme.colorScheme.onPrimary,
      fontSize: 16.0,
      fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
    );
  }
}
