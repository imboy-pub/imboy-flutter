import 'package:get/get.dart';

import 'group_member_detail_logic.dart';

class GroupMemberDetailBinding extends Binding {
  @override
    List<Bind> dependencies() => [
        Bind.lazyPut(() => GroupMemberDetailLogic()),
      ];
}
