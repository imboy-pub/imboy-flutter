import 'package:get/get.dart';

import 'select_member_logic.dart';

class SelectMemberBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SelectMemberLogic());
  }
}
