import 'package:get/get.dart';

import 'group_member_logic.dart';

class GroupMemberBinding extends Binding {
  @override
  List<Bind> dependencies() => [
        Bind.lazyPut(() => GroupMemberLogic()),
      ];
}
