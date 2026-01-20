import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'message_loading_provider.g.dart';

/// 分页信息类
class PageInfo {
  int currentPage;
  bool hasMore;
  int totalMessages;
  DateTime? lastLoadTime;

  PageInfo({
    required this.currentPage,
    required this.hasMore,
    required this.totalMessages,
    this.lastLoadTime,
  });

  PageInfo copyWith({
    int? currentPage,
    bool? hasMore,
    int? totalMessages,
    DateTime? lastLoadTime,
  }) {
    return PageInfo(
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      totalMessages: totalMessages ?? this.totalMessages,
      lastLoadTime: lastLoadTime ?? this.lastLoadTime,
    );
  }
}

/// 消息加载状态
class MessageLoadingState {
  final bool isLoading;
  final double loadingProgress;
  final String loadingMessage;
  final Map<String, bool> loadingStates;

  MessageLoadingState({
    this.isLoading = false,
    this.loadingProgress = 0.0,
    this.loadingMessage = '',
    Map<String, bool>? loadingStates,
  }) : loadingStates = loadingStates ?? {};

  MessageLoadingState copyWith({
    bool? isLoading,
    double? loadingProgress,
    String? loadingMessage,
    Map<String, bool>? loadingStates,
  }) {
    return MessageLoadingState(
      isLoading: isLoading ?? this.isLoading,
      loadingProgress: loadingProgress ?? this.loadingProgress,
      loadingMessage: loadingMessage ?? this.loadingMessage,
      loadingStates: loadingStates ?? this.loadingStates,
    );
  }

  bool getIsLoading(String conversationId) {
    return loadingStates[conversationId] ?? false;
  }
}

/// 消息加载管理器
/// 处理消息的预加载、缓存和分页加载逻辑
@riverpod
class MessageLoadingManager extends _$MessageLoadingManager {
  // 消息缓存 {conversationId: List<Message>}
  final Map<String, List<Message>> _messageCache = {};

  // 预加载队列 {conversationId: Timer}
  final Map<String, Timer> _preloadTimers = {};

  // 分页信息 {conversationId: pageInfo}
  final Map<String, PageInfo> _pageInfo = {};

  // 预加载配置
  static const int _preloadThreshold = 5; // 距离底部多少条消息时预加载
  static const int _pageSize = 20; // 每页消息数量
  static const Duration _preloadDelay = Duration(milliseconds: 500); // 预加载延迟

  @override
  MessageLoadingState build() {
    ref.onDispose(() {
      _preloadTimers.forEach((_, timer) => timer.cancel());
    });
    return MessageLoadingState();
  }

  /// 获取会话的消息缓存
  List<Message> getCachedMessages(String conversationId) {
    return _messageCache[conversationId] ?? [];
  }

  /// 缓存消息
  void cacheMessages(String conversationId, List<Message> messages) {
    _messageCache[conversationId] = messages;

    // 更新分页信息
    final pageInfo = _pageInfo[conversationId];
    if (pageInfo != null) {
      _pageInfo[conversationId] = pageInfo.copyWith(
        totalMessages: messages.length,
        lastLoadTime: DateTime.now(),
      );
    } else {
      _pageInfo[conversationId] = PageInfo(
        currentPage: 1,
        hasMore: true,
        totalMessages: messages.length,
        lastLoadTime: DateTime.now(),
      );
    }
  }

  /// 添加新消息到缓存
  void addMessageToCache(String conversationId, Message message) {
    if (!_messageCache.containsKey(conversationId)) {
      _messageCache[conversationId] = [];
    }

    // 避免重复添加
    if (!_messageCache[conversationId]!.any((m) => m.id == message.id)) {
      _messageCache[conversationId]!.add(message);

      // 更新总数
      final pageInfo = _pageInfo[conversationId];
      if (pageInfo != null) {
        _pageInfo[conversationId] = pageInfo.copyWith(
          totalMessages: _messageCache[conversationId]!.length,
        );
      }
    }
  }

  /// 从缓存中移除消息
  void removeMessageFromCache(String conversationId, String messageId) {
    _messageCache[conversationId]?.removeWhere((m) => m.id == messageId);

    // 更新总数
    final pageInfo = _pageInfo[conversationId];
    if (pageInfo != null) {
      _pageInfo[conversationId] = pageInfo.copyWith(
        totalMessages: _messageCache[conversationId]?.length ?? 0,
      );
    }
  }

  /// 检查是否需要预加载
  bool shouldPreload(String conversationId, int visibleMessageCount) {
    final cachedMessages = _messageCache[conversationId] ?? [];
    final pageInfo = _pageInfo[conversationId];

    // 如果没有更多数据或者正在加载，不需要预加载
    if (pageInfo == null ||
        !pageInfo.hasMore ||
        state.getIsLoading(conversationId)) {
      return false;
    }

    // 如果缓存的消息数量不足，需要预加载
    return cachedMessages.length - visibleMessageCount <= _preloadThreshold;
  }

  /// 预加载消息
  Future<void> preloadMessages(
    String conversationId,
    Future<List<Message>> Function(int page, int size) loadFunction,
  ) async {
    // 取消之前的预加载定时器
    _preloadTimers[conversationId]?.cancel();

    // 设置新的预加载定时器
    _preloadTimers[conversationId] = Timer(_preloadDelay, () async {
      if (state.getIsLoading(conversationId)) return;

      final pageInfo = _pageInfo[conversationId];
      if (pageInfo == null || !pageInfo.hasMore) return;

      await loadMoreMessages(conversationId, loadFunction);
    });
  }

  /// 加载更多消息
  Future<List<Message>> loadMoreMessages(
    String conversationId,
    Future<List<Message>> Function(int page, int size) loadFunction, {
    bool showLoading = true,
  }) async {
    if (state.getIsLoading(conversationId)) {
      return [];
    }

    // 更新加载状态
    final newLoadingStates = Map<String, bool>.from(state.loadingStates);
    newLoadingStates[conversationId] = true;
    state = state.copyWith(isLoading: true, loadingStates: newLoadingStates);

    if (showLoading) {
      state = state.copyWith(loadingMessage: '加载更多消息...', loadingProgress: 0.0);
    }

    try {
      final pageInfo =
          _pageInfo[conversationId] ??
          PageInfo(currentPage: 0, hasMore: true, totalMessages: 0);

      if (showLoading) {
        state = state.copyWith(loadingProgress: 0.3);
      }

      final newMessages = await loadFunction(
        pageInfo.currentPage + 1,
        _pageSize,
      );

      if (showLoading) {
        state = state.copyWith(loadingProgress: 0.8);
      }

      if (newMessages.isEmpty) {
        _pageInfo[conversationId] = pageInfo.copyWith(hasMore: false);
      } else {
        _pageInfo[conversationId] = PageInfo(
          currentPage: pageInfo.currentPage + 1,
          hasMore: pageInfo.hasMore,
          totalMessages: pageInfo.totalMessages,
          lastLoadTime: DateTime.now(),
        );

        // 添加到缓存
        if (!_messageCache.containsKey(conversationId)) {
          _messageCache[conversationId] = [];
        }

        // 避免重复添加
        final existingIds = _messageCache[conversationId]!
            .map((m) => m.id)
            .toSet();
        final uniqueMessages = newMessages
            .where((m) => !existingIds.contains(m.id))
            .toList();

        _messageCache[conversationId]!.addAll(uniqueMessages);
        _pageInfo[conversationId] = _pageInfo[conversationId]!.copyWith(
          totalMessages: _messageCache[conversationId]!.length,
        );
      }

      if (showLoading) {
        state = state.copyWith(loadingProgress: 1.0);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      return newMessages;
    } catch (e) {
      debugPrint('加载消息失败: $e');
      rethrow;
    } finally {
      final newLoadingStates = Map<String, bool>.from(state.loadingStates);
      newLoadingStates[conversationId] = false;
      state = state.copyWith(
        isLoading: false,
        loadingProgress: 0.0,
        loadingMessage: '',
        loadingStates: newLoadingStates,
      );
    }
  }

  /// 刷新消息
  Future<List<Message>> refreshMessages(
    String conversationId,
    Future<List<Message>> Function(int page, int size) loadFunction,
  ) async {
    // 清空缓存
    _messageCache[conversationId]?.clear();
    _pageInfo[conversationId] = PageInfo(
      currentPage: 0,
      hasMore: true,
      totalMessages: 0,
    );

    // 重新加载
    return loadMoreMessages(conversationId, loadFunction, showLoading: true);
  }

  /// 搜索消息
  List<Message> searchMessages(String conversationId, String query) {
    final messages = _messageCache[conversationId] ?? [];

    if (query.trim().isEmpty) {
      return messages;
    }

    final lowerQuery = query.toLowerCase();
    return messages.where((message) {
      if (message is TextMessage) {
        return message.text.toLowerCase().contains(lowerQuery);
      }
      return false;
    }).toList();
  }

  /// 获取消息位置
  int getMessageIndex(String conversationId, String messageId) {
    final messages = _messageCache[conversationId] ?? [];
    return messages.indexWhere((m) => m.id == messageId);
  }

  /// 检查是否有更多消息
  bool hasMoreMessages(String conversationId) {
    return _pageInfo[conversationId]?.hasMore ?? true;
  }

  /// 清理会话缓存
  void clearConversationCache(String conversationId) {
    _messageCache.remove(conversationId);
    _pageInfo.remove(conversationId);
    _preloadTimers[conversationId]?.cancel();
    _preloadTimers.remove(conversationId);

    final newLoadingStates = Map<String, bool>.from(state.loadingStates);
    newLoadingStates.remove(conversationId);
    state = state.copyWith(loadingStates: newLoadingStates);
  }

  /// 清理所有缓存
  void clearAllCache() {
    _messageCache.clear();
    _pageInfo.clear();
    _preloadTimers.forEach((_, timer) => timer.cancel());
    _preloadTimers.clear();
    state = state.copyWith(loadingStates: {});
  }
}

/// 消息加载指示器组件
class MessageLoadingIndicator extends ConsumerWidget {
  const MessageLoadingIndicator({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messageLoadingManagerProvider);

    if (!state.getIsLoading(conversationId)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: state.loadingProgress > 0
                      ? state.loadingProgress
                      : null,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.loadingMessage.isNotEmpty
                      ? state.loadingMessage
                      : '加载中...',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (state.loadingProgress > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: state.loadingProgress,
              backgroundColor: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 消息预加载触发器组件
class MessagePreloadTrigger extends ConsumerWidget {
  const MessagePreloadTrigger({
    super.key,
    required this.conversationId,
    required this.visibleMessageCount,
    required this.loadFunction,
    required this.child,
  });

  final String conversationId;
  final int visibleMessageCount;
  final Future<List<Message>> Function(int page, int size) loadFunction;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          // 检查是否需要预加载
          final manager = ref.read(messageLoadingManagerProvider.notifier);
          if (manager.shouldPreload(conversationId, visibleMessageCount)) {
            manager.preloadMessages(conversationId, loadFunction);
          }
        }
        return false;
      },
      child: child,
    );
  }
}
