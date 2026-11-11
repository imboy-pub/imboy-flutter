/// 合并转发 bundle 合同常量 —— W2-G / chat_history_bundle_v1（纯 Dart）。
///
/// 冻结契约来源：
/// - PLAN_SNAPSHOT §4.5（`chat_history_bundle` 合同）
/// - backend `docs/reference/chat-history-bundle-contract.md`（W1-D 冻结 v1）
///
/// ⚠️ `chat_history_bundle` 的 msg_type 常量**只定义在此处**（本地字符串）。
/// 不修改 `lib/service/message_type_constants.dart` —— 类型体系注册
/// （MessageType.chatHistoryBundle / 枚举 / mapper）由 W3-I lane 统一完成，
/// 此处提前注册会与 W3-I 的 path ownership 冲突。
library;

/// bundle 消息类型与 v1 合同数值（与后端 `chat_history_bundle_ds` 同一常量）。
abstract final class HistoryBundleContract {
  /// 合并转发消息 msg_type（JSON-only 通道类型，后端已登记）。
  static const String msgType = 'chat_history_bundle';

  /// payload.bundle_version，v1 恒为 1；其他值/缺失后端拒绝。
  static const int bundleVersion = 1;

  /// entries 条数下限（0 条拒绝）。
  static const int minEntries = 1;

  /// entries 条数上限（§4.2：合并转发条目 50 条，构建前拒绝）。
  static const int maxEntries = 50;

  /// 序列化后 payload 字节上限（与后端同一常量：256×1024，UTF-8 字节长度，
  /// 边界值本身合法）。后端在落库前用 `byte_size(jsone:encode(payload))`
  /// 做同一判定；客户端在构建与发送前各校验一次。
  static const int maxPayloadBytes = 256 * 1024;
}

/// 构建侧稳定错误码（snake_case 机器契约，供上层 UI/日志/测试依赖）。
///
/// 与后端 DS 层错误码（chat-history-bundle-contract.md §3）同名对齐的两项：
/// [entriesOutOfRange] / [payloadTooLarge]；其余为客户端构建侧
/// `rejected_*` 系列（命名口径与 W1-A `MessageSelectionReason` /
/// W1-C `ChatExportAdmission` 一致）。**只增不改语义**。
abstract final class HistoryBundleBuildErrorCode {
  /// 目标会话标识为空。
  static const String invalidTarget = 'bundle_invalid_target';

  /// entries 条数越界（0 条或 >50 条）。与后端错误码同名。
  static const String entriesOutOfRange = 'bundle_entries_out_of_range';

  /// 序列化后超过 256 KiB。与后端错误码同名。
  static const String payloadTooLarge = 'bundle_payload_too_large';

  /// E2EE 解密失败占位行（安全优先级最高）。
  static const String rejectedE2eeFailed = 'rejected_e2ee_failed';

  /// 发送中（status=sending / pendingRetry），正文可能未完整。
  static const String rejectedStatusSending = 'rejected_status_sending';

  /// 发送失败（status=error），不保证与对端一致。
  static const String rejectedStatusFailed = 'rejected_status_failed';

  /// 已撤回（正文已不可转发）。
  static const String rejectedRevoked = 'rejected_revoked';

  /// 阅后即焚（burn_read_at > 0），v1 不支持合并转发。
  static const String rejectedBurnAfterRead = 'rejected_burn_after_read';

  /// WebRTC 通话信令。
  static const String rejectedWebrtc = 'rejected_webrtc';

  /// 红包/转账（资金类）。
  static const String rejectedPayment = 'rejected_payment';

  /// 需实时 ACL 的业务卡片。
  static const String rejectedBusinessCard = 'rejected_business_card';

  /// 系统/控制类消息（C2S/S2C action 值、撤回占位等）。
  static const String rejectedSystemOrControl = 'rejected_system_or_control';

  /// 其余一切：textStream、custom、unsupported、null、未知新类型
  /// （fail-closed，默认不可合并）。
  static const String rejectedUnsupportedType = 'rejected_unsupported_type';
}
