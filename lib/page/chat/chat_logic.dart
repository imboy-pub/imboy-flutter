import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/helper/datetime.dart';
import 'package:imboy/helper/websocket.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_sp.dart';

import 'chat_state.dart';

class ChatLogic extends GetxController {
  final state = ChatState();

  final UserRepoSP current = Get.put(UserRepoSP.user);

  late var cuser;

  ChatLogic() {
    cuser = types.User(
      id: current.currentUid,
      firstName: current.currentUser.nickname!,
      imageUrl: current.currentUser.avatar!,
    );
  }

  Future<List<types.Message>?> getMessages(String id) async {
    // final response = await rootBundle.loadString('assets/data/messages.json');
    ConversationModel? obj = await ConversationRepo().find(id);
    debugPrint(">>>>> on getMessages id: $id; obj: ${obj!.toMap()}");
    List<MessageModel> items = await MessageRepo().findByConversation(obj.id);

    List<types.Message> messages = [];
    items.forEach((obj) async {
      // ContactModel? from = await obj.from;
      debugPrint(">>>>> on getMessages obj ${obj.toMap()}");
      if (obj.type == "C2C" && obj.payload!['msg_type'] == "text") {
        messages.insert(
            0,
            types.TextMessage(
              author: types.User(
                id: obj.fromId!,
                // firstName: from == null ? '' : from!.nickname ?? '',
                // imageUrl: from == null ? '' : from!.avatar ?? '',
              ),
              createdAt: obj.serverTs,
              id: obj.id!,
              text: obj.payload!['text'] ?? "",
              status: obj.eStatus,
              // status: types.Status.sent,
            ));
      }
    });
    debugPrint(">>>>> on getMessages ${messages.length};");
    return messages;
  }

  Future<ConversationModel> addMessage(
    String fromId,
    String toId,
    String? avatar,
    String title,
    String type,
    types.Message message,
    bool send,
  ) async {
    String subtitle = '';
    String msgtype = '';
    int createdAt = DateTimeHelper.currentTimeMillis();
    Map<String, dynamic> payload = {};
    if (type == 'C2C' && message is types.TextMessage) {
      msgtype = "text";
      subtitle = message.text;
      payload = {
        "msg_type": msgtype,
        "text": message.text,
      };
    }
    Map<String, dynamic> msg = {
      'id': message.id,
      'type': type,
      'from': fromId,
      'to': toId,
      'payload': payload,
      'created_at': createdAt,
    };

    // 10 发送中 sending;  11 已发送 send; 20 未读 delivered;  21 已读 seen; 41 错误（发送失败） error;
    int status = 10;
    if (send) {
      bool isSend = (WebSocket()).sendMessage(json.encode(msg));
      status = isSend ? 11 : 41;
      // message.status = types.Status.sent;
    }
    ConversationModel cobj = ConversationModel(
      cuid: fromId,
      typeId: toId,
      avatar: avatar!,
      title: title,
      subtitle: subtitle,
      type: type,
      msgtype: msgtype,
      lasttime: createdAt,
      unreadNum: 0,
      isShow: true,
      id: 0,
    );
    cobj = await (ConversationRepo()).save(cobj);
    await (MessageRepo()).insert(MessageModel(
      message.id,
      type: type,
      fromId: fromId,
      toId: toId,
      payload: payload,
      createdAt: createdAt,
      serverTs: 0,
      conversationId: cobj.id,
      status: status,
    ));

    return cobj;
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }
}
