import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/websocket_events.dart'
    show WebSocketStatusChangedEvent;

part 'channel_provider.g.dart';

/// 频道未读总数缓存（进程内）
///
/// 通过事件总线监听未读变化，在内存中维护一个同步可读的最新值，
/// 供 sync Provider 直接返回。
class _ChannelUnreadCountCache {
  _ChannelUnreadCountCache._();

  static final _ChannelUnreadCountCache instance = _ChannelUnreadCountCache._();

  final StreamController<void> _updates = StreamController<void>.broadcast();
  StreamSubscription<ChannelUnreadCountUpdatedEvent>? _unreadCountSub;
  StreamSubscription<ChannelNewMessageEvent>? _newMessageSub;
  StreamSubscription<WebSocketStatusChangedEvent>? _websocketStatusSub;
  StreamSubscription<ChannelStateChangedEvent>? _channelStateSub;

  bool _started = false;
  int _value = 0;

  int get value => _value;
  Stream<void> get updates => _updates.stream;

  void start() {
    if (_started) return;
    _started = true;

    // 冷启动优先做一次服务端权威对账，再刷新本地总未读缓存。
    unawaited(_syncFromServerAndDb(trigger: 'cache_start'));

    _unreadCountSub ??= AppEventBus.on<ChannelUnreadCountUpdatedEvent>().listen(
      (_) {
        unawaited(_syncFromDb());
      },
    );
    _newMessageSub ??= AppEventBus.on<ChannelNewMessageEvent>().listen((_) {
      unawaited(_syncFromDb());
    });
    _websocketStatusSub ??= AppEventBus.on<WebSocketStatusChangedEvent>()
        .listen((event) {
          if (event.status.toLowerCase() != 'connected') return;
          unawaited(_syncFromServerAndDb(trigger: 'ws_connected'));
        });
    // 订阅/退订/删除会改变总未读集合（例如退订一个有 5 条未读的频道，
    // 订阅行消失后 SUM 少 5）。不监听的话总未读缓存会滞留到下次推送或
    // 重连才会对齐。
    _channelStateSub ??= AppEventBus.on<ChannelStateChangedEvent>().listen((
      event,
    ) {
      switch (event.action) {
        case 'channel_unsubscribed':
        case 'channel_deleted':
        case 'channel_subscribed':
          unawaited(_syncFromDb());
          break;
        default:
          break;
      }
    });
  }

  Future<int> refresh() => _syncFromDb();

  Future<void> _syncFromServerAndDb({required String trigger}) async {
    await ChannelService.to.syncUnreadSummary(trigger: trigger);
    await _syncFromDb();
  }

  Future<int> _syncFromDb() async {
    try {
      final total = await ChannelService.to.getTotalUnreadCount();
      if (total != _value) {
        _value = total;
        if (!_updates.isClosed) {
          _updates.add(null);
        }
      }
      return _value;
    } catch (_) {
      return _value;
    }
  }
}

final _channelUnreadCountCache = _ChannelUnreadCountCache.instance;

/// 频道列表状态
class ChannelListState {
  final List<ChannelModel> channels;
  final bool isLoading;
  final bool hasMore;
  final String? cursor;
  final String? error;

  const ChannelListState({
    this.channels = const [],
    this.isLoading = false,
    this.hasMore = false,
    this.cursor,
    this.error,
  });

  ChannelListState copyWith({
    List<ChannelModel>? channels,
    bool? isLoading,
    bool? hasMore,
    String? cursor,
    String? error,
    bool clearCursor = false,
  }) {
    return ChannelListState(
      channels: channels ?? this.channels,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      error: error,
    );
  }
}

/// 频道列表 Notifier
@riverpod
class ChannelListNotifier extends _$ChannelListNotifier {
  final ChannelApi _api = ChannelApi();
  StreamSubscription<ChannelStateChangedEvent>? _stateChangedSub;

  @override
  ChannelListState build() {
    // 订阅/退订/删除：S2C 广播后自动对齐本地列表，避免用户看到过时快照。
    _stateChangedSub ??= AppEventBus.on<ChannelStateChangedEvent>().listen(
      _handleChannelStateChanged,
    );
    ref.onDispose(() {
      _stateChangedSub?.cancel();
      _stateChangedSub = null;
    });
    return const ChannelListState();
  }

  void _handleChannelStateChanged(ChannelStateChangedEvent event) {
    if (!ref.mounted) return;
    switch (event.action) {
      case 'channel_unsubscribed':
      case 'channel_deleted':
        // 本地过滤即可，无需网络往返，保留分页游标。
        final next = state.channels
            .where((c) => c.id.toString() != event.channelId)
            .toList(growable: false);
        if (next.length != state.channels.length) {
          state = state.copyWith(channels: next);
        }
        break;
      case 'channel_subscribed':
        // 新订阅需要完整 channel 数据，走一次权威拉取。
        unawaited(loadSubscribedChannels());
        break;
      default:
        break;
    }
  }

  /// 加载订阅的频道列表
  Future<void> loadSubscribedChannels() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _api.getSubscribedChannelsPage(limit: 50);
      // 检查 provider 是否仍然有效
      if (!ref.mounted) return;
      state = ChannelListState(
        channels: result.list,
        isLoading: false,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
      );
      // 列表可用后异步对账未读汇总，失败不阻断页面渲染。
      unawaited(
        ChannelService.to.syncUnreadSummary(trigger: 'channel_list_load'),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = ChannelListState(isLoading: false, error: '${e.runtimeType}');
    }
  }

  /// 加载更多订阅频道
  Future<void> loadMoreSubscribedChannels() async {
    if (state.isLoading || !state.hasMore || state.cursor == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _api.getSubscribedChannelsPage(
        cursor: state.cursor,
        limit: 50,
      );
      if (!ref.mounted) return;

      state = state.copyWith(
        channels: [...state.channels, ...result.list],
        isLoading: false,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: '${e.runtimeType}');
    }
  }

  /// 加载管理的频道列表
  Future<void> loadManagedChannels() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final channels = await _api.getManagedChannels();
      if (!ref.mounted) return;
      state = ChannelListState(
        channels: channels,
        isLoading: false,
        hasMore: false,
        cursor: null,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = ChannelListState(isLoading: false, error: '${e.runtimeType}');
    }
  }

  /// 搜索频道
  Future<List<ChannelModel>> searchChannels(String keyword) async {
    try {
      return await _api.searchChannels(keyword);
    } catch (e) {
      return [];
    }
  }

  /// 订阅频道
  ///
  /// 走 ChannelService.subscribeChannel 以保证：
  ///   1. 调用 /v1/channel/:id/subscribe
  ///   2. 拉取频道信息并 saveChannel 到本地
  ///   3. saveSubscription 写入本地订阅表
  /// 旧实现直连 _api.subscribe 会跳过 2/3 步，导致冷启动后订阅关系丢失。
  Future<bool> subscribeChannel(String channelId) async {
    try {
      final success = await ChannelService.to.subscribeChannel(channelId);
      if (success) {
        await loadSubscribedChannels();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// 取消订阅频道
  ///
  /// 走 ChannelService.unsubscribeChannel 以保证本地 deleteSubscription
  /// 同步执行，避免订阅表里残留孤儿行（getTotalUnreadCount 仍把它计入 SUM）。
  Future<bool> unsubscribeChannel(String channelId) async {
    try {
      final success = await ChannelService.to.unsubscribeChannel(channelId);
      if (success) {
        await loadSubscribedChannels();
      }
      return success;
    } catch (e) {
      return false;
    }
  }
}

/// 频道详情状态
class ChannelDetailState {
  final ChannelModel? channel;
  final List<ChannelMessageModel> messages;
  final bool isLoading;
  final bool isPublishing;
  final bool hasMore;
  final String? error;

  const ChannelDetailState({
    this.channel,
    this.messages = const [],
    this.isLoading = false,
    this.isPublishing = false,
    this.hasMore = true,
    this.error,
  });

  ChannelDetailState copyWith({
    ChannelModel? channel,
    List<ChannelMessageModel>? messages,
    bool? isLoading,
    bool? isPublishing,
    bool? hasMore,
    String? error,
    bool clearChannel = false,
  }) {
    return ChannelDetailState(
      channel: clearChannel ? null : (channel ?? this.channel),
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isPublishing: isPublishing ?? this.isPublishing,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

/// 频道详情 Notifier
@riverpod
class ChannelDetailNotifier extends _$ChannelDetailNotifier {
  final ChannelApi _api = ChannelApi();
  String? _channelId;
  @visibleForTesting
  void debugSetChannelId(String? channelId) => _channelId = channelId;
  StreamSubscription<ChannelNewMessageEvent>? _channelNewMessageSub;
  StreamSubscription<ChannelMessageDeletedEvent>? _channelMessageDeletedSub;
  StreamSubscription<ChannelStateChangedEvent>? _channelStateChangedSub;

  @override
  ChannelDetailState build() {
    _channelNewMessageSub ??= AppEventBus.on<ChannelNewMessageEvent>().listen((
      event,
    ) {
      _handleRealtimeMessage(event);
    });
    _channelMessageDeletedSub ??= AppEventBus.on<ChannelMessageDeletedEvent>()
        .listen((event) {
          _handleRealtimeMessageDeleted(event);
        });
    _channelStateChangedSub ??= AppEventBus.on<ChannelStateChangedEvent>()
        .listen((event) {
          _handleChannelStateChanged(event);
        });
    ref.onDispose(() {
      _channelNewMessageSub?.cancel();
      _channelNewMessageSub = null;
      _channelMessageDeletedSub?.cancel();
      _channelMessageDeletedSub = null;
      _channelStateChangedSub?.cancel();
      _channelStateChangedSub = null;
    });

    return const ChannelDetailState();
  }

  /// 加载频道详情
  Future<void> loadChannel(String channelId) async {
    // 避免加载失败后仍误用旧 channelId 进行发布等操作。
    _channelId = null;
    state = state.copyWith(isLoading: true, error: null, clearChannel: true);

    try {
      ChannelModel? channel = await _api.getChannel(channelId);
      // 兼容通过 custom_id 进入详情的场景
      channel ??= await _api.getChannelByCustomId(channelId);
      if (!ref.mounted) return;
      if (channel != null) {
        final effectiveChannelId = channel.id != 0
            ? channel.id.toString()
            : channelId;
        _channelId = effectiveChannelId;
        state = state.copyWith(channel: channel, isLoading: false);
        // 加载消息
        await loadMessages(effectiveChannelId);
      } else {
        _channelId = null;
        state = state.copyWith(isLoading: false, error: '频道不存在');
      }
    } catch (e) {
      _channelId = null;
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: '${e.runtimeType}');
    }
  }

  /// 加载频道消息
  Future<void> loadMessages(
    String channelId, {
    int? cursor,
    int limit = 20,
  }) async {
    try {
      final messages = await _api.getMessages(
        channelId: channelId,
        cursor: cursor,
        limit: limit,
      );

      if (!ref.mounted) return;
      if (cursor == null) {
        // 首次加载
        state = state.copyWith(
          messages: messages,
          hasMore: messages.length >= limit,
        );
      } else {
        // 加载更多
        state = state.copyWith(
          messages: [...state.messages, ...messages],
          hasMore: messages.length >= limit,
        );
      }
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(error: '${e.runtimeType}');
    }
  }

  /// 加载更多消息
  Future<void> loadMoreMessages() async {
    if (_channelId == null || state.isLoading || !state.hasMore) return;

    final lastMessage = state.messages.isNotEmpty ? state.messages.last : null;
    final cursor = lastMessage?.createdAt.millisecondsSinceEpoch;

    await loadMessages(_channelId!, cursor: cursor);
  }

  /// 发布消息
  ///
  /// 权限守卫：仅 creator/admin/editor 角色允许发布。
  /// 守卫在任何状态变更（isPublishing）和网络请求之前执行，
  /// 避免无权用户触发无谓的 API 调用与 UI 抖动。
  Future<bool> publishMessage({
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
  }) async {
    if (_channelId == null || state.isPublishing) return false;

    // 权限守卫：当频道已加载时，拒绝无发布权限的角色（订阅者/未订阅）。
    final currentChannel = state.channel;
    if (currentChannel != null && !currentChannel.userRole.canPublish) {
      return false;
    }

    state = state.copyWith(isPublishing: true);

    try {
      final normalizedType = ChannelMessageType.fromMessageType(msgType);
      // 走 ChannelService：它会在 API 成功后执行 _messageRepo.saveMessage 落库。
      // 之前直连 _api.publishMessage 的写法会让新消息仅存在于内存 state 中，
      // 下次进入详情页要等 S2C 回显才能看到自己的发言。
      final message = await ChannelService.to.publishMessage(
        channelId: _channelId!,
        content: content,
        msgType: normalizedType,
        payload: payload,
      );

      if (!ref.mounted) return false;
      if (message != null) {
        // 添加到消息列表开头
        state = state.copyWith(
          messages: [message, ...state.messages],
          isPublishing: false,
          error: null,
        );
        return true;
      }
      state = state.copyWith(isPublishing: false, error: '发布失败');
      return false;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isPublishing: false, error: '${e.runtimeType}');
      }
      return false;
    }
  }

  /// 标记已读
  ///
  /// 走 ChannelService，保证服务端、本地 DB、事件三者一致。
  /// 之前直连 _api.markAsRead 的写法会让本地 unread_count 与 UI 徽标
  /// 始终停留在旧值，必须走服务层。
  Future<void> markAsRead(String messageId) async {
    if (_channelId == null) return;
    await ChannelService.to.markAsRead(_channelId!, messageId);
  }

  void _handleRealtimeMessage(ChannelNewMessageEvent event) {
    if (_channelId == null || event.channelId != _channelId) return;
    if (!ref.mounted) return;

    try {
      final incoming = ChannelMessageModel.fromJson(event.message);
      final exists = state.messages.any((msg) => msg.id == incoming.id);
      if (exists) return;

      state = state.copyWith(messages: [incoming, ...state.messages]);
    } catch (_) {
      // 忽略解析失败，保留现有状态
    }
  }

  void _handleRealtimeMessageDeleted(ChannelMessageDeletedEvent event) {
    handleMessageDeletedEvent(event);
  }

  /// 让外部（测试或事件回调）明确执行删除逻辑
  void handleMessageDeletedEvent(ChannelMessageDeletedEvent event) {
    if (_channelId == null || event.channelId != _channelId) return;
    if (!ref.mounted) return;

    final nextMessages = state.messages
        .where((message) => message.id.toString() != event.messageId)
        .toList(growable: false);
    if (nextMessages.length == state.messages.length) {
      return;
    }
    state = state.copyWith(messages: nextMessages);
  }

  void _handleChannelStateChanged(ChannelStateChangedEvent event) {
    if (_channelId == null || event.channelId != _channelId) return;
    if (!ref.mounted) return;

    switch (event.action) {
      case 'message_ack':
        final localId = event.payload['local_id'] as int?;
        final realId = event.payload['real_id'] as int?;
        if (localId != null && realId != null) {
          final updated = state.messages
              .map((m) => m.id == localId ? m.copyWith(id: realId) : m)
              .toList();
          state = state.copyWith(messages: updated);
        }
        break;
      case 'channel_updated':
        final channelData = event.payload['channel'];
        if (channelData is Map) {
          state = state.copyWith(
            channel: ChannelModel.fromJson(
              Map<String, dynamic>.from(channelData),
            ),
          );
        }
        break;
      case 'channel_deleted':
        state = state.copyWith(clearChannel: true, error: '频道已删除');
        break;
      default:
        break;
    }
  }

  /// 立刻更新消息的置顶状态，不等待后端推送
  void updateMessagePinned(String messageId, bool pinned) {
    final updated = state.messages
        .map(
          (message) => message.id.toString() == messageId
              ? message.copyWith(isPinned: pinned)
              : message,
        )
        .toList(growable: false);
    state = state.copyWith(messages: updated);
  }

  /// 立刻从列表移除指定消息
  void removeMessageLocally(String messageId) {
    final nextMessages = state.messages
        .where((message) => message.id.toString() != messageId)
        .toList(growable: false);
    if (nextMessages.length == state.messages.length) return;
    state = state.copyWith(messages: nextMessages);
  }
}

/// 创建频道状态
class CreateChannelState {
  final bool isCreating;
  final ChannelModel? createdChannel;
  final String? error;

  const CreateChannelState({
    this.isCreating = false,
    this.createdChannel,
    this.error,
  });

  CreateChannelState copyWith({
    bool? isCreating,
    ChannelModel? createdChannel,
    String? error,
    bool clearCreatedChannel = false,
  }) {
    return CreateChannelState(
      isCreating: isCreating ?? this.isCreating,
      createdChannel: clearCreatedChannel
          ? null
          : (createdChannel ?? this.createdChannel),
      error: error,
    );
  }
}

/// 创建频道 Notifier
@riverpod
class CreateChannelNotifier extends _$CreateChannelNotifier {
  final ChannelApi _api = ChannelApi();

  @override
  CreateChannelState build() {
    return const CreateChannelState();
  }

  /// 创建频道
  Future<ChannelModel?> createChannel({
    required String name,
    String? description,
    String? avatar,
    int type = 0,
    String? customId,
    List<String>? tags,
  }) async {
    state = state.copyWith(
      isCreating: true,
      error: null,
      clearCreatedChannel: true,
    );

    try {
      final channel = await _api.createChannel(
        name: name,
        description: description,
        avatar: avatar,
        type: type,
        customId: customId,
        tags: tags,
      );

      if (!ref.mounted) return null;
      if (channel != null) {
        state = CreateChannelState(isCreating: false, createdChannel: channel);
        return channel;
      } else {
        state = CreateChannelState(isCreating: false, error: '创建失败');
        return null;
      }
    } catch (e) {
      if (!ref.mounted) return null;
      state = CreateChannelState(isCreating: false, error: '${e.runtimeType}');
      return null;
    }
  }

  /// 重置状态
  void reset() {
    state = const CreateChannelState();
  }
}

/// 频道未读计数 Provider（简单同步版本，用于快速访问）
@riverpod
int channelUnreadCount(Ref ref) {
  _channelUnreadCountCache.start();

  final sub = _channelUnreadCountCache.updates.listen((_) {
    if (ref.mounted) {
      ref.invalidateSelf();
    }
  });

  ref.onDispose(sub.cancel);
  return _channelUnreadCountCache.value;
}

/// 刷新频道未读计数
///
/// 调用此方法从数据库获取最新的未读总数
Future<int> refreshChannelUnreadCount() async {
  return await _channelUnreadCountCache.refresh();
}
