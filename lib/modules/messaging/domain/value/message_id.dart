/// 消息 ID 值对象 / Message ID value object（T0.3）。
///
/// 底层为 Xid base32hex 字符串（非 integer，不可 int.parse）。
/// 零开销 branded VO：编译期擦除，运行期即底层 String。
/// 纯 Dart——禁止 import flutter/* 与 repository/*。
extension type const MessageId(String value) {
  /// 构造并校验：空串拒绝。
  factory MessageId.parse(String raw) {
    if (raw.isEmpty) {
      throw const FormatException('empty message id');
    }
    return MessageId(raw);
  }
}
