import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'dark_model_state.dart';

class DarkModelLogic extends GetxController {
  final DarkModelState state = DarkModelState();
  final ThemeManager _themeManager = ThemeManager.instance;

  /// 配置本地主题配置
  void configLocalTheme() {
    final followSystem = _themeManager.followSystemTheme;
    final isDark = _themeManager.isDarkMode;

    state.switchValue.value = followSystem;

    if (!followSystem) {
      state.selectIndex.value = isDark ? 3 : 2;
    }
  }

  /// 点击开关 回调
  void configSwitchOnChanged(bool value) {
    iPrint("configSwitchOnChanged $value");
    state.switchValue.value = value;
    changeTheme(type: value ? 2 : 0);
  }

  Future<void> tapDarkItem({required int index}) async {
    int type = 0;
    if (index == 2) {
      type = 0;
    } else if (index == 3) {
      type = 1;
    }
    if (state.selectIndex.value == index) {
      return;
    }
    state.selectIndex.value = index;

    await changeTheme(type: type);
  }

  /// 切换主题
  /// 0 白色
  /// 1 黑色
  /// 2 系统跟随
  Future<void> changeTheme({
    int type = 0,
  }) async {
    // 更新 ThemeManager 的状态（会自动保存）
    if (type == 2) {
      // 跟随系统
      await _themeManager.updateFollowSystemTheme(true);
      _themeManager.applySystemTheme();
    } else {
      // 固定主题
      await _themeManager.updateFollowSystemTheme(false);
      await _themeManager.toggleTheme(isDark: type == 1);
    }

    // 更新 EasyLoading 样式
    _updateEasyLoadingStyle();

    // 强制更新 UI
    updateTheme();
  }

  /// 更新 EasyLoading 样式
  void _updateEasyLoadingStyle() {
    final isDark = _themeManager.isDarkMode;
    EasyLoadingStyle easyLoadingStyle = isDark
        ? EasyLoadingStyle.light
        : EasyLoadingStyle.dark;
    EasyLoading.instance.loadingStyle = easyLoadingStyle;
  }

  void updateTheme() {
    Future.delayed(const Duration(milliseconds: 250), () {
      Get.forceAppUpdate();
    });
  }

  /// 取主题类型（兼容旧代码）
  /// 0 白色
  /// 1 黑色
  /// 2 跟随系统
  int getThemeType() {
    if (_themeManager.followSystemTheme) {
      return 2;
    }
    return _themeManager.isDarkMode ? 1 : 0;
  }

  /// 获取主题数据
  ThemeData getLocalProfileAboutThemeData({
    bool isUserCache = true,
    int themeType = 0,
  }) {
    int type = isUserCache ? getThemeType() : themeType;
    if (type == 0) {
      return _themeManager.lightTheme;
    } else if (type == 1) {
      return _themeManager.darkTheme;
    } else if (type == 2) {
      // 跟随系统
      if (!Get.isDarkMode) {
        return _themeManager.darkTheme;
      } else {
        return _themeManager.lightTheme;
      }
    } else {
      return _themeManager.lightTheme;
    }
  }
}
