import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

import 'chat_background_logic.dart';
import 'chat_background_state.dart';

class ChatBackgroundPage extends StatefulWidget {
  const ChatBackgroundPage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ChatBackgroundPageState createState() => _ChatBackgroundPageState();
}

class _ChatBackgroundPageState extends State<ChatBackgroundPage> {
  final logic = Get.put(ChatBackgroundLogic());
  final ChatBackgroundState state = Get.find<ChatBackgroundLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.AppBarColor,
        appBar: PageAppBar(
          title: '设置当前聊天背景'.tr,
          // backgroundColor: AppColors.AppBarColor,
        ),
        body: const SizedBox.shrink());
  }

  @override
  void dispose() {
    Get.delete<ChatBackgroundLogic>();
    super.dispose();
  }
}
