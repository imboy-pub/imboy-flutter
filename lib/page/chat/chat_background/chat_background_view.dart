import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'chat_background_logic.dart';
import 'chat_background_state.dart';

class ChatBackgroundPage extends StatefulWidget {
  const ChatBackgroundPage({super.key});

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
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: NavAppBar(
          title: 'set_chat_background'.tr,
          automaticallyImplyLeading: true,
        ),
        body: const SizedBox.shrink());
  }

  @override
  void dispose() {
    Get.delete<ChatBackgroundLogic>();
    super.dispose();
  }
}
