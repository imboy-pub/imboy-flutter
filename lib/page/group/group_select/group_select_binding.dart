import 'package:get/get.dart';

import 'group_select_logic.dart';

class GroupSelectBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => GroupSelectLogic()),
      ];
}
