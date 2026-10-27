part of 'message_retry.dart';

/// 消息重试信息类
/// Message retry information class.
class MessageRetryInfo {
  final String messageId;
  final String type;
  final int sessionGeneration;
  int retryCount;

  /// 上次重试的单调毫秒（AppClock 单调轴，R20-A；非墙钟时间戳，
  /// 测试 `-= interval` 模拟流逝仍有效）。持久化 deadline 请用
  /// `appClock.nowMs()`（epoch 合同）。
  int lastRetryTime;

  MessageRetryInfo({
    required this.messageId,
    required this.type,
    required this.retryCount,
    required this.lastRetryTime,
    int? sessionGeneration,
  }) : sessionGeneration =
           sessionGeneration ?? UserRepoLocal.to.sessionGeneration;
}
