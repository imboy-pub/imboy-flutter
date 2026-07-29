/// E2EE-062：**重发路径的明文闸门**。
///
/// == 为什么需要它 ==
///
/// 发送路径 `ChatNetworkService.sendWsMsg` / `sendMessage` 在加密失败时是
/// fail-closed 的：catch → toast → `return false`，不发送。但消息**行早已落库**
/// （payload 是明文、`e2ee` 为空），并被置为 `error`。
///
/// `MessageRetry._scanAndRetryFailedMessages` 的重试状态集是
/// `{sending, pendingRetry, error}`，会把这条行捡起来；
/// `_retryOne` 直接从库里读出 `payload` / `e2ee` 拼报文发 WS
/// （见 `message_retry.dart` 的 `messageData` 构造），**完全不经过
/// `encryptPayload`，也不经过 PolicyGate**。
///
/// 于是：**OTK 耗尽或被限流 → 加密失败 → 明文经重发路径出网**。
/// 这正是 E2EE-062 残留要守护的不变量「耗尽/限流绝不触发 RSA/Megolm/明文」的
/// 反面。发送侧的 fail-closed 被重发路径旁路掉了。
///
/// == 取舍 ==
///
/// 本闸门只做**拒发**，不在重发路径上补加密：重发状态机不持有加密所需的上下文
/// （对端设备表、session、PFv3 的 messageId/messageType 同源约束），在那里补
/// 加密等于把发送路径复制一份，是更大的面。拒发后消息留在库里，
/// 由正常发送路径（经门）重新发出。
library;

/// 该消息是否**必须拦下**、不得按库中原样重发。
///
/// [encryptionRequired] 由调用方用与发送路径**同一个**判据算出
/// （`E2EEService.shouldEncryptOutgoingPayload` / 群级 E2EE 开关）。
/// [e2ee] 是库中该行的 e2ee 元数据；空 = 这条行是明文。
///
/// [carriesContentKey]（E2EE-061）：该行 payload 是否带着附件的 **content key**
/// （`attachment_descriptor`）。为真时**不看** [encryptionRequired] 就拦——
/// 封装判定发生在上传那一刻，而这条行可能在几小时后才被重发；
/// 中间策略翻成明文，`encryptionRequired` 就是 false，旧判据会放行，
/// 于是解开附件的钥匙明文出网。**明文出网的钥匙比明文附件更糟**，
/// 这一条不接受任何「策略说可以」的理由。
bool shouldBlockPlaintextRetry({
  required bool encryptionRequired,
  required Map<String, dynamic>? e2ee,
  bool carriesContentKey = false,
}) {
  // 空 map 不构成「已加密」：加密成功必然写入 meta_version / protocol 等字段。
  final bool isPlaintextRow = e2ee == null || e2ee.isEmpty;
  if (carriesContentKey && isPlaintextRow) return true;
  if (!encryptionRequired) return false;
  return isPlaintextRow;
}
