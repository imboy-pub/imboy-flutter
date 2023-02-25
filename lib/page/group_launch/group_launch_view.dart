import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

import 'group_launch_logic.dart';
import 'group_launch_state.dart';

class GroupLaunchPage extends StatelessWidget {
  final GroupLaunchLogic logic = Get.put(GroupLaunchLogic());
  final GroupLaunchState state = Get.find<GroupLaunchLogic>().state;

  GroupLaunchPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(title: '选择联系人'.tr),
      body: SingleChildScrollView(
        child: n.Column(const []),
      ),
    );
  }
}
