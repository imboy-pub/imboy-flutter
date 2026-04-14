/// 群聊 @提及文本降级器（C1 Z 路径）
///
/// 在消息气泡渲染之前，对 `message.text` 做一次纯字符串转换：
/// - 被 @ 用户仍在群里 → 原样保留 `@<displayName>`
/// - 被 @ 用户已退群 / 被踢 → 替换为 markdown 删除线 `~~@已退群成员~~`
/// - `@所有人` → 永不降级
///
/// 输出字符串由 `flyer_chat` 的 `GptMarkdown` 直接渲染，无需修改第三方
/// 插件或 `buildHighlightedText` 等非 markdown 路径。
///
/// 前缀白名单与 C5 `detectMentionTrigger` 保持一致，邮箱 `a@b.com` 与
/// `name_@foo` 等场景不会被误识别为 @提及。
library;

import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;

class MentionTextReducer {
  MentionTextReducer._();

  /// @所有人 的固定显示名（永不降级）。
  static const String _allMentionName = '所有人';

  /// 降级替换标签。
  static const String _removedLabel = '@已退群成员';

  /// 匹配 `@<displayName>`：
  /// - group(1)：`@` 前的合法前缀字符（行首捕获为空）
  /// - group(2)：`@` 后的 displayName
  ///
  /// displayName 字符集：ASCII 字母数字、下划线、短横线、CJK 汉字。
  /// 遇到空格、标点、emoji 等即停止，防止把紧随的 `!` / `。` 等吞进 token。
  ///
  /// 合法前缀 = 行首或非 `[A-Za-z0-9_]` 字符。与
  /// `MentionTextEditorHelper.detectMentionTrigger` 的白名单一致。
  static final RegExp _mentionRe =
      RegExp(r'(^|[^A-Za-z0-9_])@([A-Za-z0-9_\-\u4e00-\u9fa5]+)');

  /// 扫描 [text] 中的 @提及 token，按 [activeMemberNames] 做 C1 降级。
  ///
  /// 安全约定：[activeMemberNames] 为空集合时，视为调用方"群成员尚未加载"，
  /// **不做任何降级**，原样返回文本。这避免了加载未完成阶段误伤活跃成员。
  static String reduce(String text, Set<String> activeMemberNames) {
    if (activeMemberNames.isEmpty) return text;

    return text.replaceAllMapped(_mentionRe, (m) {
      final prefix = m.group(1) ?? '';
      final name = m.group(2)!;
      if (name == _allMentionName) {
        return '$prefix@$name';
      }
      if (activeMemberNames.contains(name)) {
        return '$prefix@$name';
      }
      return '$prefix~~$_removedLabel~~';
    });
  }

  /// Z-2a：对 [message] 做 @提及降级投影。
  ///
  /// 按需短路以避免分配：
  /// - [activeMemberNames] 为空 → 原对象返回
  /// - `message.text` 不含 `@` → 原对象返回
  /// - [reduce] 输出与原文相同 → 原对象返回
  ///
  /// 否则返回一个 `copyWith(text: reduced)` 的新 [TextMessage]，其余字段保留。
  static TextMessage applyTo(
    TextMessage message,
    Set<String> activeMemberNames,
  ) {
    if (activeMemberNames.isEmpty) return message;
    if (!message.text.contains('@')) return message;
    final reduced = reduce(message.text, activeMemberNames);
    if (reduced == message.text) return message;
    return message.copyWith(text: reduced);
  }
}
