/// 聊天状态类（不可变）
///
/// 遵循 Riverpod 最佳实践，使用不可变状态类
/// 所有状态变更通过 copyWith 方法
library;

/// 聊天状态
class ChatState {
  /// 每页消息数量
  final int pageSize;

  /// WebSocket 连接状态
  final bool connected;

  /// 是否有更多历史消息
  final bool hasMoreMessage;

  /// 是否正在加载（历史消息）
  final bool isLoading;

  /// 是否正在加载新消息
  final bool isLoadingNewer;

  /// 下一页起始 ID（用于分页）
  final int nextAutoId;

  /// 上一页结束 ID
  final int prevAutoId;

  /// 群成员数量
  final int memberCount;

  /// 输入框高度
  final double composerHeight;

  /// 当前会话 ID
  final String currentConversationId;

  /// 上次拉取历史消息的 conv_seq 游标（用于 msg_store 分页）
  /// 0 表示从头拉取
  final int lastHistorySeq;

  /// msg_store 历史消息是否还有更多
  final bool historyHasMore;

  const ChatState({
    this.pageSize = 16,
    this.connected = true,
    this.hasMoreMessage = true,
    this.isLoading = false,
    this.isLoadingNewer = false,
    this.nextAutoId = 0,
    this.prevAutoId = 0,
    this.memberCount = 0,
    this.composerHeight = 52.0,
    this.currentConversationId = '',
    this.lastHistorySeq = 0,
    this.historyHasMore = true,
  });

  /// 创建副本
  ChatState copyWith({
    int? pageSize,
    bool? connected,
    bool? hasMoreMessage,
    bool? isLoading,
    bool? isLoadingNewer,
    int? nextAutoId,
    int? prevAutoId,
    int? memberCount,
    double? composerHeight,
    String? currentConversationId,
    int? lastHistorySeq,
    bool? historyHasMore,
  }) {
    return ChatState(
      pageSize: pageSize ?? this.pageSize,
      connected: connected ?? this.connected,
      hasMoreMessage: hasMoreMessage ?? this.hasMoreMessage,
      isLoading: isLoading ?? this.isLoading,
      isLoadingNewer: isLoadingNewer ?? this.isLoadingNewer,
      nextAutoId: nextAutoId ?? this.nextAutoId,
      prevAutoId: prevAutoId ?? this.prevAutoId,
      memberCount: memberCount ?? this.memberCount,
      composerHeight: composerHeight ?? this.composerHeight,
      currentConversationId:
          currentConversationId ?? this.currentConversationId,
      lastHistorySeq: lastHistorySeq ?? this.lastHistorySeq,
      historyHasMore: historyHasMore ?? this.historyHasMore,
    );
  }

  /// 初始状态
  static const initial = ChatState();

  /// 是否有当前会话
  bool get hasConversation => currentConversationId.isNotEmpty;

  @override
  String toString() {
    return 'ChatState(pageSize: $pageSize, connected: $connected, '
        'hasMoreMessage: $hasMoreMessage, isLoading: $isLoading, '
        'isLoadingNewer: $isLoadingNewer, nextAutoId: $nextAutoId, '
        'prevAutoId: $prevAutoId, memberCount: $memberCount, '
        'composerHeight: $composerHeight, '
        'currentConversationId: $currentConversationId, '
        'lastHistorySeq: $lastHistorySeq, historyHasMore: $historyHasMore)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatState &&
        other.pageSize == pageSize &&
        other.connected == connected &&
        other.hasMoreMessage == hasMoreMessage &&
        other.isLoading == isLoading &&
        other.isLoadingNewer == isLoadingNewer &&
        other.nextAutoId == nextAutoId &&
        other.prevAutoId == prevAutoId &&
        other.memberCount == memberCount &&
        other.composerHeight == composerHeight &&
        other.currentConversationId == currentConversationId &&
        other.lastHistorySeq == lastHistorySeq &&
        other.historyHasMore == historyHasMore;
  }

  @override
  int get hashCode {
    return Object.hash(
      pageSize,
      connected,
      hasMoreMessage,
      isLoading,
      isLoadingNewer,
      nextAutoId,
      prevAutoId,
      memberCount,
      composerHeight,
      currentConversationId,
      lastHistorySeq,
      historyHasMore,
    );
  }
}

/// 消息发送状态
enum MessageSendStatus {
  /// 发送中
  sending,

  /// 发送成功
  sent,

  /// 发送失败
  failed,

  /// 已读
  seen,
}

/// 聊天类型
enum ChatType {
  /// 单聊
  c2c('C2C'),

  /// 群聊
  c2g('C2G'),

  /// 客服
  c2s('C2S');

  final String code;
  const ChatType(this.code);

  static ChatType fromCode(String code) {
    return switch (code.toUpperCase()) {
      'C2C' => ChatType.c2c,
      'C2G' => ChatType.c2g,
      'C2S' => ChatType.c2s,
      _ => ChatType.c2c,
    };
  }
}
