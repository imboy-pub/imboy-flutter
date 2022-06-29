import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'group_launch_logic.dart';
import 'group_launch_state.dart';

class GroupLaunchPage extends StatelessWidget {
  final GroupLaunchLogic logic = Get.put(GroupLaunchLogic());
  final GroupLaunchState state = Get.find<GroupLaunchLogic>().state;

  GroupLaunchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
