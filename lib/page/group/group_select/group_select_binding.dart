import 'package:get/get.dart';

import 'group_select_logic.dart';

class GroupSelectBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => GroupSelectLogic());
  }
}
