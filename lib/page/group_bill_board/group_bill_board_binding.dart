import 'package:get/get.dart';

import 'group_bill_board_logic.dart';

class GroupBillBoardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => GroupBillBoardLogic());
  }
}
