import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/image_gallery/image_gallery_logic.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/contact/new_friend/new_friend_logic.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/provider/user_provider.dart';
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
        WebSocketService.to.sendMessage("CLIENT_ACK,WEBRTC,${data['id']},$did");

        if (p2pCallScreenOn == false && type == 'WEBRTC_OFFER') {
          String peerId = data['from'];
          ContactModel? obj = await ContactRepo().findByUid(peerId);
          if (obj != null) {
            incomingCallScreen(
              UserModel.fromJson({
                "uid": obj.peerId,
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
          // case 'C2G':
          //  TODO leeyi 2023-04-28
          //   await receiveC2GMessage(data);
          //   break;
          // case 'C2G_SERVER_ACK': // C2G 服务端消息确认
          //  TODO leeyi 2023-04-28
          //   await receiveC2GServerAckMessage(data);
          //   break;
          // case 'C2G_REVOKE': // 对端撤回消息
          //  TODO leeyi 2023-04-28
          //   await receiveC2GRevokeMessage(data);
          //   break;
          // case 'C2G_REVOKE_ACK': // 对端撤回消息ACK
          //  TODO leeyi 2023-04-28
          //   await receiveC2GRevokeAckMessage(type, data);
          //   break;
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
    // * Msg2.code = 2 带title弹窗，Msg2.payload 不能为空 必须包含 title content 字段
    // * Msg2.code = 3 无title弹窗，Msg2.payload 不能为空 必须包含 content 字段
    switch (code.toString()) {
      // case '2':
      //   String title = data['payload']['title'] ?? '';
      //   String content = data['payload']['content'] ?? '';
      //   break;
      // case '3':
      //   String content = data['payload']['content'] ?? '';
      //   break;
      case '705': // token无效、刷新token
        // TODO
        break;
      case '706': // 需要重新登录
        WebSocketService.to.closeSocket(true);
        Get.offAll(() => PassportPage());
        break;
    }
  }

  Future<void> switchS2C(Map data) async {
    debugPrint("switchS2C ${data.toString()}");
    var payload = data['payload'] ?? {};
    if (payload is String) {
      payload = json.decode(payload);
    }
    String msgId = data['id'] ?? '';
    String msgType = payload['msg_type'] ?? '';
    String currentDID = await DeviceExt.did;
    bool autoAck = true;
    switch (msgType.toString().toLowerCase()) {
      case 'apply_friend': // 添加朋友申请
        newFriendLogic.receivedAddFriend(data);
        break;
      case 'apply_friend_confirm': // 添加朋友申请确认
        // 接受消息人（to）新增联系人
        /*
             {
                "id": "afc_jp24wa_pjyv83",
                "type": "S2C",
                "from": "pjyv83",
                "to": "jp24wa",
                "payload": {
                    "from": {
                        "source": "people_nearby",
                        "msg": "我是 leeyi109",
                        "remark": "leeyi10000",
                        "avatar": "http://a.imboy.pub/avatar/jp24wa.jpg?s=dev&a=2d098a62371bef21&v=175730",
                        "nickname": "leeyi109",
                        "role": "all",
                        "donotlookhim": false,
                        "donotlethimlook": false
                    },
                    "to": {
                        "remark": "leeyi109",
                        "avatar": "http://a.imboy.pub/avatar/0_pjyv83.jpg?s=dev&a=6273f2e63037bbaa&v=660682",
                        "nickname": "leeyi10000",
                        "role": "all",
                        "donotlookhim": false,
                        "donotlethimlook": false
                    },
                    "msg_type": "apply_friend_confirm"
                },
                "server_ts": "1681980840528"
            }
        */

        Map<String, dynamic> json = {
          // From 的个人信息
          'id': data['from'],
          'account': payload['from']['account'],
          'nickname': payload['from']['nickname'],
          'avatar': payload['from']['avatar'],
          'sign': payload['from']['sign'],
          'gender': payload['from']['gender'],
          'remark': payload['from']['remark'] ?? '',
          ContactRepo.tag: payload['from'][ContactRepo.tag] ?? '',
          'region': payload['from']['region'],
          'source': payload['from']['source'],
        };
        contactLogic.receivedConfirmFriend(json);
        // 修正好友申请状态
        newFriendLogic.receivedConfirmFriend(true, data);
        break;
      case 'in_denylist':
        // 对方将我加入黑名单后： 消息已发出，但被对方拒收了。
        // String msgId = payload['content'] ?? '';
        Get.find<ChatLogic>().setSysPrompt(msgId, 'in_denylist');
        break;
      case 'not_a_friend':
        // String msgId = payload['content'] ?? '';
        Get.find<ChatLogic>().setSysPrompt(msgId, 'not_a_friend');
        break;
      case 'logged_another_device': // 在其他设备登录了
        String did = payload['did'] ?? '';
        if (did != currentDID) {
          int serverTs = data['server_ts'] ?? 0;
          WebSocketService.to.closeSocket();
          UserRepoLocal.to.logout();
          Get.off(() => PassportPage(), arguments: {
            "msg_type": "logged_another_device",
            "server_ts": serverTs,
            "dname": payload['dname'] ?? '', // 设备名称
          });
        }
        break;
      case 'please_refresh_token': // 服务端通知客户端刷新token
        String tk = await (UserProvider()).refreshAccessTokenApi(
            UserRepoLocal.to.refreshToken,
            checkNewToken: false);
        autoAck = false;
        if (tk.isNotEmpty) {
          debugPrint("> rtc msg CLIENT_ACK,S2C,$msgId,$currentDID,$autoAck");
          WebSocketService.to.sendMessage("CLIENT_ACK,S2C,$msgId,$currentDID");
        }
        break;
      case 'online': // 好友上线提醒
        // TODO
        break;
      case 'offline': // 好友下线提醒
        // TODO
        break;
      case 'hide': // 好友hide提醒
        // TODO
        // String uid = data['from'] ?? '';
        break;
    }
    // 确认消息
    if (autoAck) {
      debugPrint("> rtc msg CLIENT_ACK,S2C,$msgId,$currentDID");
      WebSocketService.to.sendMessage("CLIENT_ACK,S2C,$msgId,$currentDID");
    }
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
      lastTime: DateTimeHelper.currentTimeMillis(),
      unreadNum: 1,
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
      status: MessageStatus.delivered, // 未读 已投递
    );
    int? exited = await (MessageRepo()).save(msg);
    // 确认消息
    String did = await DeviceExt.did;
    debugPrint("> rtc msg CLIENT_ACK,C2C,${data['id']},$did");
    WebSocketService.to.sendMessage("CLIENT_ACK,C2C,${data['id']},$did");
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
    // debugPrint("> rtc msg S_RECEIVED:$res");
    MessageModel? msg = await repo.find(id);
    if (res > 0 && msg != null) {
      eventBus.fire([msg.toTypeMessage()]);
    }
    // 更新会话状态
    conversationLogic.updateConversationByMsgId(
      id,
      {ConversationRepo.lastMsgStatus: MessageStatus.send},
    );
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
    WebSocketService.to.sendMessage(json.encode(msg2));
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
    //msgType = peerId == UserRepoLocal.to.currentUid ? 'peer_revoked' : 'my_revoked';
    conversation.msgType = msgType;
    conversation.subtitle = '';
    int res2 = await repo.updateByPeerId(peerId, {
      ConversationRepo.msgType: conversation.msgType,
      ConversationRepo.subtitle: '',
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
    WebSocketService.to.sendMessage("CLIENT_ACK,C2C,${data['id']},$did");
    changeConversation(msg, 'my_revoked');
  }
}
