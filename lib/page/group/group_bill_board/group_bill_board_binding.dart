import 'package:get/get.dart';

import 'group_bill_board_logic.dart';

class GroupBillBoardBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => GroupBillBoardLogic()),
      ];
}
