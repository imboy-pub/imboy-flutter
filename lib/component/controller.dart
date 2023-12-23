import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum ThemeMode {
  system, // 表示是系统默认的模式
  light, // 是明亮模式
  dark, // 是暗黑模式
}

class ThemeController extends GetxController {
  //0:正常模式 1：黑夜模式
  // ThemeMode _darkMode = ThemeMode.system;
  // Get.find<ThemeController>().darkMode == 0
  // ? Brightness.light
  //     : Brightness.dark
  var _darkMode = 0;
  get darkMode => _darkMode;

  void changeMode(value) {
    _darkMode = value;
    Get.changeTheme(Get.isDarkMode ? ThemeData.light() : ThemeData.dark());
    update();
  }
}
