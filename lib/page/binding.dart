import 'package:get/get.dart';

import 'logic.dart';

class MineBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MineLogic());
  }
}
