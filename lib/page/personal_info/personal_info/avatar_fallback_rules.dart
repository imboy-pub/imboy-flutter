/// 头像 fallback 首字母提取纯函数
///
/// 当用户头像 URL 为空 / 加载失败时，用首字母圆形作为兜底（iOS Contacts 范式）。
/// 本模块为零外部依赖纯函数，便于单测覆盖（无需 widget tree / mock）。
library;

/// 从昵称提取首字母用于头像 fallback。
///
/// 规则：
///   - 空字符串 / 纯空白 → `'?'`
///   - 首尾空白裁剪后取**首个 rune**（兼容 emoji 高低代理对、CJK 单字符）
///   - 英文字符统一大写（`a` → `'A'`）
///   - emoji / CJK / 数字 / 符号原样返回（已是单 rune 形式）
///
/// 之所以用 rune 而非 `String[0]`：
///   `String[0]` 会切断 surrogate pair，例如 emoji `'😀'` 长度为 2，
///   `'😀'[0]` 返回半个 surrogate（乱码），用 rune 取首个 codePoint 才正确。
///
/// 示例：
/// ```dart
/// extractAvatarInitial('Alice')  // 'A'
/// extractAvatarInitial('张三')   // '张'
/// extractAvatarInitial(' bob ')  // 'B'
/// extractAvatarInitial('')       // '?'
/// extractAvatarInitial('   ')    // '?'
/// extractAvatarInitial('😀hi')   // '😀'
/// ```
String extractAvatarInitial(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '?';
  final firstRune = trimmed.runes.first;
  return String.fromCharCode(firstRune).toUpperCase();
}
