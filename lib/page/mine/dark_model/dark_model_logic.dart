import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/service/storage.dart';

import 'dark_model_state.dart';

class DarkModelLogic extends GetxController {
  final DarkModelState state = DarkModelState();

  /// 配置本地主题配置
  configLocalTheme() {
    ThemeMode themeMode = getLocalProfileAboutThemeModel();
    if (themeMode == ThemeMode.system) {
      state.switchValue.value = true;
    } else {
      state.switchValue.value = false;
      if (themeMode == ThemeMode.light) {
        state.selectIndex.value = 2;
      } else if (themeMode == ThemeMode.dark) {
        state.selectIndex.value = 3;
      }
    }
  }

  /// 点击开关 回调
  configSwitchOnChanged(bool value) {
    iPrint("configSwitchOnChanged $value");
    state.switchValue.value = value;
    changeTheme(type: value ? 2 : 0);
  }

  tapDarkItem({required int index}) async {
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
  changeTheme({
    int type = 0,
    bool isUserCache = false,
  }) async {
    ThemeMode mode = getLocalProfileAboutThemeModel(
      isUserCache: isUserCache,
      themeType: type,
    );
    ThemeData themeData = getLocalProfileAboutThemeData(
      isUserCache: isUserCache,
      themeType: type,
    );
    iPrint(mode.toString());
    iPrint(themeData.toString());
    EasyLoadingStyle easyLoadingStyle = EasyLoadingStyle.dark;
    if (mode == ThemeMode.dark) {
      easyLoadingStyle = EasyLoadingStyle.light;
    } else if (mode == ThemeMode.system) {
      if (!Get.isDarkMode) {
        easyLoadingStyle = EasyLoadingStyle.light;
      }
    }
    EasyLoading.instance.loadingStyle = easyLoadingStyle;
    Get.changeThemeMode(mode);
    Get.changeTheme(themeData);
    updateTheme();
    if (!isUserCache) {
      saveThemeType(type);
    }
  }

  updateTheme() {
    Future.delayed(const Duration(milliseconds: 250), () {
      Get.forceAppUpdate();
    });
  }

  /// 取主题
  /// 0 白色
  /// 1 黑色
  /// 2 跟随系统
  int getThemeType() {
    return StorageService.to.getInt(Keys.themeType) ?? 0;
  }

  saveThemeType(int type) {
    StorageService.to.setInt(Keys.themeType, type);
  }

  getLocalProfileAboutThemeData({
    bool isUserCache = true,
    int themeType = 0,
  }) {
    int type = isUserCache ? getThemeType() : themeType;
    if (type == 0) {
      return lightTheme;
    } else if (type == 1) {
      return darkTheme;
    } else if (type == 2) {
      if (!Get.isDarkMode) {
        return darkTheme;
      } else {
        return lightTheme;
      }
    }
  }
}
