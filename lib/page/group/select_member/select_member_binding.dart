import 'package:get/get.dart';

import 'select_member_logic.dart';

class SelectMemberBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => SelectMemberLogic()),
      ];
}
