import 'dart:convert';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/image_gallery/image_gallery_logic.dart';
import 'package:popup_menu/popup_menu.dart' as popupmenu;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:sqflite/sqflite.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/mine/user_collect/user_collect_logic.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'chat_state.dart';

class ChatLogic extends GetxController {
  final state = ChatState();

  ChatLogic();

  void initState() {
    state.messages = [];
    state.scrollController = AutoScrollController();
  }

  Future<List<types.Message>?> getMessages(
    String peerId,
    int page,
    int size,
  ) async {
    // final response = await rootBundle.loadString('assets/data/messages.json');
    ConversationModel? obj = await ConversationRepo().findByPeerId(peerId);
    // debugPrint("> on getMessages $peerId obj: ${obj?.toJson().toString()}");
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
      debugPrint("> on getMessages $peerId obj: ${obj.toJson().toString()}");
      if (obj.status == MessageStatus.sending) {
        await sendWsMsg(obj);
      }
      messages.insert(0, obj.toTypeMessage());
    }
    return messages;
  }

  Future<bool> sendWsMsg(MessageModel obj) async {
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
      // debugPrint("> on msg check sending ${msg.toString()}");
      return await WebSocketService.to.sendMessage(json.encode(msg));
    }
    return true;
  }

  MessageModel getMsgFromTMsg(
    String type,
    int conversationId,
    types.Message message,
  ) {
    Map<String, dynamic> payload = {};
    // debugPrint("> on addMessage getMsgFromTMsg 2");
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
        "md5": message.metadata?['md5'],
      };
    } else if (message is types.FileMessage) {
      payload = {
        "msg_type": "file",
        "name": message.name,
        "size": message.size,
        "uri": message.uri,
        "mimeType": message.mimeType,
        "md5": message.metadata?['md5'],
      };
    } else if (message is types.CustomMessage) {
      payload = message.metadata ?? {};
      payload['msg_type'] = 'custom';
    }

    // 处理系统提示信息
    String sysPrompt = message.metadata?['sys_prompt'] ?? '';
    if (strNoEmpty(sysPrompt)) {
      payload['sys_prompt'] = sysPrompt;
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
    types.Message message, {
    bool sendToServer = true,
  }) async {
    String subtitle = MessageModel.conversationSubtitle(message);
    String msgType = MessageModel.conversationMsgType(message);
    int createdAt = DateTimeHelper.currentTimeMillis();
    if (toId == UserRepoLocal.to.currentUid) {
      throw Exception('not send message to myself');
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
      // lastMsgStatus 10 发送中 sending;  11 已发送 send;
      lastMsgStatus: sendToServer ? 10 : 11,
      unreadNum: 0,
      isShow: 1,
      id: 0,
    );
    // 保存会话
    conversation = await (ConversationRepo()).save(conversation);
    MessageModel obj = getMsgFromTMsg(type, conversation.id, message);
    // debugPrint("> on addMessage before insert MessageRepo");
    await (MessageRepo()).insert(obj);
    // debugPrint("> on addMessage after insert MessageRepo");
    eventBus.fire(conversation);
    // send to server
    if (sendToServer) {
      sendWsMsg(obj);
    }
    if (message is types.ImageMessage) {
      Get.find<ImageGalleryLogic>().pushToLast(
        message.id,
        message.uri,
      );
    }
  }

  Future<bool> removeMessage(int conversationId, types.Message msg) async {
    if (conversationId == 0) {
      ConversationModel? cm = await ConversationRepo().findByPeerId(
        msg.remoteId ?? '',
      );
      conversationId = cm == null ? 0 : cm.id;
    }
    MessageModel? lastMsg;
    if (conversationId > 0) {
      List<MessageModel> items = await MessageRepo().findByConversation(
        conversationId,
        2,
        1,
      );
      lastMsg = items.isEmpty ? null : items[0];
    }
    debugPrint(
        "removeMessage ${msg.id}; $conversationId, lastMsg: ${lastMsg?.toJson()} ;");
    await MessageRepo().delete(msg.id);
    ConversationRepo repo = ConversationRepo();
    if (lastMsg == null) {
      await repo.updateById(conversationId, {
        ConversationRepo.lastMsgId: '',
        ConversationRepo.lastMsgStatus: 0,
        ConversationRepo.msgType: 'empty',
        ConversationRepo.lastTime: 0,
        ConversationRepo.subtitle: '',
      });
    } else {
      types.Message msg2 = lastMsg.toTypeMessage();
      await repo.updateById(conversationId, {
        ConversationRepo.lastMsgId: lastMsg.id,
        ConversationRepo.lastMsgStatus: lastMsg.status,
        ConversationRepo.msgType: MessageModel.conversationMsgType(msg2),
        ConversationRepo.subtitle: MessageModel.conversationSubtitle(msg2),
      });
    }
    ConversationModel? conversation = await repo.findById(conversationId);
    if (conversation != null) {
      eventBus.fire(conversation);
    }
    if (msg is types.ImageMessage) {
      Get.find<ImageGalleryLogic>().remoteFromGallery(msg.id);
    }
    return true;
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

    return WebSocketService.to.sendMessage(json.encode(msg));
  }

  /// 标记为已读
  Future<ConversationModel?> markAsRead(
    int conversationId,
    List<String> msgIds,
  ) async {
    Database db = await SqliteService.to.db;
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

  /// 处理系统提示信息
  /// sysPrompt in metadata is sys_prompt
  String parseSysPrompt(String sysPrompt) {
    if (sysPrompt == 'in_denylist') {
      sysPrompt = '消息已发出，但被对方拒收了。'.tr;
    } else if (sysPrompt == 'not_a_friend') {
      sysPrompt = '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。'.tr;
    }
    return sysPrompt;
  }

  void setSysPrompt(String msgId, String sysPrompt) async {
    var repo = MessageRepo();
    MessageModel? msg = await repo.find(msgId);
    Map<String, dynamic> payload = msg!.payload ?? {};
    payload['msg_type'] = payload['msg_type'].toString();
    payload['sys_prompt'] = sysPrompt;
    await repo.update({
      'id': msgId,
      MessageRepo.status: MessageStatus.error,
      MessageRepo.payload: payload,
    });
    msg.status = MessageStatus.error;
    msg.payload = payload;
    // 更新会话里面的消息列表的特定消息状态
    eventBus.fire([msg.toTypeMessage()]);

    // 更新会话状态
    Get.find<ConversationLogic>().updateConversationByMsgId(
      msgId,
      {
        ConversationRepo.payload: {'sys_prompt': sysPrompt},
        ConversationRepo.lastMsgStatus: MessageStatus.send,
      },
    );
  }

  List<popupmenu.MenuItemProvider> getPopupMenuItems(types.Message message) {
    List<popupmenu.MenuItemProvider> items = [
      // MenuItem(
      //   title: '多选'.tr,
      //   userInfo: {"id":"multiselect", "msg":message},
      //   textAlign: TextAlign.center,
      //   textStyle: TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
      //   image: Icon(
      //     Icons.add_road,
      //     size: 16,
      //     color: Color(0xffc5c5c5),
      //   ),
      // ),
    ];
    bool canCopy = false;
    String customType = message.metadata?['custom_type'] ?? '';
    if (message.type == types.MessageType.text) {
      canCopy = true;
    } else if (customType == 'quote') {
      canCopy = true;
    }
    if (canCopy) {
      items.add(popupmenu.MenuItem(
        title: '复制',
        userInfo: {"id": "copy", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          color: Color(0xffc5c5c5),
          fontSize: 10.0,
        ),
        image: const Icon(
          Icons.copy,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }

    bool canCollect =
        UserCollectLogic.getCollectKind(message) > 0 ? true : false;
    if (canCollect) {
      items.add(popupmenu.MenuItem(
        title: '收藏'.tr,
        userInfo: {"id": "collect", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          color: Color(0xffc5c5c5),
          fontSize: 10.0,
        ),
        image: const Icon(
          Icons.collections_bookmark,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }

    //
    bool isRevoked = (message is types.CustomMessage) && customType == 'revoked'
        ? true
        : false;
    if (customType == 'webrtc_audio' || customType == 'webrtc_video') {
      isRevoked = true;
    }
    if (!isRevoked) {
      items.add(popupmenu.MenuItem(
        title: '转发'.tr,
        userInfo: {"id": "transpond", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          fontSize: 10.0,
          color: Color(0xffc5c5c5),
        ),
        image: const Icon(
          Icons.moving,
          color: Color(0xffc5c5c5),
        ),
      ));
      items.add(popupmenu.MenuItem(
        title: '引用'.tr,
        userInfo: {"id": "quote", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
        image: const Icon(
          Icons.format_quote,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }
    if (message.author.id == UserRepoLocal.to.currentUid &&
        isRevoked == false) {
      items.add(
        popupmenu.MenuItem(
          title: '撤回',
          userInfo: {"id": "revoke", "msg": message},
          textAlign: TextAlign.center,
          textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
          image: const Icon(
            Icons.layers_clear_rounded,
            size: 16,
            color: Color(0xffc5c5c5),
          ),
        ),
      );
    }
    items.add(popupmenu.MenuItem(
      title: '删除',
      userInfo: {"id": "delete", "msg": message},
      textAlign: TextAlign.center,
      textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
      image: const Icon(
        Icons.remove_circle_outline_rounded,
        size: 16,
        color: Color(0xffc5c5c5),
      ),
    ));
    return items;
  }
}
