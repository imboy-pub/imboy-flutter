/// @提及成员列表组件
///
/// 在群聊输入框中显示可 @ 的成员列表
library;

import 'package:flutter/material.dart';
import 'package:imboy/component/chat/mention_model.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/theme_manager.dart';

/// @提及相关文本（简化版，避免依赖 slang 生成的字符串）
class MentionStrings {
  static const String mentionAll = '所有人';
  static const String mentionAllHint = '通知所有群成员';
  static const String selectMention = '选择要@的成员';
}

/// @提及成员列表组件
class MentionListWidget extends StatelessWidget {
  /// 候选成员列表
  final List<MentionCandidate> candidates;

  /// 搜索关键词
  final String keyword;

  /// 是否显示 @所有人 选项
  final bool showAllMention;

  /// 当前用户是否是管理员
  final bool isAdmin;

  /// 选择成员的回调
  final void Function(MentionCandidate candidate) onSelected;

  /// 列表最大高度
  final double maxHeight;

  const MentionListWidget({
    super.key,
    required this.candidates,
    this.keyword = '',
    this.showAllMention = false,
    this.isAdmin = false,
    required this.onSelected,
    this.maxHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    // 过滤候选列表
    final filteredCandidates = _filterCandidates();

    if (filteredCandidates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: ThemeManager.instance.getThemeColor('surface'),
        borderRadius: AppRadius.borderRadiusMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: filteredCandidates.length,
        itemBuilder: (context, index) {
          return _buildMentionItem(filteredCandidates[index]);
        },
      ),
    );
  }

  /// 过滤候选列表
  List<MentionCandidate> _filterCandidates() {
    final result = <MentionCandidate>[];

    // 如果有关键词且匹配 "所有人"，且用户是管理员，添加 @所有人 选项
    if (showAllMention && isAdmin && '所有人'.toLowerCase().contains(keyword.toLowerCase())) {
      result.add(MentionCandidate.all());
    }

    // 过滤普通成员
    if (keyword.isEmpty) {
      result.addAll(candidates);
    } else {
      result.addAll(
        candidates.where((c) =>
          c.displayName.toLowerCase().contains(keyword.toLowerCase())
        ),
      );
    }

    return result;
  }

  /// 构建单个 @提及项
  Widget _buildMentionItem(MentionCandidate candidate) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(candidate),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // 头像
              _buildAvatar(candidate),
              const SizedBox(width: 10),
              // 名称和角色
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            candidate.isAllMention
                              ? MentionStrings.mentionAll
                              : candidate.displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: candidate.isAllMention
                                ? FontWeight.w600
                                : FontWeight.normal,
                              color: ThemeManager.instance.getThemeColor('textPrimary'),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (candidate.roleText.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleBackgroundColor(candidate.role),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              candidate.roleText,
                              style: TextStyle(
                                fontSize: 10,
                                color: _getRoleTextColor(candidate.role),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (candidate.isAllMention)
                      Text(
                        MentionStrings.mentionAllHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeManager.instance.getThemeColor('textSecondary'),
                        ),
                      ),
                  ],
                ),
              ),
              // @图标
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeManager.instance.getThemeColor('primary').withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '@',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ThemeManager.instance.getThemeColor('primary'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建头像
  Widget _buildAvatar(MentionCandidate candidate) {
    if (candidate.isAllMention) {
      // @所有人 的图标
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: ThemeManager.instance.getThemeColor('primary').withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.group,
          size: 24,
          color: ThemeManager.instance.getThemeColor('primary'),
        ),
      );
    }

    // 用户头像
    if (candidate.avatar.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          candidate.avatar,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar(candidate.displayName);
          },
        ),
      );
    }

    return _buildDefaultAvatar(candidate.displayName);
  }

  /// 构建默认头像
  Widget _buildDefaultAvatar(String name) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: ThemeManager.instance.getThemeColor('primary').withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: ThemeManager.instance.getThemeColor('primary'),
          ),
        ),
      ),
    );
  }

  /// 获取角色标签背景颜色
  Color _getRoleBackgroundColor(int role) {
    switch (role) {
      case 4: // 群主
        return ThemeManager.instance.getThemeColor('warning').withValues(alpha: 0.1);
      case 3: // 管理员
        return ThemeManager.instance.getThemeColor('primary').withValues(alpha: 0.1);
      default:
        return ThemeManager.instance.getThemeColor('surface');
    }
  }

  /// 获取角色标签文字颜色
  Color _getRoleTextColor(int role) {
    switch (role) {
      case 4: // 群主
        return ThemeManager.instance.getThemeColor('warning');
      case 3: // 管理员
        return ThemeManager.instance.getThemeColor('primary');
      default:
        return ThemeManager.instance.getThemeColor('textSecondary');
    }
  }
}

/// @提及列表弹出框
///
/// 用于在输入框上方显示 @提及成员列表
class MentionListPopup extends StatelessWidget {
  /// 候选成员列表
  final List<MentionCandidate> candidates;

  /// 搜索关键词
  final String keyword;

  /// 是否显示 @所有人 选项
  final bool showAllMention;

  /// 当前用户是否是管理员
  final bool isAdmin;

  /// 选择成员的回调
  final void Function(MentionCandidate candidate) onSelected;

  /// 关闭弹出框的回调
  final VoidCallback? onClose;

  const MentionListPopup({
    super.key,
    required this.candidates,
    this.keyword = '',
    this.showAllMention = false,
    this.isAdmin = false,
    required this.onSelected,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ThemeManager.instance.getThemeColor('surface'),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: ThemeManager.instance.getThemeColor('outline').withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    MentionStrings.selectMention,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: ThemeManager.instance.getThemeColor('textSecondary'),
                    ),
                  ),
                  const Spacer(),
                  if (onClose != null)
                    GestureDetector(
                      onTap: onClose,
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: ThemeManager.instance.getThemeColor('textSecondary'),
                      ),
                    ),
                ],
              ),
            ),
            // 成员列表
            MentionListWidget(
              candidates: candidates,
              keyword: keyword,
              showAllMention: showAllMention,
              isAdmin: isAdmin,
              onSelected: (candidate) {
                onSelected(candidate);
                onClose?.call();
              },
              maxHeight: 220,
            ),
          ],
        ),
      ),
    );
  }
}
