import 'package:get/get.dart';
import 'package:imboy/api/login_api.dart';
import 'package:imboy/helper/extension/get_extension.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_view.dart';

import 'login_state.dart';

class LoginLogic extends GetxController {
  final state = LoginState();
  final LoginApi api = Get.put(LoginApi());
  late String _username;
  late String _password;
  bool passwordVisible = false; //设置初始状态

  void visibilityOnOff() {
    if (passwordVisible) {
      passwordVisible = false;
    } else {
      passwordVisible = true;
    }
    update();
  }

  void onUsernameChanged(String username) {
    _username = username.trim();
  }

  void onPasswordChanged(String password) {
    _password = password.trim();
  }

  submit() async {
    if (strEmpty(_username.trim())) {
      Get.snackbar('Hi', '登录账号不能为空');
      return;
    }

    if (strEmpty(_password.trim())) {
      Get.snackbar('Hi', '登录密码不能为空');
      return;
    }

    // Get.loading();
    bool loginSuccess = await api.login(_username.trim(), _password.trim());
    Get.dismiss();
    if (loginSuccess) {
      Get.off(() => BottomNavigationPage());
    }
  }
}
