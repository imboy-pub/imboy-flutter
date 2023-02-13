import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'friend_circle_logic.dart';
import 'friend_circle_state.dart';

class FriendCirclePage extends StatefulWidget {
  const FriendCirclePage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _FriendCirclePageState createState() => _FriendCirclePageState();
}

class _FriendCirclePageState extends State<FriendCirclePage> {
  final logic = Get.put(FriendCircleLogic());
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
