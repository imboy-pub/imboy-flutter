import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:imboy/helper/constant.dart';
import 'package:imboy/helper/extension/get_extension.dart';
import 'package:imboy/page/home/home_view.dart';
import 'package:imboy/store/model/login_model.dart';
import 'package:imboy/store/repository/local_login_repository.dart';
import 'package:imboy/store/repository/login_respository.dart';

import 'login_state.dart';

class LoginLogic extends GetxController {
  final state = LoginState();
  final LoginRepository repository = Get.put(LoginRepository());
  String _username;
  String _password;
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
    if (_username == null || _username.trim.toString().isEmpty) {
      Get.snackbar('Hi', '登录账号不能为空');
      return;
    }

    if (_password == null || _password.trim.toString().isEmpty) {
      Get.snackbar('Hi', '登录密码不能为空');
      return;
    }
    Get.loading();
    try {
      LoginModel bean = await repository.login(_username, _password);

      final box = GetStorage();
      debugPrint(">>>> bean.token {$bean.token}");
      box.write(Keys.tokenKey, bean.token);
      // Get.dismiss();
      // TODO 2021-07-04 08:00:24
      LocalLoginRepository.saveLogin(bean);
      // Get.back();
      Get.to(HomePage());
    } catch (e) {
      Get.dismiss();
      Get.snackbar('Error', e.toString() ?? '登录失败');
    }
  }
}
