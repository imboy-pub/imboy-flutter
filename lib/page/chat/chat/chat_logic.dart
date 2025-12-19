import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:audio_session/audio_session.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_controller.dart';
import 'package:popup_menu/popup_menu.dart' as popupmenu;
import 'package:sqflite/sqflite.dart';
import 'package:imboy/component/chat/message_scroll_manager.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/string.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/group/group_detail/group_detail_logic.dart';
import 'package:imboy/page/mine/user_collect/user_collect_logic.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xid/xid.dart';

import 'chat_state.dart';

/// 聊天业务逻辑控制器
/// 处理消息发送、接收、状态更新等核心业务逻辑
class ChatLogic extends GetxController {
  final state = ChatState();
  final scrollController = ScrollController();
  SqliteChatController? chatController; // 聊天控制器
  PlayerController? _globalPlayerController; // 全局音频播放控制器
  StreamSubscription<PlayerState>? _playerStateSubscription; // 播放状态监听
  StreamSubscription<int>? _positionSubscription; // 播放位置监听
  bool _isDisposed = false; // 添加状态跟踪标志
  static const String _spPendingReadReceiptsKey = 'imboy.pending_read_receipts.v1';
  static const String _spPendingReactionsKey = 'imboy.pending_reactions.v1';
  Timer? _readReceiptFlushTimer;
  Worker? _onlineWorker;
  final Map<String, Timer> _burnDeleteTimers = {};
  final Map<String, Timer> _burnPurgeTimers = {};
  static const int _burnTombstoneRetentionMs = 24 * 60 * 60 * 1000;
  static const int _burnLastMessageScanLimit = 40;
  
  // 备用音频播放器相关字段
  just_audio.AudioPlayer? _audioPlayer; // 备用音频播放器
  StreamSubscription<just_audio.PlayerState>? _justAudioStateSubscription; // Just Audio状态监听
  StreamSubscription<Duration>? _justAudioPositionSubscription; // Just Audio位置监听
  final bool _useJustAudio = true; // 统一使用 Just Audio
  @override
  void onInit() {
    super.onInit();
    initState();
    _onlineWorker = ever(MessageService.to.isOnline, (bool online) {
      if (online) {
        flushPendingReadReceipts();
        flushPendingReactions();
      }
    });
  }

  
  void initChatController(String chatType) {
    // 检查是否已经被释放
    if (_isDisposed) {
      iPrint('ChatLogic已被释放，跳过初始化');
      return;
    }
    
    // 检查控制器是否为null或已被释放
    if (chatController == null || chatController!.isDisposed) {
      iPrint('initChatController: 创建新的聊天控制器');
      chatController = SqliteChatController();
    } else {
      iPrint('initChatController: 聊天控制器已存在，重置状态');
      // 重置现有控制器的状态
      chatController!.reset();
    }
    
    // 不在这里清空消息列表，让 loadMoreMessages 方法处理
    // 这样可以避免重复清空消息列表
    iPrint('initChatController: 聊天控制器初始化完成');
  }

  /// 初始化状态
  void initState() {
    // 这里可以初始化状态（如清除计数等），如有必要可扩展
    state.hasMoreMessage.value = true;
    state.isLoading.value = false;
    state.nextAutoId.value = 0;
    state.memberCount.value = 0;
    // 清除当前会话ID，确保状态正确
    state.currentConversationId.value = '';
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  void onClose() {
    // 设置释放标志
    _isDisposed = true;
    _readReceiptFlushTimer?.cancel();
    _onlineWorker?.dispose();
    for (final t in _burnDeleteTimers.values) {
      t.cancel();
    }
    _burnDeleteTimers.clear();
    for (final t in _burnPurgeTimers.values) {
      t.cancel();
    }
    _burnPurgeTimers.clear();
    
    // 清理资源
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _globalPlayerController?.dispose();
    _globalPlayerController = null;
    
    // 清理备用音频播放器资源
    _justAudioPositionSubscription?.cancel();
    _justAudioStateSubscription?.cancel();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    
    // 清除当前会话ID
    state.currentConversationId.value = '';
    
    // 注意：ChatLogic是全局单例，onClose()永远不会被自动调用
    // chatController 的释放由 ChatLifecycleMixin.dispose() 负责
    // 这里不再处理 chatController，避免双重释放
    
    super.onClose();
  }

  bool _isBurnPayload(Map<String, dynamic> payload) {
    return payload['burn'] == true || payload['is_burn'] == true;
  }

  bool _isBurnTombstonePayload(Map<String, dynamic> payload) {
    return payload['burn_deleted'] == true;
  }

  int _burnDeletedAtMsFromPayload(Map<String, dynamic> payload) {
    final raw = payload['burn_deleted_at'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  int _burnAfterMsFromPayload(Map<String, dynamic> payload) {
    final raw = payload['burn_after_ms'] ?? payload['expiry_time'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  int _burnReadAtMsFromPayload(Map<String, dynamic> payload) {
    final raw = payload['burn_read_at'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  bool _isBurnExpired(Map<String, dynamic> payload, int nowMs) {
    if (!_isBurnPayload(payload)) return false;
    final burnAfter = _burnAfterMsFromPayload(payload);
    final readAt = _burnReadAtMsFromPayload(payload);
    if (burnAfter <= 0 || readAt <= 0) return false;
    return readAt + burnAfter <= nowMs;
  }

  bool isBurnPayload(Map<String, dynamic> payload) => _isBurnPayload(payload);

  int burnAfterMsFromPayload(Map<String, dynamic> payload) => _burnAfterMsFromPayload(payload);

  int burnReadAtMsFromPayload(Map<String, dynamic> payload) => _burnReadAtMsFromPayload(payload);

  bool isBurnExpiredPayload(Map<String, dynamic> payload, {int? nowMs}) =>
      _isBurnExpired(payload, nowMs ?? DateTimeHelper.millisecond());

  Future<void> _ensureBurnTimerForItem({
    required ConversationModel conversation,
    required MessageRepo repo,
    required MessageModel item,
    required int nowMs,
  }) async {
    final payload = item.payload;
    if (!_isBurnPayload(payload)) return;
    if (_isBurnTombstonePayload(payload)) return;
    final burnAfter = _burnAfterMsFromPayload(payload);
    if (burnAfter <= 0) return;

    int readAt = _burnReadAtMsFromPayload(payload);
    if (readAt <= 0 && item.status == IMBoyMessageStatus.seen) {
      readAt = nowMs;
      payload['burn_read_at'] = readAt;
      final messageId = item.id ?? '';
      if (messageId.isNotEmpty) {
        await repo.update({
          MessageRepo.id: messageId,
          MessageRepo.payload: payload,
        });
      }
    }

    if (readAt > 0) {
      await _scheduleBurnDeletion(
        conversation: conversation,
        messageId: item.id ?? '',
        burnAfterMs: burnAfter,
        readAtMs: readAt,
      );
    }
  }

  Future<MessageModel?> _findLatestVisibleMessageModel(
    MessageRepo repo,
    ConversationModel conversation, {
    required int nowMs,
    int scanLimit = _burnLastMessageScanLimit,
  }) async {
    final items = await repo.page(
      conversationUk3: conversation.uk3,
      page: 1,
      size: scanLimit,
      orderBy: "${MessageRepo.autoId} DESC",
    );
    if (items.isEmpty) return null;

    for (final item in items) {
      final payload = item.payload;
      if (_isBurnTombstonePayload(payload)) continue;
      if (_isBurnExpired(payload, nowMs)) continue;
      return item;
    }
    return null;
  }

  Future<void> _updateConversationLastMessageAfterBurnHidden(
    ConversationModel conversation,
    MessageRepo messageRepo, {
    required String hiddenMessageId,
  }) async {
    try {
      if (conversation.lastMsgId != hiddenMessageId) return;
      final nowMs = DateTimeHelper.millisecond();
      final repo = ConversationRepo();
      final latest = await _findLatestVisibleMessageModel(
        messageRepo,
        conversation,
        nowMs: nowMs,
      );

      if (latest == null) {
        final conversationTime = conversation.lastTime > 0
            ? conversation.lastTime
            : DateTime.now().millisecondsSinceEpoch;
        await repo.updateById(conversation.id, {
          ConversationRepo.lastMsgId: '',
          ConversationRepo.lastMsgStatus: 0,
          ConversationRepo.msgType: 'empty',
          ConversationRepo.lastTime: conversationTime,
          ConversationRepo.subtitle: '',
        });
      } else {
        final msg2 = await latest.toTypeMessage();
        await repo.updateById(conversation.id, {
          ConversationRepo.lastMsgId: latest.id,
          ConversationRepo.lastMsgStatus: latest.status,
          ConversationRepo.lastTime: latest.createdAt,
          ConversationRepo.msgType: MessageModel.conversationMsgType(msg2),
          ConversationRepo.subtitle: MessageModel.conversationSubtitle(msg2),
        });
      }

      final updated = await repo.findById(conversation.id);
      if (updated != null) {
        eventBus.fire(updated);
      }
    } catch (_) {}
  }

  Future<void> expireBurnMessage(
    ConversationModel conversation,
    String messageId, {
    int? deletedAtMs,
  }) async {
    try {
      final tb = MessageRepo.getTableName(conversation.type);
      final repo = MessageRepo(tableName: tb);
      final nowMs = deletedAtMs ?? DateTimeHelper.millisecond();

      final m = await repo.find(messageId);
      if (m == null) {
        try {
          if (chatController?.isDisposed != true) {
            await chatController?.removeMessageById(messageId);
          }
        } catch (_) {}
        return;
      }

      final payload = Map<String, dynamic>.from(m.payload);
      if (!_isBurnPayload(payload)) {
        await removeMessage(conversation, await m.toTypeMessage());
        return;
      }

      if (!_isBurnTombstonePayload(payload)) {
        payload['burn_deleted'] = true;
        payload['burn_deleted_at'] = nowMs;
        await repo.update({
          MessageRepo.id: messageId,
          MessageRepo.payload: payload,
        });
      }

      try {
        if (chatController?.isDisposed != true) {
          await chatController?.removeMessageById(messageId);
        }
      } catch (_) {}

      await _updateConversationLastMessageAfterBurnHidden(
        conversation,
        repo,
        hiddenMessageId: messageId,
      );

      _scheduleBurnPurge(conversation: conversation, messageId: messageId);
    } catch (_) {}
  }

  void _scheduleBurnPurge({
    required ConversationModel conversation,
    required String messageId,
  }) {
    _burnPurgeTimers[messageId]?.cancel();
    _burnPurgeTimers[messageId] = Timer(
      const Duration(milliseconds: _burnTombstoneRetentionMs),
      () async {
        await _purgeBurnTombstone(conversation, messageId);
      },
    );
  }

  Future<void> _purgeBurnTombstone(ConversationModel conversation, String messageId) async {
    try {
      final tb = MessageRepo.getTableName(conversation.type);
      final repo = MessageRepo(tableName: tb);
      final m = await repo.find(messageId);
      if (m == null) return;
      final payload = m.payload;
      if (!_isBurnTombstonePayload(payload)) return;

      final nowMs = DateTimeHelper.millisecond();
      final deletedAt = _burnDeletedAtMsFromPayload(payload);
      if (deletedAt <= 0) return;
      if (nowMs - deletedAt < _burnTombstoneRetentionMs) return;

      await repo.delete(messageId);
      await _updateConversationLastMessageAfterBurnHidden(
        conversation,
        repo,
        hiddenMessageId: messageId,
      );
    } catch (_) {}
    _burnPurgeTimers.remove(messageId)?.cancel();
  }

  Future<void> markBurnReadAt(
    ConversationModel conversation,
    String messageId, {
    required int readAtMs,
  }) async {
    try {
      final tb = MessageRepo.getTableName(conversation.type);
      final repo = MessageRepo(tableName: tb);
      final m = await repo.find(messageId);
      if (m == null) return;
      final payload = Map<String, dynamic>.from(m.payload);
      if (!_isBurnPayload(payload)) return;

      final burnAfter = _burnAfterMsFromPayload(payload);
      if (burnAfter <= 0) return;

      final existingReadAt = _burnReadAtMsFromPayload(payload);
      final nextReadAt = existingReadAt > 0 ? existingReadAt : readAtMs;
      if (existingReadAt <= 0) {
        payload['burn_read_at'] = nextReadAt;
        await repo.update({
          MessageRepo.id: messageId,
          MessageRepo.payload: payload,
        });
      }

      await _scheduleBurnDeletion(
        conversation: conversation,
        messageId: messageId,
        burnAfterMs: burnAfter,
        readAtMs: nextReadAt,
      );

      final updated = await repo.find(messageId);
      if (updated != null) {
        eventBus.fire([await updated.toTypeMessage()]);
      }
    } catch (_) {}
  }

  Future<void> _scheduleBurnDeletion({
    required ConversationModel conversation,
    required String messageId,
    required int burnAfterMs,
    required int readAtMs,
  }) async {
    if (burnAfterMs <= 0 || readAtMs <= 0) return;
    _burnDeleteTimers[messageId]?.cancel();
    final expireAt = readAtMs + burnAfterMs;
    final now = DateTimeHelper.millisecond();
    final delayMs = expireAt - now;
    if (delayMs <= 0) {
      await _deleteBurnMessage(conversation, messageId);
      return;
    }
    _burnDeleteTimers[messageId] = Timer(Duration(milliseconds: delayMs), () async {
      await _deleteBurnMessage(conversation, messageId);
    });
  }

  Future<void> _deleteBurnMessage(ConversationModel conversation, String messageId) async {
    try {
      final tb = MessageRepo.getTableName(conversation.type);
      final repo = MessageRepo(tableName: tb);
      final m = await repo.find(messageId);
      if (m == null) {
        try {
          if (chatController?.isDisposed != true) {
            await chatController?.removeMessageById(messageId);
          }
        } catch (_) {}
        return;
      }
      await expireBurnMessage(conversation, messageId);
    } catch (_) {}
    _burnDeleteTimers.remove(messageId)?.cancel();
  }

  Future<void> cleanupExpiredBurnMessagesForConversation(
    ConversationModel conversation, {
    int scanLimit = 30,
  }) async {
    try {
      if (conversation.uk3.isEmpty) return;
      final tb = MessageRepo.getTableName(conversation.type);
      final repo = MessageRepo(tableName: tb);
      final nowMs = DateTimeHelper.millisecond();

      final items = await repo.page(
        page: 1,
        size: scanLimit,
        conversationUk3: conversation.uk3,
        orderBy: "${MessageRepo.autoId} DESC",
      );
      if (items.isEmpty) return;

      for (final item in items) {
        final payload = item.payload;
        if (_isBurnTombstonePayload(payload)) {
          final deletedAt = _burnDeletedAtMsFromPayload(payload);
          if (deletedAt > 0 && nowMs - deletedAt >= _burnTombstoneRetentionMs) {
            await repo.delete(item.id ?? '');
          }
          continue;
        }
        if (!_isBurnPayload(payload)) continue;
        if (_isBurnExpired(payload, nowMs)) {
          final id = item.id ?? '';
          if (id.isNotEmpty) {
            await expireBurnMessage(conversation, id, deletedAtMs: nowMs);
          }
          continue;
        }
        await _ensureBurnTimerForItem(
          conversation: conversation,
          repo: repo,
          item: item,
          nowMs: nowMs,
        );
      }
    } catch (_) {}
  }

  /// 获取群组标题，格式为"群组名称(人数)"
  Future<String> groupTitle(String gid, String prefix, int num) async {
    String prefix2 = strNoEmpty(prefix) ? prefix : 'groupChat'.tr;
    if (num > 0) {
      return "$prefix2($num)";
    } else {
      // 如果人数为0，则从数据库查询群组详情
      GroupModel? g = await GroupDetailLogic().detail(gid: gid);
      state.memberCount.value = g?.memberCount ?? 0;
      if (state.memberCount.value > 0) {
        return "$prefix2(${state.memberCount.value})";
      }
      return prefix2;
    }
  }

  /// 分页加载消息
  /// [obj] 当前会话对象
  /// [size] 每页大小
  Future<List<Message>> pageMessages(ConversationModel obj, int size) async {
    final tb = MessageRepo.getTableName(obj.type);
    final repo = MessageRepo(tableName: tb);

    // 从数据库分页查询消息
    final items = await repo.pageForConversation(
      obj.uk3,
      state.nextAutoId.value,
      size,
    );

    if (items.isEmpty) {
      state.hasMoreMessage.value = false;
      return [];
    }

    final nowMs = DateTimeHelper.millisecond();
    final kept = <MessageModel>[];
    for (final item in items) {
      final payload = item.payload;
      if (_isBurnTombstonePayload(payload)) {
        final deletedAt = _burnDeletedAtMsFromPayload(payload);
        if (deletedAt > 0 && nowMs - deletedAt >= _burnTombstoneRetentionMs) {
          await repo.delete(item.id ?? '');
        }
        continue;
      }
      if (_isBurnExpired(payload, nowMs)) {
        final id = item.id ?? '';
        if (id.isNotEmpty) {
          await expireBurnMessage(obj, id, deletedAtMs: nowMs);
        }
        continue;
      }
      await _ensureBurnTimerForItem(
        conversation: obj,
        repo: repo,
        item: item,
        nowMs: nowMs,
      );
      kept.add(item);
    }

    final messages = await Future.wait(
      kept.map((item) async {
        if (item.status == IMBoyMessageStatus.sending) {
          await sendWsMsg(item);
        }
        return await item.toTypeMessage();
      }),
    );

    // 更新下一页起始ID
    state.nextAutoId.value = items.first.autoId;
    // 返回反转后的列表(时间倒序)
    return messages.toList();
  }

  /// 通过WebSocket发送消息（增强版：包含重试机制）
  Future<bool> sendWsMsg(MessageModel obj) async {
    if (obj.status != IMBoyMessageStatus.sending) return true;

    // 构建消息数据
    Map<String, dynamic> msg = {
      'id': obj.id,
      'type': obj.type,
      'from': obj.fromId,
      'to': obj.toId,
      'payload': obj.payload,
      'created_at': obj.createdAt,
    };

    // 尝试发送消息，包含重试机制
    if (obj.id == null) {
      iPrint('消息ID为空，无法发送');
      return false;
    }
    return await _sendWithRetry(obj.id!, msg);
  }

  /// 带重试机制的消息发送（按照项目规范：指数退避，最大3次）
  Future<bool> _sendWithRetry(String messageId, Map<String, dynamic> msg) async {
    const maxRetries = 3;
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        iPrint('消息发送尝试 ${attempt + 1}/$maxRetries: $messageId');
        
        bool success = await WebSocketService.to.sendMessage(json.encode(msg), messageId);
        
        if (success) {
          iPrint('消息发送成功: $messageId');
          await _updateMessageStatus(messageId, IMBoyMessageStatus.sent);
          return true;
        }
        
        throw Exception('发送失败');
        
      } catch (e) {
        attempt++;
        iPrint('消息发送失败 ($attempt/$maxRetries): $messageId, 错误: $e');
        
        if (attempt >= maxRetries) {
          // 最终失败，标记为错误状态
          await _updateMessageStatus(messageId, IMBoyMessageStatus.error);
          iPrint('消息发送最终失败: $messageId');
          return false;
        }
        
        // 指数退避等待：1s, 2s, 4s
        final delay = Duration(seconds: 1 << (attempt - 1));
        iPrint('等待 ${delay.inSeconds}秒 后重试...');
        await Future.delayed(delay);
      }
    }
    
    return false;
  }
  
  /// 更新消息状态
  Future<void> _updateMessageStatus(String messageId, int status) async {
    try {
      // 查找消息并更新状态
      for (final tableType in ['C2C', 'C2G', 'C2S']) {
        final tb = MessageRepo.getTableName(tableType);
        final repo = MessageRepo(tableName: tb);
        
        final msg = await repo.find(messageId);
        if (msg != null) {
          await repo.update({
            'id': messageId,
            MessageRepo.status: status,
          });
          
          // 通知UI更新
          msg.status = status;
          final updatedMessage = await msg.toTypeMessage();
          eventBus.fire([updatedMessage]);
          break;
        }
      }
    } catch (e) {
      iPrint('更新消息状态失败: $messageId, $e');
    }
  }

  /// 从UI层消息模型转换为数据库模型
  MessageModel getMsgFromTMsg(
      String type,
      String conversationUk3,
      Message message,
      ) {
    Map<String, dynamic> payload = {};
    final metadata = message.metadata ?? <String, dynamic>{};

    // 根据消息类型构造payload
    if (message is TextMessage) {
      payload = {
        "msg_type": "text",
        "text": message.text,
      };
      payload.addAll(metadata);
    } else if (message is ImageMessage) {
      payload = {
        "msg_type": "image",
        "name": message.text,
        "text": message.text, // 用于搜索
        "size": message.size,
        "uri": message.source,
        "width": message.width,
        "height": message.height,
        "md5": message.metadata?['md5'],
      };
      payload.addAll(metadata);
    } else if (message is FileMessage) {
      payload = {
        "msg_type": "file",
        "name": message.name,
        "text": message.name, // 用于搜索
        "size": message.size,
        "uri": message.source,
        "mime_type": message.mimeType,
        "md5": message.metadata?['md5'],
      };
      payload.addAll(metadata);
    } else if (message is CustomMessage) {
      payload = {...?message.metadata};
      payload['msg_type'] = 'custom';
    }

    // 处理系统提示信息
    String sysPrompt = message.metadata?['sys_prompt'] ?? '';
    if (strNoEmpty(sysPrompt)) {
      payload['sys_prompt'] = sysPrompt;
    }
    payload['peer_id'] = message.metadata?['peer_id'];

    MessageModel obj = MessageModel(
      autoId: 0,
      message.id,
      type: type,
      fromId: message.authorId,
      toId: message.metadata?['peer_id'],
      payload: payload,
      createdAt: message.createdAt!.millisecondsSinceEpoch,
      isAuthor: message.authorId == UserRepoLocal.to.currentUid ? 1 : 0,
      conversationUk3: conversationUk3,
      status: IMBoyMessageStatus.sending,
    );
    obj.status = obj.toStatus(message.status ?? MessageStatus.sending);
    return obj;
  }

  /// 添加消息到会话
  /// [fromId] 发送者ID
  /// [toId] 接收者ID
  /// [avatar] 头像
  /// [title] 标题
  /// [type] 消息类型
  /// [message] 消息对象
  /// [sendToServer] 是否发送到服务器
  Future<void> addMessage(
      String fromId,
      String toId,
      String? avatar,
      String title,
      String type,
      Message message, {
        bool sendToServer = true,
      }) async {
    // 构造会话副标题
    String subtitle = MessageModel.conversationSubtitle(message);
    String msgType = MessageModel.conversationMsgType(message);
    int createdAt = DateTimeHelper.millisecond();

    // 查找或创建会话
    ConversationRepo repo = ConversationRepo();
    ConversationModel? conversation = await repo.findByPeerId(type, toId);
    conversation ??= await Get.find<ConversationLogic>().createConversation(
      type: type,
      peerId: toId,
      avatar: avatar ?? '',
      title: title,
      subtitle: "",
      lastTime: createdAt,
    );

    // 更新会话信息
    await repo.updateById(conversation.id, {
      ConversationRepo.title: title,
      ConversationRepo.subtitle: subtitle,
      ConversationRepo.msgType: msgType,
      ConversationRepo.lastMsgId: message.id,
      ConversationRepo.lastTime: createdAt,
      ConversationRepo.lastMsgStatus: sendToServer ? 10 : 11,
      ConversationRepo.unreadNum: conversation.unreadNum,
      ConversationRepo.isShow: 1,
    });

    // 保存消息到数据库
    MessageModel obj = getMsgFromTMsg(type, conversation.uk3, message);
    String tb = MessageRepo.getTableName(conversation.type.toString());
    await (MessageRepo(tableName: tb)).insert(obj);

    // 通知会话更新
    eventBus.fire(conversation);
    iPrint("sendMessage $sendToServer : ${message.id}, type: $type, toId: $toId");
    // 发送到服务器
    if (sendToServer) {
      sendWsMsg(obj);
    }

    // 如果是图片消息，添加到画廊
    if (message is ImageMessage) {
      Get.find<IMBoyImageGalleryController>().pushToLast(
        message.id,
        message.source,
      );
    }
  }
  /// 撤回后更新会话状态
  /// Update conversation after message revoke
  Future<void> updateConversationAfterRevoke(
    ConversationModel conversation,
    Message msg,
    String customType,
  ) async {
    try {
      iPrint('更新会话撤回状态[本端]: conversationId=${conversation.id}, msgId=${msg.id}, customType=$customType');
      
      // 获取会话仓库和消息仓库
      final conversationRepo = ConversationRepo();
      final messageRepo = MessageRepo(tableName: MessageRepo.getTableName(conversation.type));
      
      // 如果撤回的是会话的最后一条消息，需要更新会话显示
      if (conversation.lastMsgId == msg.id) {
        // 首先更新会话为撤回状态显示
        await conversationRepo.updateById(conversation.id, {
          ConversationRepo.msgType: customType, // 设置为 'my_revoked' 或 'peer_revoked'
          ConversationRepo.subtitle: customType == 'my_revoked' ? '你撤回了一条消息' : '对方撤回了一条消息',
          ConversationRepo.payload: json.encode({
            'msg_type': 'custom',
            'custom_type': customType,
            'text': msg.metadata?['text'] ?? '',
            'peer_name': msg.metadata?['peer_name'] ?? '',
          }),
        });
        
        iPrint('会话更新为撤回状态: $customType');
        
        // 查找撤回消息的前一条消息
        // 使用page方法获取最新的消息，排除当前撤回的消息
        final allMessages = await messageRepo.page(
          conversationUk3: conversation.uk3,
          page: 1,
          size: 10, // 获取更多消息以确保能找到前一条消息
        );
        
        iPrint('查找前一条消息: 当前消息ID=${msg.id}, 获取到${allMessages.length}条消息');
        for (int i = 0; i < allMessages.length; i++) {
          iPrint('消息[$i]: id=${allMessages[i].id}, text=${allMessages[i].payload['text'] ?? ''}');
        }
        
        // 找到撤回消息的前一条消息
        // 由于page方法返回的是按时间倒序的消息，所以第一个不是当前消息的就是前一条消息
        MessageModel? previousMsg;
        if (allMessages.isNotEmpty && allMessages[0].id == msg.id) {
          // 如果第一条消息就是被撤回的消息，则取第二条
          if (allMessages.length > 1) {
            previousMsg = allMessages[1];
          }
        } else if (allMessages.isNotEmpty) {
          // 否则第一条消息就是前一条消息
          previousMsg = allMessages[0];
        }
        
        iPrint('找到前一条消息: ${previousMsg?.id ?? 'null'}');
        
        if (previousMsg != null) {
          // 有前一条消息，更新会话显示前一条消息
          final previousMessage = await previousMsg.toTypeMessage();
          
          await conversationRepo.updateById(conversation.id, {
            ConversationRepo.lastMsgId: previousMsg.id,
            ConversationRepo.msgType: MessageModel.conversationMsgType(previousMessage),
            ConversationRepo.subtitle: MessageModel.conversationSubtitle(previousMessage),
            ConversationRepo.lastTime: previousMsg.createdAt,
            ConversationRepo.payload: json.encode(previousMsg.payload),
          });
          
          iPrint('会话更新为前一条消息: ${previousMsg.id}');
        } else {
          // 没有前一条消息，保持撤回状态显示
          iPrint('会话没有前一条消息，保持撤回状态显示');
        }
        
        // 重新获取更新后的会话并通知UI更新
        final updatedConversation = await conversationRepo.findById(conversation.id);
        if (updatedConversation != null) {
          iPrint('会话状态更新成功: ${updatedConversation.id}');
          iPrint('触发会话更新事件总线[本端]');
          // 重新启用事件触发，确保会话列表更新
          eventBus.fire(updatedConversation);
        }
      } else {
        iPrint('撤回的消息不是会话的最后一条消息，无需更新会话');
      }
    } catch (e, stack) {
      iPrint('更新会话撤回状态异常[本端]: $e\n$stack');
    }
  }


  /// 从会话删除消息
  Future<bool> removeMessage(
      ConversationModel cm,
      Message msg,
      ) async {
    iPrint('removeMessage - 开始删除消息: ${msg.id}, 会话ID: ${cm.id}, 会话类型: ${cm.type}');
    _burnDeleteTimers.remove(msg.id)?.cancel();
    final repo = ConversationRepo();
    final tb = MessageRepo.getTableName(cm.type);
    final mRepo = MessageRepo(tableName: tb);
    
    iPrint('removeMessage - 使用表: $tb, 消息ID: ${msg.id}');

    // 先从数据库删除消息，确保数据一致性
    iPrint('removeMessage - 开始从数据库删除消息: ${msg.id}');
    int deleteCount = await mRepo.delete(msg.id);
    iPrint('removeMessage - 数据库删除消息结果: $deleteCount, 消息ID: ${msg.id}');

    // 检查删除是否成功
    if (deleteCount == 0) {
      iPrint('removeMessage - 数据库删除失败，尝试从数据库中查找消息');
      MessageModel? dbMsg = await mRepo.find(msg.id);
      if (dbMsg != null) {
        iPrint('removeMessage - 消息仍在数据库中，重新尝试删除');
        deleteCount = await mRepo.delete(msg.id);
        iPrint('removeMessage - 重试删除结果: $deleteCount');
      } else {
        iPrint('removeMessage - 消息在数据库中未找到，可能已被删除');
        deleteCount = 1;
      }
    }

    // 只有在数据库删除成功后才从UI中移除消息
    if (deleteCount > 0) {
      // 从UI中移除消息，确保用户体验
      iPrint('removeMessage - 开始从UI移除消息: ${msg.id}');
      try {
        if (chatController?.isDisposed != true) {
          await chatController?.removeMessageById(msg.id);
        }
      } catch (_) {}
      iPrint('removeMessage - UI移除消息完成: ${msg.id}');

      // 获取最后一条消息用于更新会话
      iPrint('removeMessage - 开始获取最后一条消息');
      final items = await mRepo.page(
        conversationUk3: cm.uk3,
        page: 1,
        size: 1,
      );
      final lastMsg = items.isEmpty ? null : items[0];
      iPrint('removeMessage - 获取最后一条消息: ${lastMsg?.id ?? "null"}');

      // 如果获取到的最后一条消息就是被删除的消息，则需要获取倒数第二条消息
      MessageModel? finalLastMsg = lastMsg;
      if (lastMsg != null && lastMsg.id == msg.id) {
        iPrint('removeMessage - 最后一条消息是被删除的消息，获取倒数第二条消息');
        final moreItems = await mRepo.page(
          conversationUk3: cm.uk3,
          page: 1,
          size: 2,
        );
        if (moreItems.length >= 2) {
          finalLastMsg = moreItems[1]; // 第二条消息（倒数第二条）
          iPrint('removeMessage - 获取倒数第二条消息: ${finalLastMsg.id ?? "null"}');
        } else {
          finalLastMsg = null; // 没有更多消息了
          iPrint('removeMessage - 没有更多消息，会话将无最后消息');
        }
      }

      // 更新会话最后消息信息
      if (finalLastMsg == null) {
        iPrint('removeMessage - 更新会话: 清空最后消息信息');
        // 当会话中没有消息时，保留会话的创建时间或当前时间，而不是设置为0
        // 这样可以确保会话仍然在会话列表中显示
        int conversationTime = cm.lastTime > 0 ? cm.lastTime : DateTime.now().millisecondsSinceEpoch;
        await repo.updateById(cm.id, {
          ConversationRepo.lastMsgId: '',
          ConversationRepo.lastMsgStatus: 0,
          ConversationRepo.msgType: 'empty',
          ConversationRepo.lastTime: conversationTime,
          ConversationRepo.subtitle: '',
        });
      } else {
        Message msg2 = await finalLastMsg.toTypeMessage();
        iPrint('removeMessage - 更新会话: 最后消息ID: ${finalLastMsg.id}');
        await repo.updateById(cm.id, {
          ConversationRepo.lastMsgId: finalLastMsg.id,
          ConversationRepo.lastMsgStatus: finalLastMsg.status,
          ConversationRepo.lastTime: finalLastMsg.createdAt,
          ConversationRepo.msgType: MessageModel.conversationMsgType(msg2),
          ConversationRepo.subtitle: MessageModel.conversationSubtitle(msg2),
        });
      }

      // 通知会话更新
      ConversationModel? cm2 = await repo.findById(cm.id);
      if (cm2 != null) {
        iPrint('removeMessage - 触发会话更新事件: ${cm2.id}');
        eventBus.fire(cm2);
      } else {
        iPrint('removeMessage - 未找到更新后的会话');
      }

      // 如果是图片消息，从画廊移除
      if (msg is ImageMessage) {
        iPrint('removeMessage - 从画廊移除图片消息: ${msg.id}');
        try {
          Get.find<IMBoyImageGalleryController>().remoteFromGallery(msg.id);
          iPrint('removeMessage - 从画廊移除图片消息成功: ${msg.id}');
        } catch (e) {
          iPrint('removeMessage - 从画廊移除图片消息失败: $e');
        }
      }
    } else {
      // 如果数据库删除失败，不从UI中移除消息，保持一致性
      iPrint('removeMessage - 数据库删除失败，不从UI移除消息，保持一致性');
    }
    
    iPrint('removeMessage - 删除消息完成: ${msg.id}, 返回结果: ${deleteCount > 0}');
    return deleteCount > 0;
  }

  /// 直接发送消息(不经过数据库)
  Future<bool> sendMessage(Map<String, dynamic> msg) async {
    // 🔍 追踪撤回消息发送
    final messageType = msg['type']?.toString() ?? '';
    if (messageType.contains('REVOKE')) {
      iPrint('🔍 ChatLogic撤回消息追踪: 准备发送撤回消息');
      iPrint('🔍 消息类型: $messageType');
      iPrint('🔍 消息ID: ${msg['id']}');
      iPrint('🔍 完整消息: ${json.encode(msg)}');
    }
    
    iPrint('ChatLogic.sendMessage: ${json.encode(msg)}');
    iPrint('WebSocket连接状态: ${WebSocketService.to.status.value}');
    bool result = await WebSocketService.to.sendMessage(json.encode(msg), msg['id']);
    iPrint('ChatLogic.sendMessage结果: $result');
    
    // 🔍 追踪撤回消息发送结果
    if (messageType.contains('REVOKE')) {
      iPrint('🔍 ChatLogic撤回消息追踪: 发送结果: $result');
    }
    
    return result;
  }

  /// 标记消息为已读
  Future<bool> markAsRead(
      String type,
      String peerId,
      List<String> msgIds,
      {
        bool syncToServer = true,
      }) async {
    Database? db = await SqliteService.to.db;
    if (db == null) {
      return false;
    }

    // 查找会话
    ConversationModel? c = await ConversationRepo().findByPeerId(type, peerId);
    if (c == null) {
      return false;
    }

    String tb = MessageRepo.getTableName(c.type);
    int newUnreadNum = c.unreadNum - msgIds.length;
    c.unreadNum = newUnreadNum > 0 ? newUnreadNum : 0;

    // 使用事务更新数据库
    bool res = await db.transaction((txn) async {
      // 更新会话未读计数
      await txn.update(
        ConversationRepo.tableName,
        {
          ConversationRepo.unreadNum: c.unreadNum,
        },
        where: "${ConversationRepo.id}=?",
        whereArgs: [c.id],
      );

      // 批量更新消息状态为已读
      for (var id in msgIds) {
        await txn.update(
          tb,
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
      // 推进会话“已读水位”，并按水位重算未读
      ConversationLogic conversationLogic = Get.find<ConversationLogic>();
      await conversationLogic.advanceReadWatermarkByMsgIds(c, msgIds);
      conversationLogic.replace(c);
      for (final id in msgIds) {
        await markBurnReadAt(
          c,
          id,
          readAtMs: DateTimeHelper.millisecond(),
        );
      }
      await _emitUpdatedMessagesAfterStatusChange(type, msgIds);
      if (syncToServer) {
        await enqueueReadReceipt(type: type, peerId: peerId, msgIds: msgIds);
      }
      return true;
    } else {
      return false;
    }
  }

  Future<void> _emitUpdatedMessagesAfterStatusChange(String type, List<String> msgIds) async {
    if (msgIds.isEmpty) return;
    try {
      final repo = MessageService.to.getMessageRepo(type);
      final updated = <Message>[];
      for (final id in msgIds) {
        final m = await repo.find(id);
        if (m == null) continue;
        updated.add(await m.toTypeMessage());
      }
      if (updated.isNotEmpty) {
        eventBus.fire(updated);
      }
    } catch (_) {}
  }

  Future<void> enqueueReadReceipt({
    required String type,
    required String peerId,
    required List<String> msgIds,
  }) async {
    if (msgIds.isEmpty) return;
    final now = DateTimeHelper.millisecond();
    final item = <String, dynamic>{
      'id': Xid().toString(),
      'type': type,
      'from': UserRepoLocal.to.currentUid,
      'to': peerId,
      'payload': {
        'msg_type': 'custom',
        'action': 'message_read',
        'msg_ids': msgIds,
        'read_at': now,
      },
      'created_at': now,
    };
    await _enqueuePending(_spPendingReadReceiptsKey, item);
    _readReceiptFlushTimer?.cancel();
    _readReceiptFlushTimer = Timer(const Duration(milliseconds: 300), () {
      flushPendingReadReceipts();
    });
  }

  Future<void> flushPendingReadReceipts() async {
    await _flushPending(_spPendingReadReceiptsKey);
  }

  Future<void> enqueueReactionAction(Map<String, dynamic> actionMessage) async {
    await _enqueuePending(_spPendingReactionsKey, actionMessage);
    await flushPendingReactions();
  }

  Future<void> flushPendingReactions() async {
    await _flushPending(_spPendingReactionsKey);
  }

  Future<void> _enqueuePending(String key, Map<String, dynamic> item) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(key);
      final list = raw == null
          ? <dynamic>[]
          : (jsonDecode(raw) is List ? (jsonDecode(raw) as List) : <dynamic>[]);
      list.add(item);
      await sp.setString(key, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _flushPending(String key) async {
    if (!MessageService.to.isOnline.value) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final items = decoded.cast<dynamic>().toList();
      if (items.isEmpty) return;

      final remaining = <dynamic>[];
      for (final it in items) {
        if (it is! Map) continue;
        final map = it.cast<String, dynamic>();
        final messageId = map['id']?.toString() ?? Xid().toString();
        final ok = await WebSocketService.to.sendMessage(json.encode(map), messageId);
        if (!ok) {
          remaining.add(map);
        }
      }
      await sp.setString(key, jsonEncode(remaining));
    } catch (_) {}
  }

  Future<bool?> toggleReaction({
    required String chatType,
    required String peerId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final repo = MessageService.to.getMessageRepo(chatType);
      final msg = await repo.find(messageId);
      if (msg == null) return null;
      final currentUid = UserRepoLocal.to.currentUid;

      final newPayload = Map<String, dynamic>.from(msg.payload);
      final reactionsRaw = newPayload['reactions'];
      final reactions = reactionsRaw is Map ? reactionsRaw.cast<String, dynamic>() : <String, dynamic>{};
      final usersRaw = reactions[emoji];
      final users = usersRaw is List ? usersRaw.map((e) => e.toString()).toList() : <String>[];

      final bool isAdd;
      if (users.contains(currentUid)) {
        users.removeWhere((e) => e == currentUid);
        if (users.isEmpty) {
          reactions.remove(emoji);
        } else {
          reactions[emoji] = users;
        }
        isAdd = false;
      } else {
        users.add(currentUid);
        reactions[emoji] = users;
        isAdd = true;
      }

      newPayload['reactions'] = reactions;
      await repo.update({
        'id': messageId,
        'payload': json.encode(newPayload),
      });

      final updatedMsg = await repo.find(messageId);
      if (updatedMsg != null) {
        eventBus.fire([await updatedMsg.toTypeMessage()]);
      }

      final now = DateTimeHelper.millisecond();
      final actionMessage = <String, dynamic>{
        'id': Xid().toString(),
        'type': chatType,
        'from': currentUid,
        'to': peerId,
        'payload': {
          'msg_type': 'custom',
          'action': 'message_reaction',
          'original_msg_id': messageId,
          'emoji': emoji,
          'op': isAdd ? 'add' : 'remove',
          'user_id': currentUid,
          'reacted_at': now,
        },
        'created_at': now,
      };
      final ok = await WebSocketService.to.sendMessage(json.encode(actionMessage), actionMessage['id']);
      if (!ok) {
        await enqueueReactionAction(actionMessage);
      }
      return isAdd;
    } catch (_) {
      return null;
    }
  }

  /// 解析系统提示信息
  String parseSysPrompt(String sysPrompt) {
    if (sysPrompt == 'in_denylist') {
      sysPrompt = 'sendMsgRejected'.tr;
    } else if (sysPrompt == 'not_a_friend') {
      sysPrompt = 'sendMsgNotFriendTips'.tr;
    }
    return sysPrompt;
  }

  /// 设置系统提示信息
  Future<void> setSysPrompt(String tableName, String msgId, String sysPrompt) async {
    var repo = MessageRepo(tableName: tableName);
    MessageModel? msg = await repo.find(msgId);
    if (msg == null) return;
    Map<String, dynamic> payload = msg.payload;
    payload['msg_type'] = payload['msg_type'].toString();
    payload['sys_prompt'] = sysPrompt;

    // 更新消息状态
    await repo.update({
      'id': msgId,
      MessageRepo.status: IMBoyMessageStatus.error,
      MessageRepo.payload: payload,
    });

    msg.status = IMBoyMessageStatus.error;
    msg.payload = payload;

    // 通知消息状态更新
    eventBus.fire([await msg.toTypeMessage()]);

    // 更新会话状态
    Get.find<ConversationLogic>().updateConversationByMsgId(
      msgId,
      {
        ConversationRepo.payload: {'sys_prompt': sysPrompt},
        ConversationRepo.lastMsgStatus: IMBoyMessageStatus.sent,
      },
    );
  }

  /// 获取消息长按菜单项
  List<popupmenu.MenuItemProvider> getPopupMenuItems(Message message) {
    List<popupmenu.MenuItemProvider> items = [];

    // 检查是否可以复制
    bool canCopy = false;
    String customType = message.metadata?['custom_type'] ?? '';
    if (message is TextMessage) {
      canCopy = true;
    } else if (customType == 'quote') {
      canCopy = true;
    }

    // 添加复制菜单项
    if (canCopy) {
      items.add(popupmenu.MenuItem(
        title: 'buttonCopy'.tr,
        userInfo: {"id": "copy", "msg": message},
        textAlign: TextAlign.center,
        // textStyle: TextStyle(
        //   color: Color(0xffc5c5c5),
        //   fontSize: AppTextSize.small,
        // ),
        image: const Icon(
          Icons.copy,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }

    // 检查是否可以保存
    bool canSave = false;
    if (message is ImageMessage) {
      canSave = true;
    } else if (message is FileMessage) {
      canSave = true;
    } else if (customType == 'video') {
      canSave = true;
    } else if (customType == 'audio') {
      canSave = true;
    }

    // 添加保存菜单项
    if (canSave) {
      items.add(popupmenu.MenuItem(
        title: 'buttonSave'.tr,
        userInfo: {"id": "save", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(
          color: Color(0xffc5c5c5),
          fontSize: 10.0,
        ),
        image: const Icon(
          Icons.save_alt,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }

    // 检查是否可以收藏
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

    // 检查是否已撤回
    bool isRevoked = (message is CustomMessage) && customType.toUpperCase().contains('REVOKE');
    if (customType == 'webrtc_audio' || customType == 'webrtc_video') {
      isRevoked = true;
    }

    // 添加转发和引用菜单项
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
        // textStyle: TextStyle(color: Color(0xffc5c5c5), fontSize: AppTextSize.small),
        image: const Icon(
          Icons.format_quote,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ));
    }

    // 如果是自己发送的消息且未撤回，添加撤回菜单项
    if (message.authorId == UserRepoLocal.to.currentUid &&
        !isRevoked) {
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

    // 添加删除菜单项
    items.add(popupmenu.MenuItem(
      title: 'buttonDelete'.tr,
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

  /// 保存文件到本地
  Future<void> saveFile(String name, String uri) async {
    File? tmpF = await IMBoyCacheManager().getSingleFile(
      uri,
    );

    String ext = StringHelper.ext(uri);
    MimeType? mt = MimeType.get(ext.toUpperCase());

    // 使用FileSaver保存文件
    String? path = await FileSaver.instance.saveAs(
      name: name,
      file: tmpF,
      fileExtension: ext,
      mimeType: mt ?? MimeType.get('Other')!,
    );

    if (path != null) {
      EasyLoading.showToast('saveSuccess'.tr);
    }
  }


  /// 加载更多消息（可用于初始加载和分页加载）
  /// [isInitial] 是否首次加载（首次清空消息及游标）
  /// 返回新加载的消息列表
  Future<List<Message>> loadMoreMessages(ConversationModel obj, {bool isInitial = false}) async {
    // 检查是否已经被释放
    if (_isDisposed) {
      iPrint('ChatLogic已被释放，跳过加载更多消息');
      return [];
    }
    
    iPrint('_loadMoreMessages: isInitial=$isInitial, hasMore=${state.hasMoreMessage.value}, loading=${state.isLoading.value}');
    // 初始化时清空游标和消息
    if (isInitial) {
      state.nextAutoId.value = 0;
      state.prevAutoId.value = 0;
      state.hasMoreMessage.value = true;
      chatController?.setMessages([]);
      // 设置当前会话ID，用于防止重复计数未读消息
      state.currentConversationId.value = obj.uk3;
      iPrint('设置当前会话ID: ${obj.uk3}');
    }
    if (state.isLoading.value || !state.hasMoreMessage.value) return [];

    state.isLoading.value = true;
    final items = await pageMessages(obj, state.pageSize);
    state.isLoading.value = false;

    // 再次检查是否已被释放（异步操作后）
    if (_isDisposed) {
      iPrint('ChatLogic在异步操作后被释放，跳过消息更新');
      return [];
    }

    if (items.isEmpty) {
      state.hasMoreMessage.value = false;
      return [];
    }

    // 去重插入
    final currentIds = chatController?.messages.map((e) => e.id).toSet() ?? <String>{};
    final newItems = items.where((msg) => !currentIds.contains(msg.id)).toList();

    if (newItems.isNotEmpty) {
      // 初始加载时，直接设置消息列表（保持正确的顺序）
      if (isInitial) {
        chatController?.setMessages(newItems);
        // 设置初始的 prevAutoId 为最新消息的 auto_id
        state.prevAutoId.value = newItems.first.metadata?['auto_id'] ?? 0;
      } else {
        // 分页加载时，需要反转消息顺序后再插入到列表顶部
        // 因为 pageMessages 返回的是旧消息在前，新消息在后的顺序
        // 但分页加载的历史消息应该插入到列表顶部，且保持新旧顺序
        final reversedItems = newItems.reversed.toList();
        chatController?.insertAllMessages(reversedItems, index: 0);
      }
      // 更新游标（假设消息ID单调递减）
      state.nextAutoId.value =
          newItems.last.metadata?['auto_id'] ?? state.nextAutoId.value;

      // 标记新消息为已读
      // TODO _markMessagesAsRead
      // await _markMessagesAsRead(newItems);
    }

    return newItems;
  }

  /// 加载较新的消息（用于双向分页）
  /// 返回新加载的消息列表
  Future<List<Message>> loadNewerMessages(ConversationModel obj) async {
    // 检查是否已经被释放
    if (_isDisposed) {
      iPrint('ChatLogic已被释放，跳过加载较新消息');
      return [];
    }
    
    // 防止重复加载
    if (state.isLoadingNewer.value) {
      iPrint('正在加载较新消息，跳过');
      return [];
    }

    state.isLoadingNewer.value = true;
    update();

    try {
      final tb = MessageRepo.getTableName(obj.type);
      final repo = MessageRepo(tableName: tb);
      final prevAutoId = state.prevAutoId.value;
      final pageSize = state.pageSize;

      iPrint('loadNewerMessages: uk3=${obj.uk3}, prevAutoId=$prevAutoId, pageSize=$pageSize');

      // 从数据库查询较新的消息
      final items = await repo.pageNewerForConversation(
        obj.uk3,
        prevAutoId,
        pageSize,
      );

      if (items.isEmpty) {
        iPrint('loadNewerMessages: 没有较新的消息');
        return [];
      }

      final nowMs = DateTimeHelper.millisecond();
      final kept = <MessageModel>[];
      for (final item in items) {
        final payload = item.payload;
        if (_isBurnExpired(payload, nowMs)) {
          await removeMessage(obj, await item.toTypeMessage());
          continue;
        }
        await _ensureBurnTimerForItem(
          conversation: obj,
          repo: repo,
          item: item,
          nowMs: nowMs,
        );
        kept.add(item);
      }

      final messages = await Future.wait(
        kept.map((item) async {
          if (item.status == IMBoyMessageStatus.sending) {
            await sendWsMsg(item);
          }
          return await item.toTypeMessage();
        }),
      );

      // 去重处理
      final currentIds = chatController?.messages.map((e) => e.id).toSet() ?? <String>{};
      final newMessages = messages.where((msg) => !currentIds.contains(msg.id)).toList();

      if (newMessages.isNotEmpty) {
        iPrint('loadNewerMessages: 加载了 ${newMessages.length} 条较新消息');
        // 更新 prevAutoId 为当前加载的消息中最大的 auto_id
        state.prevAutoId.value = items
            .map((msg) => msg.autoId)
            .fold(0, (max, id) => id > max ? id : max);
        
        // 将较新的消息插入到列表顶部
        await chatController?.insertAllMessages(newMessages, index: 0);
      }

      return newMessages;
    } catch (e) {
      iPrint('loadNewerMessages: 加载较新消息失败 $e');
      return [];
    } finally {
      state.isLoadingNewer.value = false;
      update();
    }
  }

  /// 滚动到指定消息ID（优化版），支持精确定位和高亮效果
  Future<void> scrollToMessage(String chatType, MessageID messageId) async {
    if (messageId.isEmpty) return;

    bool messageExists() => chatController?.messages.any((m) => m.id == messageId) ?? false;

    // 1. 先查本地有没有，直接滚动（优化响应速度）
    if (messageExists()) {
      iPrint('消息已在内存中，直接滚动: $messageId');
      await _performScrollToMessage(messageId);
      return;
    }

    // 2. 查数据库是否存在该消息
    String tb = MessageRepo.getTableName(chatType);
    iPrint("查询消息: chatType=$chatType, tableName=$tb, messageId=$messageId");

    MessageModel? msg = await (MessageRepo(tableName: tb)).find(messageId);
    if (msg == null) {
      EasyLoading.showError('未找到该消息');
      return;
    }

    String toId = msg.toId ?? '';
    ConversationModel? conversation = await (ConversationRepo()).findByPeerId(chatType, toId);

    // 3. 智能加载历史消息，减少不必要的加载
    int maxAttempts = 5; // 减少最大尝试次数
    int attempts = 0;

    while (attempts < maxAttempts) {
      // 检查消息是否已加载到内存
      if (messageExists()) {
        break;
      }

      // 如果没有更多历史消息，退出循环
      if (!state.hasMoreMessage.value) {
        iPrint('没有更多历史消息可加载');
        break;
      }

      // 触发加载更多历史消息
      if (conversation != null) {
        iPrint('加载历史消息，尝试 ${attempts + 1}/$maxAttempts');
        await loadMoreMessages(conversation);

        // 等待UI更新
        await Future.delayed(const Duration(milliseconds: 100));
      }

      attempts++;
    }

    // 最终检查消息是否存在
    if (!messageExists()) {
      EasyLoading.showError('未能定位到该消息，可能已被删除');
      return;
    }

    // 执行滚动操作
    await _performScrollToMessage(messageId);
  }

  /// 执行滚动到指定消息的操作
  Future<void> _performScrollToMessage(String messageId) async {
    try {
      // 使用滚动管理器进行精确定位
      // 这里需要传入会话ID，暂时使用消息ID作为替代
      final conversationId = _getCurrentConversationId();

      await MessageScrollManager.to.scrollToMessage(
        conversationId,
        messageId,
        animated: true,
        offset: 80.0, // 避免被顶部栏遮挡
        highlight: true,
        duration: const Duration(milliseconds: 300),
      );

      iPrint('滚动到消息完成: $messageId');
    } catch (e) {
      iPrint('滚动到消息失败: $messageId, 错误: $e');

      // 备用方案：使用chatController的滚动方法
      await chatController?.scrollToMessage(messageId);
    }
  }

  /// 获取当前会话ID（优化版）
  String _getCurrentConversationId() {
    // 优先返回实际的会话uk3，确保滚动管理器能正确缓存位置
    try {
      // 从当前会话中获取uk3作为唯一标识
      if (chatController?.messages.isNotEmpty == true) {
        // 可以从第一条消息的metadata中获取conversation_uk3
        final firstMessage = chatController!.messages.first;
        final conversationUk3 = firstMessage.metadata?['conversation_uk3']?.toString();
        if (conversationUk3?.isNotEmpty == true) {
          return conversationUk3!;
        }
      }

      // 如果没有消息，返回默认标识
      return 'default_conversation';
    } catch (e) {
      iPrint('获取当前会话ID失败，使用默认值: $e');
      return 'default_conversation';
    }
  }

  /// 重试发送失败的消息
  /// Retry sending failed message.
  Future<bool> retryMessage(String messageId, String messageType) async {
    try {
      iPrint('开始重试消息: $messageId');
      
      // 使用MessageService的重试功能
      final success = await MessageService.to.retryMessage(messageId, messageType);
      
      if (success) {
        iPrint('消息重试成功: $messageId');
      } else {
        iPrint('消息重试失败: $messageId');
      }
      
      return success;
    } catch (e) {
      iPrint('重试消息异常: $messageId, $e');
      return false;
    }
  }

  /// 检查并重试发送中的消息
  /// Check and retry sending messages.
  Future<void> checkAndRetrySendingMessages(String type, String conversationUk3) async {
    try {
      final tb = MessageRepo.getTableName(type);
      final repo = MessageRepo(tableName: tb);
      
      // 查找所有发送中状态的消息
      final sendingMessages = await repo.findByStatus(
        conversationUk3,
        IMBoyMessageStatus.sending,
      );
      
      for (final msg in sendingMessages) {
        // 检查消息创建时间，如果超过5分钟则标记为失败
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - msg.createdAt > 5 * 60 * 1000) {
          await repo.update({
            'id': msg.id,
            'status': IMBoyMessageStatus.error,
          });
          
          // 更新UI
          final updatedMessage = await msg.toTypeMessage();
          eventBus.fire([updatedMessage]);
          
          iPrint('消息发送超时，标记为失败: ${msg.id}');
        } else {
          // 尝试重新发送
          await sendWsMsg(msg);
        }
      }
    } catch (e) {
      iPrint('检查发送中消息异常: $e');
    }
  }

  /// 初始化全局音频会话（获取音频焦点）
  Future<void> _initGlobalPlayerController() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.music());
      await session.setActive(true);
      iPrint('AudioSession configured and activated');
    } catch (e) {
      iPrint('AudioSession configuration failed: $e');
    }
  }

  /// 播放/暂停/继续播放语音（统一 just_audio）
  Future<void> playVoice({
    required String voiceUrlOrPath,
    required String messageId,
    required int duration,
  }) async {
    try {
      iPrint('playVoice called: path=$voiceUrlOrPath, messageId=$messageId, duration=$duration');
      
      if (voiceUrlOrPath.isEmpty) {
        iPrint('Error: Audio path is empty');
        return;
      }
      
      // 检查文件是否存在
      final file = File(voiceUrlOrPath);
      if (!await file.exists()) {
        iPrint('Error: Audio file does not exist at path: $voiceUrlOrPath');
        return;
      }
      
      // 初始化音频会话（获取音频焦点）
      await _initGlobalPlayerController();
      
      // 检查是否是当前正在播放的音频
      if (state.currentAudioPath.value == voiceUrlOrPath) {
        iPrint('Same audio file clicked, current state: isPlaying=${state.isPlaying.value}, isPaused=${state.isPaused.value}');
        _audioPlayer ??= just_audio.AudioPlayer();
        if (state.isPlaying.value) {
          await _audioPlayer!.pause();
          state.setCurrentPausedAudio(
            audioPath: voiceUrlOrPath,
            messageId: messageId,
            position: state.currentPosition.value,
          );
          update(['voice_playback_state']);
          return;
        } else if (state.isPaused.value) {
          await _audioPlayer!.play();
          state.resumeCurrentAudio();
          update(['voice_playback_state']);
          return;
        }
      }

      // 不同资源或首次播放：先停止当前播放，然后开始新的播放
      if (state.isPlaying.value && _audioPlayer != null) {
        iPrint('Stopping current playback to play new audio');
        await _audioPlayer!.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await _playWithJustAudio(voiceUrlOrPath, messageId, duration);
      
    } catch (e) {
      iPrint('播放语音消息异常: $e');
      debugAudioState(); // 输出调试信息
      state.stopCurrentAudio();
      update(['voice_playback_state', 'voice_playback_progress']); // 更新UI状态
    }
  }
  
  /// 使用 just_audio 播放音频
  Future<void> _playWithJustAudio(String voiceUrlOrPath, String messageId, int duration) async {
    try {
      // 初始化 just_audio 播放器
      if (_audioPlayer == null) {
        _audioPlayer = just_audio.AudioPlayer();
        iPrint('Just Audio player initialized');
        
        // 监听播放状态变化
        _justAudioStateSubscription = _audioPlayer!.playerStateStream.listen((playerState) async {
          if (_isDisposed) return;
          
          iPrint('Just Audio player state changed: $playerState');
          
          if (playerState.playing) {
            iPrint('Just Audio is playing, updating state');
            state.resumeCurrentAudio();
            update(['voice_playback_state', 'voice_playback_progress']);
          } else if (playerState.processingState == just_audio.ProcessingState.ready && !playerState.playing) {
            iPrint('Just Audio is paused, updating state');
            state.isPaused.value = true;
            state.isPlaying.value = false;
            update(['voice_playback_state']);
          } else if (playerState.processingState == just_audio.ProcessingState.completed) {
            iPrint('Just Audio is completed, checking for next audio message');
            // 播放完成，先尝试播放下一条语音消息
            // 在播放下一条之前不清除当前状态，以便能够找到当前消息的位置
            await playNextAudioMessage();
            
            // 只有在没有下一条消息时才清除状态
            // 如果有下一条消息，状态会在播放新消息时被更新
            if (state.currentMessageId.value.isEmpty) {
              state.stopCurrentAudio();
            }
            update(['voice_playback_state', 'voice_playback_progress']);
          } else if (playerState.processingState == just_audio.ProcessingState.idle) {
            iPrint('Just Audio is idle, updating state');
            state.stopCurrentAudio();
            update(['voice_playback_state', 'voice_playback_progress']);
          }
        });
        
        // 监听播放位置变化
        _justAudioPositionSubscription = _audioPlayer!.positionStream.listen((position) {
          if (_isDisposed) return;
          
          // 只在每秒更新一次日志，避免日志过多
          if (position.inMilliseconds % 1000 == 0) {
            iPrint('Just Audio playback position updated: ${position.inMilliseconds}ms');
          }
          state.updatePlaybackPosition(position.inMilliseconds);
          update(['voice_playback_progress']);
        });
      }
      
      // 设置音频源并播放
      await _audioPlayer!.setFilePath(voiceUrlOrPath);
      
      // 确保状态正确设置
      state.setCurrentPlayingAudio(
        audioPath: voiceUrlOrPath,
        messageId: messageId,
        duration: duration,
      );
      
      await _audioPlayer!.play();
      
      iPrint('Just Audio playback started successfully');
      update(['voice_playback_state', 'voice_playback_progress']);
      
    } catch (e) {
      iPrint('Just Audio playback error: $e');
      state.stopCurrentAudio();
      update(['voice_playback_state', 'voice_playback_progress']);
    }
  }

  /// 暂停播放语音
  Future<void> pauseVoice() async {
    try {
      if (state.isPlaying.value) {
        if (_audioPlayer != null) {
          await _audioPlayer!.pause();
        }
        state.setCurrentPausedAudio(
          audioPath: state.currentAudioPath.value,
          messageId: state.currentMessageId.value,
          position: state.currentPosition.value,
        );
      }
    } catch (e) {
      iPrint('暂停语音播放异常: $e');
    }
  }

  /// 继续播放语音
  Future<void> resumeVoice() async {
    try {
      if (state.isPaused.value) {
        if (_audioPlayer != null) {
          await _audioPlayer!.play();
          state.resumeCurrentAudio();
          update(['voice_playback_state']);
        }
      }
    } catch (e) {
      iPrint('继续语音播放异常: $e');
    }
  }

  /// 停止当前播放的语音（用于播放其他消息时）
  Future<void> stopCurrentVoice() async {
    try {
      if (state.isPlaying.value) {
        if (_audioPlayer != null) {
          await _audioPlayer!.stop();
        }
        state.stopCurrentAudio();
      }
    } catch (e) {
      iPrint('停止语音播放异常: $e');
    }
  }

  /// 检查是否是当前正在播放的消息
  bool isCurrentPlayingMessage(String voiceUrlOrPath) {
    return state.isCurrentPlayingAudio(voiceUrlOrPath);
  }

  /// 检查是否是当前正在暂停的消息
  bool isCurrentPausedMessage(String voiceUrlOrPath) {
    return state.isCurrentPausedAudio(voiceUrlOrPath);
  }

  /// 获取当前播放进度（0.0 到 1.0）
  double? getCurrentPlaybackProgress() {
    if (state.currentDuration.value == 0) {
      return null;
    }
    return state.currentPosition.value / state.currentDuration.value;
  }

  /// 获取当前播放位置
  int getCurrentPlaybackPosition() {
    return state.currentPosition.value;
  }

  /// 检查当前是否正在播放语音
  bool get isPlayingVoice => state.isPlaying.value;

  /// 检查当前是否处于暂停状态
  bool get isPausedVoice => state.isPaused.value;

  /// 获取当前播放的消息ID
  String get currentPlayingMessageId => state.currentMessageId.value;

  /// 标记 ChatLogic 为已释放状态
  /// 这个方法主要用于在页面生命周期结束时，阻止新的异步操作
  void markAsDisposed() {
    _isDisposed = true;
    iPrint('ChatLogic 已标记为已释放状态');
  }

  /// 重置释放状态，允许重新初始化
  void resetDisposedState() {
    _isDisposed = false;
    iPrint('ChatLogic 已重置释放状态，允许重新初始化');
  }

  /// 查找下一条语音消息
  Future<MessageModel?> findNextAudioMessage(String messageId) async {
    try {
      // 检查聊天控制器是否存在
      if (chatController == null) {
        iPrint('聊天控制器不存在，无法查找下一条语音消息');
        return null;
      }
      
      // 获取当前消息列表
      final messages = chatController!.messages;
      if (messages.isEmpty) {
        iPrint('消息列表为空，无法查找下一条语音消息');
        return null;
      }
      
      // 查找当前消息在列表中的位置
      int currentIndex = -1;
      
      for (int i = 0; i < messages.length; i++) {
        if (messages[i].id == messageId) {
          currentIndex = i;
          break;
        }
      }
      
      if (currentIndex == -1) {
        iPrint('在消息列表中找不到当前消息: $messageId');
        return null;
      }
      
      // 从当前消息的下一条开始查找语音消息
      for (int i = currentIndex + 1; i < messages.length; i++) {
        final message = messages[i];
        
        // 检查是否是语音消息
        if (message is CustomMessage) {
          final customType = message.metadata?['custom_type']?.toString();
          if (customType == 'audio') {
            iPrint('找到下一条语音消息: ${message.id}');
            
            // 将CustomMessage转换为MessageModel
            // 由于需要返回MessageModel，我们需要从数据库中获取完整信息
            for (final tableType in ['C2C', 'C2G', 'C2S']) {
              final tb = MessageRepo.getTableName(tableType);
              final repo = MessageRepo(tableName: tb);
              
              final msg = await repo.find(message.id);
              if (msg != null) {
                return msg;
              }
            }
          }
        }
      }
      
      iPrint('没有找到下一条语音消息');
      return null;
    } catch (e) {
      iPrint('查找下一条语音消息失败: $e');
      return null;
    }
  }

  /// 播放下一条语音消息
  Future<void> playNextAudioMessage() async {
    // 保存当前消息ID，避免在查找过程中状态被清除
    final currentMessageId = state.currentMessageId.value;
    
    if (currentMessageId.isEmpty) {
      iPrint('当前没有播放的消息，无法播放下一条');
      return;
    }
    
    final nextMessage = await findNextAudioMessage(currentMessageId);
    if (nextMessage == null) {
      iPrint('没有下一条语音消息可播放');
      return;
    }
    
    // 转换为 CustomMessage
    final customMessage = await nextMessage.toTypeMessage() as CustomMessage;
    
    // 获取音频文件路径
    if (customMessage.metadata?['uri'] == null) {
      iPrint('下一条语音消息没有音频文件路径');
      return;
    }
    
    final audioUri = customMessage.metadata!['uri'];
    final messageId = customMessage.id;
    final duration = customMessage.metadata?['duration_ms'] ?? 0;
    
    // 下载音频文件
    try {
      final audioFile = await IMBoyCacheManager().getSingleFile(
        audioUri,
      );
      
      if (await audioFile.exists()) {
        iPrint('开始播放下一条语音消息: $messageId');
        await playVoice(
          voiceUrlOrPath: audioFile.path,
          messageId: messageId,
          duration: duration,
        );
      } else {
        iPrint('下一条语音消息文件不存在: ${audioFile.path}');
      }
    } catch (e) {
      iPrint('播放下一条语音消息失败: $e');
    }
  }

  /// 调试音频播放状态
  void debugAudioState() {
    iPrint('=== Audio Debug Info ===');
    iPrint('Current Audio Path: ${state.currentAudioPath.value}');
    iPrint('Current Message ID: ${state.currentMessageId.value}');
    iPrint('Is Playing: ${state.isPlaying.value}');
    iPrint('Is Paused: ${state.isPaused.value}');
    iPrint('Current Position: ${state.currentPosition.value}ms');
    iPrint('Current Duration: ${state.currentDuration.value}ms');
    iPrint('Use Just Audio: $_useJustAudio');
    iPrint('Global Player Controller: ${_globalPlayerController != null ? "initialized" : "null"}');
    if (_globalPlayerController != null) {
      iPrint('Player State: ${_globalPlayerController!.playerState}');
    }
    iPrint('Just Audio Player: ${_audioPlayer != null ? "initialized" : "null"}');
    if (_audioPlayer != null) {
      iPrint('Just Audio State: ${_audioPlayer!.playerState}');
      iPrint('Just Audio Processing State: ${_audioPlayer!.processingState}');
    }
    iPrint('Is Disposed: $_isDisposed');
    iPrint('========================');
  }

  }
