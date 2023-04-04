import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/image_gallery/image_gallery_logic.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/contact/contact_logic.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/contact/friend/new_friend_logic.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class MessageService extends GetxService {
  static MessageService get to => Get.find();
  final ContactLogic contactLogic = Get.find();
  final NewFriendLogic newFriendLogic = Get.find();
  final ConversationLogic conversationLogic = Get.find();

  @override
  void onInit() {
    super.onInit();
    eventBus.on<Map>().listen((Map data) async {
      String type = data['type'] ?? 'error';
      type = type.toUpperCase();
      debugPrint(
          "> rtc msg listen: $type , $p2pCallScreenOn, ${DateTime.now()} $data");
      if (data.containsKey('ts')) {
        int now = DateTimeHelper.currentTimeMillis();
        debugPrint("> rtc msg now: $now elapsed: ${now - data['ts']}");
      }
      if (type.startsWith('WEBRTC_')) {
        // 确认消息
        String did = await DeviceExt.did;
        debugPrint("> rtc msg CLIENT_ACK,WEBRTC,${data['id']},$did");
        WSService.to.sendMessage("CLIENT_ACK,WEBRTC,${data['id']},$did");

        if (p2pCallScreenOn == false && type == 'WEBRTC_OFFER') {
          String peerId = data['from'];
          ContactModel? obj = await ContactRepo().findByUid(peerId);
          if (obj != null) {
            incomingCallScreen(
              UserModel.fromJson({
                "uid": obj.uid!,
                "nickname": obj.title,
                "avatar": obj.avatar,
                "sign": obj.sign,
              }),
              data['payload'],
            );
          }
        } else {
          WebRTCSignalingModel msgModel = WebRTCSignalingModel(
            type: data['type'],
            from: data['from'],
            to: data['to'],
            payload: data['payload'],
          );
          if (msgModel.webrtctype == 'busy' || msgModel.webrtctype == 'bye') {
            if (Get.isDialogOpen != null && Get.isDialogOpen == true) {
              Get.close(0);
            }
            p2pCallScreenOn = false;
          }
          eventBus.fire(msgModel);
        }
      } else {
        switch (type) {
          case 'C2C':
            await receiveC2CMessage(data);
            break;
          case 'C2C_SERVER_ACK': // C2C 服务端消息确认
            await receiveC2CServerAckMessage(data);
            break;
          case 'C2C_REVOKE': // 对端撤回消息
            await receiveC2CRevokeMessage(data);
            break;
          case 'C2C_REVOKE_ACK': // 对端撤回消息ACK
            await receiveC2CRevokeAckMessage(type, data);
            break;
          case 'SERVER_ACK_GROUP': // 服务端消息确认 GROUP TODO
            break;
          case 'ERROR': //
            await switchError(data);
            break;
          case 'S2C':
            await switchS2C(data);
            break;
        }
      }
    });
  }

  Future<void> switchError(Map data) async {
    var code = data['code'] ?? '';
    // * Msg2.code = 1 无需弹窗错误，可以记录日志后直接忽略错误 Msg2.payload 可能为空，不需要处理
    // * Msg2.code = 2 带title弹窗，Msg2.payload 不能为空 必须包含title content字段
    // * Msg2.code = 3 无title弹窗，Msg2.payload 不能为空 必须包含 content字段
    switch (code.toString()) {
      case '705': // token无效、刷新token
        // TODO
        break;
      case '706': // 需要重新登录
        Get.off(() => PassportPage());
        break;
    }
  }

  Future<void> switchS2C(Map data) async {
    var payload = data['payload'] ?? {};
    if (payload is String) {
      payload = json.decode(payload);
    }
    String msgType = payload['msg_type'] ?? '';
    switch (msgType.toString().toLowerCase()) {
      case "apply_friend": // 添加好友申请
        newFriendLogic.receivedAddFriend(data);
        break;
      case "apply_friend_confirm": // 添加好友申请确认
        // 接受消息人（to）新增联系人
        contactLogic.receivedConfirFriend(payload);
        // 修正好友申请状态
        newFriendLogic.receivedConfirFriend(true, data);
        break;
      case "isnotfriend":
        // String msgId = payload['content'] ?? '';
        // TODO
        break;
      case "logged_another_device": // 在其他设备登录了
        String currentId = await DeviceExt.did;
        String did = payload['did'] ?? '';
        if (did != currentId) {
          int serverTs = data['server_ts'] ?? 0;
          WSService.to.closeSocket();
          UserRepoLocal.to.logout();
          Get.off(() => PassportPage(), arguments: {
            "msgType": "logged_another_device",
            "server_ts": serverTs,
            "dname": payload['dname'] ?? '', // 设备名称
          });
        }

        break;
      case "online": // 好友上线提醒
        // TODO
        break;
      case "offline": // 好友下线提醒
        // TODO
        break;
      case "hide": // 好友hide提醒
        // TODO
        // String uid = data['from'] ?? '';
        break;
    }
    // 确认消息
    String did = await DeviceExt.did;
    debugPrint("> rtc msg CLIENT_ACK,S2C,${data['id']},$did");
    WSService.to.sendMessage("CLIENT_ACK,S2C,${data['id']},$did");
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
  Future<void> receiveC2CMessage(data) async {
    var msgType = data['payload']['msg_type'] ?? '';
    var subtitle = data['payload']['text'] ?? '';
    debugPrint("> rtc msg c2c receiveMessage $data");
    int now = DateTimeHelper.currentTimeMillis();
    debugPrint("> rtc msg c2c now: $now elapsed: ${now - data['created_at']}");

    ContactModel? ct = await ContactRepo().findByUid(data['from']);
    String avatar = ct!.avatar;
    String title = ct.nickname;

    if (msgType == 'custom') {
      msgType = data['payload']['custom_type'] ?? '';
      subtitle = '';
    }
    if (msgType == 'quote') {
      subtitle = data['payload']['quote_text'] ?? '';
    } else if (msgType == 'location') {
      subtitle = data['payload']['title'] ?? '';
    }
    ConversationModel conversationObj = ConversationModel(
      peerId: data['from'],
      avatar: avatar,
      title: title,
      subtitle: subtitle,
      type: data['type'],
      msgType: msgType,
      lastMsgId: data['id'],
      lastTime: data['created_at'],
      unreadNum: 1,
      isShow: 1,
      id: 0,
    );
    conversationObj = await (ConversationRepo()).save(conversationObj);

    MessageModel msg = MessageModel(
      data['id'],
      type: data['type'],
      fromId: data['from'],
      toId: data['to'],
      payload: data['payload'],
      createdAt: data['created_at'],
      serverTs: data['server_ts'],
      conversationId: conversationObj.id,
      status: MessageStatus.delivered,
    );
    int? exited = await (MessageRepo()).save(msg);
    // 确认消息
    String did = await DeviceExt.did;
    debugPrint("> rtc msg CLIENT_ACK,C2C,${data['id']},$did");
    WSService.to.sendMessage("CLIENT_ACK,C2C,${data['id']},$did");
    if (exited != null && exited > 0) {
      return;
    }

    eventBus.fire(conversationObj);
    // 收到一个消息，步增会话消息 1
    conversationLogic.increaseConversationRemind(data['from'], 1);
    types.Message tMsg = msg.toTypeMessage();

    if (tMsg is types.ImageMessage) {
      try {
        ImageGalleryLogic galleryLogic = Get.find();
        galleryLogic.pushToGallery(tMsg.id, tMsg.uri);
      } catch (e) {
        //
      }
    }
    eventBus.fire(tMsg);
  }

  /// 收到C2C服务端确认消息
  Future<void> receiveC2CServerAckMessage(Map data) async {
    debugPrint("> rtc msg S_RECEIVED: msg:$data");
    MessageRepo repo = MessageRepo();
    String id = data['id'];
    int res = await repo.update({
      'id': id,
      'status': MessageStatus.send,
    });
    MessageModel? msg = await repo.find(id);
    debugPrint("> rtc msg S_RECEIVED:$res");
    // 更新会话状态
    List<ConversationModel> items =
        await ConversationLogic().updateLastMsgStatus(
      id,
      MessageStatus.send,
    );
    if (items.isNotEmpty) {
      for (var cobj in items) {
        // 更新会话
        conversationLogic.replace(cobj);
        eventBus.fire(cobj);
      }
    }
    if (res > 0 && msg != null) {
      eventBus.fire([msg.toTypeMessage()]);
    }
  }

  /// 收到C2C撤回消息
  Future<void> receiveC2CRevokeMessage(data) async {
    ContactModel? contact = await ContactRepo().findByUid(data['from']);
    MessageRepo repo = MessageRepo();
    String id = data['id'];
    await repo.update({
      'id': id,
      'status': MessageStatus.send,
      'payload': json.encode({
        "msg_type": "custom",
        "custom_type": "revoked",
        "peer_name": contact!.nickname
      }),
    });
    // msg = null 的时候数据已经被删除了
    MessageModel? msg = await repo.find(id);
    if (msg != null) {
      eventBus.fire([msg.toTypeMessage()]);
      changeConversation(msg, 'peer_revoked');
    }

    // 通知服务器已撤销
    Map<String, dynamic> msg2 = {
      'id': id,
      'type': 'C2C_REVOKE_ACK',
      'from': data["to"],
      'to': data["from"],
    };
    WSService.to.sendMessage(json.encode(msg2));
  }

  /// 撤回消息修正相应会话记录
  Future<void> changeConversation(MessageModel msg, String msgType) async {
    String peerId = '';
    if (msg.fromId == UserRepoLocal.to.currentUid) {
      peerId = msg.toId ?? '';
    } else if (msg.toId == UserRepoLocal.to.currentUid) {
      peerId = msg.fromId ?? '';
    }
    if (peerId.isEmpty) {
      return;
    }
    ConversationRepo repo = ConversationRepo();
    ConversationModel? conversation = await repo.findByPeerId(peerId);
    if (conversation == null) {
      return;
    }
    if (conversation.lastMsgId != msg.id) {
      return;
    }
    conversation.subtitle = '';
    conversation.msgType =
        msgType; //peerId == UserRepoLocal.to.currentUid ? 'peer_revoked' : 'my_revoked';
    int res2 = await repo.updateByPeerId(peerId, {
      'msgType': conversation.msgType,
      'subtitle': '',
    });
    if (res2 > 0) {
      eventBus.fire(conversation);
    }
  }

  /// 收到C2C撤回ACK消息
  Future<void> receiveC2CRevokeAckMessage(dtype, data) async {
    MessageRepo repo = MessageRepo();
    MessageModel? msg = await repo.find(data['id']);
    if (msg == null) {
      return;
    }
    msg.payload = {
      "msg_type": "custom",
      "custom_type": "revoked",
      'text': msg.payload!['text'],
    };
    await repo.update({
      'id': data['id'],
      'type': dtype,
      'status': MessageStatus.send,
      'payload': json.encode(msg.payload),
    });

    eventBus.fire([msg.toTypeMessage()]);
    // 确认消息
    String did = await DeviceExt.did;
    WSService.to.sendMessage("CLIENT_ACK,C2C,${data['id']},$did");
    changeConversation(msg, 'my_revoked');
  }
}
