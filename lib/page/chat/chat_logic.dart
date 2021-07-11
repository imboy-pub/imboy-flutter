import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo.dart';

import 'chat_state.dart';

class ChatLogic extends GetxController {
  final state = ChatState();

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  Future<MessageModel> insert(Map<String, dynamic> map) async {
    return await (new MessageRepo()).insert(map);
  }

  Future<void> sendTextMsg(Map msg) async {
    try {
      debugPrint(">>>>> wshb send ${json.encode(msg)}");
      await wshb.send(json.encode(msg));
    } on PlatformException {
      debugPrint("发送消息失败");
    }
  }
}
