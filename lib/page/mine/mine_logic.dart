import 'package:get/get.dart';
import 'package:imboy/page/mine/setting/setting_view.dart';

class MineLogic extends GetxController {
  void action(name) {
    switch (name) {
      case '设置':
        // logout(context);
        Get.to(() => const SettingPage());
        break;
      case '表情':
        Get.snackbar('tips', '在开发中...');
        // Get.to(() => PassportPage());
        break;
      default:
        Get.snackbar('tips', '在开发中...');
        // Get.to(() => LanguagePage());
        break;
    }
  }
}
