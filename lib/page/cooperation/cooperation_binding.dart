import 'package:get/get.dart';

import 'cooperation_logic.dart';

class CooperationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CooperationLogic());
  }
}
