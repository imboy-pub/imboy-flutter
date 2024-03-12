import 'dart:convert';

import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery_logic.dart';
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
import 'package:popup_menu/popup_menu.dart' as popupmenu;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:sqflite/sqflite.dart';

import 'chat_state.dart';

class ChatLogic extends GetxController {
  final state = ChatState();

  ChatLogic();

  void initState() {
    state.messages = [];
    state.scrollController = AutoScrollController();
  }

  Future<List<types.Message>?> pageMessages(
    int conversationId,
    // int maxAutoId,
    int size,
  ) async {
    // final response = await rootBundle.loadString('assets/data/messages.json');
    ConversationModel? obj = await ConversationRepo().findById(conversationId);
    debugPrint(
        "> on pageMessages nextAutoId ${state.nextAutoId}, cid $conversationId, obj ${obj?.toJson().toString()}");
    if (obj == null) {
      return [];
    }
    String tb = obj.type.toUpperCase() == 'C2G'
        ? MessageRepo.c2gTable
        : MessageRepo.c2cTable;
    MessageRepo repo = MessageRepo(tableName: tb);
    List<MessageModel> items = await repo.pageForConversation(
      obj.id,
      state.nextAutoId,
      size,
    );
    if (items.isEmpty) {
      return [];
    }
    List<types.Message> messages = [];
    state.nextAutoId = items.first.autoId;
    // 重发在发送中状态的消息
    for (MessageModel obj in items) {
      debugPrint(
          "> on getMessages $conversationId obj: ${obj.toJson().toString()}");
      if (obj.status == IMBoyMessageStatus.sending) {
        await sendWsMsg(obj);
      }
      messages.insert(0, obj.toTypeMessage());
    }
    return messages;
  }

  Future<bool> sendWsMsg(MessageModel obj) async {
    if (obj.status == IMBoyMessageStatus.sending) {
      Map<String, dynamic> msg = {
        'ts': DateTimeHelper.utc(),
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
    // debugPrint("> on addMessage getMsgFromTMsg 2 ${payload.toString()}");
    iPrint("_handleSendPressed 2 ${message.createdAt}");
    MessageModel obj = MessageModel(
      autoId: 0,
      message.id,
      type: type,
      fromId: message.author.id,
      toId: message.remoteId,
      payload: payload,
      createdAt:
          message.createdAt! - DateTime.now().timeZoneOffset.inMilliseconds,
      isAuthor: message.author.id == UserRepoLocal.to.currentUid ? 1 : 0,
      conversationId: conversationId,
      status: IMBoyMessageStatus.sending,
    );
    // debugPrint("> on addMessage getMsgFromTMsg 3 ${message.status}");
    obj.status = obj.toStatus(message.status ?? types.Status.sending);
    return obj;
  }

  Future<void> addMessage(
    String fromId,
    String toId, // peerId
    String? avatar,
    String title,
    String type, // 等价于 msg type: C2C C2G S2C 等等，根据type显示item
    types.Message message, {
    bool sendToServer = true,
  }) async {
    String subtitle = MessageModel.conversationSubtitle(message);
    String msgType = MessageModel.conversationMsgType(message);
    int createdAt = DateTimeHelper.utc();
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
      // 等价于 msg type: C2C C2G S2C 等等，根据type显示item
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
    String tb = conversation.type == 'C2G'
        ? MessageRepo.c2gTable
        : MessageRepo.c2cTable;
    await (MessageRepo(tableName: tb)).insert(obj);
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

  Future<bool> removeMessage(
    int conversationId,
    types.Message msg,
  ) async {
    ConversationRepo repo = ConversationRepo();
    ConversationModel? cm;
    MessageModel? lastMsg;
    cm = await repo.findById(conversationId);
    String tb = cm?.type == 'C2G' ? MessageRepo.c2gTable : MessageRepo.c2cTable;
    if (conversationId > 0) {
      MessageRepo mRepo = MessageRepo(tableName: tb);
      // 获取lastMsg，以更新会话lastMsg信息
      List<MessageModel> items = await mRepo.findByConversation(
        conversationId,
        2,
        1,
      );
      lastMsg = items.isEmpty ? null : items[0];
      debugPrint(
          "removeMessage ${msg.id}; $conversationId, lastMsg: ${lastMsg?.toJson()} ;");
      await mRepo.delete(msg.id);
    }
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
    cm = await repo.findById(conversationId);
    if (cm != null) {
      eventBus.fire(cm);
    }
    if (msg is types.ImageMessage) {
      Get.find<ImageGalleryLogic>().remoteFromGallery(msg.id);
    }
    return true;
  }

  /// 撤回消息
  Future<bool> revokeMessage(String type, types.Message obj) async {
    Map<String, dynamic> msg = {
      'ts': DateTimeHelper.utc(),
      'id': obj.id,
      'type': type == 'C2G' ? 'C2G_REVOKE' : 'C2C_REVOKE',
      'from': obj.author.id,
      'to': obj.remoteId,
    };

    return WebSocketService.to.sendMessage(json.encode(msg));
  }

  /// 标记为已读
  Future<bool> markAsRead(
    String type,
    String peerId,
    List<String> msgIds,
  ) async {
    Database db = await SqliteService.to.db;
    ConversationModel? c = await ConversationRepo().findByPeerId(type, peerId);
    if (c == null) {
      return false;
    }
    String tableName =
        c.type == 'C2G' ? MessageRepo.c2gTable : MessageRepo.c2cTable;
    int newUnreadNum = c.unreadNum - msgIds.length;
    c.unreadNum = newUnreadNum > 0 ? newUnreadNum : 0;
    bool res = await db.transaction((txn) async {
      db.update(
        ConversationRepo.tableName,
        {
          ConversationRepo.unreadNum: c.unreadNum,
        },
        where: "${ConversationRepo.id}=?",
        whereArgs: [c.id],
      );
      for (var id in msgIds) {
        db.update(
          tableName,
          {
            MessageRepo.status: IMBoyMessageStatus.seen,
          },
          where: "${MessageRepo.id}=?",
          whereArgs: [id],
        );
      }
      return true;
    });
    if (res) {
      ConversationLogic conversationLogic = Get.find<ConversationLogic>();
      conversationLogic.decreaseConversationRemind(
        c.id,
        msgIds.length,
      );
      conversationLogic.replace(c);
      return true;
    } else {
      return false;
    }
  }

  /// 处理系统提示信息
  /// sysPrompt in metadata is sys_prompt
  String parseSysPrompt(String sysPrompt) {
    if (sysPrompt == 'in_denylist') {
      // 消息已发出，但被对方拒收了。
      sysPrompt = 'send_msg_rejected'.tr;
    } else if (sysPrompt == 'not_a_friend') {
      // '对方开启了好友验证，你还不是他（她）好友。请先发送好友验证请求，对方验证通过后，才能聊天。'
      sysPrompt = 'send_msg_not_friend_tips'.tr;
    }
    return sysPrompt;
  }

  void setSysPrompt(String tableName, String msgId, String sysPrompt) async {
    var repo = MessageRepo(tableName: tableName);
    MessageModel? msg = await repo.find(msgId);
    Map<String, dynamic> payload = msg!.payload ?? {};
    payload['msg_type'] = payload['msg_type'].toString();
    payload['sys_prompt'] = sysPrompt;
    await repo.update({
      'id': msgId,
      MessageRepo.status: IMBoyMessageStatus.error,
      MessageRepo.payload: payload,
    });
    msg.status = IMBoyMessageStatus.error;
    msg.payload = payload;
    // 更新会话里面的消息列表的特定消息状态
    eventBus.fire([msg.toTypeMessage()]);

    // 更新会话状态
    Get.find<ConversationLogic>().updateConversationByMsgId(
      msgId,
      {
        ConversationRepo.payload: {'sys_prompt': sysPrompt},
        ConversationRepo.lastMsgStatus: IMBoyMessageStatus.send,
      },
    );
  }

  List<popupmenu.MenuItemProvider> getPopupMenuItems(types.Message message) {
    List<popupmenu.MenuItemProvider> items = [
      // MenuItem(
      //   title: 'multi_select'.tr,
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
        title: 'button_copy'.tr,
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
        title: 'favorites'.tr,
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
        title: 'forward'.tr,
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
        title: 'quote'.tr,
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
          title: 'revoke'.tr,
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
      title: 'button_delete'.tr,
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
