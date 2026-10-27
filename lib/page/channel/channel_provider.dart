import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/i18n/strings.g.dart' show t;
import 'package:imboy/service/creation_receipt/channel_creation_receipt_service.dart';
import 'package:imboy/service/creation_receipt/creation_receipt_flow.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/component/http/http_exceptions.dart' as http;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/websocket_events.dart'
    show WebSocketStatusChangedEvent;

import 'channel_di_provider.dart';
import 'channel_snapshot_sync.dart';

part 'channel_provider.g.dart';
part 'create_channel_state.dart';
part 'channel_detail_state.dart';
part 'channel_post_search_provider.dart';

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
  final bool syncError;
  final ChannelListState? managedSnapshot;

  ChannelListState get managed => managedSnapshot ?? const ChannelListState();

  const ChannelListState({
    this.channels = const [],
    this.isLoading = false,
    this.hasMore = false,
    this.cursor,
    this.error,
    this.syncError = false,
    this.managedSnapshot,
  });

  ChannelListState copyWith({
    List<ChannelModel>? channels,
    bool? isLoading,
    bool? hasMore,
    String? cursor,
    String? error,
    bool clearCursor = false,
    ChannelListState? managed,
    bool? syncError,
  }) {
    return ChannelListState(
      channels: channels ?? this.channels,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      error: error,
      syncError: syncError ?? this.syncError,
      managedSnapshot: managed ?? managedSnapshot,
    );
  }
}

/// 频道列表 Notifier
@riverpod
class ChannelListNotifier extends _$ChannelListNotifier {
  ChannelApi get _api => ref.read(channelApiProvider);
  StreamSubscription<ChannelStateChangedEvent>? _stateChangedSub;
  Future<void>? _subscribedChannelsLoad;
  String? _account;
  int? _sessionGeneration;
  bool _authTransitioning = false;
  String? _subscribedLoadAccount;
  int _subscribedGeneration = 0;
  int _managedGeneration = 0;
  bool _refreshSubscribedAfterLoad = false;
  bool _refreshManagedAfterLoad = false;
  int _managedRequests = 0;

  @override
  ChannelListState build() {
    _account = UserRepoLocal.to.currentUid;
    _sessionGeneration = UserRepoLocal.to.sessionGeneration;
    _authTransitioning = UserRepoLocal.to.isAuthTransitioning;
    UserRepoLocal.to.addAuthListener(_onAuthChanged);
    // 订阅/退订/删除：S2C 广播后自动对齐本地列表，避免用户看到过时快照。
    _stateChangedSub ??= AppEventBus.on<ChannelStateChangedEvent>().listen(
      _handleChannelStateChanged,
    );
    ref.onDispose(() {
      _stateChangedSub?.cancel();
      _stateChangedSub = null;
      UserRepoLocal.to.removeAuthListener(_onAuthChanged);
    });
    return const ChannelListState();
  }

  void _handleChannelStateChanged(ChannelStateChangedEvent event) {
    if (!ref.mounted) return;
    _ensureAccount();
    switch (event.action) {
      case 'channel_unsubscribed':
      case 'channel_deleted':
        _subscribedGeneration++;
        if (_subscribedChannelsLoad != null) {
          _refreshSubscribedAfterLoad = true;
        }
        // 本地过滤即可，无需网络往返，保留分页游标。
        final next = state.channels
            .where((c) => c.id.toString() != event.channelId)
            .toList(growable: false);
        var managed = state.managed;
        if (event.action == 'channel_deleted') {
          _managedGeneration++;
          if (_managedRequests > 0) _refreshManagedAfterLoad = true;
          managed = managed.copyWith(
            channels: managed.channels
                .where((c) => c.id.toString() != event.channelId)
                .toList(growable: false),
            isLoading: false,
            error: managed.error,
          );
        }
        state = state.copyWith(
          channels: next,
          isLoading: false,
          managed: managed,
          error: state.error,
        );
        break;
      case 'channel_subscribed':
        // 新订阅需要完整 channel 数据，走一次权威拉取。
        if (_subscribedChannelsLoad != null) {
          _subscribedGeneration++;
          _refreshSubscribedAfterLoad = true;
        } else {
          unawaited(loadSubscribedChannels());
        }
        break;
      default:
        break;
    }
  }

  void _ensureAccount() {
    final user = UserRepoLocal.to;
    final account = user.currentUid;
    if (_account == account &&
        _sessionGeneration == user.sessionGeneration &&
        _authTransitioning == user.isAuthTransitioning) {
      return;
    }
    _account = account;
    _sessionGeneration = user.sessionGeneration;
    _authTransitioning = user.isAuthTransitioning;
    _subscribedGeneration++;
    _managedGeneration++;
    _refreshSubscribedAfterLoad = false;
    _refreshManagedAfterLoad = false;
    _subscribedChannelsLoad = null;
    _subscribedLoadAccount = null;
    state = const ChannelListState();
  }

  void _onAuthChanged() {
    if (ref.mounted) _ensureAccount();
  }

  /// 加载订阅的频道列表
  ///
  /// 订阅动作、页面回到前台、下拉刷新和 S2C 事件可能同时要求刷新。
  /// 统一复用同一个 in-flight 请求，避免调用方各自 reload 造成按钮闪烁和重复 GET。
  Future<void> loadSubscribedChannels() {
    _ensureAccount();
    if (_authTransitioning) return Future.value();
    final inFlight = _subscribedChannelsLoad;
    if (inFlight != null && _subscribedLoadAccount == _account) return inFlight;

    final account = _account;
    final generation = ++_subscribedGeneration;
    final request = _loadSubscribedChannels(account, generation);
    late final Future<void> coordinatedRequest;
    coordinatedRequest = request.whenComplete(() {
      if (identical(_subscribedChannelsLoad, coordinatedRequest)) {
        _subscribedChannelsLoad = null;
        _subscribedLoadAccount = null;
        if (_refreshSubscribedAfterLoad && ref.mounted) {
          _refreshSubscribedAfterLoad = false;
          unawaited(loadSubscribedChannels());
        }
      }
    });
    _subscribedChannelsLoad = coordinatedRequest;
    _subscribedLoadAccount = account;
    return coordinatedRequest;
  }

  Future<void> _loadSubscribedChannels(String? account, int generation) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _api.getSubscribedChannelsPage(limit: 50);
      // 检查 provider 是否仍然有效
      if (!ref.mounted ||
          account != UserRepoLocal.to.currentUid ||
          generation != _subscribedGeneration) {
        return;
      }
      state = state.copyWith(
        channels: result.list,
        isLoading: false,
        syncError: false,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
        clearCursor: result.nextCursor == null,
      );
      // 列表可用后异步对账本地订阅 + 未读汇总，失败不阻断页面渲染。
      // 必须先对账订阅表再对账未读：订阅表缺行时未读 UPDATE 是空操作，
      // 未读汇总对账只能修正已存在的行（Slice-1 回归，840919d0 移除了
      // 冷启动 syncSubscribedChannels 调用点）。
      unawaited(() async {
        bool isCurrent() =>
            ref.mounted &&
            !_authTransitioning &&
            account != null &&
            account.isNotEmpty &&
            account == UserRepoLocal.to.currentUid &&
            generation == _subscribedGeneration;
        if (!isCurrent()) return;
        final repo = ref.read(channelServiceProvider).repo;
        final stored = await syncChannelSnapshot(
          repo: repo,
          channels: result.list,
          isCurrent: isCurrent,
        );
        if (!isCurrent()) return;
        final synced =
            stored &&
            await syncChannelUnreadSnapshot(api: _api, isCurrent: isCurrent);
        if (isCurrent() && !synced) {
          state = state.copyWith(syncError: true, error: state.error);
        }
      }());
    } catch (e) {
      iPrint('loadSubscribedChannels failed: $e');
      if (!ref.mounted ||
          account != UserRepoLocal.to.currentUid ||
          generation != _subscribedGeneration) {
        return;
      }
      state = state.copyWith(isLoading: false, error: t.common.loadError);
    }
  }

  /// 加载更多订阅频道
  Future<void> loadMoreSubscribedChannels() async {
    _ensureAccount();
    if (_authTransitioning) return;
    if (state.isLoading || !state.hasMore || state.cursor == null) return;

    state = state.copyWith(isLoading: true, error: null);
    final account = _account;
    final generation = _subscribedGeneration;

    try {
      final result = await _api.getSubscribedChannelsPage(
        cursor: state.cursor,
        limit: 50,
      );
      if (!ref.mounted ||
          account != UserRepoLocal.to.currentUid ||
          generation != _subscribedGeneration) {
        return;
      }

      state = state.copyWith(
        channels: [...state.channels, ...result.list],
        isLoading: false,
        hasMore: result.hasMore,
        cursor: result.nextCursor,
      );
    } catch (e) {
      iPrint('loadMoreSubscribedChannels failed: $e');
      if (!ref.mounted ||
          account != UserRepoLocal.to.currentUid ||
          generation != _subscribedGeneration) {
        return;
      }
      state = state.copyWith(isLoading: false, error: t.common.loadError);
    }
  }

  /// 加载管理的频道列表
  Future<void> loadManagedChannels() async {
    _ensureAccount();
    if (_authTransitioning) return;
    final account = _account;
    final generation = ++_managedGeneration;
    _managedRequests++;
    state = state.copyWith(
      managed: state.managed.copyWith(isLoading: true),
      error: state.error,
    );

    try {
      final channels = await _api.getManagedChannels();
      if (!ref.mounted ||
          account != UserRepoLocal.to.currentUid ||
          generation != _managedGeneration) {
        return;
      }
      state = state.copyWith(
        managed: ChannelListState(channels: channels),
        error: state.error,
      );
    } catch (e) {
      iPrint('loadManagedChannels failed: $e');
      if (!ref.mounted ||
          account != UserRepoLocal.to.currentUid ||
          generation != _managedGeneration) {
        return;
      }
      state = state.copyWith(
        managed: state.managed.copyWith(
          isLoading: false,
          error: t.common.loadError,
        ),
        error: state.error,
      );
    } finally {
      _managedRequests--;
      if (_refreshManagedAfterLoad && ref.mounted && _managedRequests == 0) {
        _refreshManagedAfterLoad = false;
        unawaited(loadManagedChannels());
      }
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
  ///   1. 调用 /api/v1/channel/:id/subscribe
  ///   2. 拉取频道信息并 saveChannel 到本地
  ///   3. saveSubscription 写入本地订阅表
  /// 旧实现直连 _api.subscribe 会跳过 2/3 步，导致冷启动后订阅关系丢失。
  Future<ChannelSubscribeOutcome> subscribeChannel(String channelId) async {
    try {
      final result = await ref
          .read(channelServiceProvider)
          .subscribeChannelResult(channelId);
      if (result == ChannelSubscribeOutcome.completed) {
        await loadSubscribedChannels();
      }
      return result;
    } catch (e) {
      return ChannelSubscribeOutcome.failed;
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

/// 频道详情 Notifier
@riverpod
class ChannelDetailNotifier extends _$ChannelDetailNotifier {
  ChannelApi get _api => ref.read(channelApiProvider);
  String? _channelId;
  String? _requestedChannelId;
  String? get requestedChannelId => _requestedChannelId;
  final Set<String> _deletedChannelIds = {};
  // 叠页快照：切换目标前保存当前 personal 频道的完整状态，返回原目标时
  // 立即恢复渲染（J07：不用另一目标/清空态闪现）。受保护（workspace/未知
  // scope）内容按 C3 不做快照恢复；认证切换与频道删除事件会使快照失效。
  static const int _maxTargetSnapshots = 8;
  final Map<String, ChannelDetailState> _targetSnapshots = {};
  @visibleForTesting
  ChannelDetailState? debugSnapshotFor(String channelId) =>
      _targetSnapshots[channelId];
  @visibleForTesting
  void debugSeedSnapshot(String channelId, ChannelDetailState state) {
    _targetSnapshots[channelId] = state;
  }

  @visibleForTesting
  void debugSetChannelId(String? channelId) => _channelId = channelId;
  StreamSubscription<ChannelNewMessageEvent>? _channelNewMessageSub;
  StreamSubscription<ChannelMessageDeletedEvent>? _channelMessageDeletedSub;
  StreamSubscription<ChannelStateChangedEvent>? _channelStateChangedSub;
  // 消息分页 in-flight 互斥：state.isLoading 只在 loadChannel 置位，
  // loadMessages/loadMoreMessages 从不置位，故不能用它做并发守卫（会形同
  // 虚设导致快速滚动重复拉取/重复插入）。用独立私有标志。
  int? _loadingMoreGeneration;
  String? _messageCursor;
  int _messageGeneration = 0;
  int _channelLoadGeneration = 0;
  int _channelTargetGeneration = 0;

  @override
  ChannelDetailState build() {
    UserRepoLocal.to.addAuthListener(_onAuthChanged);
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
      UserRepoLocal.to.removeAuthListener(_onAuthChanged);
      _channelNewMessageSub?.cancel();
      _channelNewMessageSub = null;
      _channelMessageDeletedSub?.cancel();
      _channelMessageDeletedSub = null;
      _channelStateChangedSub?.cancel();
      _channelStateChangedSub = null;
    });

    return const ChannelDetailState();
  }

  void _onAuthChanged() {
    if (!ref.mounted) return;
    _channelId = null;
    _requestedChannelId = null;
    _deletedChannelIds.clear();
    _targetSnapshots.clear();
    _messageCursor = null;
    _messageGeneration++;
    _channelLoadGeneration++;
    _channelTargetGeneration++;
    state = const ChannelDetailState();
  }

  /// 读取指定目标的最近快照（叠页返回/页面归属过滤兜底）。
  ChannelDetailState? snapshotFor(String channelId) =>
      _targetSnapshots[channelId];

  void _snapshotCurrentTarget() {
    final id = _channelId;
    final channel = state.channel;
    if (id == null || channel == null || channel.scope != 'personal') return;
    _targetSnapshots[id] = state.copyWith(
      isPublishing: false,
      isLoading: false,
      error: null,
    );
    while (_targetSnapshots.length > _maxTargetSnapshots) {
      _targetSnapshots.remove(_targetSnapshots.keys.first);
    }
  }

  /// 切换目标后的初始状态：personal 快照立即恢复，其余走加载态。
  ChannelDetailState _restoredInitialState(String channelId) {
    final snapshot = _targetSnapshots[channelId];
    if (snapshot != null && snapshot.channel?.scope == 'personal') {
      return snapshot.copyWith(isLoading: false, error: null);
    }
    return const ChannelDetailState(isLoading: true);
  }

  /// 加载频道详情
  Future<void> loadChannel(String channelId) async {
    if (UserRepoLocal.to.isAuthTransitioning) return;
    _deletedChannelIds.clear();
    _requestedChannelId = channelId;
    final loadGeneration = ++_channelLoadGeneration;
    bool isCurrent() => ref.mounted && loadGeneration == _channelLoadGeneration;
    final service = ref.read(channelServiceProvider);
    if (_channelId != channelId) {
      _snapshotCurrentTarget();
      _channelTargetGeneration++;
      _channelId = null;
      state = _restoredInitialState(channelId);
    } else if (state.channel != null && state.channel!.scope != 'personal') {
      _channelTargetGeneration++;
      _channelId = null;
      state = _restoredInitialState(channelId);
    }
    _messageCursor = null;
    _messageGeneration++;

    // 1. 优先尝试从本地缓存加载并立即渲染（秒开），提前拿到并保留管理员/创建者等角色信息
    ChannelModel? cached;
    try {
      cached = await service.getChannel(channelId, isCurrent: isCurrent);
    } catch (error) {
      iPrint('loadChannel cache failed: $error');
      if (!ref.mounted || loadGeneration != _channelLoadGeneration) return;
      _channelId = null;
      _channelTargetGeneration++;
      state = const ChannelDetailState().copyWith(error: t.common.loadError);
      return;
    }
    if (!ref.mounted || loadGeneration != _channelLoadGeneration) return;
    if (cached != null && _deletedChannelIds.contains(cached.id.toString())) {
      _invalidateDeletedChannel();
      return;
    }
    // 旧 SQLite 快照没有 scope，不能把来源未知当作个人频道离线展示。
    final protectedCache = cached != null && cached.scope != 'personal';
    if (cached != null && !protectedCache) {
      _channelId = cached.id.toString();
      state = state.copyWith(channel: cached, isLoading: true, error: null);
      // 预先拉取本地缓存的消息
      await loadMessages(cached.id.toString());
      if (!ref.mounted || loadGeneration != _channelLoadGeneration) return;
    } else {
      _channelId = null;
      state = const ChannelDetailState(isLoading: true);
    }

    try {
      // 2. 在后台静默/刷新网络最新详情，保证 has_purchased 等权益及消息的最终一致性
      ChannelModel? channel = cached != null && !protectedCache
          ? await service.refreshChannelChecked(
              cached.id.toString(),
              isCurrent: isCurrent,
            )
          : await service.refreshChannel(channelId, isCurrent: isCurrent);
      if (!ref.mounted || loadGeneration != _channelLoadGeneration) return;
      if (channel != null &&
          _deletedChannelIds.contains(channel.id.toString())) {
        _invalidateDeletedChannel();
        return;
      }
      if (channel == null && cached == null) {
        // 兼容通过 custom_id 进入详情的场景；该 API 结果同样必须落缓存。
        channel = await _api.getChannelByCustomIdChecked(channelId);
        if (!ref.mounted || loadGeneration != _channelLoadGeneration) return;
        if (_deletedChannelIds.contains(channel.id.toString())) {
          _invalidateDeletedChannel();
          return;
        }
        await service.cacheChannelSnapshot(
          channel,
          isCurrent: () =>
              isCurrent() &&
              !_deletedChannelIds.contains(channel!.id.toString()),
        );
        if (!ref.mounted || loadGeneration != _channelLoadGeneration) return;
        if (_deletedChannelIds.contains(channel.id.toString())) {
          _invalidateDeletedChannel();
          return;
        }
      }
      if (!ref.mounted || loadGeneration != _channelLoadGeneration) return;
      if (channel != null) {
        final effectiveChannelId = channel.id != 0
            ? channel.id.toString()
            : channelId;
        _channelId = effectiveChannelId;
        state = state.copyWith(channel: channel, isLoading: false);
        // 静默刷新并载入最新消息
        await loadMessages(effectiveChannelId);
        if (!ref.mounted || loadGeneration != _channelLoadGeneration) return;
      } else if (cached != null && !protectedCache) {
        // 远端加载失败但本地已有缓存时，允许降级走本地缓存（无网络离线进入）
        state = state.copyWith(isLoading: false);
      } else {
        _channelId = null;
        state = state.copyWith(
          isLoading: false,
          error: protectedCache
              ? t.common.loadError
              : t.channel.channelNotFound,
        );
      }
    } catch (e) {
      iPrint('loadChannel failed: $e');
      if (!ref.mounted || loadGeneration != _channelLoadGeneration) return;
      final temporaryFailure =
          e is http.NetworkException ||
          (e is http.HttpException && {502, 503, 504}.contains(e.code));
      if (!temporaryFailure) {
        _channelId = null;
        _channelTargetGeneration++;
        _messageGeneration++;
        state = const ChannelDetailState().copyWith(error: t.common.loadError);
        return;
      }
      if (cached != null && !protectedCache) {
        // 允许降级使用本地缓存，清除 loading 状态
        state = state.copyWith(isLoading: false);
      } else {
        _channelId = null;
        state = state.copyWith(isLoading: false, error: t.common.loadError);
      }
    }
  }

  /// 加载频道消息
  Future<void> loadMessages(
    String channelId, {
    int? cursor,
    int limit = 20,
  }) async {
    if (UserRepoLocal.to.isAuthTransitioning) return;
    if (cursor == null) {
      _messageCursor = null;
      _messageGeneration++;
    }
    await _loadMessagePage(channelId, cursor: cursor?.toString(), limit: limit);
  }

  Future<void> _loadMessagePage(
    String channelId, {
    String? cursor,
    int limit = 20,
  }) async {
    final generation = _messageGeneration;
    try {
      final page = await _api.getMessagesPage(
        channelId: channelId,
        cursor: cursor,
        limit: limit,
      );
      if (!ref.mounted || generation != _messageGeneration) return;
      _messageCursor = page.nextCursor;
      state = state.copyWith(
        messages: cursor == null
            ? page.list
            : [...state.messages, ...page.list],
        hasMore: page.hasMore,
      );
    } catch (e) {
      iPrint('loadMessages failed: $e');
      if (!ref.mounted || generation != _messageGeneration) return;
      state = state.copyWith(error: t.common.loadError);
    }
  }

  /// 加载更多消息
  Future<void> loadMoreMessages() async {
    if (_channelId == null ||
        _loadingMoreGeneration == _messageGeneration ||
        !state.hasMore ||
        _messageCursor == null) {
      return;
    }
    final generation = _messageGeneration;
    _loadingMoreGeneration = generation;
    try {
      await _loadMessagePage(_channelId!, cursor: _messageCursor);
    } finally {
      if (_loadingMoreGeneration == generation) _loadingMoreGeneration = null;
    }
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
    String? expectedChannelId,
  }) async {
    if (_channelId == null || state.isPublishing) return false;
    if (expectedChannelId != null &&
        _channelId != expectedChannelId &&
        !(state.channel?.id.toString() == _channelId &&
            state.channel?.customId == expectedChannelId)) {
      return false;
    }
    final targetChannelId = _channelId!;
    final generation = _channelTargetGeneration;

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
      final message = await ref
          .read(channelServiceProvider)
          .publishMessage(
            channelId: targetChannelId,
            content: content,
            msgType: normalizedType,
            payload: payload,
          );

      if (!ref.mounted ||
          generation != _channelTargetGeneration ||
          targetChannelId != _channelId) {
        return false;
      }
      if (message != null) {
        // 添加到消息列表开头
        state = state.copyWith(
          messages: [message, ...state.messages],
          isPublishing: false,
          error: null,
        );
        return true;
      }
      state = state.copyWith(
        isPublishing: false,
        error: t.channel.publishFailed,
      );
      return false;
    } catch (e) {
      iPrint('publishMessage failed: $e');
      if (ref.mounted &&
          generation == _channelTargetGeneration &&
          targetChannelId == _channelId) {
        state = state.copyWith(
          isPublishing: false,
          error: t.channel.publishFailed,
        );
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
    if (!ref.mounted) return;
    if (event.action == 'channel_deleted') {
      _targetSnapshots.remove(event.channelId);
      if (_channelId == null && _requestedChannelId != null) {
        _deletedChannelIds.add(event.channelId);
      }
      if (event.channelId == _channelId ||
          event.channelId == _requestedChannelId) {
        _invalidateDeletedChannel();
        return;
      }
    }
    if (_channelId == null || event.channelId != _channelId) return;

    switch (event.action) {
      case 'message_ack':
        final localId = IMBoyHttpResponse.payloadInt(event.payload, 'local_id');
        final realId = IMBoyHttpResponse.payloadInt(event.payload, 'real_id');
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
      case 'channel_message_edited':
        // 后端 channel_message_edited 推送：原地替换该条消息内容
        // （本地库已由 ChannelService 同步更新，此处只刷内存态）
        final editedId = event.payload['message_id']?.toString() ?? '';
        final newContent = event.payload['content']?.toString() ?? '';
        if (editedId.isNotEmpty) {
          final updated = state.messages
              .map(
                (m) => m.id.toString() == editedId
                    ? m.copyWith(content: newContent)
                    : m,
              )
              .toList(growable: false);
          state = state.copyWith(messages: updated);
        }
        break;
      default:
        break;
    }
  }

  void _invalidateDeletedChannel() {
    _channelId = null;
    _messageCursor = null;
    _channelLoadGeneration++;
    _channelTargetGeneration++;
    _messageGeneration++;
    state = const ChannelDetailState().copyWith(
      error: t.channel.channelDeleted,
    );
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

  /// 立刻更新指定消息的点赞反应状态，供详情卡片与阅读页双向高保真同步
  void updateMessageReaction(String messageId, bool liked, int totalLikes) {
    final updated = state.messages
        .map((message) {
          if (message.id.toString() == messageId) {
            // 构造新的 reactionSummary
            final Map<String, int> summary = Map<String, int>.from(
              message.reactionSummary ?? {},
            );
            summary[ChannelReactionType.like] = totalLikes;

            // 构造新的 myReactions
            final List<String> myReactions = List<String>.from(
              message.myReactions,
            );
            if (liked) {
              if (!myReactions.contains(ChannelReactionType.like)) {
                myReactions.add(ChannelReactionType.like);
              }
            } else {
              myReactions.remove(ChannelReactionType.like);
            }

            return message.copyWith(
              reactionSummary: summary,
              myReactions: myReactions,
            );
          }
          return message;
        })
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
    int visibility = 0,
    int accessType = 0,
    int joinPolicy = 0,
    String? customId,
    List<String>? tags,
  }) async {
    state = state.copyWith(
      isCreating: true,
      error: null,
      clearCreatedChannel: true,
    );

    try {
      // W04.d.c：受理合同路径（manifest 能力门开启时启用；恢复重放/只查
      // 一律原键原载荷）。capabilityMissing 且无未知意图 → 回落既有键less
      // 路径（行为零变化）；已有未知意图时绝不剥键走旧 POST。
      final receipt = await ChannelCreationReceiptService()
          .createOrRecoverChannel(
            account: UserRepoLocal.to.currentUid,
            name: name,
            description: description,
            avatar: avatar,
            visibility: visibility,
            accessType: accessType,
            joinPolicy: joinPolicy,
            customId: customId,
            tags: tags,
          );
      if (!ref.mounted) return null;
      if (receipt.ok) {
        // 成功 payload 即频道对象 + 增量字段（request_id/creation_state）。
        final channel = ChannelModel.fromJson(receipt.payload);
        state = CreateChannelState(isCreating: false, createdChannel: channel);
        return channel;
      }
      if (!(receipt.failure == CreationFlowFailure.capabilityMissing &&
          !receipt.pendingIntentBlocked)) {
        // conflict/notAccepted/unknownPending：意图保留，重试继续恢复；
        // expired/unavailable：意图已清，可重新发起（新键）；
        // capabilityMissing+未知意图：不剥键，展示恢复不可用。
        state = CreateChannelState(
          isCreating: false,
          error: receipt.errorText ?? t.channel.creationRecoveryUnavailable,
        );
        return null;
      }
      // 能力未启用且无未知意图：既有键less路径（行为零变化）。
      final channel = await _api.createChannel(
        name: name,
        description: description,
        avatar: avatar,
        visibility: visibility,
        accessType: accessType,
        joinPolicy: joinPolicy,
        customId: customId,
        tags: tags,
      );

      if (!ref.mounted) return null;
      if (channel != null) {
        state = CreateChannelState(isCreating: false, createdChannel: channel);
        return channel;
      } else {
        state = CreateChannelState(
          isCreating: false,
          error: t.common.operationFailedAgainLater,
        );
        return null;
      }
    } catch (e) {
      iPrint('createChannel failed: $e');
      if (!ref.mounted) return null;
      state = CreateChannelState(
        isCreating: false,
        error: t.common.operationFailedAgainLater,
      );
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
