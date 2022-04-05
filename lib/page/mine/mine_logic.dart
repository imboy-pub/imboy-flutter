import 'package:get/get.dart';
import 'package:imboy/page/mine/setting/setting_view.dart';
import 'package:imboy/page/passport/passport_view.dart';

import 'mine_state.dart';

class MineLogic extends GetxController {
  final state = MineState();
  void action(name) {
    switch (name) {
      case '设置':
        // logout(context);
        Get.to(
          () => SettingPage(),
        );
        break;
      case '表情':
        Get.to(() => PassportPage());
        break;
      default:
        Get.snackbar('tips', '在开发中...');
        // Get.to(
        //   () => LanguagePage(),
        // );
        break;
    }
  }
}
