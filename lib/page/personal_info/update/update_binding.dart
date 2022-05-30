import 'package:get/get.dart';

import 'update_logic.dart';

class UpdateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => UpdateLogic());
  }
}
