import 'package:get/get.dart';

import 'bottom_navigation_logic.dart';

class BottomNavigationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => BottomNavigationLogic());
  }
}
