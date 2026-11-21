/// 聊天状态类（不可变）
///
/// 遵循 Riverpod 最佳实践，使用不可变状态类
/// 所有状态变更通过 copyWith 方法
library;

import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;

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

  /// 归档历史正向同步（syncHistoryBackfill）最近一次是否失败
  ///
  /// BUG#119：回填失败不再静默。置 true 时聊天页空态显示「历史记录
  /// 加载失败，点击重试」，与「服务端确认无数据」的「暂无数据」区分。
  final bool historySyncFailed;

  /// 归档历史回填成功但服务端确认 0 条（msg_store 为空），而会话有
  /// lastMsgId（服务端会话行确认消息存在）——即「消息存在但历史不可取」。
  ///
  /// 与 historySyncFailed（API 失败/落库异常）不同：本标记是服务端
  /// 正常返回空归档，不能归为失败，但也不能展示误导性的「暂无数据」。
  /// 置 true 时聊天页空态显示「历史消息暂不可用」，附重试入口。
  final bool historyUnavailable;

  /// 当前会话的消息列表（Phase 2.1.d 接缝字段）
  ///
  /// 默认 const []。ChatNotifier 在 init / 收消息 / 发消息 / 加载更多 等关键
  /// 路径调 `state = state.copyWith(messages: _chatService.messages.toList())`
  /// 同步给外部消费方（如 WebShellBootstrap.chatBuilder 接入 ChatPanel.messages）。
  ///
  /// 注：当前 chat_provider.dart 内部仍以 `_chatService.messages` 为唯一真相源，
  /// 本字段是给外部 `ref.watch(chatProvider(peerId)).messages` 用的响应式镜像。
  /// 后续 slice 在关键路径填充（避免本切片侵入 2554 行 chat_provider）。
  final List<Message> messages;

  // ================= 个人云端历史四维状态（MH-01 §5/§10.9，FL-04） =================

  /// 维度一：本地是否已有（个人历史）投影行。
  final bool personalHistoryLocalPresent;

  /// 维度二：云端个人历史开关（服务端授权状态 ON/OFF）。
  final bool personalHistoryCloudEnabled;

  /// 维度三：同步态（同步中/失败/等待密钥）。
  final PersonalHistorySyncStatus personalHistorySyncStatus;

  /// 维度四：删除阶段进度（关闭+删除我的云端历史）。
  final PersonalHistoryDeletionPhase personalHistoryDeletionPhase;

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
    this.historySyncFailed = false,
    this.historyUnavailable = false,
    this.messages = const [],
    this.personalHistoryLocalPresent = false,
    this.personalHistoryCloudEnabled = false,
    this.personalHistorySyncStatus = PersonalHistorySyncStatus.idle,
    this.personalHistoryDeletionPhase = PersonalHistoryDeletionPhase.none,
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
    bool? historySyncFailed,
    bool? historyUnavailable,
    List<Message>? messages,
    bool? personalHistoryLocalPresent,
    bool? personalHistoryCloudEnabled,
    PersonalHistorySyncStatus? personalHistorySyncStatus,
    PersonalHistoryDeletionPhase? personalHistoryDeletionPhase,
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
      historySyncFailed: historySyncFailed ?? this.historySyncFailed,
      historyUnavailable: historyUnavailable ?? this.historyUnavailable,
      messages: messages ?? this.messages,
      personalHistoryLocalPresent:
          personalHistoryLocalPresent ?? this.personalHistoryLocalPresent,
      personalHistoryCloudEnabled:
          personalHistoryCloudEnabled ?? this.personalHistoryCloudEnabled,
      personalHistorySyncStatus:
          personalHistorySyncStatus ?? this.personalHistorySyncStatus,
      personalHistoryDeletionPhase:
          personalHistoryDeletionPhase ?? this.personalHistoryDeletionPhase,
    );
  }

  /// 初始状态
  static const initial = ChatState();

  /// 是否有当前会话
  bool get hasConversation => currentConversationId.isNotEmpty;

  /// §10.9 四维冲突时的可见性优先级投影。
  PersonalHistoryVisibility get personalHistoryVisibility =>
      resolvePersonalHistoryVisibility(
        deletionPhase: personalHistoryDeletionPhase,
        syncStatus: personalHistorySyncStatus,
        cloudEnabled: personalHistoryCloudEnabled,
        localPresent: personalHistoryLocalPresent,
      );

  @override
  String toString() {
    return 'ChatState(pageSize: $pageSize, connected: $connected, '
        'hasMoreMessage: $hasMoreMessage, isLoading: $isLoading, '
        'isLoadingNewer: $isLoadingNewer, nextAutoId: $nextAutoId, '
        'prevAutoId: $prevAutoId, memberCount: $memberCount, '
        'composerHeight: $composerHeight, '
        'currentConversationId: $currentConversationId, '
        'lastHistorySeq: $lastHistorySeq, historyHasMore: $historyHasMore, '
        'historySyncFailed: $historySyncFailed, '
        'historyUnavailable: $historyUnavailable)';
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
        other.historyHasMore == historyHasMore &&
        other.historySyncFailed == historySyncFailed &&
        other.historyUnavailable == historyUnavailable &&
        other.personalHistoryLocalPresent == personalHistoryLocalPresent &&
        other.personalHistoryCloudEnabled == personalHistoryCloudEnabled &&
        other.personalHistorySyncStatus == personalHistorySyncStatus &&
        other.personalHistoryDeletionPhase == personalHistoryDeletionPhase;
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
      historySyncFailed,
      historyUnavailable,
      personalHistoryLocalPresent,
      personalHistoryCloudEnabled,
      personalHistorySyncStatus,
      personalHistoryDeletionPhase,
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

/// 个人云端历史四维状态之一：同步态（MH-01 §5/§10.9）。
///
/// 与既有 [ChatState.historySyncFailed]（msg_store 归档回填失败）正交：
/// 本状态只描述「个人云端历史副本」通道。
enum PersonalHistorySyncStatus {
  /// 空闲（无在途同步，且无失败残留）。
  idle,

  /// 同步进行中（changes 拉取/解密/合并或上传队列冲刷）。
  syncing,

  /// 最近一次同步失败（网络/服务端 fail-closed 错误），可重试。
  failed,

  /// 恢复密钥未就绪：无法解密云端副本（显式不可用，不静默跳过）。
  waitingKey,
}

/// 个人云端历史删除阶段（MH-01 §2.6/§10.6，MSG-H07）。
enum PersonalHistoryDeletionPhase {
  /// 未发起关闭/删除。
  none,

  /// 关闭已受理（202 OFF_PURGE_PENDING），在线清理进行中。
  pending,

  /// 在线副本清理完成，等待备份/PITR 窗口到期（窗口内读闸门保持关闭）。
  onlineDone,

  /// 备份窗口已到期（删除流程完结）。
  backupExpiry,

  /// 清理失败，等待重试（delete-status failures 非空且提供 retry）。
  failed,
}

/// 四维状态冲突时对用户可见的最高优先项（MH-01 §10.9 优先级矩阵）：
/// 删除进度 > 等待密钥 > 同步失败 > 云端关闭 > 本地空态。
enum PersonalHistoryVisibility {
  /// 删除进行中（或清理失败待重试）——读闸门关闭提示。
  deletionProgress,

  /// 等待恢复密钥——云端有副本但暂不可解密。
  waitingKey,

  /// 同步失败——本地视图可用但可能有缺口，提供重试。
  syncFailed,

  /// 云端关闭（默认 OFF）——仅本地历史。
  cloudOff,

  /// 云端开启但本地无历史投影（未恢复/新设备）。
  localEmpty,

  /// 一切正常：无更高优先项需要提示。
  none,
}

/// 计算 §10.9 优先级矩阵（空态优先级矩阵随 MH-02 验收冻结）。
PersonalHistoryVisibility resolvePersonalHistoryVisibility({
  required PersonalHistoryDeletionPhase deletionPhase,
  required PersonalHistorySyncStatus syncStatus,
  required bool cloudEnabled,
  required bool localPresent,
}) {
  if (deletionPhase == PersonalHistoryDeletionPhase.pending ||
      deletionPhase == PersonalHistoryDeletionPhase.onlineDone ||
      deletionPhase == PersonalHistoryDeletionPhase.failed) {
    return PersonalHistoryVisibility.deletionProgress;
  }
  if (syncStatus == PersonalHistorySyncStatus.waitingKey) {
    return PersonalHistoryVisibility.waitingKey;
  }
  if (syncStatus == PersonalHistorySyncStatus.failed) {
    return PersonalHistoryVisibility.syncFailed;
  }
  if (!cloudEnabled) {
    return PersonalHistoryVisibility.cloudOff;
  }
  if (!localPresent) {
    return PersonalHistoryVisibility.localEmpty;
  }
  return PersonalHistoryVisibility.none;
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
