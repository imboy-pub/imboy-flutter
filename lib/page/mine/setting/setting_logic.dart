import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class SettingLogic extends GetxController {
  String themeTypeTips() {
    int themeType = StorageService.to.getInt(Keys.themeType) ?? 0;
    if (themeType == 2) {
      return 'follow_system'.tr;
    } else if (themeType == 1) {
      return 'on'.tr;
    } else if (themeType == 0) {
      return 'off'.tr;
    }
    return '';
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
                  'button_confirm'.tr,
                  style: TextStyle(
                    color: Get.isDarkMode ? Colors.white : Colors.black,
                  ),
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
