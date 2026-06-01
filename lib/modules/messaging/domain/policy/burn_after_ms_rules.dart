/// 阅后即焚时长解析 —— 纯函数（零外部依赖）
///
/// slice-C-9: `chat_page.dart` L472-478 内联的 `burn_after_ms` 字段解析
/// 仅接受严格正整数，防止零/负数/非数字类型污染内部状态。
/// 返回 null 表示"不更新调用方的默认值"（调用方自行决定 fallback）。
library;

/// 从 conversation payload 字段中安全解析阅后即焚时长（毫秒）。
///
/// 接受类型：
/// - `int`    且 > 0 → 直接返回
/// - `String` 且可解析为 int 且 > 0 → 返回解析结果
///
/// 返回 `null` 的情况：
/// - null 值
/// - int 0 或负数
/// - 无法解析为 int 的 String
/// - String 解析后 <= 0
/// - double、bool 或其他类型
int? parseBurnAfterMs(dynamic raw) {
  if (raw is int) return raw > 0 ? raw : null;
  if (raw is String) {
    final v = int.tryParse(raw);
    return (v != null && v > 0) ? v : null;
  }
  return null;
}
