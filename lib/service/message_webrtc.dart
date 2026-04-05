import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/webrtc_signaling_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// MessageWebrtc
/// WebRTC 消息处理，包含音视频通话相关功能
/// WebRTC message handling including audio/video call functionality
///
/// ## 架构说明
///
/// 此服务已从 GetX 迁移到纯 Dart 实现：
/// - ✅ 移除了 `Get.find<ChatLogic>()` 依赖
/// - ✅ 使用事件总线与 UI 层通信
/// - ✅ 保持单例模式
/// - ✅ 可以通过 Riverpod Provider 访问
///
/// ## 使用方式
///
/// ### 方式1：通过单例
/// ```dart
/// MessageWebrtc.instance.addLocalMsg(...);
/// MessageWebrtc.instance.changeLocalMsgState(...);
/// ```
///
/// ### 方式2：通过 Riverpod（推荐）
/// ```dart
/// final webrtc = ref.watch(messageWebrtcProvider);
/// webrtc.addLocalMsg(...);
/// ```
///
/// ## 依赖注入
///
/// - `ContactRepo` - 通过构造函数注入
/// - `MessageRepo` - 按需创建
/// - UI 通信通过 `AppEventBus` 事件总线
class MessageWebrtc {
  /// 单例实例
  static MessageWebrtc? _instance;

  /// 获取单例实例
  static MessageWebrtc get instance {
    _instance ??= MessageWebrtc._internal();
    return _instance!;
  }

  /// 私有构造函数
  MessageWebrtc._internal() {
    // WebRTC 模块初始化
    // WebRTC module initialization
  }

  // 缓存常用仓库实例，避免重复 new。
  // Cache repository instances to avoid repeated instantiation.
  final ContactRepo _contactRepo = ContactRepo();

  /// 添加消息锁，防止重复添加
  /// Lock to prevent duplicate message addition
  bool _addMessageLock = false;

  /// 正在进行的 WebRTC 消息 ID 集合，用于去重和批量操作
  /// Track ongoing WebRTC message IDs for dedupe and batch state changes.
  final Set<String> webrtcMsgIds = <String>{};

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
      if (contact != null && navigatorKey.currentContext != null) {
        await incomingCallScreen(
          navigatorKey.currentContext!,
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
        // Close dialogs using navigatorKey
        if (navigatorKey.currentContext != null) {
          navigatorKey.currentState?.pop();
        }
        gTimer?.cancel();
        gTimer = null;
        p2pCallScreenOn = false;
      }
      AppEventBus.fireData(msgModel);
    }
  }

  /// Add a local WebRTC message record (UI only)
  /// 本地添加一条 WebRTC 消息记录，仅更新 UI
  ///
  /// ## 迁移说明
  ///
  /// 此方法已从依赖 `ChatLogic` 改为通过事件总线通知 UI 层
  /// UI 层需要订阅 `ChatMessageAddRequestedEvent` 事件来处理消息添加
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
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          DateTimeHelper.millisecond(),
          isUtc: true,
        ),
        id: msgId,
        status: MessageStatus.delivered,
        metadata: {
          'peer_id': peer.peerId,
          'msg_type': media == 'video' ? MessageType.webrtcVideo : MessageType.webrtcAudio,
          'media': media,
          'start_at': 0,
          'end_at': 0,
          'state': 0,
        },
      );

      // 通过事件总线通知 UI 层添加消息
      // UI 层（ChatProvider）需要订阅此事件
      AppEventBus.fire(
        ChatMessageAddRequestedEvent(
          peerId: peer.peerId,
          peerAvatar: peer.avatar,
          peerNickname: peer.nickname,
          conversationType: 'C2C',
          message: msg,
          sendToServer: false,
        ),
      );

      iPrint('✅ [WebRTC] 已发送本地消息添加请求: msgId=$msgId');
    } catch (e, s) {
      iPrint('❌ [WebRTC] addLocalMsg error: $e; $s');
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
    final msgType = metadata['msg_type'] ?? '';
    if (![MessageType.webrtcVideo, MessageType.webrtcAudio].contains(msgType)) return;

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
