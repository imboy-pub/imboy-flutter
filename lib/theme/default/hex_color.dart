import 'dart:ui' show Color;

final RegExp _hexColorPattern = RegExp(r'^#[0-9a-fA-F]{6}$');

/// 把 `#RRGGBB` 文本转成不透明 [Color]；格式非法返回 null 由调用方回退默认值。
///
/// 用于运行时下发的颜色（白标品牌配置等），不是硬编码设计 token——
/// 设计 token 一律走 [AppColors]。
///
/// 用正则而非 `int.tryParse`：后者会接受 `#-12345` 这类带符号串。
Color? hexToColor(Object? value) {
  if (value is! String || !_hexColorPattern.hasMatch(value)) return null;
  return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
}
