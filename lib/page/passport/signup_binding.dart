import 'package:get/get.dart';

import 'passport_logic.dart';

class SignupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PassportLogic());
  }
}
