import 'package:get/get.dart';

import 'friend_add_state.dart';

class FriendAddLogic extends GetxController {
  final state = FriendAddState();

  RxString role = "1".obs;

  void setRole(String role) {
    // debugPrint(">>> on FriendAddLogic/setRole1 ${this.role.value} = ${role}");
    this.role.value = role;
    update([this.role]);

    // debugPrint(">>> on FriendAddLogic/setRole2 ${this.role.value} = ${role}");
  }
}
