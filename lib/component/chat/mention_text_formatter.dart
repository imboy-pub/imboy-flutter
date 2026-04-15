/// @提及文本输入辅助工具（C5 触发 + 候选项插入）。
///
/// ## 历史
///
/// 本文件**曾经**承担两条独立职责：
/// 1. 消息气泡内 `@xxx` 的富文本高亮（`MentionTextFormatter.buildHighlightedText`）
/// 2. 输入框 `@` 触发检测 + 候选项插入（`MentionTextEditorHelper`）
///
/// slice-B-2（refactor-cleaner）删除了职责 1 的整条死链路：
///   - `MentionTextFormatter` 整个类（含 `parseMentions` / `buildHighlightedText`
///     / `isUserMentioned` / `extractMentionIds` / `_getMentionColor` /
///     `isRemovedMember` / `_mentionRegex`）
///   - 顶层 `kRemovedMemberMentionLabel` getter
///   - 私有 `_isStaleMention` helper
///   - `MentionParseResult`（`mention_model.dart`，唯一消费者是 `parseMentions`）
///
/// 消息气泡的 @ 渲染现在走 `mention_text_reducer.dart` → markdown 删除线方案，
/// 由 `flyer_chat` 的 `GptMarkdown` 直接渲染，无需富文本 TextSpan 自制。
///
/// 仅保留的 `MentionTextEditorHelper` 服务于 `chat_input.dart`（@ 候选弹窗）。
library;

import 'package:flutter/material.dart';
import 'package:imboy/component/chat/mention_model.dart';

/// C5 前缀白名单：`@` 前的字符是否允许触发候选弹窗。
///
/// 拒绝字母、数字、下划线（这些通常是 username 或 email 的一部分，
/// 如 `a@b.com`、`test_@` 不应弹出群成员候选）。
/// 其余字符（空格、标点、中文字符、换行、行首）均允许触发。
bool _isLegalAtPrefix(String? ch) {
  if (ch == null) return true; // 行首
  return !RegExp(r'[A-Za-z0-9_]').hasMatch(ch);
}

/// @提及文本编辑器辅助类
///
/// 用于在输入框中处理 @提及的插入和删除
class MentionTextEditorHelper {
  /// 在文本中插入 @提及
  ///
  /// [text] 原始文本
  /// [selection] 当前光标位置
  /// [candidate] 要插入的 @提及候选项
  ///
  /// 返回新的文本和光标位置
  static TextEditingValue insertMention({
    required String text,
    required TextSelection selection,
    required MentionCandidate candidate,
  }) {
    // 找到光标前最近的 @ 符号位置
    final atIndex = text.lastIndexOf('@', selection.extentOffset - 1);

    if (atIndex == -1) {
      return TextEditingValue(text: text, selection: selection);
    }

    // 构建新文本
    final displayName = candidate.displayName;
    final newText = text.replaceRange(
      atIndex + 1,
      selection.extentOffset,
      '$displayName ',
    );

    // 新光标位置（在插入的 @提及之后）
    final newCursorPosition = atIndex + displayName.length + 2;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }

  /// 检测是否应该显示 @提及列表
  ///
  /// [text] 当前文本
  /// [selection] 当前光标位置
  ///
  /// 返回 (是否显示, 搜索关键词)
  static (bool, String) detectMentionTrigger(
    String text,
    TextSelection selection,
  ) {
    if (text.isEmpty || selection.extentOffset <= 0) {
      return (false, '');
    }

    // 获取光标前的文本
    final textBeforeCursor = text.substring(0, selection.extentOffset);

    // 找到最后一个 @ 符号
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex == -1) {
      return (false, '');
    }

    // C5：@ 前必须是行首 / 空格 / 标点 / 中文字符等；
    // 若紧邻的前一个字符属于 [A-Za-z0-9_]（如 email `a@b`、`name_@`），
    // 视为用户原文输入，不弹出候选。
    final prevChar = lastAtIndex == 0
        ? null
        : textBeforeCursor.substring(lastAtIndex - 1, lastAtIndex);
    if (!_isLegalAtPrefix(prevChar)) {
      return (false, '');
    }

    // 检查 @ 符号后是否有空格（如果有，说明已经完成了 @提及）
    final textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
    if (textAfterAt.contains(' ')) {
      return (false, '');
    }

    // 获取搜索关键词
    final keyword = textAfterAt.toLowerCase();

    return (true, keyword);
  }
}
