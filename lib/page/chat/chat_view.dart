import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/store/model/message_model.dart';

import 'chat_logic.dart';
import 'chat_state.dart';

class ChatPage extends StatefulWidget {
  final String id; // 用户ID
  final String type; // [C2C | GROUP]
  final String title;

  ChatPage({
    @required this.id,
    this.type = 'C2C',
    this.title,
  });

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  final logic = Get.find<ChatLogic>();
  final ChatState state = Get.find<ChatLogic>().state;

  List<MessageModel> chatData = [];
  // StreamSubscription<dynamic> _msgStreamSubs;
  bool _isVoice = false;
  bool _isMore = false;
  double keyboardHeight = 270.0;
  bool _emojiState = false;
  String newGroupName;

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  void dispose() {
    Get.delete<ChatLogic>();
    super.dispose();
  }
}
