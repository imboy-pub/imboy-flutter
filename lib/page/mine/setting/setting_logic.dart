import 'package:get/get.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';

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
}
