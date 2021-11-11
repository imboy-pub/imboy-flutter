import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

class MessageService extends GetxController {
  // 系统消息提醒计时器 暂时无用
  var sysMsgRemindCounter = 0.obs;

  RxMap<String, int> conversationRemind = RxMap<String, int>({});

  // 会话列表
  RxMap<String, ConversationModel> conversations =
      RxMap<String, ConversationModel>();

  // 设置会话提醒
  setConversationRemind(String key, int val) {
    conversationRemind[key] = val;
    // 有并发的话，可能会有脏数据，待测试 TODO leeyi 2021-11-13 09:38:58
    (ConversationRepo()).update({"type_id": key, "unread_num": val});
  }

  //
  increaseConversationRemind(String key, int val) {
    if (conversationRemind.containsKey(key)) {
      val = conversationRemind[key]! + val;
    }
    setConversationRemind(key, val);
  }

  decreaseConversationRemind(String key, int val) {
    if (conversationRemind.containsKey(key)) {
      val = conversationRemind[key]! - val;
    }
    setConversationRemind(key, val);
  }

  // 聊天消息提醒技术器
  int get chatMsgRemindCounter {
    int c = 0;
    conversationRemind.forEach((key, value) {
      c += value;
    });
    return c;
  }

  StreamSubscription<dynamic>? _msgStreamSubs;

  @override
  void onInit() {
    // TODO: implement onInit
    debugPrint(">>>>> on Messageservice onInit: ${conversations.toString()}");

    if (_msgStreamSubs == null) {
      // Register listeners for all events:
      _msgStreamSubs = eventBus.on<Map>().listen((e) async {
        debugPrint(">>>>> on MessageService onInit: " + e.toString());
        var message = await reciveMessage(e);
        if (message != null) {
          eventBus.fire(message);
        }
      });
    }

    super.onInit();
  }

  /// Called before [onDelete] method. [onClose] might be used to
  /// dispose resources used by the controller. Like closing events,
  /// or streams before the controller is destroyed.
  /// Or dispose objects that can potentially create some memory leaks,
  /// like TextEditingControllers, AnimationControllers.
  /// Might be useful as well to persist some data on disk.
  @override
  void onClose() {
    if (_msgStreamSubs != null) {
      _msgStreamSubs!.cancel();
      _msgStreamSubs = null;
    }
    // 该方法貌似没有生效 TODO leey 2021-11-13 09:36:28
    debugPrint(">>>>> on ConversationRemind MessageService onClose");
    conversationRemind.forEach((typeId, unreadNum) {
      (ConversationRepo()).update({"type_id": typeId, "unread_num": unreadNum});
    });
    super.onClose();
  }

  Future<types.Message?> reciveMessage(data) async {
    String dtype = data['type'] ?? 'error';
    dtype = dtype.toUpperCase();
    var msgtype = data['payload']['msg_type'] ?? '';
    debugPrint(">>>>> on reciveMessage " + data.toString());
    /**{
        "id": "8f22f09c-1a28-4dce-9ca8-659fd650535d",
        "type": "C2C",
        "from": "kybqdp",
        "to": "18aw3p",
        "payload": {
        "msg_type": "text",
        "text": "asdf"
        },
        "created_at": 1635945957968,
        "server_ts": 1635945957968
        }
     */
    types.Message? message = null;
    String subtitle = '';

    ContactModel? ct = await ContactRepo().find(data['from']);
    String avatar = ct == null ? '' : ct.avatar!;
    String title = ct == null ? '' : ct.nickname;

    if (dtype == 'C2C' && msgtype == 'text') {
      String text = data['payload']['text'] ?? '';
      message = types.TextMessage(
        author: types.User(
          id: data['from'],
          // firstName: "",
          // imageUrl: "",
        ),
        createdAt: data['server_ts'],
        id: data['id'] ?? "",
        remoteId: data['to'],
        text: text,
      );
      subtitle = text;
      // addMessage(data['from'], data['from'], avatar, title, type, message, send)
    }
    ConversationModel cobj = ConversationModel(
      cuid: data['to'],
      typeId: data['from'],
      avatar: avatar,
      title: title,
      subtitle: subtitle,
      type: data['type'],
      msgtype: msgtype,
      lasttime: data['created_at'],
      unreadNum: 0,
      isShow: true,
      id: 0,
    );
    cobj = await (ConversationRepo()).save(cobj);
    // status 10 未发送  11 已发送  20 未读  21 已读
    int status = 20;
    MessageModel msg = MessageModel(
      data['id'],
      // cuid: data['to'],
      type: data['type'],
      fromId: data['from'],
      toId: data['to'],
      payload: data['payload'],
      createdAt: data['created_at'],
      serverTs: data['server_ts'],
      conversationId: cobj.id,
      status: status,
    );
    await (MessageRepo()).save(msg);
    increaseConversationRemind(data['from'], 1);
    conversations[data['from']] = cobj;
    // conversations
    update([conversations]);
    return message;
  }
}
