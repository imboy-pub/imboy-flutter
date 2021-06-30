import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'friend_circle_logic.dart';
import 'friend_circle_state.dart';

class FriendCirclePage extends StatefulWidget {
  @override
  _FriendCirclePageState createState() => _FriendCirclePageState();
}

class _FriendCirclePageState extends State<FriendCirclePage> {
  final logic = Get.find<FriendCircleLogic>();
  final FriendCircleState state = Get.find<FriendCircleLogic>().state;

  @override
    Widget build(BuildContext context) {
      return Container();
    }

  @override
  void dispose() {
    Get.delete<FriendCircleLogic>();
    super.dispose();
  }
}