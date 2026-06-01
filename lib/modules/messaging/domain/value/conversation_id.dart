/// 会话 ID 值对象 / Conversation ID value object（T0.3）。
///
/// 底层为后端 conv_key 字符串（权威格式见后端 conv_key_vo）：
///   C2C = "c2c:{min_uid}:{max_uid}"，C2G = "c2g:{group_id}"。
/// T0.3 仅校验非空；格式语义对齐留待会话域充血任务深化。
/// 纯 Dart——禁止 import flutter/* 与 repository/*。
extension type const ConversationId(String value) {
  /// 构造并校验：空串拒绝。
  factory ConversationId.parse(String raw) {
    if (raw.isEmpty) {
      throw const FormatException('empty conversation id');
    }
    return ConversationId(raw);
  }
}
