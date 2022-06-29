import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/sqflite.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:sqflite/sqflite.dart';

import 'chat_state.dart';

class ChatLogic extends GetxController {
  final state = ChatState();

  // ignore: prefer_typing_uninitialized_variables
  late var cuser;

  ChatLogic() {
    cuser = types.User(
      id: UserRepoLocal.to.currentUid,
      firstName: UserRepoLocal.to.currentUser.nickname,
      imageUrl: UserRepoLocal.to.currentUser.avatar,
    );
  }

  Future<List<types.Message>?> getMessages(
    String typeId,
    int page,
    int size,
  ) async {
    // final response = await rootBundle.loadString('assets/data/messages.json');
    ConversationModel? obj = await ConversationRepo().findByTypeId(typeId);
    if (obj == null) {
      return [];
    }
    List<MessageModel> items = await MessageRepo().findByConversation(
      obj.id,
      page,
      size,
    );

    List<types.Message> messages = [];
    // 重发在发送中状态的消息
    for (MessageModel obj in items) {
      debugPrint(
          ">>> on msg status ${obj.status}, ${obj.status == MessageStatus.sending}");
      if (obj.status! == MessageStatus.sending) {
        sendWsMsg(obj);
      }
      messages.insert(0, obj.toTypeMessage());
    }
    return messages;
  }

  bool sendWsMsg(MessageModel obj) {
    if (obj.status == MessageStatus.sending) {
      Map<String, dynamic> msg = {
        'id': obj.id,
        'type': obj.type,
        'from': obj.fromId,
        'to': obj.toId,
        'payload': obj.payload,
        'created_at': obj.createdAt,
      };

      return WSService.to.sendMessage(json.encode(msg));
    }
    return true;
  }

  MessageModel getMsgFromTmsg(
    String type,
    int conversationId,
    types.Message message,
  ) {
    Map<String, dynamic> payload = {};
    if (message is types.TextMessage) {
      payload = {
        "msg_type": "text",
        "text": message.text,
      };
    } else if (message is types.ImageMessage) {
      payload = {
        "msg_type": "image",
        "name": message.name,
        "size": message.size,
        "uri": message.uri,
        "width": message.width,
        "height": message.height,
      };
    } else if (message is types.FileMessage) {
      payload = {
        "msg_type": "file",
        "name": message.name,
        "size": message.size,
        "uri": message.uri,
        "mimeType": message.mimeType,
      };
    } else if (message is types.CustomMessage) {
      payload = message.metadata!;
      payload['msg_type'] = 'custom';
    }
    debugPrint(">>> on getMsgFromTmsg ${message.toJson().toString()}");
    MessageModel obj = MessageModel(
      message.id,
      type: type,
      fromId: message.author.id,
      toId: message.remoteId!,
      payload: payload,
      createdAt: message.createdAt,
      serverTs: message.updatedAt,
      conversationId: conversationId,
      status: MessageStatus.sending,
    );
    obj.status = obj.toStatus(message.status!);
    return obj;
  }

  Future<void> addMessage(
    String fromId,
    String toId,
    String? avatar,
    String title,
    String type, // C2C or GROUP
    types.Message message,
  ) async {
    String subtitle = '';
    String msgtype = MessageModel.ctype(message.type);
    int createdAt = DateTimeHelper.currentTimeMillis();

    // message.status = types.Status.sent;
    ConversationModel cobj = ConversationModel(
      typeId: toId,
      avatar: avatar!,
      title: title,
      subtitle: subtitle,
      type: type, // C2C or GROUP
      msgtype: msgtype,
      lastMsgId: message.id,
      lasttime: createdAt,
      lastMsgStatus: 10, // astMsgStatus 10 发送中 sending;  11 已发送 send;
      unreadNum: 0,
      isShow: 1,
      id: 0,
    );
    // 保存会话
    cobj = await (ConversationRepo()).save(cobj);
    MessageModel obj = getMsgFromTmsg(type, cobj.id, message);
    await (MessageRepo()).insert(obj);

    if (message is types.TextMessage) {
      cobj.subtitle = obj.payload!['text'];
    } else if (message is types.FileMessage) {
      cobj.subtitle = '[文件]';
      cobj.msgtype = 'file';
    } else if (message is types.ImageMessage) {
      cobj.subtitle = '[图片]';
      cobj.msgtype = 'image';
    } else if (message.metadata!['custom_type'] == 'video') {
      cobj.msgtype = 'custom';
      cobj.subtitle = '[视频]';
    } else if (message.metadata!['custom_type'] == 'audio') {
      cobj.msgtype = 'custom';
      cobj.subtitle = '[语音]';
    }
    await (ConversationRepo()).updateById(cobj.id, {
      ConversationRepo.msgtype: cobj.msgtype,
      ConversationRepo.subtitle: cobj.subtitle,
    });
    eventBus.fire(cobj);
    // send to servier
    sendWsMsg(obj);
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

  /// 撤回消息
  Future<bool> revokeMessage(types.Message obj) async {
    Map<String, dynamic> msg = {
      'id': obj.id,
      'type': 'C2C_REVOKE',
      'from': obj.author.id,
      'to': obj.remoteId,
    };

    return WSService.to.sendMessage(json.encode(msg));
  }

  Future<ConversationModel?> markAsRead(
    int conversationId,
    List<String> msgIds,
  ) async {
    Database db = await Sqlite.instance.database;
    ConversationModel? cobj = await ConversationRepo().findById(conversationId);
    if (cobj == null) {
      return null;
    }
    int newUnreadNum = cobj.unreadNum - msgIds.length;
    cobj.unreadNum = newUnreadNum > 0 ? newUnreadNum : 0;
    bool res = await db.transaction((txn) async {
      db.update(
        ConversationRepo.tablename,
        {
          ConversationRepo.unreadNum: cobj.unreadNum,
        },
        where: "id=?",
        whereArgs: [conversationId],
      );
      for (var id in msgIds) {
        db.update(
          MessageRepo.tablename,
          {
            MessageRepo.status: MessageStatus.seen,
          },
          where: "id=?",
          whereArgs: [id],
        );
      }

      return true;
    });
    if (res) {
      return cobj;
    } else {
      return null;
    }
  }
}
