import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

import 'friend_add_logic.dart';
import 'friend_add_state.dart';

class FriendAddPage extends StatelessWidget {
  final FriendAddLogic logic = Get.put(FriendAddLogic());
  final FriendAddState state = Get.find<FriendAddLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '申请添加朋友'.tr,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: Colors.white,
          child: Column(children: [
            Text('发送添加朋友申请'.tr),
            Text('设置备注'.tr),
            Text('标签'.tr),
            Text('设置朋友圈'.tr),
          ]),
        ),
      ),
    );
  }
}
