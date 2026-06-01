/// 群组 ID 值对象 / Group ID value object（T0.3）。
///
/// 底层为 TSID 字符串（同 UserId，经 safeParseBigIntJson 转 String）。
/// 纯 Dart——禁止 import flutter/* 与 repository/*。
extension type const GroupId(String value) {
  /// 构造并校验：空串拒绝。
  factory GroupId.parse(String raw) {
    if (raw.isEmpty) {
      throw const FormatException('empty group id');
    }
    return GroupId(raw);
  }
}
