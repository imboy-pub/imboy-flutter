/// 客户端重试策略单一真值源（SSOT）
///
/// 固化三端客户端重试数值，杜绝 message_retry / ack_manager / SDK
/// 各自为政且注释互相矛盾的分叉。
///
/// 语义区分（关键，勿与服务端投递重试混淆）：
/// - [messageSendRetryIntervals]：客户端「发消息 → 等服务端确认」的重试节奏。
///   用于 [MessageRetry]（发 C2C/C2G/C2S 消息等 SERVER_ACK），
///   与 imboy-sdk-js 的 `sendWithAck` 同语义——两端必须一致。
/// - [ackConfirmRetryIntervals]：客户端「发 CLIENT_ACK → 等服务端 confirm」
///   的重试节奏，用于 [AckManager]。4 次重试总跨度 33s，足以覆盖服务端
///   最长投递重试窗口（c2s ~23s），确保服务端放弃投递前持续收到 ACK。
///
/// 服务端「投递给接收端、等接收端 ACK、超时重投」的节奏在后端
/// `elib_retry_config.erl`（按消息类型 c2c/c2s/s2c 不同），是另一套语义，
/// 客户端不镜像。
library;

/// 客户端重试策略常量与取值辅助。
///
/// 所有客户端侧重试间隔必须从这里取，禁止在各 service 内手写魔法数。
class RetryPolicy {
  const RetryPolicy._();

  /// 发消息等 SERVER_ACK 的重试间隔（毫秒），4 次。
  ///
  /// 与 imboy-sdk-js `ACK_RETRY_INTERVALS_MS` 必须保持一致。
  static const List<int> messageSendRetryIntervals = [3000, 5000, 10000, 20000];

  /// 发 ACK 等 confirm 的重试间隔（毫秒），4 次。
  static const List<int> ackConfirmRetryIntervals = [3000, 5000, 10000, 15000];

  /// 最大重试次数（两个语义一致）。
  static const int maxRetryAttempts = 4;

  /// 按重试索引取「发消息等确认」间隔；越界取最后一个，负数取第一个。
  static int messageSendIntervalAt(int retryCount) =>
      _intervalAt(messageSendRetryIntervals, retryCount);

  /// 按重试索引取「发 ACK 等 confirm」间隔；越界取最后一个，负数取第一个。
  static int ackConfirmIntervalAt(int retryCount) =>
      _intervalAt(ackConfirmRetryIntervals, retryCount);

  static int _intervalAt(List<int> intervals, int retryCount) {
    if (retryCount < 0) return intervals.first;
    if (retryCount >= intervals.length) return intervals.last;
    return intervals[retryCount];
  }
}
