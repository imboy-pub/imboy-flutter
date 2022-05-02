import 'package:get/get.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'setting_state.dart';

class SettingLogic extends GetxController {
  final state = SettingState();

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  Future<void> action(name) async {
    if (name.toString() == 'logout') {
      bool result = await UserRepoLocal.to.logout();
      if (result) {
        Get.off(() => PassportPage());
      }
    } else {
      Get.snackbar('action', name.toString());
    }
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }
}
