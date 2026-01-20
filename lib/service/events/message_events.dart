import 'base_event.dart';
import 'package:imboy/store/model/message_model.dart';

/// 消息相关事件
///
/// 定义了消息发送、接收、状态变更等所有消息相关的事件类型

/// 请求发送消息事件
///
/// 当用户请求发送消息时触发，消息进入发送流程
final class MessageSendRequestedEvent extends AppEvent {
  @override
  List<Object> get props => [message, conversationUk3, isOffline, priority];

  /// 消息模型
  final MessageModel message;

  /// 目标会话的 UK3
  final String conversationUk3;

  /// 是否为离线消息（网络不可用时）
  final bool isOffline;

  /// 消息优先级（0-10，数字越大优先级越高）
  final int priority;

  const MessageSendRequestedEvent({
    required this.message,
    required this.conversationUk3,
    this.isOffline = false,
    this.priority = 5,
  });

  @override
  String toString() {
    return 'MessageSendRequestedEvent(messageId: ${message.id}, conversationUk3: $conversationUk3, isOffline: $isOffline, priority: $priority)';
  }
}

/// 消息已发送事件
///
/// 当消息成功发送到服务器时触发
final class MessageSentEvent extends AppEvent {
  @override
  List<Object> get props => [
    messageId,
    messageType,
    conversationUk3,
    serverTimestamp,
    sendDuration,
  ];

  /// 消息 ID
  final String messageId;

  /// 消息类型（C2C, C2G 等）
  final String messageType;

  /// 会话 UK3
  final String conversationUk3;

  /// 服务器返回的消息时间戳（毫秒）
  final int serverTimestamp;

  /// 发送耗时（毫秒）
  final int sendDuration;

  /// 消息在服务器的存储 ID（如果有）
  final String? serverMessageId;

  const MessageSentEvent({
    required this.messageId,
    required this.messageType,
    required this.conversationUk3,
    required this.serverTimestamp,
    required this.sendDuration,
    this.serverMessageId,
  });

  @override
  String toString() {
    return 'MessageSentEvent(messageId: $messageId, messageType: $messageType, conversationUk3: $conversationUk3, sendDuration: ${sendDuration}ms)';
  }
}

/// 消息发送失败事件
///
/// 当消息发送失败时触发
final class MessageSendFailedEvent extends ErrorEvent {
  @override
  List<Object> get props => [
    messageId,
    messageType,
    conversationUk3,
    failureReason,
    willRetry,
    currentRetryCount,
    maxRetryCount,
  ];

  /// 消息 ID
  final String messageId;

  /// 消息类型（C2C, C2G 等）
  final String messageType;

  /// 会话 UK3
  final String conversationUk3;

  /// 失败原因类型
  final MessageFailureReason failureReason;

  /// 是否会自动重试
  final bool willRetry;

  /// 当前重试次数
  final int currentRetryCount;

  /// 最大重试次数
  final int maxRetryCount;

  const MessageSendFailedEvent({
    required super.errorCode,
    required super.errorMessage,
    required this.messageId,
    required this.messageType,
    required this.conversationUk3,
    required this.failureReason,
    this.willRetry = false,
    this.currentRetryCount = 0,
    this.maxRetryCount = 3,
    super.error,
    super.stackTrace,
  });

  @override
  String toString() {
    return 'MessageSendFailedEvent(messageId: $messageId, messageType: $messageType, failureReason: $failureReason, willRetry: $willRetry, retry: $currentRetryCount/$maxRetryCount, errorCode: $errorCode, errorMessage: $errorMessage)';
  }
}

/// 消息失败原因枚举
enum MessageFailureReason {
  /// 网络不可用
  networkUnavailable,

  /// WebSocket 未连接
  websocketNotConnected,

  /// 消息格式错误
  messageFormatError,

  /// 消息过大
  messageTooLarge,

  /// 用户未登录
  notAuthenticated,

  /// 对方不存在或已删除
  targetNotFound,

  /// 对方已拉黑发送者
  blockedByReceiver,

  /// 群组已解散
  groupDisbanded,

  /// 已被移出群组
  removedFromGroup,

  /// 服务器错误
  serverError,

  /// 超时
  timeout,

  /// 其他原因
  other,
}

/// 消息状态变更事件
///
/// 当消息状态发生变化时触发（如：发送中 → 已发送 → 已送达 → 已读）
final class MessageStatusChangedEvent extends AppEvent {
  @override
  List<Object> get props => [
    messageId,
    conversationUk3,
    newStatus,
    statusChangeTime,
  ];

  /// 消息 ID
  final String messageId;

  /// 会话 UK3
  final String conversationUk3;

  /// 旧状态
  final int? oldStatus;

  /// 新状态
  final int newStatus;

  /// 状态变更时间戳（毫秒）
  final int statusChangeTime;

  const MessageStatusChangedEvent({
    required this.messageId,
    required this.conversationUk3,
    this.oldStatus,
    required this.newStatus,
    required this.statusChangeTime,
  });

  @override
  String toString() {
    return 'MessageStatusChangedEvent(messageId: $messageId, conversationUk3: $conversationUk3, oldStatus: $oldStatus, newStatus: $newStatus)';
  }
}

/// 消息接收事件
///
/// 当接收到新消息时触发（已解析并存储到本地数据库）
final class MessageReceivedEvent extends AppEvent {
  @override
  List<Object> get props => [
    message,
    conversationUk3,
    isOfflineMessage,
    isDuplicate,
  ];

  /// 消息模型
  final MessageModel message;

  /// 会话 UK3
  final String conversationUk3;

  /// 是否为离线消息
  final bool isOfflineMessage;

  /// 是否为重复消息（已根据消息 ID 去重）
  final bool isDuplicate;

  const MessageReceivedEvent({
    required this.message,
    required this.conversationUk3,
    this.isOfflineMessage = false,
    this.isDuplicate = false,
  });

  @override
  String toString() {
    return 'MessageReceivedEvent(messageId: ${message.id}, conversationUk3: $conversationUk3, isOffline: $isOfflineMessage, isDuplicate: $isDuplicate)';
  }
}

/// 消息撤回事件
///
/// 当消息被撤回时触发
final class MessageRevokedEvent extends AppEvent {
  @override
  List<Object> get props => [messageId, conversationUk3, revokerId, revokeTime];

  /// 被撤回的消息 ID
  final String messageId;

  /// 会话 UK3
  final String conversationUk3;

  /// 撤回操作者的用户 ID
  final String revokerId;

  /// 撤回时间戳（毫秒）
  final int revokeTime;

  /// 撤回原因（可选）
  final String? reason;

  const MessageRevokedEvent({
    required this.messageId,
    required this.conversationUk3,
    required this.revokerId,
    required this.revokeTime,
    this.reason,
  });

  @override
  String toString() {
    return 'MessageRevokedEvent(messageId: $messageId, conversationUk3: $conversationUk3, revokerId: $revokerId, reason: $reason)';
  }
}

/// 消息已读事件
///
/// 当消息被标记为已读时触发
final class MessageReadEvent extends AppEvent {
  @override
  List<Object> get props => [
    messageId,
    conversationUk3,
    readerId,
    readTime,
    isBatchRead,
  ];

  /// 已读消息的 ID
  final String messageId;

  /// 会话 UK3
  final String conversationUk3;

  /// 阅读者的用户 ID
  final String readerId;

  /// 已读时间戳（毫秒）
  final int readTime;

  /// 是否为批量已读（多条消息同时标记为已读）
  final bool isBatchRead;

  const MessageReadEvent({
    required this.messageId,
    required this.conversationUk3,
    required this.readerId,
    required this.readTime,
    this.isBatchRead = false,
  });

  @override
  String toString() {
    return 'MessageReadEvent(messageId: $messageId, conversationUk3: $conversationUk3, readerId: $readerId, isBatch: $isBatchRead)';
  }
}

/// 消息编辑事件
///
/// 当消息被编辑时触发
final class MessageEditedEvent extends AppEvent {
  @override
  List<Object> get props => [messageId, conversationUk3, editorId, editTime];

  /// 被编辑的消息 ID
  final String messageId;

  /// 会话 UK3
  final String conversationUk3;

  /// 编辑者的用户 ID
  final String editorId;

  /// 旧内容
  final String? oldContent;

  /// 新内容
  final String? newContent;

  /// 编辑时间戳（毫秒）
  final int editTime;

  const MessageEditedEvent({
    required this.messageId,
    required this.conversationUk3,
    required this.editorId,
    this.oldContent,
    this.newContent,
    required this.editTime,
  });

  @override
  String toString() {
    return 'MessageEditedEvent(messageId: $messageId, conversationUk3: $conversationUk3, editorId: $editorId)';
  }
}

/// 消息删除事件
///
/// 当消息被删除时触发
final class MessageDeletedEvent extends AppEvent {
  @override
  List<Object> get props => [
    messageId,
    conversationUk3,
    deleterId,
    deleteTime,
    isBothDeleted,
  ];

  /// 被删除的消息 ID
  final String messageId;

  /// 会话 UK3
  final String conversationUk3;

  /// 删除操作者的用户 ID
  final String deleterId;

  /// 删除时间戳（毫秒）
  final int deleteTime;

  /// 是否为双向删除（双方都删除）
  final bool isBothDeleted;

  const MessageDeletedEvent({
    required this.messageId,
    required this.conversationUk3,
    required this.deleterId,
    required this.deleteTime,
    this.isBothDeleted = false,
  });

  @override
  String toString() {
    return 'MessageDeletedEvent(messageId: $messageId, conversationUk3: $conversationUk3, deleterId: $deleterId, isBothDeleted: $isBothDeleted)';
  }
}

/// 消息重试事件
///
/// 当消息发送失败后进行重试时触发
final class MessageRetryEvent extends AppEvent {
  @override
  List<Object> get props => [
    messageId,
    conversationUk3,
    currentAttempt,
    maxAttempts,
    retryDelay,
    lastFailureReason,
  ];

  /// 消息 ID
  final String messageId;

  /// 会话 UK3
  final String conversationUk3;

  /// 当前重试次数
  final int currentAttempt;

  /// 最大重试次数
  final int maxAttempts;

  /// 重试延迟（毫秒）
  final int retryDelay;

  /// 上次失败原因
  final String lastFailureReason;

  const MessageRetryEvent({
    required this.messageId,
    required this.conversationUk3,
    required this.currentAttempt,
    required this.maxAttempts,
    required this.retryDelay,
    required this.lastFailureReason,
  });

  @override
  String toString() {
    return 'MessageRetryEvent(messageId: $messageId, conversationUk3: $conversationUk3, attempt: $currentAttempt/$maxAttempts, retryDelay: ${retryDelay}ms, reason: $lastFailureReason)';
  }
}

/// 消息输入状态事件
///
/// 当对方正在输入时触发
final class MessageTypingEvent extends AppEvent {
  @override
  List<Object> get props => [conversationUk3, typierId, status];

  /// 会话 UK3
  final String conversationUk3;

  /// 输入者的用户 ID
  final String typierId;

  /// 输入状态
  final TypingStatus status;

  const MessageTypingEvent({
    required this.conversationUk3,
    required this.typierId,
    required this.status,
  });

  @override
  String toString() {
    return 'MessageTypingEvent(conversationUk3: $conversationUk3, typierId: $typierId, status: $status)';
  }
}

/// 输入状态枚举
enum TypingStatus {
  /// 开始输入
  start,

  /// 停止输入
  stop,
}

/// 消息进度更新事件
///
/// 当消息发送或接收进度更新时触发（如文件上传/下载进度）
final class MessageProgressEvent extends AppEvent {
  @override
  List<Object> get props => [
    messageId,
    conversationUk3,
    progressType,
    progress,
    bytesTransferred,
    totalBytes,
  ];

  /// 消息 ID
  final String messageId;

  /// 会话 UK3
  final String conversationUk3;

  /// 进度类型（上传、下载等）
  final MessageProgressType progressType;

  /// 当前进度（0.0 - 1.0）
  final double progress;

  /// 已传输字节数
  final int bytesTransferred;

  /// 总字节数
  final int totalBytes;

  /// 传输速度（字节/秒）
  final int? transferRate;

  const MessageProgressEvent({
    required this.messageId,
    required this.conversationUk3,
    required this.progressType,
    required this.progress,
    required this.bytesTransferred,
    required this.totalBytes,
    this.transferRate,
  });

  @override
  String toString() {
    return 'MessageProgressEvent(messageId: $messageId, conversationUk3: $conversationUk3, progressType: $progressType, progress: ${(progress * 100).toStringAsFixed(1)}%, bytes: $bytesTransferred/$totalBytes, rate: $transferRate)';
  }
}

/// 消息进度类型枚举
enum MessageProgressType {
  /// 上传中
  uploading,

  /// 下载中
  downloading,

  /// 处理中（如图片压缩、视频转码等）
  processing,

  /// 完成
  completed,

  /// 失败
  failed,
}
