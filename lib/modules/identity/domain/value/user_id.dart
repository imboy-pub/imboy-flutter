/// 用户 ID 值对象 / User ID value object（T0.3）。
///
/// 底层为 TSID 字符串（JSON 以 integer 传输，前端经
/// safeParseBigIntJson 转 String 后包装；不可 int.parse 丢精度）。
/// 纯 Dart——禁止 import flutter/* 与 repository/*。
extension type const UserId(String value) {
  /// 构造并校验：空串拒绝。
  factory UserId.parse(String raw) {
    if (raw.isEmpty) {
      throw const FormatException('empty user id');
    }
    return UserId(raw);
  }
}
