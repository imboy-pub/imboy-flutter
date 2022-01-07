import 'package:get/get.dart';
import 'package:imboy/page/login/login_view.dart';
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
    Get.snackbar('action', name.toString());
    print(">>>>> on action " +
        name.toString() +
        "; res: " +
        (name.toString() == 'logout').toString());
    if (name.toString() == 'logout') {
      bool result = await UserRepoLocal.user.logout();
      if (result) {
        Get.off(() => LoginPage());
      }
    }
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }
}
