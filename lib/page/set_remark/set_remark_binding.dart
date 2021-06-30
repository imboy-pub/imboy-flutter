import 'package:get/get.dart';

import 'set_remark_logic.dart';

class SetRemarkBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SetRemarkLogic());
  }
}
