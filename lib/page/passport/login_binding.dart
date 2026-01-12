import 'package:get/get.dart';

import 'passport_logic.dart';

class LoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PassportLogic());
  }
}
