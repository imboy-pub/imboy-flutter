import 'package:get/get.dart';

import 'group_detail_logic.dart';

class GroupDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => GroupDetailLogic());
  }
}
