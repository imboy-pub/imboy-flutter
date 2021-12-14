import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/helper/datetime.dart';
import 'package:imboy/helper/sqflite.dart';
import 'package:imboy/helper/websocket.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_sp.dart';
import 'package:sqflite/sqflite.dart';

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
              createdAt: obj.createdAt,
              updatedAt: obj.serverTs == null ? 0 : obj.serverTs,
              id: obj.id!,
              text: obj.payload!['text'] ?? "",
              status: obj.eStatus,
              remoteId: obj.toId,
              // status: types.Status.sent,
            ));
      }
    });
    debugPrint(">>>>> on getMessages ${messages.length};");
    return messages;
  }

  bool sendWsMsg(MessageModel obj) {
    debugPrint(">>>>> on chat sendWsMsg ${obj.toMap().toString()}");
    if (obj.status == 10) {
      Map<String, dynamic> msg = {
        'id': obj.id,
        'type': obj.type,
        'from': obj.fromId,
        'to': obj.toId,
        'payload': obj.payload,
        'created_at': obj.createdAt,
      };

      return (WebSocket()).sendMessage(json.encode(msg));
    }
    return true;
  }

  MessageModel getMsgFromTmsg(
    String type,
    int conversationId,
    types.Message message,
  ) {
    Map<String, dynamic> payload = {};
    if (type == 'C2C' && message is types.TextMessage) {
      payload = {
        "msg_type": "text",
        "text": message.text,
      };
    }
    debugPrint(">>>>> on getMsgFromTmsg ${message.toJson().toString()}");
    int status = 10;
    MessageModel obj = MessageModel(
      message.id,
      type: type,
      fromId: message.author.id,
      toId: message.remoteId!,
      payload: payload,
      createdAt: message.createdAt,
      serverTs: message.updatedAt,
      conversationId: conversationId,
      status: status,
    );
    obj.status = obj.toStatus(message.status!);
    return obj;
  }

  Future<ConversationModel> addMessage(
    String fromId,
    String toId,
    String? avatar,
    String title,
    String type,
    types.Message message,
  ) async {
    String subtitle = '';
    String msgtype = '';
    int createdAt = DateTimeHelper.currentTimeMillis();

    // message.status = types.Status.sent;
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
    // 保存会话
    cobj = await (ConversationRepo()).save(cobj);
    MessageModel obj = getMsgFromTmsg(type, cobj.id, message);
    await (MessageRepo()).insert(obj);
    cobj.msgtype = obj.payload!["msg_type"];
    cobj.subtitle = obj.payload!["text"];
    await (ConversationRepo()).save(cobj);
    debugPrint(">>>>> on chat addMessage ${message.toString()}");
    sendWsMsg(obj);
    return cobj;
  }

  Future<bool> removeMessage(String id) async {
    Database db = await Sqlite.instance.database;
    return await db.transaction((txn) async {
      await txn.execute(
        "DELETE FROM ${MessageRepo.tablename} WHERE ${MessageRepo.id}=?",
        [id],
      );

      debugPrint('on >>>>> removeMessage :' + id + ';');
      return true;
    });
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }
}
