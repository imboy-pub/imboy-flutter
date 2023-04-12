import 'package:get/get.dart';

import 'group_member_detail_logic.dart';

class GroupMemberDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => GroupMemberDetailLogic());
  }
}
