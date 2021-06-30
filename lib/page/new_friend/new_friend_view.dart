import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'new_friend_logic.dart';
import 'new_friend_state.dart';

class NewFriendPage extends StatefulWidget {
  @override
  _NewFriendPageState createState() => _NewFriendPageState();
}

class _NewFriendPageState extends State<NewFriendPage> {
  final logic = Get.find<NewFriendLogic>();
  final NewFriendState state = Get.find<NewFriendLogic>().state;

  @override
    Widget build(BuildContext context) {
      return Container();
    }

  @override
  void dispose() {
    Get.delete<NewFriendLogic>();
    super.dispose();
  }
}