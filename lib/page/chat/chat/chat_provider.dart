import 'dart:async';
import 'dart:convert';
import 'dart:io';

export 'package:imboy/page/chat/chat/chat_stream_state_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:xid/xid.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:file_saver/file_saver.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/string.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/chat/message_scroll_provider.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/chat/services/message_handling_service.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/page/chat/chat/services/chat_burn_service.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';

import 'package:imboy/page/chat/chat/providers/chat_audio_handler.dart';
// 技术债清理 (#14): 统一 ChatState 来源，避免与 chat_state.dart 双份定义
import 'package:imboy/page/chat/chat/chat_state.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:imboy/service/storage.dart';
export 'package:imboy/page/chat/chat/chat_state.dart' show ChatState;

part 'chat_provider.g.dart';

/// 消息处理服务 Provider
@riverpod
MessageHandlingService messageHandlingService(Ref ref) {
  return const MessageHandlingService();
}

// 技术债 #14: ChatState 内部定义已删除，统一从 chat_state.dart import

/// 聊天 Provider（Riverpod Notifier 实现）
@riverpod
class ChatNotifier extends _$ChatNotifier {
  SqliteChatService? _chatService;
  PlayerController? _globalPlayerController;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<int>? _positionSubscription;
  bool _isDisposed = false;

  late final ChatAudioHandler _audioHandler;

  // Service instances
  final ChatNetworkService _networkService = const ChatNetworkService();
  final ChatBurnService _burnService = const ChatBurnService();
  final ChatArchiveService _archiveService = const ChatArchiveService();

  /// conv_seq 正向增量同步单会话在途标记，防重入（P1-2）
  bool _historySyncing = false;

  /// 单次进会话最多正向同步的页数（每页 50 条），有界避免大会话首开卡顿；
  /// 未追平的靠持久化游标下次进会话继续。
  static const int _historyMaxPagesPerOpen = 6;

  // SharedPreferences keys
  static const String _spPendingReadReceiptsKey =
      'imboy.pending_read_receipts.v1';
  static const String _spPendingReactionsKey = 'imboy.pending_reactions.v1';
  static const String _spDeletedMessageIdsKey = 'imboy.deleted_message_ids.v1';

  // Timers
  Timer? _readReceiptFlushTimer;
  Timer? _cleanupDeletedMessageIdsTimer;

  // Burn message timers（mixin 访问，去掉 _ 前缀以允许 service 持有引用）
  final Map<String, Timer> burnDeleteTimers = {};
  final Map<String, Timer> burnPurgeTimers = {};

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

    _audioHandler.setMessagesGetter(
      () => _chatService?.messages.toList() ?? [],
    );

    ref.onDispose(() {
      iPrint('Chat Provider: 执行 dispose');
      _dispose();
      _audioHandler.dispose();
    });

    final onlineSub = MessagingFacade.instance.onlineStatusStream.listen((
      online,
    ) {
      if (online) {
        _flushPendingReadReceipts();
        _flushPendingReactions();
      }
    });
    ref.onDispose(onlineSub.cancel);

    _cleanupDeletedMessageIdsTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _burnService.cleanupDeletedMessageIds(_spDeletedMessageIdsKey),
    );

    ref.listen<VoicePlaybackState>(voicePlaybackServiceProvider, (
      previous,
      next,
    ) {
      if (previous != null &&
          previous.isPlaying &&
          !next.isPlaying &&
          !next.isPaused) {
        final String finishedId = previous.currentMessageId;
        if (finishedId.isNotEmpty) {
          _playNextAudioMessage(finishedId);
        }
      }
    });

    return const ChatState();
  }

  /// 初始化网络状态监听
  void initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final bool isConnected = !results.contains(ConnectivityResult.none);
      if (!isDisposed) {
        state = state.copyWith(connected: isConnected);
      }
    });
  }

  // ===== Getters =====

  SqliteChatService? get chatService => _chatService;

  bool get isDisposed => _isDisposed;

  // ===== 初始化方法 =====

  void initChatService(String chatType) {
    final bool serviceExists = _chatService != null;
    final bool serviceDisposed = _chatService?.isDisposed ?? true;
    final int messageCount = _chatService?.messages.length ?? 0;

    iPrint(
      'initChatService: 检查状态 - serviceExists=$serviceExists, serviceDisposed=$serviceDisposed, messageCount=$messageCount',
    );

    if (!serviceExists || serviceDisposed) {
      if (serviceExists && serviceDisposed) {
        iPrint('initChatService: 聊天服务已释放，创建新实例');
      } else {
        iPrint('initChatService: 创建新的聊天服务');
      }
      _chatService = SqliteChatService(ref);
    } else {
      iPrint('initChatService: 聊天服务已存在，保留 $messageCount 条消息');
    }

    iPrint(
      'initChatService: 聊天服务初始化完成，当前消息数: ${_chatService?.messages.length ?? 0}',
    );
  }

  void syncMessagesToState() {
    final list = _chatService?.messages.toList() ?? const <Message>[];
    state = state.copyWith(messages: list);
  }

  // ===== 状态更新方法 =====

  void updateComposerHeight(double height) {
    state = state.copyWith(composerHeight: height);
  }

  void updateMemberCount(int count) {
    state = state.copyWith(memberCount: count);
  }

  void updateConnected(bool connected) {
    state = state.copyWith(connected: connected);
  }

  void updateNextAutoId(int id) {
    state = state.copyWith(nextAutoId: id);
  }

  void setCurrentConversationId(String id) {
    state = state.copyWith(currentConversationId: id);
  }

  // ===== 消息加载 =====

  Future<List<Message>> loadMoreMessages(
    ConversationModel obj, {
    bool isInitial = false,
  }) async {
    iPrint(
      '_loadMoreMessages: isInitial=$isInitial, hasMore=${state.hasMoreMessage}, loading=${state.isLoading}',
    );

    if (isInitial) {
      final String oldConversationId = state.currentConversationId;

      (_chatService?.messages.length ?? 0) > 0;
      final bool isStateReset = state.currentConversationId.isEmpty;

      final bool isDifferentConversation =
          !isStateReset && state.currentConversationId != obj.uk3;

      state = state.copyWith(
        nextAutoId: 0,
        prevAutoId: 0,
        hasMoreMessage: true,
        currentConversationId: obj.uk3,
      );

      // P1-2：进会话后台正向同步服务端归档历史入 SQLite（不阻塞首屏渲染）
      unawaited(syncHistoryBackfill(obj));

      if (isDifferentConversation) {
        _chatService?.setMessages([]);
        iPrint('切换会话: $oldConversationId -> ${obj.uk3}');
      } else {
        final int messageCount = _chatService?.messages.length ?? 0;
        iPrint(
          '会话初始化: ${obj.uk3}, 保留现有消息 ($messageCount 条), isStateReset=$isStateReset',
        );

        if (messageCount == 0) {
          iPrint('警告：会话初始化但消息列表为空，将重新加载');
        } else {
          iPrint('会话初始化：跳过加载，直接返回现有 $messageCount 条消息');
          return _chatService!.messages.toList();
        }
      }

      iPrint('设置当前会话ID: ${obj.uk3}');
    }

    if (state.isLoading) return [];

    if (!isInitial && !state.hasMoreMessage) {
      final int messageCount = _chatService?.messages.length ?? 0;
      if (messageCount > 0) {
        iPrint('没有更多消息，返回现有 $messageCount 条消息');
        return _chatService!.messages.toList();
      }
    }

    state = state.copyWith(isLoading: true);
    final items = await _pageMessages(obj, state.pageSize);
    state = state.copyWith(isLoading: false);

    syncMessagesToState();

    if (items.isEmpty) {
      state = state.copyWith(hasMoreMessage: false);
      return [];
    }

    final Set<String> currentIds =
        _chatService?.messages.map((e) => e.id).toSet() ?? <String>{};
    final List<Message> newItems = items
        .where((msg) => !currentIds.contains(msg.id))
        .toList();

    iPrint(
      'loadMoreMessages: items=${items.length}, currentIds=${currentIds.length}, newItems=${newItems.length}, isInitial=$isInitial',
    );

    if (newItems.isNotEmpty) {
      if (isInitial) {
        final service = _chatService;
        service?.setMessages(newItems);
        state = state.copyWith(
          nextAutoId: newItems.first.metadata?['auto_id'] as int? ?? 0,
          prevAutoId: newItems.last.metadata?['auto_id'] as int? ?? 0,
        );
      } else {
        _chatService?.insertAllMessages(newItems, index: 0);
        state = state.copyWith(
          nextAutoId:
              newItems.first.metadata?['auto_id'] as int? ?? state.nextAutoId,
        );
      }
    }

    return newItems;
  }

  Future<List<Message>> _pageMessages(ConversationModel obj, int size) async {
    final String tb = MessageRepo.getTableName(obj.type);
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
      return [];
    }

    final messages = await Future.wait(
      items.map((item) async {
        if (item.status == IMBoyMessageStatus.sending) {
          await _networkService.sendWsMsg(item);
        }
        return await item.toTypeMessage();
      }),
    );

    state = state.copyWith(nextAutoId: items.first.autoId);
    return messages.toList();
  }

  // ===== 消息发送（委托给 ChatNetworkService）=====

  Future<void> addMessage(
    String fromId,
    String toId,
    String? avatar,
    String title,
    String type,
    Message message, {
    bool sendToServer = true,
  }) async {
    await _networkService.addMessage(
      ref: ref,
      chatService: _chatService!,
      fromId: fromId,
      toId: toId,
      avatar: avatar,
      title: title,
      type: type,
      message: message,
      sendToServer: sendToServer,
      syncMessagesToState: () async => syncMessagesToState(),
    );
  }

  Future<bool> sendMessage(Map<String, dynamic> msg) async {
    return await _networkService.sendMessage(msg);
  }

  // ===== 消息操作 =====

  Future<bool> removeMessage(ConversationModel cm, Message msg) async {
    iPrint('removeMessage - 开始删除消息: ${msg.id}');

    burnDeleteTimers.remove(msg.id)?.cancel();

    try {
      MessageRetry.instance.removeFromRetryQueue(msg.id);
    } catch (e) {
      iPrint('[chat_provider] removeFromRetryQueue error: $e');
    }

    final ConversationRepo repo = ConversationRepo();
    final String tb = MessageRepo.getTableName(cm.type);
    final mRepo = MessageRepo(tableName: tb);

    final int deleteCount = await mRepo.delete(msg.id);

    if (deleteCount > 0) {
      try {
        if (_chatService?.isDisposed != true) {
          await _chatService?.removeMessageById(msg.id);
        }
      } catch (e) {
        iPrint('[chat_provider] removeMessageById error: $e');
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
        final int conversationTime = cm.lastTime > 0
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

    final String tb = MessageRepo.getTableName(c.type);
    final int newUnreadNum = c.unreadNum - msgIds.length;
    c.unreadNum = newUnreadNum > 0 ? newUnreadNum : 0;

    final bool res = await db.transaction((txn) async {
      await txn.update(
        ConversationRepo.tableName,
        {ConversationRepo.unreadNum: c.unreadNum},
        where: "${ConversationRepo.id}=?",
        whereArgs: [c.id],
      );

      for (final String id in msgIds) {
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
      final List<Message> updated = [];
      for (final String id in msgIds) {
        final m = await repo.find(id);
        if (m == null) continue;
        updated.add(await m.toTypeMessage());
      }
      if (updated.isNotEmpty) {
        AppEventBus.fireData(updated);
      }
    } catch (e) {
      iPrint('[chat_provider] fireData error: $e');
    }
  }

  Future<void> _enqueueReadReceipt({
    required String type,
    required String peerId,
    required List<String> msgIds,
  }) async {
    if (msgIds.isEmpty) return;
    final int now = DateTimeHelper.millisecond();
    final item = _networkService.buildReadReceiptItem(
      type,
      peerId,
      msgIds,
      now,
    );
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
      final String? raw = sp.getString(key);
      final list = raw == null
          ? <dynamic>[]
          : (jsonDecode(raw) is List ? (jsonDecode(raw) as List) : <dynamic>[]);
      list.add(item);
      await sp.setString(key, jsonEncode(list));
    } catch (e) {
      iPrint('[chat_provider] setString error: $e');
    }
  }

  Future<void> _flushPending(String key) async {
    if (!MessagingFacade.instance.isOnline) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final String? raw = sp.getString(key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final items = decoded.cast<dynamic>().toList();
      if (items.isEmpty) return;

      for (final it in items) {
        if (it is! Map<String, dynamic>) continue;
        final map = it.cast<String, dynamic>();
        final String messageId = map['id']?.toString() ?? Xid().toString();

        AppEventBus.fire(
          WebSocketMessageSendRequestEvent(
            message: json.encode(map),
            messageId: messageId,
          ),
        );

        final String type = map['type']?.toString() ?? 'C2C';
        MessageRetry.instance.addToRetryQueue(messageId, type);
      }

      await sp.setString(key, '[]');
    } catch (e) {
      iPrint('[chat_provider] setString error: $e');
    }
  }

  /// 阅后即焚清理
  Future<void> cleanupExpiredBurnMessagesForConversation(
    ConversationModel conversation, {
    int scanLimit = 30,
  }) async {
    iPrint('阅后即焚清理: ${conversation.uk3}');
  }

  // ===== 语音播放（委托给 ChatAudioHandler）=====

  Future<void> playVoice({
    required String voiceUrlOrPath,
    required String messageId,
    required int duration,
  }) async {
    await _audioHandler.playVoice(
      voiceUrlOrPath: voiceUrlOrPath,
      messageId: messageId,
      duration: duration,
    );
  }

  Future<void> pauseVoice() async {
    await _audioHandler.pauseVoice();
  }

  Future<void> resumeVoice() async {
    await _audioHandler.resumeVoice();
  }

  Future<void> stopCurrentVoice() async {
    await _audioHandler.stopCurrentVoice();
  }

  Future<MessageModel?> findNextAudioMessage(String messageId) async {
    return await _audioHandler.findNextAudioMessage(messageId);
  }

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

  Future<void> saveFile(String name, String uri) async {
    File? tmpF = await IMBoyCacheManager().getSingleFile(
      uri,
      validateImageData: false,
    );

    final String ext = StringHelper.ext(uri);
    final MimeType? mt = MimeType.get(ext.toUpperCase());

    final String? path = await FileSaver.instance.saveAs(
      name: name,
      file: tmpF,
      fileExtension: ext,
      mimeType: mt ?? MimeType.get('Other')!,
    );

    if (path != null) {
      AppLoading.showToast(t.common.saveSuccess);
    }
  }

  // ===== 群组操作 =====

  Future<String> groupTitle(String gid, String prefix, int num) async {
    return await _networkService.groupTitle(gid, prefix, num);
  }

  // ===== 重试机制 =====

  Future<bool> retryMessage(String messageId, String messageType) async {
    try {
      iPrint('开始重试消息: $messageId');
      final bool success = await MessageRetry.instance.retryMessage(
        messageId,
        messageType,
      );
      iPrint(success ? '消息重试成功: $messageId' : '消息重试失败: $messageId');
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
      final String currentUid = UserRepoLocal.to.currentUid;

      final newPayload = Map<String, dynamic>.from(
        msg.payload as Map<dynamic, dynamic>,
      );
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

      final int now = DateTimeHelper.millisecond();
      final actionMessage = <String, dynamic>{
        'id': Xid().toString(),
        'type': chatType,
        'from': currentUid,
        'to': peerId,
        'msg_type': 'custom',
        'action': 'message_reaction',
        'e2ee': '',
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

  // ===== 系统提示 =====

  String parseSysPrompt(String sysPrompt) {
    if (sysPrompt == 'in_denylist') {
      sysPrompt = t.chat.sendMsgRejected;
    } else if (sysPrompt == 'not_a_friend') {
      sysPrompt = t.common.sendMsgNotFriendTips;
    }
    return sysPrompt;
  }

  Future<void> setSysPrompt(
    String tableName,
    String msgId,
    String sysPrompt,
  ) async {
    final repo = MessageRepo(tableName: tableName);
    MessageModel? msg = await repo.find(msgId);
    if (msg == null) return;
    Map<String, dynamic> payload = msg.payload as Map<String, dynamic>;
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

  // ===== 阅后即焚（委托给 ChatBurnService）=====

  static bool isBurnPayload(Map<String, dynamic> payload) =>
      ChatBurnService.isBurnPayload(payload);

  Future<void> markBurnReadAt(
    ConversationModel conversation,
    String messageId, {
    required int readAtMs,
  }) async {
    await _burnService.markBurnReadAt(
      burnDeleteTimers: burnDeleteTimers,
      conversation: conversation,
      messageId: messageId,
      readAtMs: readAtMs,
      onDelete: (conv, msgId) => _deleteBurnMessage(conv, msgId),
    );
  }

  Future<void> expireBurnMessage(
    ConversationModel conversation,
    String messageId, {
    int? deletedAtMs,
  }) async {
    await _burnService.expireBurnMessage(
      chatService: _chatService,
      conversation: conversation,
      messageId: messageId,
      deletedMessageIdsKey: _spDeletedMessageIdsKey,
      onRemoveMessage: removeMessage,
      deletedAtMs: deletedAtMs,
    );
  }

  Future<void> _deleteBurnMessage(
    ConversationModel conversation,
    String messageId,
  ) async {
    await _burnService.deleteBurnMessage(
      burnDeleteTimers: burnDeleteTimers,
      chatService: _chatService,
      conversation: conversation,
      messageId: messageId,
      onExpire: expireBurnMessage,
    );
    burnDeleteTimers.remove(messageId)?.cancel();
  }

  static Future<bool> isMessageDeleted(String messageId) async {
    return ChatBurnService.isMessageDeleted(
      messageId,
      'imboy.deleted_message_ids.v1',
    );
  }

  // ===== 消息定位 / 历史 / 双向分页（委托给 ChatArchiveService）=====

  Future<void> loadMessagesAround(
    ConversationModel obj,
    String msgId, {
    int count = 20,
  }) async {
    await _archiveService.loadMessagesAround(
      chatService: _chatService!,
      scrollManager: ref.read(messageScrollManagerProvider.notifier),
      conversation: obj,
      msgId: msgId,
      loadMoreMessages: loadMoreMessages,
      updateState:
          ({
            required int nextAutoId,
            required int prevAutoId,
            required String currentConversationId,
          }) {
            state = state.copyWith(
              nextAutoId: nextAutoId,
              prevAutoId: prevAutoId,
              currentConversationId: currentConversationId,
            );
          },
      count: count,
    );
  }

  Future<List<Message>> loadNewerMessages(ConversationModel obj) async {
    if (state.isLoadingNewer) {
      iPrint('正在加载较新消息，跳过');
      return [];
    }

    state = state.copyWith(isLoadingNewer: true);

    try {
      final result = await _archiveService.loadNewerMessages(
        chatService: _chatService,
        conversation: obj,
        prevAutoId: state.prevAutoId,
        pageSize: state.pageSize,
        isBurnExpired: _burnService.isBurnExpired,
        onRemoveMessage: removeMessage,
        ensureBurnTimer:
            ({
              required ConversationModel conversation,
              required MessageRepo repo,
              required MessageModel item,
              required int nowMs,
            }) => _burnService.ensureBurnTimerForItem(
              burnDeleteTimers: burnDeleteTimers,
              conversation: conversation,
              repo: repo,
              item: item,
              nowMs: nowMs,
              onDelete: (conv, msgId) => _deleteBurnMessage(conv, msgId),
            ),
        onSendWsMsg: (item) async {
          await _networkService.sendWsMsg(item);
        },
        updatePrevAutoId: (newPrevAutoId) {
          state = state.copyWith(prevAutoId: newPrevAutoId);
        },
      );

      state = state.copyWith(isLoadingNewer: false);
      return result;
    } catch (e) {
      iPrint('loadNewerMessages error: $e');
      state = state.copyWith(isLoadingNewer: false);
      return [];
    }
  }

  /// conv_seq 正向增量同步：把服务端归档历史落本地 SQLite（P1-2）。
  ///
  /// 进会话时后台 fire-and-forget 调用，填补离线拉取（msg_c2c/c2g 是 ACK 后
  /// 即清的临时投递队列）覆盖不到的永久历史缺口（如新装机、离线超保留期）。
  /// 游标按会话持久化于 StorageService，重复进会话只增量拉新，不重复全量。
  /// 落库后既有 SQLite 分页（loadMoreMessages）自然渲染，无需另建渲染路径。
  Future<void> syncHistoryBackfill(ConversationModel obj) async {
    if (_historySyncing) return;
    final String chatType = obj.type.toLowerCase();
    if (chatType != 'c2c' && chatType != 'c2g') return;

    _historySyncing = true;
    final String cursorKey = 'msg_history_seq_${obj.uk3}';
    try {
      final String peerId = obj.peerId.toString();
      int seq = StorageService.to.getInt(cursorKey) ?? 0;
      bool anyFetched = false;
      int pages = 0;
      while (pages < _historyMaxPagesPerOpen) {
        final page = await _archiveService.fetchAndPersistHistoryPage(
          chatType: chatType,
          peerId: peerId,
          afterSeq: seq,
          limit: 50,
        );
        pages++;
        if (page.fetched > 0) anyFetched = true;
        if (page.nextSeq > seq) {
          seq = page.nextSeq;
          await StorageService.to.setInt(cursorKey, seq);
        }
        if (!page.hasMore) break;
      }
      // 有回填则重置本地分页游标位，让上滑能读到新落库的更老消息
      if (anyFetched) {
        state = state.copyWith(hasMoreMessage: true);
      }
    } catch (e) {
      iPrint('syncHistoryBackfill error: $e');
    } finally {
      _historySyncing = false;
    }
  }

  Future<void> scrollToMessage(String chatType, String messageId) async {
    try {
      if (_chatService == null || _chatService!.isDisposed) {
        iPrint('聊天控制器未初始化或已释放，无法滚动');
        return;
      }
      if (_chatService!.messages.isEmpty) {
        iPrint("消息列表为空，无法滚动");
        return;
      }
      final messages = _chatService!.messages;
      final int targetIndex = messages.indexWhere((m) => m.id == messageId);
      if (targetIndex == -1) return;

      await _chatService?.scrollToMessage(
        messageId,
        duration: const Duration(milliseconds: 500),
        offset: 100.0,
      );

      ref
          .read(messageScrollManagerProvider.notifier)
          .highlightMessage(messageId);
    } catch (e) {
      iPrint('[chat_provider] highlightMessage error: $e');
    }
  }

  Future<void> updateConversationAfterRevoke(
    ConversationModel conversation,
    String msgId,
  ) async {
    await _archiveService.updateConversationAfterRevoke(conversation, msgId);
  }

  Future<void> checkAndRetrySendingMessages(
    ConversationModel conversation,
  ) async {
    try {
      final String tb = MessageRepo.getTableName(conversation.type);
      final repo = MessageRepo(tableName: tb);

      final items = await repo.page(
        conversationUk3: conversation.uk3,
        page: 1,
        size: 50,
      );

      if (items.isEmpty) return;

      final sendingItems = items
          .where((item) => item.status == IMBoyMessageStatus.sending)
          .toList();

      if (sendingItems.isEmpty) return;

      iPrint('找到 ${sendingItems.length} 条发送中的消息，开始重试');

      for (final item in sendingItems) {
        if (item.status == IMBoyMessageStatus.sending) {
          await _networkService.sendWsMsg(item);
        }
      }
    } catch (e) {
      iPrint('检查并重试发送中的消息失败: $e');
    }
  }

  // ===== 语音播放状态 Getters =====

  bool isCurrentPlayingMessage(String voiceUrlOrPath) {
    final playbackState = voicePlaybackState;
    return playbackState.currentAudioPath == voiceUrlOrPath &&
        playbackState.isPlaying;
  }

  bool isCurrentPausedMessage(String voiceUrlOrPath) {
    final playbackState = voicePlaybackState;
    return playbackState.currentAudioPath == voiceUrlOrPath &&
        playbackState.isPaused;
  }

  double? getCurrentPlaybackProgress() {
    final playbackState = voicePlaybackState;
    if (playbackState.currentDuration == 0) return null;
    return playbackState.currentPosition / playbackState.currentDuration;
  }

  int getCurrentPlaybackPosition() {
    return voicePlaybackState.currentPosition;
  }

  bool get isPlayingVoice => voicePlaybackState.isPlaying;
  bool get isPausedVoice => voicePlaybackState.isPaused;
  String get currentPlayingMessageId => voicePlaybackState.currentMessageId;

  // ===== 队列管理公共方法 =====

  Future<void> enqueueReactionAction(Map<String, dynamic> actionMessage) async {
    await _enqueuePending(_spPendingReactionsKey, actionMessage);
    await _flushPendingReactions();
  }

  Future<void> flushPendingReactions() async {
    await _flushPending(_spPendingReactionsKey);
  }

  // ===== 调试方法 =====

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

  // ===== 资源清理 =====

  void _dispose() {
    if (_isDisposed) return;

    iPrint('开始释放 Chat 资源...');

    _readReceiptFlushTimer?.cancel();
    _cleanupDeletedMessageIdsTimer?.cancel();

    for (final timer in burnDeleteTimers.values) {
      timer.cancel();
    }
    burnDeleteTimers.clear();

    for (final timer in burnPurgeTimers.values) {
      timer.cancel();
    }
    burnPurgeTimers.clear();

    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    try {
      _globalPlayerController?.dispose();
    } catch (e) {
      iPrint('释放 PlayerController 失败: $e');
    }
    _globalPlayerController = null;

    _justAudioStateSubscription?.cancel();
    _justAudioPositionSubscription?.cancel();
    _audioPlayer?.dispose();
    _audioPlayer = null;

    try {
      _chatService?.setMessages([]);
      _chatService?.dispose();
    } catch (e) {
      iPrint('Error disposing chat controller: $e');
    }

    _ssMsgExt?.cancel();
    _ssMsg?.cancel();
    _ssMsgState?.cancel();
    _ssReEdit?.cancel();
    _connectivitySubscription?.cancel();

    _isDisposed = true;
    iPrint('Chat 资源释放完成');
  }

  void markAsDisposed() {
    _isDisposed = true;
    iPrint('Chat 已标记为已释放状态');
  }

  void resetDisposedState() {
    _isDisposed = false;
    iPrint('Chat 已重置释放状态，允许重新初始化');
  }
}
