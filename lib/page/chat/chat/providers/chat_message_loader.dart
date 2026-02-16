/// 消息加载处理器
///
/// 负责消息的分页加载、转换、缓存等操作
/// 从 ChatNotifier 中提取，遵循单一职责原则（SRP）
library;

import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

/// 加载结果
class LoadResult {
  /// 加载的消息列表
  final List<Message> messages;

  /// 是否有更多消息
  final bool hasMore;

  /// 下一页游标
  final int? nextCursor;

  const LoadResult({
    required this.messages,
    required this.hasMore,
    this.nextCursor,
  });

  /// 空结果
  static const empty = LoadResult(messages: [], hasMore: false);
}

/// 消息加载配置
class MessageLoaderConfig {
  /// 每页消息数量
  final int pageSize;

  /// 是否启用缓存
  final bool enableCache;

  /// 预加载阈值（距离底部多少条消息时开始预加载）
  final int preloadThreshold;

  const MessageLoaderConfig({
    this.pageSize = 16,
    this.enableCache = true,
    this.preloadThreshold = 5,
  });

  /// 默认配置
  static const defaultConfig = MessageLoaderConfig();
}

/// 消息加载处理器
///
/// 封装所有消息加载相关逻辑，包括：
/// - 分页加载
/// - 消息转换
/// - 去重处理
class ChatMessageLoader {
  /// 配置
  final MessageLoaderConfig config;

  /// 消息仓库缓存
  final Map<String, MessageRepo> _repoCache = {};

  ChatMessageLoader({
    this.config = MessageLoaderConfig.defaultConfig,
  });

  /// 获取消息仓库
  MessageRepo getRepo(String chatType) {
    final tb = MessageRepo.getTableName(chatType);
    return _repoCache.putIfAbsent(tb, () => MessageRepo(tableName: tb));
  }

  /// 加载消息
  ///
  /// [conversation] 会话模型
  /// [cursor] 分页游标（auto_id）
  /// [existingIds] 已有消息 ID 集合（用于去重）
  Future<LoadResult> loadMessages(
    ConversationModel conversation, {
    int cursor = 0,
    Set<String>? existingIds,
  }) async {
    final repo = getRepo(conversation.type);
    final items = await repo.pageForConversation(
      conversation.uk3,
      cursor,
      config.pageSize,
    );

    if (items.isEmpty) {
      return LoadResult(
        messages: [],
        hasMore: false,
        nextCursor: cursor,
      );
    }

    // 转换消息
    final messages = await _convertMessages(items);

    // 去重
    final filteredMessages = existingIds != null
        ? messages.where((m) => !existingIds.contains(m.id)).toList()
        : messages;

    return LoadResult(
      messages: filteredMessages,
      hasMore: items.length >= config.pageSize,
      nextCursor: items.first.autoId,
    );
  }

  /// 初始加载
  ///
  /// 用于首次进入会话时加载消息
  Future<LoadResult> initialLoad(ConversationModel conversation) async {
    return loadMessages(conversation, cursor: 0);
  }

  /// 加载更多（历史消息）
  ///
  /// [conversation] 会话模型
  /// [currentCursor] 当前游标
  /// [existingIds] 已有消息 ID
  Future<LoadResult> loadMore(
    ConversationModel conversation,
    int currentCursor,
    Set<String> existingIds,
  ) async {
    return loadMessages(
      conversation,
      cursor: currentCursor,
      existingIds: existingIds,
    );
  }

  /// 搜索消息
  ///
  /// [conversation] 会话模型
  /// [keyword] 搜索关键词
  Future<List<Message>> searchMessages(
    ConversationModel conversation,
    String keyword,
  ) async {
    if (keyword.isEmpty) return [];

    final repo = getRepo(conversation.type);
    // 使用 page 方法并通过 payload 过滤
    // MessageRepo 没有 search 方法，使用 page 代替
    final items = await repo.page(
      conversationUk3: conversation.uk3,
      page: 1,
      size: 100, // 搜索结果限制
    );

    // 简单的关键词过滤
    final filtered = items.where((msg) {
      final payloadStr = msg.payload?.toString().toLowerCase() ?? '';
      return payloadStr.contains(keyword.toLowerCase());
    }).toList();

    return _convertMessages(filtered);
  }

  /// 获取特定消息周围的消息
  ///
  /// [conversation] 会话模型
  /// [messageId] 目标消息 ID
  /// [beforeCount] 目标之前的消息数量
  /// [afterCount] 目标之后的消息数量
  Future<List<Message>> getMessagesAround(
    ConversationModel conversation,
    String messageId, {
    int beforeCount = 10,
    int afterCount = 10,
  }) async {
    final repo = getRepo(conversation.type);

    // 查找目标消息
    final targetMsg = await repo.find(messageId);
    if (targetMsg == null) return [];

    final targetAutoId = targetMsg.autoId;

    // 获取之前的消息（使用 pageForConversation）
    final beforeItems = await repo.pageForConversation(
      conversation.uk3,
      targetAutoId + 1, // 从目标消息之后开始
      beforeCount,
    );

    // 获取之后的消息（使用 pageNewerForConversation）
    final afterItems = await repo.pageNewerForConversation(
      conversation.uk3,
      targetAutoId - 1, // 从目标消息之前开始
      afterCount,
    );

    // 合并结果
    final allItems = [...beforeItems, targetMsg, ...afterItems];
    return _convertMessages(allItems);
  }

  /// 获取最新消息
  ///
  /// [conversation] 会话模型
  /// [count] 获取数量
  Future<List<Message>> getLatestMessages(
    ConversationModel conversation, {
    int count = 1,
  }) async {
    final repo = getRepo(conversation.type);
    final items = await repo.page(
      conversationUk3: conversation.uk3,
      page: 1,
      size: count,
    );

    return _convertMessages(items);
  }

  /// 转换消息模型
  Future<List<Message>> _convertMessages(List<MessageModel> items) async {
    final messages = <Message>[];

    for (final item in items) {
      try {
        final message = await item.toTypeMessage();
        messages.add(message);
      } catch (e) {
        // 转换失败时跳过
        continue;
      }
    }

    return messages;
  }

  /// 清理缓存
  void clearCache() {
    _repoCache.clear();
  }

  /// 释放资源
  void dispose() {
    clearCache();
  }
}

/// 消息加载状态
///
/// 用于追踪加载状态
class MessageLoadState {
  /// 是否正在加载
  final bool isLoading;

  /// 是否正在加载更多
  final bool isLoadingMore;

  /// 是否有更多消息
  final bool hasMore;

  /// 错误信息
  final String? error;

  const MessageLoadState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  /// 初始状态
  static const initial = MessageLoadState();

  /// 复制并修改
  MessageLoadState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    return MessageLoadState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }

  /// 加载中状态
  static const loading = MessageLoadState(isLoading: true);

  /// 加载更多状态
  static const loadingMore = MessageLoadState(isLoadingMore: true);

  /// 错误状态
  static Function(String) errorState = (String msg) =>
      MessageLoadState(error: msg, hasMore: false);
}
