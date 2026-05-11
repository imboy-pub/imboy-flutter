import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:xid/xid.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:file_saver/file_saver.dart';
import 'package:popup_menu/popup_menu.dart' as popupmenu;

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/string.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/chat/message_scroll_provider.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/modules/group_collab/public.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/modules/security_privacy/public.dart';
import 'package:imboy/modules/social_graph/public.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/services/message_handling_service.dart';

import 'package:imboy/page/chat/chat/providers/chat_audio_handler.dart';
// 技术债清理 (#14): 统一 ChatState 来源，避免与 chat_state.dart 双份定义
import 'package:imboy/page/chat/chat/chat_state.dart';
export 'package:imboy/page/chat/chat/chat_state.dart' show ChatState;

part 'chat_provider.g.dart';

/// 消息处理服务 Provider
/// 提供消息发送、删除、收藏等操作
@riverpod
MessageHandlingService messageHandlingService(Ref ref) {
  return const MessageHandlingService();
}

// 技术债 #14: ChatState 内部定义已删除，统一从 chat_state.dart import
// （chat_state.dart 是 ChatState 的唯一真相源；本文件 export 它给下游使用）

/// 聊天 Provider（Riverpod Notifier 实现）
///
/// 这是聊天模块的核心状态管理类，使用 Riverpod 的 Notifier 模式
@riverpod
class ChatNotifier extends _$ChatNotifier {
  SqliteChatService? _chatService;
  PlayerController? _globalPlayerController;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<int>? _positionSubscription;
  bool _isDisposed = false;

  late final ChatAudioHandler _audioHandler;

  // SharedPreferences keys
  static const String _spPendingReadReceiptsKey =
      'imboy.pending_read_receipts.v1';
  static const String _spPendingReactionsKey = 'imboy.pending_reactions.v1';
  static const String _spDeletedMessageIdsKey = 'imboy.deleted_message_ids.v1';

  // Timers
  Timer? _readReceiptFlushTimer;
  Timer? _cleanupDeletedMessageIdsTimer;

  // Burn message timers
  final Map<String, Timer> _burnDeleteTimers = {};
  final Map<String, Timer> _burnPurgeTimers = {};

  // Constants
  static const int _maxBurnTimers = 500;
  static const int _burnLastMessageScanLimit = 40;
  static const int _deletedMessageRetentionMs = 24 * 60 * 60 * 1000;

  // Audio players
  just_audio.AudioPlayer? _audioPlayer;
  StreamSubscription<just_audio.PlayerState>? _justAudioStateSubscription;
  StreamSubscription<Duration>? _justAudioPositionSubscription;

  // Stream subscriptions
  StreamSubscription<dynamic>? _ssMsgExt;
  StreamSubscription<dynamic>? _ssMsg;
  StreamSubscription<dynamic>? _ssMsgState;
  StreamSubscription<dynamic>? _ssReEdit;
  StreamSubscription<dynamic>? _connectivitySubscription;

  // VoicePlaybackState 访问器
  VoicePlaybackState get voicePlaybackState =>
      ref.read(voicePlaybackServiceProvider);

  @override
  ChatState build() {
    _audioHandler = ChatAudioHandler(
      getVoicePlaybackNotifier: () =>
          ref.read(voicePlaybackServiceProvider.notifier),
    );

    // 设置消息获取回调
    _audioHandler.setMessagesGetter(
      () => _chatService?.messages.toList() ?? [],
    );

    // 在 dispose 时清理资源
    ref.onDispose(() {
      iPrint('Chat Provider: 执行 dispose');
      _dispose();
      _audioHandler.dispose();
    });

    // 监听在线状态
    final onlineSub = MessagingFacade.instance.onlineStatusStream.listen((
      online,
    ) {
      if (online) {
        _flushPendingReadReceipts();
        _flushPendingReactions();
      }
    });
    ref.onDispose(onlineSub.cancel);

    // 启动清理定时器
    _cleanupDeletedMessageIdsTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _cleanupDeletedMessageIds(),
    );

    // 监听语音播放状态，自动播放下一条
    ref.listen<VoicePlaybackState>(voicePlaybackServiceProvider, (
      previous,
      next,
    ) {
      // 当播放完成时（playing 变为 false 且 paused 为 false）
      if (previous != null &&
          previous.isPlaying &&
          !next.isPlaying &&
          !next.isPaused) {
        final finishedId = previous.currentMessageId;
        if (finishedId.isNotEmpty) {
          _playNextAudioMessage(finishedId);
        }
      }
    });

    return const ChatState();
  }

  /// 初始化网络状态监听（必须在 initState 或其他初始化方法中调用）
  void initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final isConnected = !results.contains(ConnectivityResult.none);
      // 安全地更新状态（仅在 provider 未销毁时）
      if (!isDisposed) {
        state = state.copyWith(connected: isConnected);
      }
    });
  }

  // ===== Getters =====

  SqliteChatService? get chatService => _chatService;

  bool get isDisposed => _isDisposed;

  // ===== 初始化方法 =====

  /// 初始化聊天服务
  void initChatService(String chatType) {
    // 检查 ChatService 状态
    final serviceExists = _chatService != null;
    final serviceDisposed = _chatService?.isDisposed ?? true;
    final messageCount = _chatService?.messages.length ?? 0;

    iPrint(
      'initChatService: 检查状态 - serviceExists=$serviceExists, serviceDisposed=$serviceDisposed, messageCount=$messageCount',
    );

    if (!serviceExists || serviceDisposed) {
      if (serviceExists && serviceDisposed) {
        iPrint('initChatService: 聊天服务已释放，创建新实例');
      } else {
        iPrint('initChatService: 创建新的聊天服务');
      }
      // 直接创建新实例，不依赖 Provider（Provider 可能返回已释放的实例）
      _chatService = SqliteChatService(ref);
    } else {
      iPrint('initChatService: 聊天服务已存在，保留 $messageCount 条消息');
      // 不重置消息列表，保留之前的状态
    }

    iPrint(
      'initChatService: 聊天服务初始化完成，当前消息数: ${_chatService?.messages.length ?? 0}',
    );

    // Phase 2.1.e: 同步 messages 到 ChatState（让 WebShellBootstrap 等外部
    // 消费方能 ref.watch(chatProvider).messages 响应式拿到列表）
    syncMessagesToState();
  }

  /// Phase 2.1.e — 把 _chatService.messages 同步到 ChatState.messages
  ///
  /// 调用时机：init / 收消息 / 发消息 / loadMore 等关键路径后。
  /// 当前最小切片仅在 initChatService 末尾调用，后续 slice 在更多变更点接入。
  /// no-op 防御：service 不存在时仅清空 state.messages。
  void syncMessagesToState() {
    final list = _chatService?.messages.toList() ?? const <Message>[];
    state = state.copyWith(messages: list);
  }

  // ===== 状态更新方法 =====

  /// 更新 composer 高度
  void updateComposerHeight(double height) {
    state = state.copyWith(composerHeight: height);
  }

  /// 更新成员数量
  void updateMemberCount(int count) {
    state = state.copyWith(memberCount: count);
  }

  /// 更新网络连接状态
  void updateConnected(bool connected) {
    state = state.copyWith(connected: connected);
  }

  /// 更新 nextAutoId
  void updateNextAutoId(int id) {
    state = state.copyWith(nextAutoId: id);
  }

  /// 设置当前会话ID
  void setCurrentConversationId(String id) {
    state = state.copyWith(currentConversationId: id);
  }

  // ===== 消息加载 =====

  /// 加载更多消息
  Future<List<Message>> loadMoreMessages(
    ConversationModel obj, {
    bool isInitial = false,
  }) async {
    iPrint(
      '_loadMoreMessages: isInitial=$isInitial, hasMore=${state.hasMoreMessage}, loading=${state.isLoading}',
    );

    // 初始化时清空游标和消息
    if (isInitial) {
      // 保存旧的会话ID，用于日志记录
      final oldConversationId = state.currentConversationId;

      // 检查是否真的需要切换会话
      // 1. 如果 currentConversationId 为空（页面刚初始化或被重置），检查 ChatService 中是否有消息
      // 2. 如果 ChatService 中有消息且 currentConversationId 为空，说明是重新进入，应保留消息
      (_chatService?.messages.length ?? 0) > 0; // hasExistingMessages check
      final isStateReset = state.currentConversationId.isEmpty;

      // 只有在明确切换到不同会话时才清空消息列表
      final isDifferentConversation =
          !isStateReset && state.currentConversationId != obj.uk3;

      state = state.copyWith(
        nextAutoId: 0,
        prevAutoId: 0,
        hasMoreMessage: true,
        currentConversationId: obj.uk3,
      );

      if (isDifferentConversation) {
        // 明确切换会话：清空消息列表
        _chatService?.setMessages([]);
        iPrint('切换会话: $oldConversationId -> ${obj.uk3}');
      } else {
        // 同一会话或状态重置：保留现有消息，只更新分页游标
        final messageCount = _chatService?.messages.length ?? 0;
        iPrint(
          '会话初始化: ${obj.uk3}, 保留现有消息 ($messageCount 条), isStateReset=$isStateReset',
        );

        // 健壮性检查：如果消息列表为空，强制重新加载
        if (messageCount == 0) {
          iPrint('警告：会话初始化但消息列表为空，将重新加载');
          // 不清空消息（因为本来就是空的），但会继续执行下面的加载逻辑
        } else {
          // 如果有现有消息，跳过加载，直接返回
          iPrint('会话初始化：跳过加载，直接返回现有 $messageCount 条消息');
          return _chatService!.messages.toList();
        }
      }

      iPrint('设置当前会话ID: ${obj.uk3}');
    }

    // 如果正在加载，直接返回
    if (state.isLoading) return [];

    // 重新进入同一会话时，如果有消息且没有更多消息，直接返回现有消息
    if (!isInitial && !state.hasMoreMessage) {
      final messageCount = _chatService?.messages.length ?? 0;
      if (messageCount > 0) {
        iPrint('没有更多消息，返回现有 $messageCount 条消息');
        return _chatService!.messages.toList();
      }
    }

    state = state.copyWith(isLoading: true);
    final items = await _pageMessages(obj, state.pageSize);
    state = state.copyWith(isLoading: false);

    // Phase 2.1.e 续 — loadMoreMessages 加载完成后同步 messages 到 ChatState
    syncMessagesToState();

    if (items.isEmpty) {
      state = state.copyWith(hasMoreMessage: false);
      return [];
    }

    // 去重插入
    final currentIds =
        _chatService?.messages.map((e) => e.id).toSet() ?? <String>{};
    final newItems = items
        .where((msg) => !currentIds.contains(msg.id))
        .toList();

    iPrint(
      'loadMoreMessages: items=${items.length}, currentIds=${currentIds.length}, newItems=${newItems.length}, isInitial=$isInitial',
    );
    iPrint(
      'loadMoreMessages: _chatService=${_chatService != null}, isDisposed=${_chatService?.isDisposed ?? true}',
    );

    if (newItems.isNotEmpty) {
      iPrint('loadMoreMessages: 准备设置 ${newItems.length} 条新消息到 ChatService');
      if (isInitial) {
        final service = _chatService;
        iPrint(
          'loadMoreMessages: 调用 setMessages 之前，service=$service, isDisposed=${service?.isDisposed ?? true}',
        );
        service?.setMessages(newItems);
        iPrint('loadMoreMessages: 调用 setMessages 之后');
        state = state.copyWith(
          nextAutoId: newItems.first.metadata?['auto_id'] as int? ?? 0,
          prevAutoId: newItems.last.metadata?['auto_id'] as int? ?? 0,
        );
        iPrint(
          'loadMoreMessages: 已设置消息到 ChatService, nextAutoId=${state.nextAutoId}, prevAutoId=${state.prevAutoId}',
        );
      } else {
        _chatService?.insertAllMessages(newItems, index: 0);
        state = state.copyWith(
          nextAutoId: newItems.first.metadata?['auto_id'] as int? ?? state.nextAutoId,
        );
        iPrint('loadMoreMessages: 已插入消息到 ChatService');
      }
    } else {
      iPrint('loadMoreMessages: newItems 为空，跳过设置消息');
    }

    return newItems;
  }

  /// 分页加载消息（内部方法）
  Future<List<Message>> _pageMessages(ConversationModel obj, int size) async {
    final tb = MessageRepo.getTableName(obj.type);
    final repo = MessageRepo(tableName: tb);

    iPrint(
      '_pageMessages: 加载消息 - conversation: ${obj.uk3}, nextAutoId: ${state.nextAutoId}, size: $size',
    );

    final items = await repo.pageForConversation(
      obj.uk3,
      state.nextAutoId,
      size,
    );

    iPrint('_pageMessages: 查询返回 ${items.length} 条消息');

    if (items.isEmpty) {
      state = state.copyWith(hasMoreMessage: false);
      iPrint('_pageMessages: 没有更多消息');
      return [];
    }

    final messages = await Future.wait(
      items.map((item) async {
        if (item.status == IMBoyMessageStatus.sending) {
          await _sendWsMsg(item);
        }
        return await item.toTypeMessage();
      }),
    );

    state = state.copyWith(nextAutoId: items.first.autoId);
    iPrint(
      '_pageMessages: 成功加载 ${messages.length} 条消息，新的 nextAutoId: ${state.nextAutoId}',
    );
    return messages.toList();
  }

  // ===== 消息发送 =====

  /// 添加消息到会话
  Future<void> addMessage(
    String fromId,
    String toId,
    String? avatar,
    String title,
    String type,
    Message message, {
    bool sendToServer = true,
  }) async {
    iPrint(
      '📤 [ChatProvider.addMessage] 开始: msgId=${message.id}, type=$type, toId=$toId, sendToServer=$sendToServer',
    );
    try {
      String subtitle = MessageModel.conversationSubtitle(message);
      String msgType = MessageModel.conversationMsgType(message);
      int createdAt = DateTimeHelper.millisecond();

      ConversationRepo repo = ConversationRepo();
      ConversationModel? conversation = await repo.findByPeerId(type, toId);

      iPrint(
        '📤 [ChatProvider.addMessage] 会话查找: conversation=${conversation != null ? conversation.uk3 : 'null'}',
      );

      if (conversation == null) {
        conversation = await ref
            .read(conversationProvider.notifier)
            .createConversation(
              type: type,
              peerId: toId,
              avatar: avatar ?? '',
              title: title,
              subtitle: "",
              lastTime: createdAt,
            );
        iPrint('📤 [ChatProvider.addMessage] 创建新会话: ${conversation.uk3}');
      }

      if (conversation.id > 0) {
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
        iPrint('📤 [ChatProvider.addMessage] 更新会话完成: ${conversation.uk3}');
      }

      MessageModel obj = _getMsgFromTMsg(type, conversation.uk3, message);
      String tb = MessageRepo.getTableName(conversation.type);
      iPrint(
        '📤 [ChatProvider.addMessage] 准备插入数据库: table=$tb, msgId=${obj.id}',
      );
      try {
        final insertResult = await (MessageRepo(tableName: tb)).insert(obj);
        iPrint(
          '📤 [ChatProvider.addMessage] 数据库插入完成: msgId=${obj.id}, result=$insertResult',
        );
      } catch (e) {
        iPrint(
          '❌ [ChatProvider.addMessage] 数据库插入异常: msgId=${obj.id}, error=$e',
        );
        rethrow;
      }

      AppEventBus.fireData(conversation);
      iPrint(
        "📤 [ChatProvider.addMessage] 发送事件到 EventBus: msgId=${message.id}, type: $type, toId: $toId, sendToServer=$sendToServer",
      );

      if (sendToServer) {
        iPrint('📤 [ChatProvider.addMessage] 准备通过 WebSocket 发送消息');
        await _sendWsMsg(obj);
        iPrint('📤 [ChatProvider.addMessage] WebSocket 发送完成: msgId=${obj.id}');
      }

      if (message is ImageMessage) {
        ref
            .read(imageGalleryProvider.notifier)
            .pushToLast(message.id, message.source);
      }

      iPrint('✅ [ChatProvider.addMessage] 完成: msgId=${message.id}');

      // Phase 2.1.e — 同步 messages 到 ChatState（让外部 ref.watch 拿到新消息）
      syncMessagesToState();
    } catch (e, stack) {
      iPrint('❌ [ChatProvider.addMessage] 异常: msgId=${message.id}, error=$e');
      iPrint('❌ [ChatProvider.addMessage] stackTrace: $stack');
      rethrow;
    }
  }

  /// 从UI层消息模型转换为数据库模型
  /// WebSocket API v2.0: msg_type 字段提升到顶层，payload 只包含内容
  MessageModel _getMsgFromTMsg(
    String type,
    String conversationUk3,
    Message message,
  ) {
    // 空值验证（Message.id 和 Message.authorId 是 required String，不会为空）
    if (message.id.isEmpty) {
      iPrint('[ERROR] _getMsgFromTMsg: Message ID cannot be empty');
      throw ArgumentError('Message ID cannot be empty');
    }

    if (message.authorId.isEmpty) {
      iPrint('[ERROR] _getMsgFromTMsg: Message authorId cannot be empty');
      throw ArgumentError('Message authorId cannot be empty');
    }

    if (message.createdAt == null) {
      iPrint('[ERROR] _getMsgFromTMsg: Message createdAt cannot be null');
      throw ArgumentError('Message createdAt cannot be null');
    }

    Map<String, dynamic> payload = {};
    final metadata = message.metadata ?? <String, dynamic>{};

    // v2.0: 提取 msg_type 到变量，存储在顶层，payload 中只包含内容
    String msgType = '';

    if (message is TextMessage) {
      msgType = 'text';
      payload = {"text": message.text}; // v2.0: payload 中不包含 msg_type
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is ImageMessage) {
      msgType = 'image';
      payload = {
        "name": message.text,
        "text": message.text,
        "size": message.size,
        "uri": message.source,
        "width": message.width,
        "height": message.height,
        "thumbhash": message.thumbhash,
      };
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is FileMessage) {
      msgType = 'file';
      payload = {
        "name": message.name,
        "text": message.name,
        "size": message.size,
        "uri": message.source,
        "mime_type": message.mimeType,
        "md5": message.metadata?['md5'],
      };
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is VideoMessage) {
      // 视频消息
      msgType = 'video';
      payload = {
        "name": message.name ?? (message.text ?? ''),
        "size": message.size,
        "uri": message.source,
        "width": message.width,
        "height": message.height,
      };
      if (message.text != null) {
        payload['text'] = message.text;
      }
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is AudioMessage) {
      // 语音消息（WebSocket API v2.0 使用 'voice'）
      msgType = 'voice';
      payload = {
        "uri": message.source,
        "duration_ms": message.duration.inMilliseconds,
        "size": message.size,
      };
      if (message.text != null) {
        payload['name'] = message.text;
      }
      if (message.waveform != null) {
        payload['waveform'] = message.waveform;
      }
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is TextStreamMessage) {
      // 文本流消息（用于 AI 对话等流式输出）
      msgType = 'textStream';
      payload = {"stream_id": message.streamId};
      _cleanAndAddMetadata(payload, metadata);
    } else if (message is SystemMessage) {
      // 系统消息
      msgType = 'system';
      payload = Map<String, dynamic>.from(metadata);
      payload.remove('msg_type');
      payload.remove('action');
      payload.remove('e2ee');
    } else if (message is CustomMessage) {
      final customMsgType = message.metadata?['msg_type']?.toString() ?? '';
      msgType = customMsgType.isNotEmpty ? customMsgType : 'custom';
      // v2.0: 清理 metadata，移除顶层字段（msg_type, action, e2ee）
      final cleanMetadata = Map<String, dynamic>.from(message.metadata ?? {});
      cleanMetadata.remove('msg_type');
      cleanMetadata.remove('action');
      cleanMetadata.remove('e2ee');
      payload = {...cleanMetadata};
    } else {
      // 未知消息类型，标记为 unsupported
      msgType = 'unsupported';
      iPrint(
        '[WARN] _getMsgFromTMsg: 未知的消息类型: ${message.runtimeType}，默认使用 unsupported',
      );
      payload = {
        'error': 'unknown_message_type',
        'runtime_type': message.runtimeType.toString(),
      };
    }

    String sysPrompt = message.metadata?['sys_prompt'] as String? ?? '';
    if (strNoEmpty(sysPrompt)) {
      payload['sys_prompt'] = sysPrompt;
    }
    payload['peer_id'] = message.metadata?['peer_id'];

    // v2.0: 创建 MessageModel 时设置顶层 msgType 和 action 字段
    // 修复 #20：直接使用 String 形式的 message.id（Xid 等 base32hex 不能 parse 为 int），
    // 对齐 backend `binary()` msg_id 契约（imboy/src/ds/message_ds.erl:566）。
    MessageModel obj = MessageModel(
      message.id,
      autoId: 0,
      type: type,
      fromId: int.tryParse(message.authorId) ?? 0,
      toId: int.tryParse(message.metadata?['peer_id']?.toString() ?? '') ?? 0,
      payload: payload,
      createdAt: message.createdAt!.millisecondsSinceEpoch,
      isAuthor: message.authorId == UserRepoLocal.to.currentUid ? 1 : 0,
      conversationUk3: conversationUk3,
      status: IMBoyMessageStatus.sending,
      msgType: msgType, // v2.0: 设置顶层 msg_type
      action: '', // v2.0: 设置顶层 action（默认为空）
    );
    obj.status = obj.toStatus(message.status ?? MessageStatus.sending);
    return obj;
  }

  /// 辅助方法：清理 metadata 并添加到 payload
  /// 移除顶层字段（msg_type, action, e2ee）后合并到 payload
  void _cleanAndAddMetadata(
    Map<String, dynamic> payload,
    Map<String, dynamic> metadata,
  ) {
    final cleanMetadata = Map<String, dynamic>.from(metadata);
    cleanMetadata.remove('msg_type');
    cleanMetadata.remove('action');
    cleanMetadata.remove('e2ee');
    payload.addAll(cleanMetadata);
  }

  /// 通过WebSocket发送消息
  /// WebSocket API v2.0: msg_type/action/e2ee 字段提升到顶层
  /// - 普通消息: payload 是 `Map<String, dynamic>`（只包含内容）
  /// - E2EE 消息: payload 是密文字符串
  Future<bool> _sendWsMsg(MessageModel obj) async {
    iPrint('📤 [_sendWsMsg] 开始: msgId=${obj.id}, status=${obj.status}');
    if (obj.status != IMBoyMessageStatus.sending) {
      iPrint(
        '⚠️ [_sendWsMsg] 消息状态不是 sending，跳过发送: msgId=${obj.id}, status=${obj.status}',
      );
      return true;
    }

    final clientSendTs = DateTimeHelper.millisecond();
    Map<String, dynamic> payloadWithTs = Map<String, dynamic>.from(obj.payload as Map<dynamic, dynamic>);    payloadWithTs['client_send_ts'] = clientSendTs;

    // v2.0: 优先使用 MessageModel 的顶层字段
    String msgType = obj.msgType ?? '';
    String action = obj.action ?? '';
    // v2.0: e2ee 字段必须是 Map<String, dynamic> 类型（不能是 JSON 字符串）
    Map<String, dynamic>? e2ee;

    // v2.0: payload 可以是 Map<String, dynamic> 或 String（E2EE 密文）
    dynamic finalPayload;

    // 检查是否需要端到端加密（action 消息不加密）
    final needEncrypt =
        action.isEmpty &&
        E2EEService.shouldEncryptOutgoingPayload(obj.type ?? 'C2C');

    if (needEncrypt) {
      try {
        final encrypted = await _encryptPayload(
          chatType: obj.type ?? 'C2C',
          toId: obj.toId.toString(),
          plaintextMap: obj.payload as Map<String, dynamic>,
          action: action,
          removeKeys: ['client_send_ts'],
        );
        if (encrypted != null) {
          e2ee = encrypted['e2ee'] as Map<String, dynamic>;
          finalPayload = encrypted['payload'];
        } else {
          finalPayload = payloadWithTs;
        }
      } catch (e, stackTrace) {
        iPrint('❌ [E2EE] v2.0 加密失败: msgId=${obj.id}, error=$e');
        AppLogger.error(
          'E2EE加密失败(_sendWsMsg) - msgId:${obj.id} msgType:${obj.type} to:${obj.toId}',
          e,
          stackTrace,
        );
        EasyLoading.showToast(_getE2EEErrorMessage(e));
        if (obj.id.isNotEmpty) {
          await _updateMessageStatus(obj.id, IMBoyMessageStatus.error);
        }
        // fail-close：加密失败时阻止发送，不降级明文
        return false;
      }
    } else {
      // v2.0: 普通消息的 payload 只包含内容（不包含 msg_type/action/e2ee）
      finalPayload = payloadWithTs;
    }

    iPrint(
      '📤 [发送 v2.0] msgId: ${obj.id}, msg_type: $msgType, action: $action, e2ee: ${e2ee != null}',
    );

    // v2.0: 构建 WebSocket 消息，msg_type/action/e2ee 在顶层
    Map<String, dynamic> msg = {
      'id': obj.id,
      'type': obj.type,
      'from': obj.fromId,
      'to': obj.toId,
      // v2.0: 字段提升到顶层
      'msg_type': msgType,
      'action': action,
      'e2ee': e2ee,
      'payload': finalPayload, // Map<String, dynamic> 或 String
      'created_at': obj.createdAt,
    };

    if (obj.id.isEmpty) {
      iPrint('消息ID为空，无法发送');
      return false;
    }
    return await _sendWithRetry(obj.id, msg);
  }

  /// 带重试机制的消息发送
  Future<bool> _sendWithRetry(
    String messageId,
    Map<String, dynamic> msg,
  ) async {
    try {
      iPrint('📤 [_sendWithRetry] 开始发送: msgId=$messageId');
      iPrint('📤 [_sendWithRetry] 消息内容: ${json.encode(msg)}');

      AppEventBus.fire(
        WebSocketMessageSendRequestEvent(
          message: json.encode(msg),
          messageId: messageId,
        ),
      );

      final type = msg['type']?.toString() ?? 'C2C';
      MessageRetry.instance.addToRetryQueue(messageId, type);

      iPrint('✅ [_sendWithRetry] 消息已提交到重试队列: msgId=$messageId');
      return true;
    } catch (e) {
      iPrint('❌ [_sendWithRetry] 消息发送失败: msgId=$messageId, 错误: $e');
      await _updateMessageStatus(messageId, IMBoyMessageStatus.error);
      return false;
    }
  }

  /// 更新消息状态
  Future<void> _updateMessageStatus(String messageId, int status) async {
    try {
      final found = await MessageRepo.updateStatusInAnyTable(messageId, status);
      if (found) {
        // 通知 UI 更新（需要重新查找以获取更新后的消息）
        for (final tableType in ['C2C', 'C2G', 'C2S']) {
          final tb = MessageRepo.getTableName(tableType);
          final repo = MessageRepo(tableName: tb);
          final msg = await repo.find(messageId);
          if (msg != null) {
            final updatedMessage = await msg.toTypeMessage();
            AppEventBus.fireData([updatedMessage], 'List<Message>');
            break;
          }
        }
      }
    } catch (e) {
      iPrint('更新消息状态失败: $messageId, $e');
    }
  }

  /// 直接发送消息(不经过数据库)
  /// WebSocket API v2.0: 已集成端到端加密，C2C/C2G 消息会自动加密后再发送
  Future<bool> sendMessage(Map<String, dynamic> msg) async {
    iPrint('Chat.sendMessage: ${json.encode(msg)}');

    // v2.0: 从消息中提取字段
    // chatType 持会话类型 (C2C/C2G/C2S)，对齐 WebSocket API v2.0 顶层 `type` 字段
    final chatType = msg['type']?.toString() ?? '';
    final msgAction = msg['action']?.toString() ?? '';
    final originalPayload = msg['payload'];

    // v2.0: 设置顶层字段（如果未设置）
    if (!msg.containsKey('msg_type') && originalPayload is Map<String, dynamic>) {
      msg['msg_type'] = originalPayload['msg_type']?.toString() ?? '';
    }
    if (!msg.containsKey('action')) {
      msg['action'] = msgAction;
    }
    // v2.0: e2ee 字段只在加密时设置，非加密消息保持 null

    if (originalPayload is Map<String, dynamic>) {
      final payload = Map<String, dynamic>.from(originalPayload);

      // 检查是否需要加密（C2C/C2G 消息，非 action 操作）
      final needEncrypt =
          msgAction.isEmpty &&
          E2EEService.shouldEncryptOutgoingPayload(chatType);

      if (needEncrypt) {
        try {
          final toUid = msg['to']?.toString() ?? '';
          final encrypted = await _encryptPayload(
            chatType: chatType,
            toId: toUid,
            plaintextMap: payload,
            action: msgAction,
            removeKeys: ['msg_type'],
          );
          if (encrypted != null) {
            msg['e2ee'] = encrypted['e2ee'];
            msg['payload'] = encrypted['payload'];
            iPrint('Chat.sendMessage: E2EE v2.0 加密成功 (${msg['id']})');
          }
        } catch (e, stackTrace) {
          iPrint('Chat.sendMessage: E2EE v2.0 加密失败: $e');
          AppLogger.error(
            'E2EE加密失败 - msgId:${msg['id']?.toString()} msgType:${msg['type']?.toString()} to:${msg['to']?.toString()}',
            e,
            stackTrace,
          );
          EasyLoading.showToast(_getE2EEErrorMessage(e));
          return false;
        }
      } else {
        // v2.0: 普通消息，确保 payload 中不包含冗余的 msg_type/action/e2ee
        final cleanPayload = Map<String, dynamic>.from(payload);
        cleanPayload.remove('msg_type');
        cleanPayload.remove('action');
        cleanPayload.remove('e2ee');
        msg['payload'] = cleanPayload;
      }
    }

    AppEventBus.fire(
      WebSocketMessageSendRequestEvent(
        message: json.encode(msg),
        messageId: msg['id']?.toString(),
      ),
    );

    final msgId = msg['id']?.toString();
    if (msgId != null && msgId.isNotEmpty) {
      final type = msg['type']?.toString() ?? 'C2C';
      MessageRetry.instance.addToRetryQueue(msgId, type);
    }

    iPrint('Chat.sendMessage已提交: ${msg['id']}');
    return true;
  }

  /// E2EE 加密结果
  /// 返回加密后的 {e2ee, payload}，或 null 表示不需要加密
  /// 失败时抛出异常，调用方负责处理
  Future<Map<String, dynamic>?> _encryptPayload({
    required String chatType,
    required String toId,
    required Map<String, dynamic> plaintextMap,
    required String action,
    List<String> removeKeys = const [],
  }) async {
    final needEncrypt =
        action.isEmpty && E2EEService.shouldEncryptOutgoingPayload(chatType);
    if (!needEncrypt) return null;

    // 1. 获取接收方设备公钥
    final deviceKeys = await (chatType == 'C2G'
        ? E2EEService.getGroupDevicePublicKeys(toId)
        : E2EEService.getUserDevicePublicKeys(toId));
    final didToPem = deviceKeys['didToPem'] ?? {};
    if (didToPem.isEmpty) {
      throw Exception('no_recipient_keys');
    }

    // 2. 构造接收方设备列表
    final recipients = <RecipientDevice>[];
    for (final entry in didToPem.entries) {
      recipients.add(
        RecipientDevice(
          deviceId: entry.key,
          keyId: entry.key,
          publicKey: entry.value,
        ),
      );
    }

    // 3. 构造明文
    final plaintextPayload = Map<String, dynamic>.from(plaintextMap);
    for (final key in removeKeys) {
      plaintextPayload.remove(key);
    }
    final plaintext = jsonEncode(plaintextPayload);

    // 4. 加密
    final result = await E2EEService.buildE2EEData(
      plaintext: plaintext,
      recipients: recipients,
    );

    return {
      'e2ee': result['e2ee'] as Map<String, dynamic>,
      'payload': result['ciphertext'] as String,
    };
  }

  /// 生成E2EE加密失败的用户友好错误消息
  ///
  /// 隐藏技术细节，提供用户可理解的错误描述
  String _getE2EEErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('no_recipient_keys') ||
        errorStr.contains('设备密钥') ||
        errorStr.contains('device.*key')) {
      return t.e2eeErrNoRecipientKey;
    }

    if (errorStr.contains('timeout') || errorStr.contains('超时')) {
      return t.e2eeErrTimeout;
    }

    if (errorStr.contains('network') || errorStr.contains('网络')) {
      return t.e2eeErrNetwork;
    }

    if (errorStr.contains('invalid') || errorStr.contains('格式')) {
      return t.e2eeErrInvalidFormat;
    }

    // 默认错误消息（不暴露技术细节）
    return t.e2eeErrDefault;
  }

  // ===== 消息操作 =====

  /// 删除消息
  Future<bool> removeMessage(ConversationModel cm, Message msg) async {
    iPrint('removeMessage - 开始删除消息: ${msg.id}');

    _burnDeleteTimers.remove(msg.id)?.cancel();

    // MessageRetry 现在是单例服务，始终可用
    try {
      MessageRetry.instance.removeFromRetryQueue(msg.id);
    } catch (e) {
      // MessageRetry 可能未初始化，忽略错误
    }

    final repo = ConversationRepo();
    final tb = MessageRepo.getTableName(cm.type);
    final mRepo = MessageRepo(tableName: tb);

    int deleteCount = await mRepo.delete(msg.id);

    if (deleteCount > 0) {
      try {
        if (_chatService?.isDisposed != true) {
          await _chatService?.removeMessageById(msg.id);
        }
      } catch (e) {
        debugPrint(
          '[ChatNotifier] remove message from chat service failed: $e',
        );
      }

      final items = await mRepo.page(conversationUk3: cm.uk3, page: 1, size: 1);
      final lastMsg = items.isEmpty ? null : items[0];

      MessageModel? finalLastMsg = lastMsg;
      if (lastMsg != null && lastMsg.id == msg.id) {
        final moreItems = await mRepo.page(
          conversationUk3: cm.uk3,
          page: 1,
          size: 2,
        );
        if (moreItems.length >= 2) {
          finalLastMsg = moreItems[1];
        } else {
          finalLastMsg = null;
        }
      }

      if (finalLastMsg == null) {
        int conversationTime = cm.lastTime > 0
            ? cm.lastTime
            : DateTimeHelper.millisecond();
        await repo.updateById(cm.id, {
          ConversationRepo.lastMsgId: '',
          ConversationRepo.lastMsgStatus: 0,
          ConversationRepo.msgType: 'empty',
          ConversationRepo.lastTime: conversationTime,
          ConversationRepo.subtitle: '',
        });
      } else {
        // 直接从 MessageModel 读取，避免 toTypeMessage 转换
        await repo.updateById(cm.id, {
          ConversationRepo.lastMsgId: finalLastMsg.id,
          ConversationRepo.lastMsgStatus: finalLastMsg.status,
          ConversationRepo.lastTime: finalLastMsg.createdAt,
          ConversationRepo.msgType: MessageModel.conversationMsgTypeFromModel(
            finalLastMsg,
          ),
          ConversationRepo.subtitle: MessageModel.conversationSubtitleFromModel(
            finalLastMsg,
          ),
        });
      }

      ConversationModel? cm2 = await repo.findById(cm.id);
      if (cm2 != null) {
        AppEventBus.fireData(cm2);
      }

      if (msg is ImageMessage) {
        try {
          ref.read(imageGalleryProvider.notifier).remoteFromGallery(msg.id);
        } catch (e) {
          iPrint('从画廊移除图片消息失败: $e');
        }
      }
    }

    return deleteCount > 0;
  }

  /// 标记消息为已读
  Future<bool> markAsRead(
    String type,
    String peerId,
    List<String> msgIds, {
    bool syncToServer = true,
  }) async {
    Database? db = await SqliteService.to.db;
    if (db == null) return false;

    ConversationModel? c = await ConversationRepo().findByPeerId(type, peerId);
    if (c == null) return false;

    String tb = MessageRepo.getTableName(c.type);
    int newUnreadNum = c.unreadNum - msgIds.length;
    c.unreadNum = newUnreadNum > 0 ? newUnreadNum : 0;

    bool res = await db.transaction((txn) async {
      await txn.update(
        ConversationRepo.tableName,
        {ConversationRepo.unreadNum: c.unreadNum},
        where: "${ConversationRepo.id}=?",
        whereArgs: [c.id],
      );

      for (var id in msgIds) {
        await txn.update(
          tb,
          {MessageRepo.status: IMBoyMessageStatus.seen},
          where: "${MessageRepo.id}=?",
          whereArgs: [id],
        );
      }
      return true;
    });

    if (res) {
      await ref
          .read(conversationProvider.notifier)
          .advanceReadWatermarkByMsgIds(c, msgIds);
      await ref.read(conversationProvider.notifier).replace(c);
      await _emitUpdatedMessagesAfterStatusChange(type, msgIds);
      if (syncToServer) {
        await _enqueueReadReceipt(type: type, peerId: peerId, msgIds: msgIds);
      }
      return true;
    }
    return false;
  }

  Future<void> _emitUpdatedMessagesAfterStatusChange(
    String type,
    List<String> msgIds,
  ) async {
    if (msgIds.isEmpty) return;
    try {
      final repo = MessagingFacade.instance.getMessageRepo(type);
      final updated = <Message>[];
      for (final id in msgIds) {
        final m = await repo.find(id);
        if (m == null) continue;
        updated.add(await m.toTypeMessage());
      }
      if (updated.isNotEmpty) {
        AppEventBus.fireData(updated);
      }
    } catch (e) {
      debugPrint(
        '[ChatNotifier] emit updated messages after status change failed: $e',
      );
    }
  }

  Future<void> _enqueueReadReceipt({
    required String type,
    required String peerId,
    required List<String> msgIds,
  }) async {
    if (msgIds.isEmpty) return;
    final now = DateTimeHelper.millisecond();
    // v2.0: 字段提升到顶层
    final item = <String, dynamic>{
      'id': Xid().toString(),
      'type': type,
      'from': UserRepoLocal.to.currentUid,
      'to': peerId,
      // v2.0: msg_type/action 提升到顶层
      'msg_type': 'custom',
      'action': 'message_read',
      'e2ee': '',
      // v2.0: payload 只包含内容
      'payload': {'msg_ids': msgIds, 'read_at': now},
      'created_at': now,
    };
    await _enqueuePending(_spPendingReadReceiptsKey, item);
    _readReceiptFlushTimer?.cancel();
    _readReceiptFlushTimer = Timer(const Duration(milliseconds: 300), () {
      _flushPendingReadReceipts();
    });
  }

  Future<void> _flushPendingReadReceipts() async {
    await _flushPending(_spPendingReadReceiptsKey);
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
    } catch (e) {
      debugPrint('[ChatNotifier] enqueue pending item failed: $e');
    }
  }

  Future<void> _flushPending(String key) async {
    if (!MessagingFacade.instance.isOnline) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final items = decoded.cast<dynamic>().toList();
      if (items.isEmpty) return;

      for (final it in items) {
        if (it is! Map<String, dynamic>) continue;
        final map = it.cast<String, dynamic>();
        final messageId = map['id']?.toString() ?? Xid().toString();

        AppEventBus.fire(
          WebSocketMessageSendRequestEvent(
            message: json.encode(map),
            messageId: messageId,
          ),
        );

        final type = map['type']?.toString() ?? 'C2C';
        MessageRetry.instance.addToRetryQueue(messageId, type);
      }

      await sp.setString(key, '[]');
    } catch (e) {
      debugPrint('[ChatNotifier] flush pending messages failed: $e');
    }
  }

  /// 阅后即焚相关
  Future<void> cleanupExpiredBurnMessagesForConversation(
    ConversationModel conversation, {
    int scanLimit = 30,
  }) async {
    // 阅后即焚清理逻辑（简化版）
    iPrint('阅后即焚清理: ${conversation.uk3}');
  }

  // ===== 语音播放 =====

  /// 播放语音
  ///
  /// 重构：委托给 ChatAudioHandler 处理
  Future<void> playVoice({
    required String voiceUrlOrPath,
    required String messageId,
    required int duration,
  }) async {
    // 使用新的处理器（推荐）
    await _audioHandler.playVoice(
      voiceUrlOrPath: voiceUrlOrPath,
      messageId: messageId,
      duration: duration,
    );
  }

  /// 暂停播放
  ///
  /// 重构：委托给 ChatAudioHandler 处理
  Future<void> pauseVoice() async {
    await _audioHandler.pauseVoice();
  }

  /// 继续播放
  ///
  /// 重构：委托给 ChatAudioHandler 处理
  Future<void> resumeVoice() async {
    await _audioHandler.resumeVoice();
  }

  /// 停止播放
  ///
  /// 重构：委托给 ChatAudioHandler 处理
  Future<void> stopCurrentVoice() async {
    await _audioHandler.stopCurrentVoice();
  }

  /// 查找下一条语音消息
  ///
  /// 重构：委托给 ChatAudioHandler 处理
  Future<MessageModel?> findNextAudioMessage(String messageId) async {
    return await _audioHandler.findNextAudioMessage(messageId);
  }

  /// 播放下一条语音消息
  ///
  /// 重构：委托给 ChatAudioHandler 处理
  Future<void> _playNextAudioMessage(String currentMessageId) async {
    await _audioHandler.playNextAudioMessage(
      currentMessageId,
      onPlayNext: (messageId, path, duration) async {
        await playVoice(
          voiceUrlOrPath: path,
          messageId: messageId,
          duration: duration,
        );
      },
    );
  }

  // ===== 文件操作 =====

  /// 保存文件
  Future<void> saveFile(String name, String uri) async {
    File? tmpF = await IMBoyCacheManager().getSingleFile(
      uri,
      validateImageData: false, // 文件保存不验证图片格式
    );

    String ext = StringHelper.ext(uri);
    MimeType? mt = MimeType.get(ext.toUpperCase());

    String? path = await FileSaver.instance.saveAs(
      name: name,
      file: tmpF,
      fileExtension: ext,
      mimeType: mt ?? MimeType.get('Other')!,
    );

    if (path != null) {
      EasyLoading.showToast(t.saveSuccess);
    }
  }

  // ===== 群组操作 =====

  /// 获取群组标题
  Future<String> groupTitle(String gid, String prefix, int num) async {
    String prefix2 = strNoEmpty(prefix) ? prefix : t.groupChat;
    if (num > 0) {
      return "$prefix2($num)";
    } else {
      GroupModel? g = await GroupDetailService().detail(gid: gid);
      final memberCount = g?.memberCount ?? 0;
      if (memberCount > 0) {
        return "$prefix2($memberCount)";
      }
      return prefix2;
    }
  }

  // ===== 重试机制 =====

  /// 重试发送失败的消息
  Future<bool> retryMessage(String messageId, String messageType) async {
    try {
      iPrint('开始重试消息: $messageId');

      final success = await MessageRetry.instance.retryMessage(
        messageId,
        messageType,
      );

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

  // ===== 消息反应 =====

  Future<bool?> toggleReaction({
    required String chatType,
    required String peerId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      final repo = MessagingFacade.instance.getMessageRepo(chatType);
      final msg = await repo.find(messageId);
      if (msg == null) return null;
      final currentUid = UserRepoLocal.to.currentUid;

      final newPayload = Map<String, dynamic>.from(msg.payload as Map<dynamic, dynamic>);
      final reactionsRaw = newPayload['reactions'];
      final reactions = reactionsRaw is Map<String, dynamic>
          ? reactionsRaw.cast<String, dynamic>()
          : <String, dynamic>{};
      final usersRaw = reactions[emoji];
      final users = usersRaw is List
          ? usersRaw.map((e) => e.toString()).toList()
          : <String>[];

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
      await repo.update({'id': messageId, 'payload': json.encode(newPayload)});

      final updatedMsg = await repo.find(messageId);
      if (updatedMsg != null) {
        AppEventBus.fireData([
          await updatedMsg.toTypeMessage(),
        ], 'List<Message>');
      }

      final now = DateTimeHelper.millisecond();
      // v2.0: 字段提升到顶层
      final actionMessage = <String, dynamic>{
        'id': Xid().toString(),
        'type': chatType,
        'from': currentUid,
        'to': peerId,
        // v2.0: msg_type/action 提升到顶层
        'msg_type': 'custom',
        'action': 'message_reaction',
        'e2ee': '',
        // v2.0: payload 只包含内容
        'payload': {
          'original_msg_id': messageId,
          'emoji': emoji,
          'op': isAdd ? 'add' : 'remove',
          'user_id': currentUid,
          'reacted_at': now,
        },
        'created_at': now,
      };

      AppEventBus.fire(
        WebSocketMessageSendRequestEvent(
          message: json.encode(actionMessage),
          messageId: actionMessage['id']?.toString(),
        ),
      );

      MessageRetry.instance.addToRetryQueue(
        actionMessage['id'].toString(),
        chatType,
      );

      return isAdd;
    } catch (_) {
      return null;
    }
  }

  Future<void> _flushPendingReactions() async {
    await _flushPending(_spPendingReactionsKey);
  }

  // ===== 清理方法 =====

  Future<void> _cleanupDeletedMessageIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deleted = prefs.getStringList(_spDeletedMessageIdsKey) ?? [];
      final nowMs = DateTimeHelper.millisecond();
      final cleaned = <String>[];
      for (final entry in deleted) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          final deletedAt = int.tryParse(parts[1]) ?? 0;
          if (nowMs - deletedAt < _deletedMessageRetentionMs) {
            cleaned.add(entry);
          }
        }
      }
      await prefs.setStringList(_spDeletedMessageIdsKey, cleaned);
      iPrint('清理已删除消息ID记录完成: ${deleted.length} -> ${cleaned.length}');
    } catch (e) {
      iPrint('清理已删除消息ID记录失败: $e');
    }
  }

  // ===== 消息菜单 =====

  List<popupmenu.MenuItemProvider> getPopupMenuItems(Message message) {
    List<popupmenu.MenuItemProvider> items = [];

    bool canCopy = false;
    String msgType = message.metadata?['msg_type'] as String? ?? '';
    if (message is TextMessage) {
      canCopy = true;
    } else if (msgType == MessageType.quote) {
      canCopy = true;
    }

    if (canCopy) {
      items.add(
        popupmenu.MenuItem(
          title: t.buttonCopy,
          userInfo: {"id": "copy", "msg": message},
          textAlign: TextAlign.center,
          image: const Icon(Icons.copy, size: 16, color: Color(0xffc5c5c5)),
        ),
      );
    }

    bool canSave = false;
    if (message is ImageMessage) {
      canSave = true;
    } else if (message is FileMessage) {
      canSave = true;
    } else if (msgType == MessageType.video || msgType == MessageType.voice) {
      canSave = true;
    }

    if (canSave) {
      items.add(
        popupmenu.MenuItem(
          title: t.buttonSave,
          userInfo: {"id": "save", "msg": message},
          textAlign: TextAlign.center,
          textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
          image: const Icon(Icons.save_alt, size: 16, color: Color(0xffc5c5c5)),
        ),
      );
    }

    bool canCollect = UserCollectHelper.getCollectKind(message) > 0;
    if (canCollect) {
      items.add(
        popupmenu.MenuItem(
          title: t.favorites,
          userInfo: {"id": "collect", "msg": message},
          textAlign: TextAlign.center,
          textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
          image: const Icon(
            Icons.collections_bookmark,
            size: 16,
            color: Color(0xffc5c5c5),
          ),
        ),
      );
    }

    final msgTypeForMenu = message.metadata?['msg_type']?.toString() ?? '';
    bool isRevoked =
        (message is CustomMessage) &&
        msgTypeForMenu.toUpperCase().contains('REVOKE');
    if (msgTypeForMenu == MessageType.webrtcAudio ||
        msgTypeForMenu == MessageType.webrtcVideo) {
      isRevoked = true;
    }

    if (!isRevoked) {
      items.add(
        popupmenu.MenuItem(
          title: t.forward,
          userInfo: {"id": "transpond", "msg": message},
          textAlign: TextAlign.center,
          textStyle: const TextStyle(fontSize: 10.0, color: Color(0xffc5c5c5)),
          image: const Icon(Icons.moving, color: Color(0xffc5c5c5)),
        ),
      );
      items.add(
        popupmenu.MenuItem(
          title: t.quote,
          userInfo: {"id": "quote", "msg": message},
          textAlign: TextAlign.center,
          image: const Icon(
            Icons.format_quote,
            size: 16,
            color: Color(0xffc5c5c5),
          ),
        ),
      );
    }

    if (message.authorId == UserRepoLocal.to.currentUid && !isRevoked) {
      items.add(
        popupmenu.MenuItem(
          title: t.revoke,
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

    items.add(
      popupmenu.MenuItem(
        title: t.buttonDelete,
        userInfo: {"id": "delete", "msg": message},
        textAlign: TextAlign.center,
        textStyle: const TextStyle(color: Color(0xffc5c5c5), fontSize: 10.0),
        image: const Icon(
          Icons.remove_circle_outline_rounded,
          size: 16,
          color: Color(0xffc5c5c5),
        ),
      ),
    );

    return items;
  }

  // ===== 系统提示 =====

  String parseSysPrompt(String sysPrompt) {
    if (sysPrompt == 'in_denylist') {
      sysPrompt = t.sendMsgRejected;
    } else if (sysPrompt == 'not_a_friend') {
      sysPrompt = t.sendMsgNotFriendTips;
    }
    return sysPrompt;
  }

  Future<void> setSysPrompt(
    String tableName,
    String msgId,
    String sysPrompt,
  ) async {
    var repo = MessageRepo(tableName: tableName);
    MessageModel? msg = await repo.find(msgId);
    if (msg == null) return;
    Map<String, dynamic> payload = msg.payload as Map<String, dynamic>;
    // WebSocket API v2.0: 从顶层 msgType 字段读取，不再从 payload 读取
    payload['msg_type'] = msg.msgType ?? 'text';
    payload['sys_prompt'] = sysPrompt;

    await repo.update({
      'id': msgId,
      MessageRepo.status: IMBoyMessageStatus.error,
      MessageRepo.payload: payload,
    });

    msg.status = IMBoyMessageStatus.error;
    msg.payload = payload;

    AppEventBus.fireData([await msg.toTypeMessage()], 'List<Message>');

    await ref.read(conversationProvider.notifier).updateConversationByMsgId(
      msgId,
      {
        ConversationRepo.payload: {'sys_prompt': sysPrompt},
        ConversationRepo.lastMsgStatus: IMBoyMessageStatus.sent,
      },
    );
  }

  // ===== 资源清理 =====

  void _dispose() {
    if (_isDisposed) return;

    iPrint('开始释放 Chat 资源...');

    // 取消定时器
    _readReceiptFlushTimer?.cancel();
    _cleanupDeletedMessageIdsTimer?.cancel();

    // 释放阅后即焚定时器
    for (final timer in _burnDeleteTimers.values) {
      timer.cancel();
    }
    _burnDeleteTimers.clear();

    for (final timer in _burnPurgeTimers.values) {
      timer.cancel();
    }
    _burnPurgeTimers.clear();

    // 释放音频播放器
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    try {
      _globalPlayerController?.dispose();
    } catch (e) {
      iPrint('释放 PlayerController 失败: $e');
    }
    _globalPlayerController = null;

    // 释放备用音频播放器
    _justAudioStateSubscription?.cancel();
    _justAudioPositionSubscription?.cancel();
    _audioPlayer?.dispose();
    _audioPlayer = null;

    // 释放聊天控制器
    try {
      _chatService?.setMessages([]);
      _chatService?.dispose();
    } catch (e) {
      iPrint('Error disposing chat controller: $e');
    }

    // 取消订阅
    _ssMsgExt?.cancel();
    _ssMsg?.cancel();
    _ssMsgState?.cancel();
    _ssReEdit?.cancel();
    _connectivitySubscription?.cancel();

    _isDisposed = true;
    iPrint('Chat 资源释放完成');
  }

  /// 标记为已释放
  void markAsDisposed() {
    _isDisposed = true;
    iPrint('Chat 已标记为已释放状态');
  }

  /// 重置释放状态
  void resetDisposedState() {
    _isDisposed = false;
    iPrint('Chat 已重置释放状态，允许重新初始化');
  }

  // ===== 消息定位功能 =====

  /// 加载指定消息及其前后的消息
  Future<void> loadMessagesAround(
    ConversationModel obj,
    String msgId, {
    int count = 20,
  }) async {
    final tb = MessageRepo.getTableName(obj.type);
    final repo = MessageRepo(tableName: tb);

    // 1. 获取目标消息
    final targetMsgModel = await repo.find(msgId);
    if (targetMsgModel == null) {
      // 消息不存在，回退到普通加载
      await loadMoreMessages(obj, isInitial: true);
      return;
    }

    // 2. 获取较旧的消息 (包括 targetMsg)
    final olderMessages = await repo.pageForConversation(
      obj.uk3,
      targetMsgModel.autoId,
      count,
    );

    // 3. 获取较新的消息 (不包含 targetMsg)
    final newerMessages = await repo.pageNewerForConversation(
      obj.uk3,
      targetMsgModel.autoId,
      count,
    );

    // 4. 组合列表
    final List<MessageModel> allModels = [
      ...olderMessages,
      targetMsgModel,
      ...newerMessages,
    ];

    // 转换模型
    final messages = await Future.wait(
      allModels.map((item) async => await item.toTypeMessage()),
    );

    // 设置分页标记 - 向下加载更多(更旧)
    int nextAutoId;
    if (olderMessages.isNotEmpty) {
      nextAutoId = olderMessages.first.autoId;
    } else {
      nextAutoId = targetMsgModel.autoId;
    }

    // 设置分页标记 - 向上加载更多(更新)
    int prevAutoId;
    if (newerMessages.isNotEmpty) {
      prevAutoId = newerMessages.last.autoId;
    } else {
      prevAutoId = targetMsgModel.autoId;
    }

    // 更新状态
    state = state.copyWith(
      nextAutoId: nextAutoId,
      prevAutoId: prevAutoId,
      currentConversationId: obj.uk3,
    );

    // 设置消息列表
    // 禁用动画，确保 setMessages 立即生效，避免动画干扰后续的滚动定位
    _chatService?.setMessages(messages.toList(), animated: false);

    // 缓存消息位置，便于后续定位
    _cacheMessagePositionsForConversation(obj.uk3, messages, msgId);
  }

  /// 缓存会话的消息位置
  void _cacheMessagePositionsForConversation(
    String conversationUk3,
    List<Message> messages,
    String targetMsgId,
  ) {
    try {
      final scrollManager = ref.read(messageScrollManagerProvider.notifier);

      // 计算目标消息的大概位置
      final targetIndex = messages.indexWhere((m) => m.id == targetMsgId);
      if (targetIndex == -1) return;

      // 估算每个消息的平均高度
      const double averageMessageHeight = 80.0;

      // 为消息列表中的每个消息估算位置
      for (int i = 0; i < messages.length; i++) {
        final message = messages[i];
        // 计算相对位置：目标消息位置 + 偏移量
        final offsetFromTarget = (i - targetIndex) * averageMessageHeight;
        final estimatedPosition =
            (targetIndex * averageMessageHeight) + offsetFromTarget;

        // 缓存位置，确保为正数
        final position = estimatedPosition.clamp(0.0, double.infinity);
        scrollManager.cacheMessagePosition(
          conversationUk3,
          message.id,
          position,
        );
      }

      iPrint('缓存了 ${messages.length} 条消息的位置，目标消息索引: $targetIndex');
    } catch (e) {
      iPrint('缓存消息位置失败: $e');
    }
  }

  /// 加载较新的消息（用于双向分页）
  Future<List<Message>> loadNewerMessages(ConversationModel obj) async {
    // 防止重复加载
    if (state.isLoadingNewer) {
      iPrint('正在加载较新消息，跳过');
      return [];
    }

    state = state.copyWith(isLoadingNewer: true);

    try {
      final tb = MessageRepo.getTableName(obj.type);
      final repo = MessageRepo(tableName: tb);
      final prevAutoId = state.prevAutoId;
      final pageSize = state.pageSize;

      iPrint(
        'loadNewerMessages: uk3=${obj.uk3}, prevAutoId=$prevAutoId, pageSize=$pageSize',
      );

      // 从数据库查询较新的消息
      final items = await repo.pageNewerForConversation(
        obj.uk3,
        prevAutoId,
        pageSize,
      );

      if (items.isEmpty) {
        iPrint('loadNewerMessages: 没有较新的消息');
        state = state.copyWith(isLoadingNewer: false);
        return [];
      }

      final nowMs = DateTimeHelper.millisecond();
      final kept = <MessageModel>[];
      for (final item in items) {
        final payload = item.payload as Map<String, dynamic>;
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
            await _sendWsMsg(item);
          }
          return await item.toTypeMessage();
        }),
      );

      // 去重处理
      final currentIds =
          _chatService?.messages.map((e) => e.id).toSet() ?? <String>{};
      final newItems = messages
          .where((msg) => !currentIds.contains(msg.id))
          .toList();

      if (newItems.isNotEmpty) {
        _chatService?.insertAllMessages(newItems);
        state = state.copyWith(
          prevAutoId: newItems.last.metadata?['auto_id'] as int? ?? state.prevAutoId,
        );
      }

      state = state.copyWith(isLoadingNewer: false);
      return newItems;
    } catch (e) {
      iPrint('loadNewerMessages error: $e');
      state = state.copyWith(isLoadingNewer: false);
      return [];
    }
  }

  // ===== 消息历史（conv_seq 游标，msg_store 永久存储）=====

  /// 从服务端 msg_store 拉取历史消息（conv_seq 游标分页）
  ///
  /// 适用场景：运营平台开启了 `msg_archive_enabled` 时，客户端可通过此接口
  /// 查阅永久存储的消息历史，不受本地 SQLite 数据影响。
  ///
  /// - [chatType]  'c2c' 或 'c2g'
  /// - [peerId]    对端 ID
  /// - [limit]     每页条数，默认 50
  ///
  /// 返回拉到的消息列表（原始 `Map<String, dynamic>`），同时更新 [state.lastHistorySeq] 和
  /// [state.historyHasMore] 用于下一次翻页。
  Future<List<Map<String, dynamic>>> loadHistory({
    required String chatType,
    required String peerId,
    int limit = 50,
  }) async {
    if (!state.historyHasMore) {
      iPrint('loadHistory: 没有更多历史消息');
      return [];
    }
    if (state.isLoading) {
      iPrint('loadHistory: 正在加载中，跳过');
      return [];
    }

    state = state.copyWith(isLoading: true);
    try {
      final result = await MsgApi().history(
        chatType: chatType.toLowerCase(),
        peerId: peerId,
        afterSeq: state.lastHistorySeq,
        limit: limit,
      );

      if (result == null) {
        iPrint('loadHistory: 请求失败或 msg_archive_enabled=false');
        state = state.copyWith(isLoading: false, historyHasMore: false);
        return [];
      }

      final messages =
          (result['messages'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList(growable: false) ??
          const [];

      final nextSeq =
          (result['next_seq'] as num?)?.toInt() ?? state.lastHistorySeq;
      final hasMore = (result['has_more'] as bool?) ?? false;

      state = state.copyWith(
        isLoading: false,
        lastHistorySeq: nextSeq,
        historyHasMore: hasMore,
      );

      iPrint(
        'loadHistory: 拉到 ${messages.length} 条，nextSeq=$nextSeq, hasMore=$hasMore',
      );
      return messages;
    } catch (e) {
      iPrint('loadHistory error: $e');
      state = state.copyWith(isLoading: false);
      return [];
    }
  }

  /// 重置历史游标（切换会话时调用）
  void resetHistoryCursor() {
    state = state.copyWith(lastHistorySeq: 0, historyHasMore: true);
  }

  /// 滚动到指定消息
  Future<void> scrollToMessage(String chatType, String messageId) async {
    try {
      if (_chatService == null || _chatService!.isDisposed) {
        iPrint('聊天控制器未初始化或已释放，无法滚动');
        return;
      }

      // 确保消息列表已加载
      if (_chatService!.messages.isEmpty) {
        iPrint("消息列表为空，无法滚动");
        return;
      }

      // 查找目标消息在列表中的索引
      final messages = _chatService!.messages;
      final targetIndex = messages.indexWhere((m) => m.id == messageId);

      if (targetIndex == -1) {
        debugPrint("未找到目标消息: $messageId");
        return;
      }

      debugPrint(
        "找到目标消息: $messageId, 索引: $targetIndex, 总消息数: ${messages.length}",
      );

      // 使用聊天控制器的滚动方法
      await _chatService?.scrollToMessage(
        messageId,
        duration: const Duration(milliseconds: 500),
        offset: 100.0,
      );

      // 高亮消息
      ref
          .read(messageScrollManagerProvider.notifier)
          .highlightMessage(messageId);
    } catch (e) {
      debugPrint("滚动到目标消息失败: $e");
    }
  }

  /// 更新会话信息（撤回消息后）
  Future<void> updateConversationAfterRevoke(
    ConversationModel conversation,
    String msgId,
  ) async {
    try {
      final repo = ConversationRepo();
      final tb = MessageRepo.getTableName(conversation.type);
      final mRepo = MessageRepo(tableName: tb);

      // 获取最后一条消息
      final items = await mRepo.page(
        conversationUk3: conversation.uk3,
        page: 1,
        size: 1,
      );

      if (items.isEmpty) {
        // 没有消息了，清空会话信息
        await repo.updateById(conversation.id, {
          ConversationRepo.lastMsgId: '',
          ConversationRepo.lastMsgStatus: 0,
          ConversationRepo.msgType: 'empty',
          ConversationRepo.subtitle: '',
        });
      } else {
        // 更新为最后一条消息
        final lastMsg = items[0];
        // 直接从 MessageModel 读取，避免 toTypeMessage 转换
        await repo.updateById(conversation.id, {
          ConversationRepo.lastMsgId: lastMsg.id,
          ConversationRepo.lastMsgStatus: lastMsg.status,
          ConversationRepo.lastTime: lastMsg.createdAt,
          ConversationRepo.msgType: MessageModel.conversationMsgTypeFromModel(
            lastMsg,
          ),
          ConversationRepo.subtitle: MessageModel.conversationSubtitleFromModel(
            lastMsg,
          ),
        });
      }

      // 触发会话更新事件
      final updated = await repo.findById(conversation.id);
      if (updated != null) {
        AppEventBus.fireData(updated);
      }
    } catch (e) {
      iPrint('更新会话信息失败: $e');
    }
  }

  /// 检查并重试发送中的消息
  Future<void> checkAndRetrySendingMessages(
    ConversationModel conversation,
  ) async {
    try {
      final tb = MessageRepo.getTableName(conversation.type);
      final repo = MessageRepo(tableName: tb);

      // 查询消息
      final items = await repo.page(
        conversationUk3: conversation.uk3,
        page: 1,
        size: 50,
      );

      if (items.isEmpty) return;

      // 过滤出发送中的消息
      final sendingItems = items
          .where((item) => item.status == IMBoyMessageStatus.sending)
          .toList();

      if (sendingItems.isEmpty) return;

      iPrint('找到 ${sendingItems.length} 条发送中的消息，开始重试');

      for (final item in sendingItems) {
        if (item.status == IMBoyMessageStatus.sending) {
          await _sendWsMsg(item);
        }
      }
    } catch (e) {
      iPrint('检查并重试发送中的消息失败: $e');
    }
  }

  // ===== 阅后即焚相关辅助方法 =====

  /// 检查是否是阅后即焚消息（公共静态方法，供其他模块使用）
  static bool isBurnPayload(Map<String, dynamic> payload) {
    return payload['burn'] == true || payload['is_burn'] == true;
  }

  bool _isBurnPayload(Map<String, dynamic> payload) {
    return isBurnPayload(payload);
  }

  bool _isBurnTombstonePayload(Map<String, dynamic> payload) {
    return payload['burn_deleted'] == true;
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

  Future<void> _ensureBurnTimerForItem({
    required ConversationModel conversation,
    required MessageRepo repo,
    required MessageModel item,
    required int nowMs,
  }) async {
    final payload = item.payload as Map<String, dynamic>;
    if (!_isBurnPayload(payload)) return;
    if (_isBurnTombstonePayload(payload)) return;
    final burnAfter = _burnAfterMsFromPayload(payload);
    if (burnAfter <= 0) return;

    int readAt = _burnReadAtMsFromPayload(payload);
    if (readAt <= 0 && item.status == IMBoyMessageStatus.seen) {
      readAt = nowMs;
      payload['burn_read_at'] = readAt;
      final messageId = item.id;
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
        messageId: item.id,
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
      final payload = item.payload as Map<String, dynamic>;
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
      if (conversation.lastMsgId.toString() != hiddenMessageId) return;
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
            : DateTimeHelper.millisecond();
        await repo.updateById(conversation.id, {
          ConversationRepo.lastMsgId: 0,
          ConversationRepo.lastMsgStatus: 0,
          ConversationRepo.msgType: 'empty',
          ConversationRepo.lastTime: conversationTime,
          ConversationRepo.subtitle: '',
        });
      } else {
        // 直接从 MessageModel 读取，避免 toTypeMessage 转换
        await repo.updateById(conversation.id, {
          ConversationRepo.lastMsgId: latest.id,
          ConversationRepo.lastMsgStatus: latest.status,
          ConversationRepo.lastTime: latest.createdAt,
          ConversationRepo.msgType: MessageModel.conversationMsgTypeFromModel(
            latest,
          ),
          ConversationRepo.subtitle: MessageModel.conversationSubtitleFromModel(
            latest,
          ),
        });
      }

      final updated = await repo.findById(conversation.id);
      if (updated != null) {
        AppEventBus.fireData(updated);
      }
    } catch (e) {
      debugPrint(
        '[ChatNotifier] update conversation last message after burn hidden failed: $e',
      );
    }
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
    // 防止内存泄漏： 超过上限时移除最早的定时器
    if (_burnDeleteTimers.length >= _maxBurnTimers) {
      final oldestKey = _burnDeleteTimers.keys.first;
      _burnDeleteTimers.remove(oldestKey)?.cancel();
    }
    _burnDeleteTimers[messageId] = Timer(
      Duration(milliseconds: delayMs),
      () async {
        await _deleteBurnMessage(conversation, messageId);
      },
    );
  }

  Future<void> _deleteBurnMessage(
    ConversationModel conversation,
    String messageId,
  ) async {
    try {
      final tb = MessageRepo.getTableName(conversation.type);
      final repo = MessageRepo(tableName: tb);
      final m = await repo.find(messageId);
      if (m == null) {
        try {
          if (_chatService?.isDisposed != true) {
            await _chatService?.removeMessageById(messageId);
          }
        } catch (e) {
          debugPrint(
            '[ChatNotifier] remove orphan burn message from chat service failed: $e',
          );
        }
        return;
      }
      await expireBurnMessage(conversation, messageId);
    } catch (e) {
      debugPrint('[ChatNotifier] delete burn message failed: $e');
    }
    _burnDeleteTimers.remove(messageId)?.cancel();
  }

  /// 标记阅后即焚消息为已读
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
      final payload = Map<String, dynamic>.from(m.payload as Map<dynamic, dynamic>);
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
        AppEventBus.fireData([await updated.toTypeMessage()], 'List<Message>');
      }
    } catch (e) {
      debugPrint('[ChatNotifier] mark burn read at failed: $e');
    }
  }

  /// 过期阅后即焚消息
  Future<void> expireBurnMessage(
    ConversationModel conversation,
    String messageId, {
    int? deletedAtMs,
  }) async {
    try {
      final tb = MessageRepo.getTableName(conversation.type);
      final repo = MessageRepo(tableName: tb);

      final m = await repo.find(messageId);
      if (m == null) {
        try {
          if (_chatService?.isDisposed != true) {
            await _chatService?.removeMessageById(messageId);
          }
        } catch (e) {
          debugPrint(
            '[ChatNotifier] remove missing burn message from chat service failed: $e',
          );
        }
        return;
      }

      final payload = Map<String, dynamic>.from(m.payload as Map<dynamic, dynamic>);
      if (!_isBurnPayload(payload)) {
        await removeMessage(conversation, await m.toTypeMessage());
        return;
      }

      // 直接从数据库删除，不使用墓碑标记
      // 从重试队列中移除该消息
      MessageRetry.instance.removeFromRetryQueue(messageId);
      await repo.delete(messageId);

      // 记录已删除的消息ID，防止服务端重复投递
      await _recordDeletedMessageId(messageId);

      try {
        if (_chatService?.isDisposed != true) {
          await _chatService?.removeMessageById(messageId);
        }
      } catch (e) {
        debugPrint(
          '[ChatNotifier] remove expired burn message from chat service failed: $e',
        );
      }

      await _updateConversationLastMessageAfterBurnHidden(
        conversation,
        repo,
        hiddenMessageId: messageId,
      );
    } catch (e) {
      debugPrint('[ChatNotifier] expire burn message failed: $e');
    }
  }

  /// 记录已删除的消息ID
  Future<void> _recordDeletedMessageId(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deleted = prefs.getStringList(_spDeletedMessageIdsKey) ?? [];
      final nowMs = DateTimeHelper.millisecond();
      final entry = '$messageId:$nowMs';
      deleted.add(entry);
      await prefs.setStringList(_spDeletedMessageIdsKey, deleted);
      iPrint('记录已删除消息ID: $messageId');
    } catch (e) {
      iPrint('记录已删除消息ID失败: $e');
    }
  }

  /// 检查消息ID是否已被删除
  static Future<bool> isMessageDeleted(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deleted = prefs.getStringList(_spDeletedMessageIdsKey) ?? [];
      final nowMs = DateTimeHelper.millisecond();
      for (final entry in deleted) {
        final parts = entry.split(':');
        if (parts.length == 2 && parts[0] == messageId) {
          final deletedAt = int.tryParse(parts[1]) ?? 0;
          // 如果删除时间超过保留期，则忽略
          if (nowMs - deletedAt >= _deletedMessageRetentionMs) {
            return false;
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      iPrint('检查消息删除状态失败: $e');
      return false;
    }
  }

  // ===== 语音播放状态 Getters =====

  /// 检查是否是当前正在播放的消息
  bool isCurrentPlayingMessage(String voiceUrlOrPath) {
    final playbackState = voicePlaybackState;
    return playbackState.currentAudioPath == voiceUrlOrPath &&
        playbackState.isPlaying;
  }

  /// 检查是否是当前正在暂停的消息
  bool isCurrentPausedMessage(String voiceUrlOrPath) {
    final playbackState = voicePlaybackState;
    return playbackState.currentAudioPath == voiceUrlOrPath &&
        playbackState.isPaused;
  }

  /// 获取当前播放进度（0.0 到 1.0）
  double? getCurrentPlaybackProgress() {
    final playbackState = voicePlaybackState;
    if (playbackState.currentDuration == 0) {
      return null;
    }
    return playbackState.currentPosition / playbackState.currentDuration;
  }

  /// 获取当前播放位置
  int getCurrentPlaybackPosition() {
    return voicePlaybackState.currentPosition;
  }

  /// 检查当前是否正在播放语音
  bool get isPlayingVoice => voicePlaybackState.isPlaying;

  /// 检查当前是否处于暂停状态
  bool get isPausedVoice => voicePlaybackState.isPaused;

  /// 获取当前播放的消息ID
  String get currentPlayingMessageId => voicePlaybackState.currentMessageId;

  // ===== 队列管理公共方法 =====

  /// 添加反应动作到队列
  Future<void> enqueueReactionAction(Map<String, dynamic> actionMessage) async {
    await _enqueuePending(_spPendingReactionsKey, actionMessage);
    await _flushPendingReactions();
  }

  /// 刷新待处理的反应
  Future<void> flushPendingReactions() async {
    await _flushPending(_spPendingReactionsKey);
  }

  // ===== 调试方法 =====

  /// 调试音频播放状态
  void debugAudioState() {
    iPrint('=== Audio Debug Info ===');
    final playbackState = voicePlaybackState;
    iPrint('Current Audio Path: ${playbackState.currentAudioPath}');
    iPrint('Current Message ID: ${playbackState.currentMessageId}');
    iPrint('Is Playing: ${playbackState.isPlaying}');
    iPrint('Is Paused: ${playbackState.isPaused}');
    iPrint('Current Position: ${playbackState.currentPosition}ms');
    iPrint('Current Duration: ${playbackState.currentDuration}ms');
    iPrint('Chat Controller: ${_chatService != null ? "initialized" : "null"}');
    if (_chatService != null) {
      iPrint('Messages Count: ${_chatService!.messages.length}');
    }
    iPrint('Is Disposed: $_isDisposed');
    iPrint('========================');
  }
}

/// 文本流消息的实时状态管理
///
/// Key: message.id (TextStreamMessage 的唯一标识)
/// Value: 当前流状态 (loading / streaming / completed / error)
///
/// 使用方式：
///   - AI 发送新流消息时：startStream(messageId)
///   - 每次收到 chunk：updateStream(messageId, accumulatedText)
///   - 流结束时：completeStream(messageId, finalText)
///   - 出错时：errorStream(messageId, error)
class ChatStreamStateNotifier extends Notifier<Map<String, StreamState>> {
  @override
  Map<String, StreamState> build() => {};

  /// 开始新的流（初始 Loading 状态）
  void startStream(String messageId) {
    state = {...state, messageId: const StreamStateLoading()};
  }

  /// 更新流中的累计文本
  void updateStream(String messageId, String accumulatedText) {
    state = {...state, messageId: StreamStateStreaming(accumulatedText)};
  }

  /// 标记流已完成
  void completeStream(String messageId, String finalText) {
    state = {...state, messageId: StreamStateCompleted(finalText)};
  }

  /// 标记流出错
  void errorStream(String messageId, Object error, {String? partial}) {
    state = {
      ...state,
      messageId: StreamStateError(error, accumulatedText: partial),
    };
  }

  /// 获取指定消息的流状态
  StreamState getState(String messageId) {
    return state[messageId] ?? const StreamStateLoading();
  }

  /// 清除已完成的流（节省内存）
  void clearCompleted() {
    state = Map<String, StreamState>.fromEntries(
      state.entries.where((e) => e.value is! StreamStateCompleted),
    );
  }
}

/// 全局文本流消息状态 Provider
final chatStreamStateNotifierProvider =
    NotifierProvider<ChatStreamStateNotifier, Map<String, StreamState>>(
      ChatStreamStateNotifier.new,
    );
