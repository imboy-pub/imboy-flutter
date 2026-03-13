/// @提及文本格式化工具
///
/// 用于在消息气泡中高亮显示 @提及
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/chat/mention_model.dart';

/// @提及文本格式化器
class MentionTextFormatter {
  /// @提及正则表达式
  ///
  /// 匹配格式: @用户名 或 @所有人
  static final RegExp _mentionRegex = RegExp(r'@([^\s@]+)');

  /// 解析文本中的 @提及
  ///
  /// [text] 原始文本
  /// [mentionIds] 消息中的 mentionIds 列表
  ///
  /// 返回解析后的结果，包含文本和 @提及范围
  static MentionParseResult parseMentions(
    String text,
    List<String>? mentionIds,
  ) {
    if (mentionIds == null || mentionIds.isEmpty) {
      return MentionParseResult(text: text, mentionData: const MentionData());
    }

    final ranges = <MentionRange>[];
    final matches = _mentionRegex.allMatches(text);

    // 构建用户ID到显示名称的映射
    // 注意：这里需要从外部传入用户信息，这里只是占位
    for (final match in matches) {
      final mentionText = match.group(1) ?? '';
      // 检查是否是有效的 @提及（在 mentionIds 中）
      // 这里简化处理，实际应该匹配用户名
      if (mentionIds.contains(mentionText) || mentionText == '所有人') {
        ranges.add(
          MentionRange(
            start: match.start,
            end: match.end,
            userId: mentionText == '所有人' ? 'all' : mentionText,
          ),
        );
      }
    }

    return MentionParseResult(
      text: text,
      mentionData: MentionData(mentionIds: mentionIds, ranges: ranges),
    );
  }

  /// 构建带高亮的文本组件
  ///
  /// [text] 原始文本
  /// [mentionIds] 消息中的 mentionIds 列表
  /// [style] 基础文本样式
  /// [onMentionTap] 点击 @提及的回调
  /// [currentUserId] 当前用户ID，用于判断是否被 @
  /// [isCurrentUser] 是否是当前用户发送的消息
  static Widget buildHighlightedText({
    required String text,
    required List<String>? mentionIds,
    required TextStyle style,
    required String currentUserId,
    void Function(String userId)? onMentionTap,
    bool isCurrentUser = false,
  }) {
    if (mentionIds == null || mentionIds.isEmpty) {
      return Text(text, style: style);
    }

    final parseResult = parseMentions(text, mentionIds);
    final ranges = parseResult.mentionData.ranges;

    if (ranges.isEmpty) {
      return Text(text, style: style);
    }

    // 检查当前用户是否被 @
    final isMentioned =
        mentionIds.contains(currentUserId) || mentionIds.contains('all');

    // 构建富文本
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final range in ranges) {
      // 添加普通文本
      if (range.start > lastEnd) {
        spans.add(
          TextSpan(text: text.substring(lastEnd, range.start), style: style),
        );
      }

      // 添加 @提及文本
      final mentionText = text.substring(range.start, range.end);

      // 高亮样式
      final mentionStyle = style.copyWith(
        color: _getMentionColor(
          isCurrentUser: isCurrentUser,
          isMentioned: isMentioned,
        ),
        fontWeight: FontWeight.w600,
      );

      spans.add(
        TextSpan(
          text: mentionText,
          style: mentionStyle,
          recognizer: onMentionTap != null
              ? (TapGestureRecognizer()
                  ..onTap = () => onMentionTap(range.userId))
              : null,
        ),
      );

      lastEnd = range.end;
    }

    // 添加剩余的普通文本
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: style));
    }

    return RichText(
      text: TextSpan(children: spans, style: style),
    );
  }

  /// 获取 @提及的颜色
  static Color _getMentionColor({
    required bool isCurrentUser,
    required bool isMentioned,
  }) {
    const primaryColor = Color(0xFF1976D2);
    const sentPrimaryColor = Color(0xFF90CAF9);
    if (isCurrentUser) {
      // 当前用户发送的消息
      return sentPrimaryColor;
    } else if (isMentioned) {
      // 当前用户被 @
      return primaryColor;
    } else {
      // 其他 @提及
      return primaryColor.withValues(alpha: 0.8);
    }
  }

  /// 检查文本中是否包含当前用户的 @提及
  ///
  /// [text] 文本内容
  /// [mentionIds] @提及 ID 列表
  /// [currentUserId] 当前用户ID
  static bool isUserMentioned(
    String text,
    List<String>? mentionIds,
    String currentUserId,
  ) {
    if (mentionIds == null || mentionIds.isEmpty) {
      return false;
    }
    return mentionIds.contains(currentUserId) || mentionIds.contains('all');
  }

  /// 从文本中提取 @提及的用户ID列表
  ///
  /// [text] 文本内容
  /// [candidateNames] 候选用户名映射 (displayName -> userId)
  static List<String> extractMentionIds(
    String text,
    Map<String, String> candidateNames,
  ) {
    final mentionIds = <String>[];
    final matches = _mentionRegex.allMatches(text);

    for (final match in matches) {
      final displayName = match.group(1) ?? '';
      if (displayName == '所有人') {
        if (!mentionIds.contains('all')) {
          mentionIds.add('all');
        }
      } else {
        final userId = candidateNames[displayName];
        if (userId != null && !mentionIds.contains(userId)) {
          mentionIds.add(userId);
        }
      }
    }

    return mentionIds;
  }
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
