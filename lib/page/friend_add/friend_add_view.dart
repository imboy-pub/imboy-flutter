import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'friend_add_logic.dart';
import 'friend_add_state.dart';

class FriendAddPage extends StatelessWidget {
  final FriendAddLogic logic = Get.put(FriendAddLogic());
  final FriendAddState state = Get.find<FriendAddLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
