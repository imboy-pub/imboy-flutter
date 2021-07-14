import 'package:get/get.dart';
import 'package:imboy/store/repository/user_repository.dart';

import 'setting_state.dart';

class SettingLogic extends GetxController {
  final state = SettingState();

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void action(name) {
    Get.snackbar('action', name.toString());

    if (name.toString() == 'logout') {
      logout();
    }
  }

  @override
  void logout() {
    UserRepository.logout();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }
}
