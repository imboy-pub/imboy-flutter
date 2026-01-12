import 'package:get/get.dart';

import 'passport_logic.dart';

class ForgotPasswordBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PassportLogic());
  }
}
