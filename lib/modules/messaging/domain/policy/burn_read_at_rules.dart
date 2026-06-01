/// 阅后即焚已读时间戳解析 —— 纯函数（零外部依赖）
///
/// slice-C-8: `chat_page.dart` L2028-2032 内联的 `burn_read_at` 字段解析
/// 含三个类型分支（int / String数字 / 其他→0），
/// 提取后注入 metadata，可独立单测钉死所有类型分支与边界契约。
library;

/// 从消息 metadata 中安全解析 `burn_read_at` 毫秒时间戳。
///
/// 解析优先级：
/// 1. metadata 为 null 或键缺失 → 0
/// 2. 值类型为 `int`             → 原值
/// 3. 值可被 `int.tryParse` 解析 → 解析结果
/// 4. 其他（double / bool / 非数字 String / null 值）→ 0
///
/// 注意：不对返回值做范围约束（≥0），调用方自行决定负数语义。
int parseBurnReadAtMs(Map<String, dynamic>? metadata) {
  if (metadata == null) return 0;
  final raw = metadata['burn_read_at'];
  if (raw is int) return raw;
  return int.tryParse('$raw') ?? 0;
}
