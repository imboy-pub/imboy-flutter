import 'dart:async';
import 'dart:convert';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';

import 'package:imboy/page/group/group_detail/group_detail_logic.dart';
import 'package:imboy/page/passport/login_view.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
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

/// MessageService
/// 负责消息处理的核心服务，包括可靠传递、状态同步、UI 通知。
/// Core service for message handling: reliable delivery, state sync, UI updates.
class MessageService extends GetxService {
  static MessageService get to => Get.find();

  final ConversationLogic _conversationLogic = Get.find();

  // 缓存常用仓库实例，避免重复 new。
  // Cache repository instances to avoid repeated instantiation.
  final ConversationRepo _conversationRepo = ConversationRepo();
  final ContactRepo _contactRepo = ContactRepo();

  /// 根据消息类型获取对应的 MessageRepo
  /// Helper: get MessageRepo by message type.
  MessageRepo _getMessageRepo(String type) =>
      MessageRepo(tableName: MessageRepo.getTableName(type));

  /// 正在进行的 WebRTC 消息 ID 集合，用于去重和批量操作
  /// Track ongoing WebRTC message IDs for dedupe and batch state changes.
  final Set<String> _webrtcMsgIds = <String>{};

  /// 本地添加消息锁，防止并发重复添加
  /// Lock to prevent concurrent duplicate local messages.
  bool _addMessageLock = false;

  StreamSubscription? _ssMsg;

  @override
  void onInit() {
    super.onInit();
    // 订阅事件总线，集中分发并捕获错误，防止订阅 silently 断开。
    // Listen to eventBus with error handling to avoid silent drop.
    _ssMsg = eventBus.on<Map>().listen(
      _handleIncomingEvent,
      onError: (e, s) => iPrint('EventBus error: $e - $s'),
    );
  }

  @override
  void onClose() {
    _ssMsg?.cancel();
    super.onClose();
  }

  /// Central dispatcher for all incoming events
  /// 消息统一分发入口
  Future<void> _handleIncomingEvent(Map data) async {
    try {
      final msgId = (data['id'] ?? '').toString();
      if (msgId.isEmpty) return;

      final rawType = (data['type'] ?? 'ERROR').toString();
      final type = rawType.toUpperCase();
      data['type'] = type;

      iPrint("> msg listen: $type, ${DateTime.now()} $data");

      // 如果有 ts 字段，则打印延迟
      // Log latency if timestamp provided
      if (data.containsKey('ts')) {
        iPrint(
          "> msg latency: ${DateTimeHelper.millisecond() - (data['ts'] as int)} ms",
        );
      }

      // 所有消息均需回执 ACK
      // Always send ACK for receipt
      if (type.startsWith('WEBRTC_')) {
        sendAckMsg('WEBRTC', msgId);
        await _handleWebRTC(type, data);
      } else if (type.endsWith('_SERVER_ACK')) {
        await _receiveServerAck(data);
      } else if (type.contains('REVOKE')) {
        await _receiveRevoke(type, data);
      } else {
        switch (type) {
          case 'C2C':
          case 'C2G':
          case 'C2S':
            await _receiveMessage(data);
            break;
          case 'S2C':
            await MessageS2CService.switchS2C(data);
            break;
          case 'ERROR':
            await _handleError(data);
            break;
          default:
            iPrint('Unhandled message type: $type');
        }
      }
    } catch (e, s) {
      iPrint('Error processing message: $e - $s');
    }
  }

  /// Handle WebRTC-specific messages
  /// 处理 WebRTC 信令：OFFER, BUSY, BYE 等
  Future<void> _handleWebRTC(String type, Map data) async {
    final msgId = data['id'];
    if (['WEBRTC_OFFER', 'WEBRTC_BUSY', 'WEBRTC_BYE'].contains(type)) {
      _webrtcMsgIds.add(msgId);
    }

    if (type == 'WEBRTC_OFFER') {
      final peerId = data['from'];
      final contact = await _contactRepo.findByUid(peerId);
      if (contact != null) {
        await incomingCallScreen(
          msgId,
          ContactModel.fromMap({
            'id': contact.peerId,
            'nickname': contact.title,
            'avatar': contact.avatar,
            'sign': contact.sign,
          }),
          data['payload'],
        );
      }
    } else {
      final msgModel = WebRTCSignalingModel(
        msgId: data['id'],
        type: data['type'],
        from: data['from'],
        to: data['to'],
        payload: data['payload'],
      );
      if (['WEBRTC_BUSY', 'WEBRTC_BYE'].contains(type)) {
        // 批量更新本地消息状态为结束/忙碌
        // Batch update local WebRTC message state
        for (var id in _webrtcMsgIds) {
          changeLocalMsgState(id, 4);
        }
        _webrtcMsgIds.clear();
        if (Get.isDialogOpen ?? false) Get.closeAllDialogs();
        gTimer?.cancel();
        gTimer = null;
        p2pCallScreenOn = false;
      }
      eventBus.fire(msgModel);
    }
  }

  /// Send reliable ACK back to server/peer
  /// 发送消息回执
  /// type is ['C2C' | 'S2C' | 'C2G' | 'C2S | 'WEBRTC']
  void sendAckMsg(String type, String msgId) {
    WebSocketService.to.sendMessage('CLIENT_ACK,$type,$msgId,$deviceId');
  }

  /// Process incoming chat messages (C2C/C2G/C2S)
  /// 处理文本/自定义/位置等消息
  Future<void> _receiveMessage(Map data) async {
    // 强制 cast 为 Map<String, dynamic>
    // Safely cast payload to Map<String, dynamic>
    final payload = (data['payload'] as Map?)?.cast<String, dynamic>();
    if (payload == null) return;

    // 归一化 created_at 时间戳
    // Normalize timestamp field
    var createdAt = data['created_at'];
    if (createdAt is String) {
      createdAt = DateTimeHelper.rfc3339ToMillisecond(createdAt);
      data['created_at'] = createdAt;
    }

    // 区分单聊/群聊，获取 peer 信息
    // Determine peer info for C2C or C2G
    String peerId, avatar, title;
    if (data['type'] == 'C2G') {
      peerId = data['to'];
      final g = await GroupDetailLogic().detail(gid: peerId);
      avatar = g?.avatar ?? '';
      title = g?.title ?? '';
    } else {
      final ct = await _contactRepo.findByUid(data['from']);
      peerId = data['from'];
      avatar = ct?.avatar ?? '';
      title = ct?.title ?? '';
    }

    // 构造会话列表要显示的 subtitle
    // Derive subtitle based on msg_type
    String msgType = payload['msg_type'] ?? '';
    String subtitle = payload['text'] ?? '';
    if (msgType == 'custom') {
      msgType = payload['custom_type'] ?? '';
      subtitle = '';
    } else if (msgType == 'quote') {
      subtitle = payload['quote_text'] ?? '';
    } else if (msgType == 'location') {
      subtitle = payload['title'] ?? '';
    }

    // 保存或更新会话
    // Persist conversation record
    var conv = ConversationModel(
      peerId: peerId,
      avatar: avatar,
      title: title,
      subtitle: subtitle,
      type: data['type'],
      msgType: msgType,
      lastMsgId: data['id'],
      lastTime: data['created_at'] ?? DateTimeHelper.millisecond(),
      unreadNum: 1,
      id: 0,
    );
    conv = await _conversationRepo.save(conv);

    // 保存消息到 sqlite
    // Persist message to local DB
    final msg = MessageModel(
      data['id'],
      autoId: 0,
      type: data['type'],
      fromId: data['from'],
      toId: data['to'],
      payload: payload,
      createdAt: data['created_at'],
      isAuthor: data['from'] == UserRepoLocal.to.currentUid ? 1 : 0,
      topicId: data['topic_id'] ?? 0,
      conversationUk3: conv.uk3,
      status: IMBoyMessageStatus.delivered,
    );
    final repo = _getMessageRepo(data['type']);
    final existed = await repo.save(msg);

    // 发送 ACK 给服务端或对端
    // Send ACK back
    // data['type'] C2C | C2G | C2S
    sendAckMsg(data['type'], data['id']);

    // 如果已存在则不再触发通知
    // If duplicate, skip UI update
    if (existed != null && existed > 0) return;

    // 增加会话未读计数并通知 UI
    // Increase unread count & notify UI
    await _conversationLogic.increaseConversationRemind(conv, 1);
    eventBus.fire(conv);
    final tMsg = await msg.toTypeMessage();
    eventBus.fire(tMsg);
  }

  /// 收到撤回消息 C2C_REVOKE C2G_REVOKE
  /// Handle server-side ACK for sent messages
  /// 处理服务端发送确认
  Future<void> _receiveServerAck(Map data) async {
    final repo = _getMessageRepo(data['type']);
    final msg = await _updateStatus(repo, data['id'], IMBoyMessageStatus.sent);
    // iPrint("> rtc msg S_RECEIVED: msg:${msg?.toJson().toString()} ;");
    if (msg != null) {
      // 更新会话里面的消息列表的特定消息状态
      eventBus.fire([await msg.toTypeMessage()]);
    }
  }

  /// 对外保留：改变消息状态（兼容旧调用）
  /// Public API: change message status (for backward compatibility)
  Future<MessageModel?> changeStatus(String tb, String msgId, int status) {
    final repo = MessageRepo(tableName: tb);
    return _updateStatus(repo, msgId, status);
  }

  /// Internal: update message status and conversation state
  /// 内部：更新消息状态并同步会话
  Future<MessageModel?> _updateStatus(
    MessageRepo repo,
    String msgId,
    int status,
  ) async {
    await repo.update({'id': msgId, 'status': status});
    _conversationLogic.updateConversationByMsgId(msgId, {
      ConversationRepo.lastMsgStatus: status,
    });
    return repo.find(msgId);
  }

  /// Handle revoke & revoke-ACK for C2C/C2G
  /// 处理消息撤回及撤回确认
  /// 收到撤回ACK消息 C2C_REVOKE_ACK C2G_REVOKE_ACK
  Future<void> _receiveRevoke(String type, Map data) async {
    if (type.endsWith('REVOKE_ACK')) {
      // 对方确认了我们的撤回
      // Peer acknowledged our revoke
      final baseType = type.replaceAll('_REVOKE_ACK', '');
      final repo = _getMessageRepo(baseType);
      final msg = await repo.find(data['id']);
      if (msg == null) return;
      final metadata =
          (msg.payload as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      metadata.addAll({'msg_type': 'custom', 'custom_type': 'my_revoked'});
      await repo.update({
        'id': data['id'],
        'type': type,
        'payload': json.encode(metadata),
        'status': IMBoyMessageStatus.sent,
      });
      // 更新会话里面的消息列表的特定消息状态
      eventBus.fire([await msg.toTypeMessage()]);
      sendAckMsg(baseType.startsWith('C2G') ? 'C2G' : 'C2C', data['id']);
    } else {
      // 接收到对端撤回
      // Received revoke from peer
      final baseType = type.replaceAll('_REVOKE', '');
      final repo = _getMessageRepo(baseType);
      final contact = await _contactRepo.findByUid(data['from']);
      final newPayload = <String, dynamic>{
        'msg_type': 'custom',
        'custom_type': 'peer_revoked',
        'peer_name': contact?.nickname ?? '',
      };
      await repo.update({
        'id': data['id'],
        'status': IMBoyMessageStatus.sent,
        'payload': json.encode(newPayload),
      });
      final msg = await repo.find(data['id']);
      if (msg != null) {
        eventBus.fire([await msg.toTypeMessage()]);
        _updateConversationAfterRevoke(msg, 'peer_revoked');
      }
      // 回复服务端我们已处理撤回
      // Notify server we've processed revoke
      WebSocketService.to.sendMessage(
        json.encode({
          'id': data['id'],
          'type': '${baseType}_REVOKE_ACK',
          'from': data['to'],
          'to': data['from'],
        }),
      );
    }
  }

  /// Update conversation record after revoke
  /// 撤回后同步更新会话列表
  Future<void> _updateConversationAfterRevoke(
    MessageModel msg,
    String customType,
  ) async {
    String peerId;
    if (msg.type == 'C2C') {
      peerId = msg.fromId == UserRepoLocal.to.currentUid
          ? msg.toId!
          : msg.fromId!;
    } else if (msg.type == 'C2G') {
      peerId = msg.toId!;
    } else {
      peerId = msg.toId ?? '';
    }
    if (peerId == '') {
      return;
    }
    final conv = await _conversationRepo.findByPeerId(msg.type!, peerId);
    if (conv != null && conv.lastMsgId == msg.id) {
      conv.msgType = customType;
      conv.subtitle = '';
      conv.payload = msg.payload;
      await _conversationRepo.updateById(conv.id, {
        ConversationRepo.msgType: conv.msgType,
        ConversationRepo.subtitle: '',
        ConversationRepo.payload: conv.payload,
      });
      eventBus.fire(conv);
    }
  }

  /// Handle error codes from server
  /// 处理服务端错误通知
  Future<void> _handleError(Map data) async {
    final code = data['code']?.toString() ?? '';
    // * Msg2.code = 1 无需弹窗错误，可以记录日志后直接忽略错误 Msg2.payload 可能为空，不需要处理
    // * Msg2.code = 2 带title弹窗，Msg2.payload 不能为空 必须包含 title content 字段
    // * Msg2.code = 3 无title弹窗，Msg2.payload 不能为空 必须包含 content 字段
    if (code == '706') {
      UserRepoLocal.to.quitLogin();
      Get.offAll(() => const LoginPage());
    }
  }

  /// Add a local WebRTC message record (UI only)
  /// 本地添加一条 WebRTC 消息记录，仅更新 UI
  Future<void> addLocalMsg({
    required String media,
    required bool caller,
    required String msgId,
    required ContactModel peer,
  }) async {
    if (msgId.isEmpty || peer.peerId == UserRepoLocal.to.currentUid) return;
    if (_addMessageLock) return;
    _addMessageLock = true;
    try {
      User author;
      if (caller) {
        author = User(
          id: UserRepoLocal.to.currentUid,
          name: UserRepoLocal.to.current.nickname,
          imageSource: UserRepoLocal.to.current.avatar,
        );
      } else {
        author = User(
          id: peer.peerId,
          name: peer.nickname,
          imageSource: peer.avatar,
        );
      }
      final msg = CustomMessage(
        authorId: author.id,
        createdAt: DateTimeHelper.now(),
        id: msgId,
        status: MessageStatus.delivered,
        metadata: {
          'peer_id': peer.peerId,
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
    } catch (e, s) {
      iPrint('addLocalMsg error: $e; $s');
      rethrow;
    } finally {
      _addMessageLock = false;
    }
  }

  /// Update local WebRTC message state (UI only)
  /// 更新本地 WebRTC 消息状态，仅更新 UI
  Future<void> changeLocalMsgState(
    String msgId,
    int state, {
    int startAt = -1,
    int endAt = -1,
  }) async {
    final repo = MessageRepo(tableName: MessageRepo.c2cTable);
    final msg = await repo.find(msgId);
    if (msg == null) return;
    _webrtcMsgIds.clear();

    final metadata = (msg.payload as Map?)?.cast<String, dynamic>() ?? {};
    final customType = metadata['custom_type'] ?? '';
    if (!['webrtc_video', 'webrtc_audio'].contains(customType)) return;

    metadata['state'] = state;
    if (startAt >= 0 && metadata['start_at'] == 0) {
      metadata['start_at'] = startAt;
    }
    if (endAt >= 0) metadata['end_at'] = endAt;

    final res = await repo.update({
      MessageRepo.id: msgId,
      MessageRepo.payload: metadata,
    });
    if (res > 0) {
      msg.payload = metadata;
      final updated = await msg.toTypeMessage();
      // 更新会话里面的消息列表的特定消息状态
      eventBus.fire([updated]);
      if (endAt >= 0 || state > 0) {
        eventBus.fire(updated);
      }
    }
  }
}
