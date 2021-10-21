import 'package:get/get.dart';

import 'welcome_logic.dart';

class WelcomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => WelcomeLogic());
  }
}
