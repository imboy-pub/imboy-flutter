import 'dart:async';
import 'dart:convert';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:xid/xid.dart';

import 'package:imboy/page/group/group_detail/group_detail_logic.dart';
import 'package:imboy/store/model/group_model.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/passport/passport_view.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'message_s2c.dart';

class MessageService extends GetxService {
  static MessageService get to => Get.find();
  final ConversationLogic conversationLogic = Get.find();
  List<String> webrtcMsgIdLi = [];
  bool addMessageLock = false;

  late StreamSubscription ssMsg;

  @override
  void onInit() {
    super.onInit();
    ssMsg = eventBus.on<Map>().listen((Map data) async {
      // 等价于 msg type: C2C C2G S2C 等等，根据type显示item
      String type = data['type'] ?? 'error';
      type = type.toUpperCase();
      iPrint(
          "rtc_msg listen: $type , $p2pCallScreenOn, ${DateTime.now()} $data");
      if (data.containsKey('ts')) {
        int now = DateTimeHelper.utc();
        iPrint("> rtc msg now: $now elapsed: ${now - data['ts']}");
      }
      if (type.startsWith('WEBRTC_')) {
        // 确认消息
        iPrint("rtc_msg CLIENT_ACK,WEBRTC,${data['id']},$deviceId");
        MessageService.to.sendAckMsg('WEBRTC', data['id']);

        String msgId = '';
        if (type == 'WEBRTC_OFFER' ||
            type == 'WEBRTC_BUSY' ||
            type == 'WEBRTC_BYE') {
          msgId = Xid().toString();
          webrtcMsgIdLi.add(msgId);
        }
        if (p2pCallScreenOn == false && type == 'WEBRTC_OFFER') {
          String peerId = data['from'];
          ContactModel? obj = await ContactRepo().findByUid(peerId);
          iPrint("rtc_msg obj ${obj?.toJson().toString()}");
          if (obj != null) {
            await incomingCallScreen(
              msgId,
              ContactModel.fromMap({
                "id": obj.peerId,
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
            for (var id in webrtcMsgIdLi) {
              changeLocalMsgState(id, 4);
            }
            if (Get.isDialogOpen ?? false) {
              Get.closeAllDialogs();
            }
            gTimer?.cancel();
            gTimer = null;
            p2pCallScreenOn = false;
          }
          eventBus.fire(msgModel);
        }
      } else {
        data['type'] = type;
        switch (type) {
          case 'C2C':
            await receiveMessage(data);
            break;
          case 'C2C_SERVER_ACK': // C2C 服务端消息确认
            await receiveServerAckMessage(data);
            break;
          case 'C2C_REVOKE': // 对端撤回消息
            await receiveRevokeMessage(data);
            break;
          case 'C2C_REVOKE_ACK': // 对端撤回消息ACK
            await receiveRevokeAckMessage(type, data);
            break;

          //
          case 'C2G':
            await receiveMessage(data);
            break;
          case 'C2G_SERVER_ACK': // C2G 服务端消息确认
            await receiveServerAckMessage(data);
            break;
          case 'C2G_REVOKE': // 对端撤回消息
            await receiveRevokeMessage(data);
            break;
          case 'C2G_REVOKE_ACK': // 对端撤回消息ACK
            await receiveRevokeAckMessage(type, data);
            break;

          //
          case 'C2S':
            await receiveMessage(data);
            break;
          case 'C2S_SERVER_ACK': // C2S 服务端消息确认
            await receiveServerAckMessage(data);
            break;

          case 'SERVER_ACK_GROUP': // 服务端消息确认 GROUP TODO
            break;
          case 'S2C':
            await MessageS2CService.switchS2C(data);
            break;
          case 'ERROR': //
            await switchError(data);
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
      case '706': // 需要重新登录
        UserRepoLocal.to.quitLogin();
        Get.offAll(() => PassportPage());
        break;
    }
  }

  /// type is ['C2C' | 'S2C' | 'C2G' | 'C2S | 'WEBRTC']
  void sendAckMsg(String type, String msgId) {
    WebSocketService.to.sendMessage("CLIENT_ACK,$type,$msgId,$deviceId");
  }

  /// Called before [onDelete] method. [onClose] might be used to
  /// dispose resources used by the controller. Like closing events,
  /// or streams before the controller is destroyed.
  /// Or dispose objects that can potentially create some memory leaks,
  /// like TextEditingControllers, AnimationControllers.
  /// Might be useful as well to persist some data on disk.
  @override
  void onClose() {
    ssMsg.cancel();
    super.onClose();
  }

  /// 收到消息  C2C | C2G | C2S
  Future<void> receiveMessage(data) async {
    var msgType = data['payload']['msg_type'] ?? '';
    var subtitle = data['payload']['text'] ?? '';
    iPrint("> rtc msg receiveMessage $data");
    int now = DateTimeHelper.utc();
    iPrint("> rtc msg now: $now elapsed: ${data['created_at'] - now}");

    String peerId = '';
    String avatar = '';
    String title = '';
    if (data['type'] == 'C2G') {
      peerId = data['to'];
      GroupModel? g = await GroupDetailLogic().detail(gid: peerId);
      avatar = g?.avatar ?? '';
      title = g?.title ?? '';
    } else {
      ContactModel? ct = await ContactRepo().findByUid(data['from']);
      peerId = data['from'];
      avatar = ct!.avatar;
      title = ct.title;
    }
    if (msgType == 'custom') {
      msgType = data['payload']['custom_type'] ?? '';
      subtitle = '';
    }
    if (msgType == 'quote') {
      subtitle = data['payload']['quote_text'] ?? '';
    } else if (msgType == 'location') {
      subtitle = data['payload']['title'] ?? '';
    }

    ConversationModel conversation = ConversationModel(
      peerId: peerId,
      avatar: avatar,
      title: title,
      subtitle: subtitle,
      // 等价于 msg type: C2C C2G S2C 等等，根据type显示item
      type: data['type'],
      msgType: msgType,
      lastMsgId: data['id'],
      lastTime: data['created_at'] ?? DateTimeHelper.utc(),
      unreadNum: 1,
      id: 0,
    );
    conversation = await (ConversationRepo()).save(conversation);
    MessageModel msg = MessageModel(
      data['id'],
      autoId: 0,
      type: data['type'],
      fromId: data['from'],
      toId: data['to'],
      payload: data['payload'],
      createdAt: data['created_at'],
      isAuthor: data['from'] == UserRepoLocal.to.currentUid ? 1 : 0,
      topicId: data['topic_id'] ?? 0,
      conversationUk3: conversation.uk3,
      status: IMBoyMessageStatus.delivered, // 未读 已投递
    );
    String tb = MessageRepo.getTableName(data['type']);
    MessageRepo repo = MessageRepo(tableName: tb);
    int? exited = await repo.save(msg);
    // 确认消息
    iPrint(
        "380> rtc msg CLIENT_ACK,${data['type']},${data['id']},$deviceId, exited $exited, ${DateTime.now()}");
    // data['type'] C2C | C2G | C2S
    MessageService.to.sendAckMsg(data['type'], data['id']);
    if (exited != null && exited > 0) {
      return;
    }

    // 收到一个消息，步增会话消息 1
    await conversationLogic.increaseConversationRemind(conversation, 1);

    eventBus.fire(conversation);
    types.Message tMsg = await msg.toTypeMessage();
    iPrint("chat_view/listen eventBus.fire ${msg.id}; ${DateTime.now()}");
    eventBus.fire(tMsg);
  }

  /// 收到服务端确认消息 C2C_SERVER_ACK C2G_SERVER_ACK
  Future<void> receiveServerAckMessage(Map data) async {
    iPrint("> rtc msg S_RECEIVED: data:$data");
    String tb = MessageRepo.getTableName(data['type']);
    MessageModel? msg = await changeStatus(
      tb,
      data['id'],
      IMBoyMessageStatus.send,
    );
    iPrint("> rtc msg S_RECEIVED: msg:${msg?.toJson().toString()} ;");
    if (msg != null) {
      // 更新会话里面的消息列表的特定消息状态
      eventBus.fire([await msg.toTypeMessage()]);
    }
  }

  Future<MessageModel?> changeStatus(
    String tb,
    String msgId,
    int status,
  ) async {
    iPrint("changeStatus tb $tb, msgId, $msgId, status $status");
    MessageRepo repo = MessageRepo(tableName: tb);
    await repo.update({
      'id': msgId,
      'status': status,
    });
    // 更新会话状态
    conversationLogic.updateConversationByMsgId(
      msgId,
      {ConversationRepo.lastMsgStatus: status},
    );
    return await repo.find(msgId);
  }

  /// 收到撤回消息 C2C_REVOKE C2G_REVOKE
  Future<void> receiveRevokeMessage(data) async {
    String tb = MessageRepo.getTableName(data['type']);
    MessageRepo repo = MessageRepo(tableName: tb);
    ContactModel? contact = await ContactRepo().findByUid(data['from']);
    String id = data['id'];
    await repo.update({
      'id': id,
      'status': IMBoyMessageStatus.send,
      'payload': json.encode({
        "msg_type": "custom",
        "custom_type": "peer_revoked",
        "peer_name": contact!.nickname
      }),
    });
    // msg = null 的时候数据已经被删除了
    MessageModel? msg = await repo.find(id);
    iPrint("changeConversation tb $tb, ${msg?.toJson().toString()}");
    if (msg != null) {
      // 更新会话里面的消息列表的特定消息状态
      eventBus.fire([await msg.toTypeMessage()]);
      changeConversation(msg, 'peer_revoked');
    }

    // 通知服务器已撤销
    Map<String, dynamic> msg2 = {
      'id': id,
      'type':
          data['type'] == 'C2G_REVOKE' ? 'C2G_REVOKE_ACK' : 'C2C_REVOKE_ACK',
      'from': data["to"],
      'to': data["from"],
    };
    WebSocketService.to.sendMessage(json.encode(msg2));
  }

  /// 收到撤回ACK消息 C2C_REVOKE_ACK C2G_REVOKE_ACK
  Future<void> receiveRevokeAckMessage(dType, data) async {
    String tb = MessageRepo.getTableName(dType);
    MessageRepo repo = MessageRepo(tableName: tb);
    MessageModel? msg = await repo.find(data['id']);
    if (msg == null) {
      return;
    }
    String customType = 'my_revoked';
    msg.payload = {
      "msg_type": "custom",
      "custom_type": customType,
      'text': msg.payload!['text'],
    };
    await repo.update({
      'id': data['id'],
      'type': dType,
      'status': IMBoyMessageStatus.send,
      'payload': json.encode(msg.payload),
    });
    // 更新会话里面的消息列表的特定消息状态
    eventBus.fire([await msg.toTypeMessage()]);
    // 确认消息
    String ackType = dType == 'C2G_REVOKE_ACK' ? 'C2G' : 'C2C';
    MessageService.to.sendAckMsg(ackType, data['id']);
    // ack消息不需要修改回话信息了
    // changeConversation(msg, customType);
  }

  /// 撤回消息修正相应会话记录
  Future<void> changeConversation(MessageModel msg, String msgType) async {
    String peerId = '';
    if (msg.type == 'C2C') {
      if (msg.fromId == UserRepoLocal.to.currentUid) {
        peerId = msg.toId ?? '';
      } else if (msg.toId == UserRepoLocal.to.currentUid) {
        peerId = msg.fromId ?? '';
      }
    } else if (msg.type == 'C2G') {
      peerId = msg.toId ?? '';
    }
    iPrint(
        "changeConversation $peerId, msgType $msgType, ${msg.toJson().toString()}");
    if (peerId.isEmpty) {
      return;
    }
    ConversationRepo repo = ConversationRepo();
    ConversationModel? conversation = await repo.findByPeerId(
      msg.type ?? '',
      peerId,
    );
    if (conversation == null) {
      return;
    }
    if (conversation.lastMsgId != msg.id) {
      return;
    }
    //msgType = peerId == UserRepoLocal.to.currentUid ? 'peer_revoked' : 'my_revoked';
    conversation.msgType = msgType;
    // conversation.subtitle = '';
    int res2 = await repo.updateById(conversation.id, {
      ConversationRepo.msgType: conversation.msgType,
      ConversationRepo.subtitle: '',
      ConversationRepo.payload: msg.payload
    });

    if (res2 > 0) {
      eventBus.fire(conversation);
    }
  }

  /// 一对一通话添加本地消息
  Future<void> addLocalMsg({
    required String media,
    required bool caller,
    required String msgId,
    required ContactModel peer,
  }) async {
    iPrint(
        "changeLocalMsgState_addMessageLock $addMessageLock $msgId, ${peer.peerId == UserRepoLocal.to.currentUid}; peer.peerId ${peer.toJson().toString()} ;");
    if (msgId.isEmpty) {
      return;
    }
    if (peer.peerId == UserRepoLocal.to.currentUid) {
      throw Exception('not send message to myself');
    }
    if (addMessageLock) {
      return;
    }
    addMessageLock = true;
    try {
      types.User author = types.User(
        id: peer.peerId,
        firstName: peer.nickname,
        imageUrl: peer.avatar,
      );
      if (caller) {
        author = types.User(
          id: UserRepoLocal.to.currentUid,
          firstName: UserRepoLocal.to.current.nickname,
          imageUrl: UserRepoLocal.to.current.avatar,
        );
      }
      types.CustomMessage msg = types.CustomMessage(
        author: author,
        createdAt: DateTimeHelper.currentTimeMillis(),
        id: msgId,
        remoteId: peer.peerId,
        status: types.Status.delivered,
        metadata: {
          'custom_type': media == 'video' ? 'webrtc_video' : 'webrtc_audio',
          'media': media,
          'start_at': 0,
          'end_at': 0,
          'state': 0,
        },
      );
      await Get.find<ChatLogic>().addMessage(
        UserRepoLocal.to.currentUid,
        peer.peerId,
        peer.avatar,
        peer.nickname,
        'C2C',
        msg,
        sendToServer: false,
      );
    } catch (e) {
      iPrint("addLocalMsg_error ${e.toString()}");
      rethrow;
    } finally {
      addMessageLock = false;
    }
  }

  /// 更新消息状态
  Future<void> changeLocalMsgState(
    String msgId,
    int state, {
    int startAt = -1,
    int endAt = -1,
  }) async {
    iPrint(
        "changeLocalMsgState state $state, $msgId, startAt $startAt, endAt $endAt;");
    MessageRepo repo = MessageRepo(tableName: MessageRepo.c2cTable);
    MessageModel? msg = await repo.find(msgId);
    iPrint(
        "changeLocalMsgState 2 $msgId, ${msg?.payload?.toString()}; webrtcMsgIdLi ${webrtcMsgIdLi.toString()}");
    if (msg == null) {
      return;
    }
    webrtcMsgIdLi = [];
    String customType = msg.payload?['custom_type'] ?? '';
    if (customType != 'webrtc_video' && customType != 'webrtc_audio') {
      return;
    }
    Map<String, dynamic> payload = msg.payload ?? {};
    payload['state'] = state;
    if (startAt > -1 && payload['start_at'] == 0) {
      payload['start_at'] = startAt;
    }
    if (endAt > -1) {
      payload['end_at'] = endAt;
    }
    iPrint("changeLocalMsgState 3 $msgId, ${payload.toString()};");
    int res = await repo.update({
      MessageRepo.id: msgId,
      MessageRepo.payload: payload,
    });
    if (res > 0) {
      msg.payload = payload;
      types.Message msg2 = await msg.toTypeMessage();
      // 更新会话里面的消息列表的特定消息状态
      eventBus.fire([msg2]);
      // 通话完成，加入到消息列表
      if (endAt > -1 || state > 0) {
        eventBus.fire(msg2);
      }
    }
  }

  /// 清理无效的本地消息
/*
  Future<void> cleanInvalidLocalMsg({
    required String tableName,
    required String msgId,
    types.Message? message,
  }) async {
    if (msgId.isEmpty) {
      MessageModel? m = await MessageRepo(tableName: tableName).lastMsg();
      message = await m?.toTypeMessage();
    }
    if (message == null) {
      MessageModel? m = await MessageRepo(tableName: tableName).find(msgId);
      message = await m?.toTypeMessage();
    }
    int startAt = message?.metadata?['start_at'] ?? 0;
    int endAt = message?.metadata?['end_at'] ?? 0;
    int state = message?.metadata?['state'] ?? 0;
    if (state == 0 && startAt == 0 && endAt == 0 && message != null) {
      Get.find<ChatLogic>().removeMessage(0, message);
    }
  }
  */
}
