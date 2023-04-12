import 'package:get/get.dart';

import 'group_remark_logic.dart';

class GroupRemarkBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => GroupRemarkLogic());
  }
}
