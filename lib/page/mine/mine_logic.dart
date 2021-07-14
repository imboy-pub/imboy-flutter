import 'package:get/get.dart';
import 'package:imboy/page/language/language_view.dart';
import 'package:imboy/page/mine/setting/setting_view.dart';

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
      default:
        Get.to(
          () => LanguagePage(),
        );
        break;
    }
  }
}
