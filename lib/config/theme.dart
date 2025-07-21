import 'package:flutter/material.dart';
import 'package:get/get.dart';

//调用的时候需要把hex改一下，比如#223344 needs change to 0xFF223344
//即把#换成0xFF即可
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = <int, Color>{};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

const mainSpace = 10.0;
double mainLineWidth = Get.isDarkMode ? 0.5 : 1.0;

const Color lightBgColor = Color.fromRGBO(248, 248, 248, 1.0);
// const Color lightInputBgColor = Colors.white70;
const Color lightPrimaryColor = Color.fromRGBO(236, 236, 236, 1);
const Color lightOnPrimaryColor = Color.fromRGBO(68, 68, 68, 1.0);
const Color lightInputTextColor = Color.fromRGBO(10, 25, 12, 1.0);
const Color lightInputFillColor = Color.fromRGBO(255, 255, 255, 1.0);

const Color darkBgColor = Color.fromRGBO(40, 40, 40, 1.0);
// const Color darkInputBgColor = Colors.black87;
const Color darkPrimaryColor = Color.fromRGBO(26, 26, 26, 1);
const Color darkOnPrimaryColor = Color.fromRGBO(208, 208, 208, 1.0);
const Color darkInputTextColor = Color.fromRGBO(255, 255, 255, 1.0);
const Color darkInputFillColor = Color.fromRGBO(44, 44, 44, 1.0);

class ChatColor {
  // for chat
  // static const ChatBg = Color.fromRGBO(243, 243, 243, 1.0);
  static const ChatSendMessageBgColor = Color.fromRGBO(178, 236, 114, 1.0);
  static const ChatSentMessageBodyTextColor = Color.fromRGBO(19, 29, 13, 1.0);

  static const ChatReceivedMessageBodyTextColor =
      Color.fromRGBO(255, 255, 255, 1.0);
  static const ChatReceivedMessageBodyBgColor = Color.fromRGBO(48, 48, 48, 1.0);

  static const ChatInputFillGgColor = Color.fromRGBO(220, 220, 220, 1.0);

// static const MainTextColor = Color.fromRGBO(115, 115, 115, 1.0);
// end for chat
}

final ColorScheme lightColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.light,
  seedColor: Colors.black,
  primary: lightPrimaryColor,
  // 主色调，用于突出显示和主要操作
  onPrimary: lightOnPrimaryColor,
  // 主色调上的文字或图标颜色
  primaryContainer: lightPrimaryColor.withValues(alpha: 0.8),
  // 主色调的容器背景色，更淡一些以提供对比
  onPrimaryContainer: Colors.black54,
  // 主色调容器上的文字或图标颜色
  surface: lightBgColor,
  // 背景颜色，比表面颜色稍深一些以提供对比
  onSurface: Colors.black54,
  // 背景颜色上的文字或图标颜色
  error: Colors.red,
  // 错误状态的颜色
  onError: Colors.white, // 错误状态上的文字或图标颜色
);
final ColorScheme darkColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.dark,
  seedColor: Colors.black,
  primary: darkPrimaryColor,
  // 主色调保持不变，以确保品牌一致性
  onPrimary: darkOnPrimaryColor,
  // 主色调上的文字颜色改为黑色或深色
  primaryContainer: darkPrimaryColor.withValues(alpha: 0.8),
  // 主色调的容器背景色，更淡一些以提供对比
  onPrimaryContainer: Colors.black54,
  // 主色调容器上的文字或图标颜色
  surface: darkBgColor,
  // 背景颜色改为更深的黑色调
  onSurface: Colors.white70,
  // 背景颜色上的文字颜色保持一定的透明度
  error: Colors.red,
  // 错误颜色
  onError: Colors.white, // 错误颜色上的文字颜色改为黑色
);

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  platform: TargetPlatform.iOS,
  useMaterial3: true,
  primarySwatch: createMaterialColor(const Color(0xFF223344)),
  colorScheme: lightColorScheme,
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  platform: TargetPlatform.iOS,
  primarySwatch: createMaterialColor(const Color(0x00ffffff)),
  useMaterial3: true,
  colorScheme: darkColorScheme,
  // inputDecorationTheme: InputDecorationTheme(),
);


class AppStyle {
  static TextStyle navAppBarTitleStyle = TextStyle(
    color: Theme.of(Get.context!).colorScheme.onPrimary,
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
  );
}
