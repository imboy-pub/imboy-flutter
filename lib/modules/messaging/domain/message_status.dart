/// 消息状态领域枚举 / Message status (domain enum)（T1.4）。
///
/// 领域层自有状态枚举，与 store 层 IMBoyMessageStatus 语义对齐但解耦
/// （domain 不依赖 store/flutter）。T1.5 委托时在边界做映射。
enum MessageStatus {
  /// 发送中。
  sending,

  /// 已发送（服务端已确认）。
  sent,

  /// 已投递到对端设备。
  delivered,

  /// 对端已读。
  seen,

  /// 发送失败。
  error,

  /// 已撤回。
  revoked,
}
