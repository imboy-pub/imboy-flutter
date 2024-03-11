import 'package:get/get.dart';

import 'mine_logic.dart';

class MineBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => MineLogic()),
      ];
}
