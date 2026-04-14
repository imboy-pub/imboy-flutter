/// @提及文本格式化工具
///
/// 用于在消息气泡中高亮显示 @提及
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/chat/mention_model.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 降级显示标签：被 @ 成员已退群 / 被踢。
///
/// C1：在原 @ 文本位置渲染该标签，并取消点击跳转。
/// i18n runtime getter（随 locale 变化）。
String get kRemovedMemberMentionLabel => t.atMentionLeftMember;

/// C1 降级判定：给定 userId 是否应显示为"已退群"。
///
/// - [activeMemberIds] 为 null 时表示上层未提供活跃成员集合，不做降级（向后兼容）。
/// - `'all'` 是 @所有人 的特殊 id，不参与降级。
bool _isStaleMention(String userId, Set<String>? activeMemberIds) {
  if (activeMemberIds == null) return false;
  if (userId == 'all') return false;
  return !activeMemberIds.contains(userId);
}

/// C5 前缀白名单：`@` 前的字符是否允许触发候选弹窗。
///
/// 拒绝字母、数字、下划线（这些通常是 username 或 email 的一部分，
/// 如 `a@b.com`、`test_@` 不应弹出群成员候选）。
/// 其余字符（空格、标点、中文字符、换行、行首）均允许触发。
bool _isLegalAtPrefix(String? ch) {
  if (ch == null) return true; // 行首
  return !RegExp(r'[A-Za-z0-9_]').hasMatch(ch);
}

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

  /// C1：判定被 @ 用户是否已退群 / 被踢，需降级显示。
  ///
  /// [activeMemberIds] 为 null 时不降级（保持旧行为）。
  /// `'all'` 为特殊的 @所有人 id，永不降级。
  @visibleForTesting
  static bool isRemovedMember(
    String userId,
    Set<String>? activeMemberIds,
  ) =>
      _isStaleMention(userId, activeMemberIds);

  /// 构建带高亮的文本组件
  ///
  /// [text] 原始文本
  /// [mentionIds] 消息中的 mentionIds 列表
  /// [style] 基础文本样式
  /// [onMentionTap] 点击 @提及的回调
  /// [currentUserId] 当前用户ID，用于判断是否被 @
  /// [isCurrentUser] 是否是当前用户发送的消息
  /// [activeMemberIds] C1：群当前活跃成员 ID 集合；
  ///   若提供且某个被 @ 用户不在其中，则替换为"@已退群成员"且不可点击；
  ///   为 null 时保持向后兼容。
  static Widget buildHighlightedText({
    required String text,
    required List<String>? mentionIds,
    required TextStyle style,
    required String currentUserId,
    void Function(String userId)? onMentionTap,
    bool isCurrentUser = false,
    Set<String>? activeMemberIds,
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

      final stale = _isStaleMention(range.userId, activeMemberIds);

      if (stale) {
        // C1 降级：替换显示文本为"@已退群成员"，灰色、不可点击。
        spans.add(
          TextSpan(
            text: kRemovedMemberMentionLabel,
            style: style.copyWith(
              color: style.color?.withValues(alpha: 0.5) ??
                  Colors.grey,
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.lineThrough,
            ),
            // 不附加 recognizer：禁止跳转到已不存在的用户资料。
          ),
        );
      } else {
        final mentionText = text.substring(range.start, range.end);
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
      }

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

    // C5：@ 前必须是行首 / 空格 / 标点 / 中文字符等；
    // 若紧邻的前一个字符属于 [A-Za-z0-9_]（如 email `a@b`、`name_@`），
    // 视为用户原文输入，不弹出候选。
    final prevChar =
        lastAtIndex == 0 ? null : textBeforeCursor.substring(lastAtIndex - 1, lastAtIndex);
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
