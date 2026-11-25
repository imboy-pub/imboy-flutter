part of 'chat_provider.dart';

/// 分页消息加载实现（自 ChatNotifier 抽出的扩展，行为与调用方零变更）
extension ChatNotifierMessagesLoad on ChatNotifier {
  Future<List<Message>> _loadMoreMessagesImpl(
    ConversationModel obj, {
    bool isInitial = false,
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async {
    iPrint(
      '_loadMoreMessages: isInitial=$isInitial, hasMore=${loadState.hasMoreMessage}, loading=${loadState.isLoading}',
    );

    if (isInitial) {
      final String oldConversationId = loadState.currentConversationId;
      if (oldConversationId != obj.uk3) _locationRequest++;

      (_chatService?.messages.length ?? 0) > 0;
      final bool isStateReset = loadState.currentConversationId.isEmpty;

      final bool isDifferentConversation =
          !isStateReset && loadState.currentConversationId != obj.uk3;
      final keepContext =
          _contextPaginationConversationId == obj.uk3 &&
          (_chatService?.messages.isNotEmpty ?? false);
      if (!keepContext) _contextPaginationConversationId = null;

      loadState = loadState.copyWith(
        nextAutoId: keepContext ? loadState.nextAutoId : 0,
        prevAutoId: keepContext ? loadState.prevAutoId : 0,
        hasMoreMessage: true,
        currentConversationId: obj.uk3,
      );

      // P1-2：进会话后台正向同步服务端归档历史入 SQLite（不阻塞首屏渲染）
      unawaited(
        syncHistoryBackfill(
          obj,
          webNewestFirst: webNewestFirst,
          allowPendingRetry: allowPendingRetry,
        ),
      );

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
        } else if (!webNewestFirst) {
          iPrint('会话初始化：跳过加载，直接返回现有 $messageCount 条消息');
          return _chatService!.messages.toList();
        }
      }

      iPrint('设置当前会话ID: ${obj.uk3}');
    }

    if (loadState.isLoading) return [];

    if (!isInitial && !loadState.hasMoreMessage) {
      final int messageCount = _chatService?.messages.length ?? 0;
      if (messageCount > 0) {
        iPrint('没有更多消息，返回现有 $messageCount 条消息');
        return _chatService!.messages.toList();
      }
    }

    final request = _locationRequest;
    final service = _chatService;
    final conversationId = obj.uk3;
    bool current() =>
        !_isDisposed &&
        sessionReader.isCurrent(_ownerSession) &&
        Env().apiBaseUrl == _ownerEndpoint &&
        request == _locationRequest &&
        identical(service, _chatService) &&
        loadState.currentConversationId == conversationId;
    if (!current()) return [];
    loadState = loadState.copyWith(isLoading: true);
    final List<Message> items;
    try {
      items = await pageMessagesForConversation(
        obj,
        loadState.pageSize,
        current,
        allowPendingRetry: allowPendingRetry,
      );
    } finally {
      if (current()) loadState = loadState.copyWith(isLoading: false);
    }
    if (!current()) return [];

    syncMessagesToState();

    if (items.isEmpty) {
      loadState = loadState.copyWith(hasMoreMessage: false);
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

    if (isInitial && webNewestFirst) {
      final service = _chatService;
      if (service == null) return [];
      final merged = _mergeWebInitialMessages(service.messages.toList(), items);
      await service.setMessages(merged, animated: false);
      if (!current()) return [];
    }
    if (newItems.isNotEmpty) {
      if (isInitial) {
        final service = _chatService;
        if (!webNewestFirst) service?.setMessages(newItems);
        loadState = loadState.copyWith(
          nextAutoId: parseModelInt(newItems.first.metadata?['auto_id']),
          prevAutoId: parseModelInt(newItems.last.metadata?['auto_id']),
        );
      } else {
        if (webNewestFirst) {
          final service = _chatService;
          await service?.insertAllMessages(
            newItems.reversed.toList(),
            index: service.messages.length,
          );
          if (!current()) return [];
        } else {
          _chatService?.insertAllMessages(newItems, index: 0);
        }
        if (_contextPaginationConversationId != obj.uk3) {
          loadState = loadState.copyWith(
            nextAutoId: parseModelInt(
              newItems.first.metadata?['auto_id'],
              defaultValue: loadState.nextAutoId,
            ),
          );
        }
      }
    }

    if (current()) syncMessagesToState();
    return newItems;
  }
}
