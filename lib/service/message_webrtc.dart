import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_constants.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

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
  Future<void> handleWebRTC(String type, Map<String, dynamic> data) async {
    final msgId = data['id'];
    if (['WEBRTC_OFFER', 'WEBRTC_BUSY', 'WEBRTC_BYE'].contains(type)) {
      webrtcMsgIds.add(msgId as String);
    }

    if (type == 'WEBRTC_OFFER') {
      final peerId = data['from'];
      final contact = await _contactRepo.findByUid(peerId as String);
      if (contact != null && navigatorKey.currentContext != null) {
        await incomingCallScreen(
          navigatorKey.currentContext!,
          msgId as String,
          ContactModel.fromMap({
            'id': contact.peerId,
            'nickname': contact.title,
            'avatar': contact.avatar,
            'sign': contact.sign,
          }),
          data['payload'] as Map<String, dynamic>,
        );
      }
    } else {
      if (['WEBRTC_BUSY', 'WEBRTC_BYE'].contains(type)) {
        // 批量更新本地消息状态为结束/忙碌
        // Batch update local WebRTC message state
        for (var id in webrtcMsgIds) {
          changeLocalMsgState(id, 4);
        }
        webrtcMsgIds.clear();
        // 关闭来电对话框（incomingCallScreen 是 showDialog 路由）。
        // ⚠️ 必须用 canPop 守卫：通话已进入 OverlayEntry（非路由）时无对话框
        // 可弹，裸 pop 会弹掉最后一个 go_router 页面并触发断言崩溃；
        // 此时通话页 overlay 由其自身 BYE 处理（closePage）负责关闭。
        if (navigatorKey.currentState?.canPop() ?? false) {
          navigatorKey.currentState?.pop();
        }
        gTimer?.cancel();
        gTimer = null;
        p2pCallScreenOn = false;
      }
      // WRTC-00 修复：answer/candidate/ringing/busy/bye 必须 fire
      // WebRTCSignalingEvent（通话页 page:245 订阅的类型），此前误发
      // fireData（DataWrapperEvent）导致类型不匹配、信令进黑洞、主叫收不到
      // answer → 无 remoteDescription → ICE 不启动 → relay permission=0。
      AppEventBus.fire(WebRTCSignalingEvent(data: data));
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
    if (msgId.isEmpty ||
        peer.peerId.toString() == UserRepoLocal.to.currentUid) {
      return;
    }
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
          id: peer.peerId.toString(),
          name: peer.nickname,
          imageSource: peer.avatar,
        );
      }
      final String currentUid = UserRepoLocal.to.currentUid;
      final String peerUid = peer.peerId.toString();
      final String msgType = media == 'video'
          ? MessageType.webrtcVideo
          : MessageType.webrtcAudio;

      // ⚠️ 这条记录必须落库，不能只丢给事件总线：
      // 原实现只 fire ChatMessageAddRequestedEvent，而全项目**没有任何订阅方**，
      // 消息从未写进 msg_c2c；随后 changeLocalMsgState 的 repo.find(msgId)
      // 恒为 null 直接 return，于是通话结束后聊天里永远看不到通话记录。
      final model = MessageModel(
        msgId,
        autoId: 0,
        type: 'C2C',
        status: IMBoyMessageStatus.delivered,
        fromId: int.tryParse(author.id) ?? 0,
        toId: int.tryParse(author.id == currentUid ? peerUid : currentUid) ?? 0,
        isAuthor: author.id == currentUid ? 1 : 0,
        msgType: msgType,
        createdAt: DateTimeHelper.millisecond(),
        conversationUk3: ConversationUk3Generator.generateSmart(
          type: 'C2C',
          currentUserId: currentUid,
          peerId: peerUid,
        ),
        payload: <String, dynamic>{
          'peer_id': peer.peerId,
          'msg_type': msgType,
          'media': media,
          'start_at': 0,
          'end_at': 0,
          'state': CallStateCode.calling,
        },
      );
      await MessageRepo(tableName: MessageRepo.c2cTable).save(model);

      // ⚠️ 通话记录落库后必须同步 upsert 会话元数据：旧实现只写消息表，
      // 会话表 subtitle/msgType 停留在上一条消息的值（甚至为空），
      // 会话列表把通话会话显示成「[未知消息]」（生产实测）。
      // subtitle 文案与 MessageService._messageTypeLabel 的 webrtc case 保持一致。
      final conv = ConversationModel(
        peerId: int.tryParse(peerUid) ?? 0,
        avatar: peer.avatar,
        title: peer.nickname,
        subtitle: msgType == MessageType.webrtcVideo ? '[视频通话]' : '[语音通话]',
        type: 'C2C',
        msgType: msgType,
        lastMsgId: int.tryParse(msgId) ?? 0,
        lastTime: DateTimeHelper.millisecond(),
        unreadNum: 0,
        id: 0,
      );
      await ConversationRepo().save(conv, autoIncrement: false);

      // 会话页正开着时立刻插入气泡；页面关闭时也无妨——记录已在库里，
      // 下次进会话由 pageForConversation 读出来。
      AppEventBus.fireData(await model.toTypeMessage(), 'Message');

      iPrint('✅ [WebRTC] 本地通话记录已落库: msgId=$msgId');
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

    final metadata =
        (msg.payload as Map<String, dynamic>?)?.cast<String, dynamic>() ?? {};
    final msgType = metadata['msg_type'] ?? '';
    if (![MessageType.webrtcVideo, MessageType.webrtcAudio].contains(msgType)) {
      return;
    }

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
