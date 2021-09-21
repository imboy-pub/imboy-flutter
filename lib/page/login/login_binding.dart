import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/api/login_api.dart';

import 'login_logic.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    debugPrint(">>>> LoginBinding/dependencies/0");
    Get.lazyPut(() => LoginApi());
    Get.lazyPut<LoginLogic>(
      () => LoginLogic(),
    );
  }
}
