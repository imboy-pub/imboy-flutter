import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/login/login_view.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class MessageService extends GetxService {
  static MessageService get to => Get.find();

  final RxMap<String, int> conversationRemind = RxMap<String, int>({});

  // 会话列表
  final RxMap<String, ConversationModel> conversations =
      RxMap<String, ConversationModel>();

  // 设置会话提醒
  setConversationRemind(String key, int val) {
    val = val > 0 ? val : 0;
    conversationRemind[key] = val;
    (ConversationRepo()).update({
      ConversationRepo.typeId: key,
      ConversationRepo.unreadNum: val,
      ConversationRepo.isShow: 1,
    });
  }

  // 步增会话提醒
  _increaseConversationRemind(String key, int val) {
    if (!conversationRemind.containsKey(key) ||
        conversationRemind[key] == null ||
        conversationRemind[key]! < 0) {
      conversationRemind[key] = 0;
    }

    conversationRemind[key] = conversationRemind[key]!.toInt() + val;
    debugPrint(
        ">>> on _increaseConversationRemind key ${key}, val: ${val}, ${conversationRemind[key]!}");
    setConversationRemind(key, conversationRemind[key]!);
  }

  // 步减会话提醒
  decreaseConversationRemind(String key, int val) {
    if (conversationRemind.containsKey(key)) {
      val = conversationRemind[key]! - val;
    }
    setConversationRemind(key, val);
  }

  // 聊天消息提醒计数器
  int get chatMsgRemindCounter {
    int c = 0;
    conversationRemind.forEach((key, value) {
      c += value;
    });
    return c;
  }

  @override
  void onInit() {
    super.onInit();
    eventBus.on<Map>().listen((data) async {
      debugPrint(">>> on MessageService onInit: " + data.toString());
      int code = data['code'] ?? 99999;
      String dtype = data['type'] ?? 'error';
      dtype = dtype.toUpperCase();
      switch (dtype) {
        case 'C2C':
          await reciveC2CMessage(data);
          break;
        case 'C2C_SERVER_ACK': // C2C 服务端消息确认
          await reciveC2CServerAckMessage(data);
          break;
        case 'C2C_REVOKE': // 对端撤回消息
          await reciveC2CRevokeMessage(data);
          break;
        case 'C2C_REVOKE_ACK': // 对端撤回消息ACK
          await reciveC2CRevokeAckMessage(dtype, data);
          break;
        case 'SERVER_ACK_GROUP': // 服务端消息确认 GROUP TODO
          break;
        case 'S2C':
          switch (code) {
            // case 705: // token无效、刷新token 这里不处理，不发送消息
            case 706: // 需要重新登录
              {
                Get.off(new LoginPage());
              }
              break;
            case 786: // 在其他地方上线
              {
                // TODO
                WSService.to.closeSocket();
                UserRepoLocal.to.logout();
                Get.off(new LoginPage());
              }
              break;
            case 1019: // 好友上线提现
              // TODO
              break;
          }
          break;
      }
    });
  }

  /// Called before [onDelete] method. [onClose] might be used to
  /// dispose resources used by the controller. Like closing events,
  /// or streams before the controller is destroyed.
  /// Or dispose objects that can potentially create some memory leaks,
  /// like TextEditingControllers, AnimationControllers.
  /// Might be useful as well to persist some data on disk.
  @override
  void onClose() {
    super.onClose();
  }

  /// 收到C2C消息
  Future<void> reciveC2CMessage(data) async {
    var msgtype = data['payload']['msg_type'] ?? '';
    var text = data['payload']['text'] ?? '';
    debugPrint(">>> on reciveMessage " + data.toString());

    String subtitle = '';

    ContactModel? ct = await ContactRepo().findByUid(data['from']);
    String avatar = ct == null ? '' : ct.avatar!;
    String title = ct == null ? '' : ct.nickname;

    subtitle = text;

    ConversationModel cobj = ConversationModel(
      typeId: data['from'],
      avatar: avatar,
      title: title,
      subtitle: subtitle,
      type: data['type'],
      msgtype: msgtype,
      lastMsgId: data['id'],
      lasttime: data['created_at'],
      unreadNum: 1,
      isShow: 1,
      id: 0,
    );
    cobj = await (ConversationRepo()).save(cobj);

    MessageModel msg = MessageModel(
      data['id'],
      type: data['type'],
      fromId: data['from'],
      toId: data['to'],
      payload: data['payload'],
      createdAt: data['created_at'],
      serverTs: data['server_ts'],
      conversationId: cobj.id,
      status: MessageStatus.delivered,
    );
    await (MessageRepo()).save(msg);

    eventBus.fire(cobj);

    // 步增会话消息
    _increaseConversationRemind(data['from'], 1);

    eventBus.fire(msg.toTypeMessage());
    // 确实消息
    WSService.to.sendMessage(json.encode({
      'id': data['id'],
      'type': 'C2C_CLIENT_ACK',
      'remark': 'recived',
    }));
  }

  /// 收到C2C服务端确认消息
  Future<void> reciveC2CServerAckMessage(data) async {
    MessageRepo repo = MessageRepo();
    String id = data['id'];
    int res = await repo.update({
      'id': id,
      'status': MessageStatus.send,
    });
    MessageModel? msg = await repo.find(id);
    debugPrint(">>>>> on MessageService S_RECEIVED:$res; msg:" +
        msg!.toJson().toString());
    if (res > 0 && msg != null) {
      eventBus.fire([msg.toTypeMessage()]);
    }
  }

  /// 收到C2C撤回消息
  Future<void> reciveC2CRevokeMessage(data) async {
    ContactModel? c = await ContactRepo().findByUid(data['from']);
    // debugPrint(">> on reciveC2CRevokeMessage ${c.toJson().toString()}");
    MessageRepo repo = MessageRepo();
    String id = data['id'];
    int res = await repo.update({
      'id': id,
      'status': MessageStatus.send,
      'payload': json.encode({
        "msg_type": "custom",
        "custom_type": "revoked",
        "from_name": c!.nickname
      }),
    });
    MessageModel? msg = await repo.find(id);
    if (res > 0 && msg != null) {
      // 通知服务器已撤销
      Map<String, dynamic> msg2 = {
        'id': id,
        'type': 'C2C_REVOKE_ACK',
        'from': data["to"],
        'to': data["from"],
      };
      WSService.to.sendMessage(json.encode(msg2));

      eventBus.fire([msg.toTypeMessage()]);
      changeConversation(msg);
    }
  }

  /**
   * 撤回消息修正相应会话记录
   */
  Future<void> changeConversation(MessageModel msg) async {
    ConversationRepo repo2 = ConversationRepo();
    ConversationModel? cobj = await repo2.findById(msg.conversationId!);
    debugPrint(">>> on changeConversation : ${cobj!.toJson().toString()}");

    if (cobj != null && cobj.lastMsgId == msg.id) {
      Map<String, dynamic> data2 = cobj.toJson();
      bool isCUid = UserRepoLocal.to.currentUid == msg.fromId ? true : false;
      String subtitle = isCUid ? '你撤回了一条消息' : '"${cobj.title}"撤回了一条消息';
      int res2 = await repo2.updateById(cobj.id, {
        'subtitle': subtitle,
      });
      if (res2 > 0) {
        cobj.subtitle = subtitle;
        eventBus.fire(cobj);
      }
    }
  }

  /// 收到C2C撤回ACK消息
  Future<void> reciveC2CRevokeAckMessage(dtype, data) async {
    MessageRepo repo = MessageRepo();
    String id = data['id'];
    MessageModel? msg = await repo.find(id);
    msg!.payload = {
      "msg_type": "custom",
      "custom_type": "revoked",
      'text': msg.payload!['text'],
    };
    int res = await repo.update({
      'id': id,
      'type': dtype,
      'status': MessageStatus.send,
      'payload': json.encode(msg.payload),
    });
    // debugPrint(">>> on MessageService REVOKE_C2C ack:$res; msg:" +
    //     msg.toJson().toString());
    if (res > 0 && msg != null) {
      eventBus.fire([msg.toTypeMessage()]);
      // 确认消息
      WSService.to.sendMessage(json.encode({
        'id': id,
        'type': 'C2C_CLIENT_ACK',
        'remark': 'revoked',
      }));
      changeConversation(msg);
    }
  }
}
