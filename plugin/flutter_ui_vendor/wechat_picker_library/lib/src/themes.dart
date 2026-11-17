// Locally patched for standalone Flutter UI packages; see UPSTREAM.json.
// Copyright 2019 The FlutterCandies author. All rights reserved.
// Use of this source code is governed by an Apache license that can be found
// in the LICENSE file.

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

/// Default theme color from WeChat.
const defaultThemeColorWeChat = Color(0xff00bc56);

/// Rounded border radius.
const maxBorderRadius = BorderRadius.all(Radius.circular(9999999));

/// {@template wechat_picker_library.themeData}
/// Build a [ThemeData] with the given [themeColor] for the picker.
/// 为选择器构建基于 [themeColor] 的 [ThemeData]。
///
/// If [themeColor] is null, the color will use the fallback
/// [defaultThemeColorWeChat] which is the default color in the WeChat design.
/// 如果 [themeColor] 为 null，主题色将回落使用 [defaultThemeColorWeChat]，
/// 即微信设计中的绿色主题色。
///
/// Set [light] to true if pickers require a light version of the theme.
/// 设置 [light] 为 true 时可以获取浅色版本的主题。
/// {@endtemplate}
ThemeData buildTheme(Color? themeColor, {bool light = false}) {
  themeColor ??= defaultThemeColorWeChat;
  if (light) {
    final base = ThemeData.light();
    return base.copyWith(
      primaryColor: Colors.grey[50],
      primaryColorLight: Colors.grey[50],
      primaryColorDark: Colors.grey[50],
      canvasColor: Colors.grey[100],
      scaffoldBackgroundColor: Colors.grey[50],
      cardColor: Colors.grey[50],
      highlightColor: Colors.transparent,
      textSelectionTheme: base.textSelectionTheme.copyWith(
        cursorColor: themeColor,
        selectionColor: themeColor.withAlpha(100),
        selectionHandleColor: themeColor,
      ),
      // ignore: deprecated_member_use
      indicatorColor: themeColor,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.grey[100],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
        iconTheme:
            base.appBarTheme.iconTheme?.copyWith(color: Colors.grey[900]) ??
                IconThemeData(color: Colors.grey[900]),
        elevation: 0,
      ),
      bottomAppBarTheme: base.bottomAppBarTheme.copyWith(
        color: Colors.grey[100],
      ),
      buttonTheme: base.buttonTheme.copyWith(buttonColor: themeColor),
      iconTheme: base.iconTheme.copyWith(color: Colors.grey[900]),
      checkboxTheme: base.checkboxTheme.copyWith(
        checkColor: WidgetStateProperty.all(Colors.black),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return themeColor;
          }
          return null;
        }),
        side: const BorderSide(color: Colors.black),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: Colors.grey[50]!,
        secondary: themeColor,
        surface: Colors.grey[50]!,
        brightness: Brightness.light,
        error: const Color(0xffcf6679),
        onPrimary: Colors.white,
        onSecondary: Colors.grey[100]!,
        onSurface: Colors.black,
        onError: Colors.white,
      ),
    );
  }

  final base = ThemeData.dark();
  return base.copyWith(
    primaryColor: Colors.grey[900],
    primaryColorLight: Colors.grey[900],
    primaryColorDark: Colors.grey[900],
    canvasColor: Colors.grey[850],
    scaffoldBackgroundColor: Colors.grey[900],
    cardColor: Colors.grey[900],
    highlightColor: Colors.transparent,
    textSelectionTheme: base.textSelectionTheme.copyWith(
      cursorColor: themeColor,
      selectionColor: themeColor.withAlpha(100),
      selectionHandleColor: themeColor,
    ),
    // ignore: deprecated_member_use
    indicatorColor: themeColor,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: Colors.grey[850],
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      iconTheme: base.appBarTheme.iconTheme?.copyWith(color: Colors.white) ??
          const IconThemeData(color: Colors.white),
      elevation: 0,
    ),
    bottomAppBarTheme: base.bottomAppBarTheme.copyWith(
      color: Colors.grey[850],
    ),
    buttonTheme: base.buttonTheme.copyWith(buttonColor: themeColor),
    iconTheme: base.iconTheme.copyWith(color: Colors.white),
    checkboxTheme: base.checkboxTheme.copyWith(
      checkColor: WidgetStateProperty.all(Colors.white),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return themeColor;
        }
        return null;
      }),
      side: const BorderSide(color: Colors.white),
    ),
    colorScheme: base.colorScheme.copyWith(
      primary: Colors.grey[900]!,
      secondary: themeColor,
      surface: Colors.grey[900]!,
      brightness: Brightness.dark,
      error: const Color(0xffcf6679),
      onPrimary: Colors.black,
      onSecondary: Colors.grey[850]!,
      onSurface: Colors.white,
      onError: Colors.black,
    ),
  );
}
