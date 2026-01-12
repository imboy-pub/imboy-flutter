import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';

import 'package:imboy/config/init.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/theme_manager.dart';

class SettingLogic extends GetxController {
  RxBool allowSearch = true.obs;

  @override
  void onInit() {
    super.onInit();
    allowSearch.value = UserRepoLocal.to.setting.allowSearch;
  }

  /// 获取主题类型提示文字
  String themeTypeTips() {
    final themeManager = ThemeManager.instance;

    // 跟随系统
    if (themeManager.followSystemTheme) {
      return t.followSystem;
    }

    // 深色模式
    if (themeManager.isDarkMode) {
      return t.on;
    }

    // 浅色模式
    return t.off;
  }

  Future<void> switchEnvironment(String env) async {
    await StorageService.to.setString('env', env);
    await StorageService.to.setBool('changedEnv', true);
    await UserRepoLocal.to.quitLogin();
    // 重启应用
    _restartApp();
  }

  void _restartApp() {
    iPrint("packageName $packageName");
    if (Platform.isAndroid) {
      SystemNavigator.pop();
      // Process.run('am', ['force-stop', packageName]);
      // Process.run('am', ['start', '{$packageName}/.MainActivity']);
    } else if (Platform.isIOS) {
      showDialog(
        context: Get.context!,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Restart Required'),
            content: const Text('Please restart the app to apply the changes.'),
            actions: <Widget>[
              TextButton(
                child: Text(
                  t.buttonConfirm,
                  // style: TextStyle(
                  //   color: ThemeManager.instance.getThemeColor('textPrimary'),
                  // ),
                ),
                onPressed: () {
                  exit(0);
                  // Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }
}
