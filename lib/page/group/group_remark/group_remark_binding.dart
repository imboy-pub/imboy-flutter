import 'package:get/get.dart';

import 'group_remark_logic.dart';

class GroupRemarkBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => GroupRemarkLogic()),
      ];
}
