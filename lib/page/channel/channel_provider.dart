import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/service/channel_service.dart';

part 'channel_provider.g.dart';

/// 频道列表状态
class ChannelListState {
  final List<ChannelModel> channels;
  final bool isLoading;
  final String? error;

  const ChannelListState({
    this.channels = const [],
    this.isLoading = false,
    this.error,
  });

  ChannelListState copyWith({
    List<ChannelModel>? channels,
    bool? isLoading,
    String? error,
  }) {
    return ChannelListState(
      channels: channels ?? this.channels,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 频道列表 Notifier
@riverpod
class ChannelListNotifier extends _$ChannelListNotifier {
  final ChannelApi _api = ChannelApi();

  @override
  ChannelListState build() {
    return const ChannelListState();
  }

  /// 加载订阅的频道列表
  Future<void> loadSubscribedChannels() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final channels = await _api.getSubscribedChannels();
      // 检查 provider 是否仍然有效
      if (!ref.mounted) return;
      state = ChannelListState(channels: channels, isLoading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = ChannelListState(isLoading: false, error: e.toString());
    }
  }

  /// 加载管理的频道列表
  Future<void> loadManagedChannels() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final channels = await _api.getManagedChannels();
      if (!ref.mounted) return;
      state = ChannelListState(channels: channels, isLoading: false);
    } catch (e) {
      if (!ref.mounted) return;
      state = ChannelListState(isLoading: false, error: e.toString());
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
  Future<bool> subscribeChannel(String channelId) async {
    try {
      final success = await _api.subscribe(channelId);
      if (success) {
        await loadSubscribedChannels();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// 取消订阅频道
  Future<bool> unsubscribeChannel(String channelId) async {
    try {
      final success = await _api.unsubscribe(channelId);
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
  final bool hasMore;
  final String? error;

  const ChannelDetailState({
    this.channel,
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  ChannelDetailState copyWith({
    ChannelModel? channel,
    List<ChannelMessageModel>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
    bool clearChannel = false,
  }) {
    return ChannelDetailState(
      channel: clearChannel ? null : (channel ?? this.channel),
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
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

  @override
  ChannelDetailState build() {
    return const ChannelDetailState();
  }

  /// 加载频道详情
  Future<void> loadChannel(String channelId) async {
    _channelId = channelId;
    state = state.copyWith(isLoading: true, error: null, clearChannel: true);

    try {
      final channel = await _api.getChannel(channelId);
      if (!ref.mounted) return;
      if (channel != null) {
        state = state.copyWith(channel: channel, isLoading: false);
        // 加载消息
        await loadMessages(channelId);
      } else {
        state = state.copyWith(isLoading: false, error: '频道不存在');
      }
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
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
      state = state.copyWith(error: e.toString());
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
  Future<bool> publishMessage({
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
  }) async {
    if (_channelId == null) return false;

    try {
      final message = await _api.publishMessage(
        channelId: _channelId!,
        content: content,
        msgType: msgType,
        payload: payload,
      );

      if (!ref.mounted) return false;
      if (message != null) {
        // 添加到消息列表开头
        state = state.copyWith(messages: [message, ...state.messages]);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 标记已读
  Future<void> markAsRead(String messageId) async {
    if (_channelId == null) return;
    await _api.markAsRead(_channelId!, messageId);
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
      state = CreateChannelState(isCreating: false, error: e.toString());
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
  // 从 ChannelService 获取未读总数
  // 注意：这是一个同步 Provider，不会自动更新
  // 需要通过 refreshChannelUnreadCount() 手动刷新
  return 0; // 默认值，实际值由 ChannelService 管理
}

/// 刷新频道未读计数
///
/// 调用此方法从数据库获取最新的未读总数
Future<int> refreshChannelUnreadCount() async {
  return await ChannelService.to.getTotalUnreadCount();
}
