import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:imboy/api/dialog_api.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/datetime.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo.dart';
import 'package:imboy/store/repository/user_repository.dart';

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

  Future getChatMsgData() async {
    List<MessageModel> listChat = await getConversationsListData();
    if (!listNoEmpty(listChat)) return;

    state.chatData.clear();
    // chatData..addAll(listChat.reversed);
    state.chatData..addAll(listChat);
    update();
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

  Future<void> handleSubmittedData(
      String msgType, String touid, String text) async {
    // String fromid = await SharedUtil.instance.getString(Keys.uid);
    String? fromid = UserRepository.currentUser().uid;

    // _textController.clear();

    Map<String, dynamic> payload = {
      "msg_type": 10,
      "content": text,
      "send_ts": DateTimeHelper.currentTimeMillis(),
    };
    Map<String, dynamic> msg = {
      'type': msgType,
      'from': fromid,
      'to': touid,
      'payload': payload
    };

    await sendTextMsg(msg);
    state.chatData.insert(0, await insert(msg));
    update();
  }
}
