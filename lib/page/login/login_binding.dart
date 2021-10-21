import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import 'login_logic.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    debugPrint(">>>> on user LoginBinding/dependencies/0");
    Get.lazyPut<LoginLogic>(
      () => LoginLogic(),
    );
  }
}
