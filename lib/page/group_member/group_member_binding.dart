import 'package:get/get.dart';

import 'group_member_logic.dart';

class GroupMemberBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => GroupMemberLogic());
  }
}
