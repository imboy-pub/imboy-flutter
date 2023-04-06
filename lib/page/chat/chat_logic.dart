import 'dart:convert';

import 'package:flutter/cupertino.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:flutter/material.dart';
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
  late var currentUser;

  ChatLogic() {
    currentUser = types.User(
      id: UserRepoLocal.to.currentUid,
      firstName: UserRepoLocal.to.current.nickname,
      imageUrl: UserRepoLocal.to.current.avatar,
    );
  }

  Future<List<types.Message>?> getMessages(
    String peerId,
    int page,
    int size,
  ) async {
    // final response = await rootBundle.loadString('assets/data/messages.json');
    ConversationModel? obj = await ConversationRepo().findByPeerId(peerId);
    debugPrint("> on getMessages $peerId obj: ${obj?.toJson().toString()}");
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
          "> on msg check status ${obj.status}, ${obj.status == MessageStatus.sending}");
      if (obj.status == MessageStatus.sending) {
        debugPrint(
            "> on msg check sending ${obj.status}, ${obj.status == MessageStatus.sending}");
        sendWsMsg(obj);
      }
      messages.insert(0, obj.toTypeMessage());
    }
    return messages;
  }

  bool sendWsMsg(MessageModel obj) {
    if (obj.status == MessageStatus.sending) {
      Map<String, dynamic> msg = {
        'ts': DateTimeHelper.currentTimeMillis(),
        'id': obj.id,
        'type': obj.type,
        'from': obj.fromId,
        'to': obj.toId,
        'payload': obj.payload,
        'created_at': obj.createdAt,
      };
      debugPrint("> on msg check sending ${msg.toString()}");
      return WSService.to.sendMessage(json.encode(msg));
    }
    return true;
  }

  MessageModel getMsgFromTMsg(
    String type,
    int conversationId,
    types.Message message,
  ) {
    Map<String, dynamic> payload = {};
    debugPrint("> on addMessage getMsgFromTMsg 2");
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
      payload = message.metadata ?? {};
      payload['msg_type'] = 'custom';
    }
    debugPrint("> on addMessage getMsgFromTMsg 2 ${payload.toString()}");
    MessageModel obj = MessageModel(
      message.id,
      type: type,
      fromId: message.author.id,
      toId: message.remoteId,
      payload: payload,
      createdAt: message.createdAt,
      serverTs: message.updatedAt,
      conversationId: conversationId,
      status: MessageStatus.sending,
    );
    debugPrint("> on addMessage getMsgFromTMsg 3 ${message.status}");
    obj.status = obj.toStatus(message.status ?? types.Status.sending);
    return obj;
  }

  Future<void> addMessage(
    String fromId,
    String toId, // peerId
    String? avatar,
    String title,
    String type, // C2C or GROUP
    types.Message message,
  ) async {
    String subtitle = '';
    String msgType = MessageModel.conversationMsgType(message);
    int createdAt = DateTimeHelper.currentTimeMillis();

    String customType = '';
    if (message is types.CustomMessage) {
      customType = message.metadata?['custom_type'] ?? '';
    }
    if (message is types.TextMessage) {
      subtitle = message.text;
    } else if (customType == "quote") {
      subtitle = message.metadata?['quote_text'] ?? '';
    } else if (customType == 'visit_card') {
      subtitle = message.metadata?['title'] ?? '';
    } else if (customType == 'location') {
      subtitle = message.metadata?['title'] ?? '';
    }

    // message.status = types.Status.sent;
    ConversationModel conversation = ConversationModel(
      peerId: toId,
      avatar: avatar!,
      title: title,
      subtitle: subtitle,
      type: type,
      // C2C or GROUP
      msgType: msgType,
      lastMsgId: message.id,
      lastTime: createdAt,
      lastMsgStatus: 10,
      // astMsgStatus 10 发送中 sending;  11 已发送 send;
      unreadNum: 0,
      isShow: 1,
      id: 0,
    );
    // 保存会话
    conversation = await (ConversationRepo()).save(conversation);
    MessageModel obj = getMsgFromTMsg(type, conversation.id, message);
    debugPrint("> on addMessage before insert MessageRepo");
    await (MessageRepo()).insert(obj);
    debugPrint("> on addMessage after insert MessageRepo");
    eventBus.fire(conversation);
    // send to server
    sendWsMsg(obj);
  }

  Future<bool> removeMessage(String id) async {
    Database db = await Sqlite.instance.database;
    return await db.transaction((txn) async {
      await txn.execute(
        "DELETE FROM ${MessageRepo.tableName} WHERE ${MessageRepo.id}=?",
        [id],
      );
      debugPrint('> on removeMessage : $id ;');
      return true;
    });
  }

  /// 撤回消息
  Future<bool> revokeMessage(types.Message obj) async {
    Map<String, dynamic> msg = {
      'ts': DateTimeHelper.currentTimeMillis(),
      'id': obj.id,
      'type': 'C2C_REVOKE',
      'from': obj.author.id,
      'to': obj.remoteId,
    };

    return WSService.to.sendMessage(json.encode(msg));
  }

  /// 标记为已读
  Future<ConversationModel?> markAsRead(
    int conversationId,
    List<String> msgIds,
  ) async {
    Database db = await Sqlite.instance.database;
    ConversationModel? conversation =
        await ConversationRepo().findById(conversationId);
    if (conversation == null) {
      return null;
    }
    int newUnreadNum = conversation.unreadNum - msgIds.length;
    conversation.unreadNum = newUnreadNum > 0 ? newUnreadNum : 0;
    bool res = await db.transaction((txn) async {
      db.update(
        ConversationRepo.tableName,
        {
          ConversationRepo.unreadNum: conversation.unreadNum,
        },
        where: "${ConversationRepo.id}=?",
        whereArgs: [conversationId],
      );
      for (var id in msgIds) {
        db.update(
          MessageRepo.tableName,
          {
            MessageRepo.status: MessageStatus.seen,
          },
          where: "${MessageRepo.id}=?",
          whereArgs: [id],
        );
      }

      return true;
    });
    if (res) {
      return conversation;
    } else {
      return null;
    }
  }
}
