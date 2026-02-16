/// @提及高亮文本显示组件
///
/// 用于在消息气泡中显示带 @提及 高亮的文本
library;

import 'package:flutter/material.dart';
import 'package:imboy/component/chat/mention_text_formatter.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/theme_manager.dart';

/// @提及高亮文本组件
class MentionTextWidget extends StatelessWidget {
  /// 文本内容
  final String text;

  /// @提及 ID 列表
  final List<String>? mentionIds;

  /// 基础文本样式
  final TextStyle? style;

  /// 是否是当前用户发送的消息
  final bool isCurrentUser;

  /// 点击 @提及 的回调
  final void Function(String userId)? onMentionTap;

  const MentionTextWidget({
    super.key,
    required this.text,
    this.mentionIds,
    this.style,
    this.isCurrentUser = false,
    this.onMentionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (mentionIds == null || mentionIds!.isEmpty) {
      return Text(
        text,
        style: style ?? _defaultStyle(context),
      );
    }

    final currentUserId = UserRepoLocal.to.currentUid;

    return MentionTextFormatter.buildHighlightedText(
      text: text,
      mentionIds: mentionIds,
      style: style ?? _defaultStyle(context),
      currentUserId: currentUserId,
      isCurrentUser: isCurrentUser,
      onMentionTap: onMentionTap,
    );
  }

  /// 获取默认样式
  TextStyle _defaultStyle(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      color: ThemeManager.instance.getThemeColor('textPrimary'),
    );
  }
}

/// 简化的 @提及检测工具
class MentionChecker {
  /// 检查消息中是否 @了当前用户
  ///
  /// [mentionIds] 消息的 mentionIds 列表
  /// [currentUserId] 当前用户ID
  static bool isCurrentUserMentioned(List<String>? mentionIds, String currentUserId) {
    if (mentionIds == null || mentionIds.isEmpty) {
      return false;
    }
    return mentionIds.contains(currentUserId) || mentionIds.contains('all');
  }

  /// 检查消息中是否包含 @所有人
  static bool hasAllMention(List<String>? mentionIds) {
    if (mentionIds == null || mentionIds.isEmpty) {
      return false;
    }
    return mentionIds.contains('all');
  }

  /// 检查消息中是否包含任何 @提及
  static bool hasMentions(List<String>? mentionIds) {
    return mentionIds != null && mentionIds.isNotEmpty;
  }
}
