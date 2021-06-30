import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/api/login_api.dart';
import 'package:imboy/helper/dio.dart';
import 'package:imboy/store/repository/login_respository.dart';

import 'login_logic.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    debugPrint(">>>> LoginBinding/dependencies/0");
    Get.lazyPut(() => DioUtil());
    Get.lazyPut(() => LoginApi());
    Get.lazyPut(() => LoginRepository());
    Get.lazyPut<LoginLogic>(
      () => LoginLogic(),
    );
  }
}
