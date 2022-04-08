import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeController extends GetxController {
  //0:正常模式 1：黑夜模式
  var _darkMode = 0;

  get darkMode => _darkMode;

  void changeMode(value) {
    _darkMode = value;
    Get.changeTheme(Get.isDarkMode ? ThemeData.light() : ThemeData.dark());
    update();
  }
}
