/// 翻译访问器别名
///
/// 使用 `t` 访问当前语言的翻译
/// 提供统一的翻译调用接口
///
/// 示例:
/// ```dart
/// import 'package:imboy/i18n/tr.dart';
///
/// Text(t.about)  // 使用 slang 的全局翻译访问器
/// ```
library;

export 'strings.g.dart' show t;
