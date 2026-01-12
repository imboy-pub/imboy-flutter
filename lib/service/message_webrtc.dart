import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/init.dart';

/// MessageWebrtc
/// WebRTC 消息处理，包含音视频通话相关功能
/// WebRTC message handling including audio/video call functionality
class MessageWebrtc extends GetxService {
  static MessageWebrtc get to => Get.find();

  // 缓存常用仓库实例，避免重复 new。
  // Cache repository instances to avoid repeated instantiation.
  final ContactRepo _contactRepo = ContactRepo();

  /// 添加消息锁，防止重复添加
  /// Lock to prevent duplicate message addition
  bool _addMessageLock = false;

  /// 正在进行的 WebRTC 消息 ID 集合，用于去重和批量操作
  /// Track ongoing WebRTC message IDs for dedupe and batch state changes.
  final Set<String> webrtcMsgIds = <String>{};

  @override
  void onInit() {
    super.onInit();
    // WebRTC 模块初始化
    // WebRTC module initialization
  }

  /// Handle WebRTC-specific messages
  /// 处理 WebRTC 信令：OFFER, BUSY, BYE 等
  Future<void> handleWebRTC(String type, Map data) async {
    final msgId = data['id'];
    if (['WEBRTC_OFFER', 'WEBRTC_BUSY', 'WEBRTC_BYE'].contains(type)) {
      webrtcMsgIds.add(msgId);
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
        for (var id in webrtcMsgIds) {
          changeLocalMsgState(id, 4);
        }
        webrtcMsgIds.clear();
        if (Get.isDialogOpen ?? false) Get.closeAllDialogs();
        gTimer?.cancel();
        gTimer = null;
        p2pCallScreenOn = false;
      }
      AppEventBus.fireData(msgModel);
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
        createdAt: DateTime.fromMillisecondsSinceEpoch(DateTimeHelper.millisecond(), isUtc: true),
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
    webrtcMsgIds.clear();

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
      AppEventBus.fireData([updated], 'List<Message>');
      if (endAt >= 0 || state > 0) {
        AppEventBus.fireData(updated, 'Message');
      }
    }
  }
}