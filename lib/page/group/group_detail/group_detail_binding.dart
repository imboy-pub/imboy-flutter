import 'package:get/get.dart';

import 'group_detail_logic.dart';

class GroupDetailBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => GroupDetailLogic()),
      ];
}
