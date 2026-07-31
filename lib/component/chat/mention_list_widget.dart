/// @提及成员列表组件
///
/// 在群聊输入框中显示可 @ 的成员列表。
library;

import 'package:flutter/material.dart';

import 'package:imboy/component/chat/mention_model.dart';
import 'package:imboy/component/chat/mention_search.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// @提及成员列表组件
class MentionListWidget extends StatelessWidget {
  /// 候选成员列表（已由 MentionRanking 按互动频率排好序）
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

  /// 头像直径 / 行最小高度：行高 = 头像 + 上下 padding，天然满足 44 触达。
  static const double _avatarSize = 40;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final filtered = _filterCandidates(context);

    // 无关键词且无候选 = 群成员还没加载完，不是「搜不到」。
    // 这时提示「没有匹配的成员」是撒谎，保持不渲染。
    if (filtered.isEmpty && keyword.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMedium,
        // DESIGN.md §5.2 例外：@ 提及候选下拉浮窗（Tooltip 类）。
        // 阴影色改走分隔线 token：原先写死纯黑，暗色背景下黑影等于没有，
        // 浮窗与背景糊成一片分不清层级。
        boxShadow: [
          BoxShadow(
            color: AppColors.getIosSeparator(
              Theme.of(context).brightness,
            ).withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // 搜索无结果时不再整块消失：用户刚打完字面板凭空不见，分不清是
      // 「没这个人」还是「功能坏了」。
      child: filtered.isEmpty
          ? _EmptyHint(text: t.mention.noMatchedMember)
          : ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              itemBuilder: (context, index) =>
                  _buildMentionItem(context, filtered[index]),
            ),
    );
  }

  /// 过滤候选列表（保持传入顺序，即 MentionRanking 的频率排序）。
  List<MentionCandidate> _filterCandidates(BuildContext context) {
    final t = context.t;
    final result = <MentionCandidate>[];

    // @所有人：文案取 i18n，匹配也按当前语言走——写死「所有人」的话
    // 英文用户打 "all" 永远匹配不到。
    if (showAllMention &&
        isAdmin &&
        mentionMatches(t.mention.mentionAll, keyword)) {
      result.add(MentionCandidate.all());
    }

    // 成员：支持原文 / 全拼 / 首字母（见 mention_search.dart）
    result.addAll(
      candidates.where((c) => mentionMatches(c.displayName, keyword)),
    );

    return result;
  }

  /// 构建单个 @提及项
  Widget _buildMentionItem(BuildContext context, MentionCandidate candidate) {
    final t = context.t;
    final colorScheme = Theme.of(context).colorScheme;
    final name = candidate.isAllMention
        ? t.mention.mentionAll
        : candidate.displayName;

    // 不用 Material + InkWell：DESIGN.md §13.2 禁止在 Cupertino 列表行
    // 使用 Material Ripple。透明命中区 + 最小 44 高度即可。
    // 不设 label：名字 Text 已提供标签，外层再设一遍会双标签重复读屏
    // （与 glass_bottom_bar.dart 同一约定）。
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(candidate),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.medium,
              vertical: AppSpacing.small,
            ),
            child: Row(
              children: [
                _buildAvatar(context, candidate, name),
                const SizedBox(width: AppSpacing.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: context.textStyle(
                                FontSizeType.subheadline,
                                fontWeight: candidate.isAllMention
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (candidate.roleText.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.tiny),
                            _RoleChip(candidate: candidate),
                          ],
                        ],
                      ),
                      if (candidate.isAllMention)
                        Text(
                          t.mention.mentionAllHint,
                          style: context.textStyle(
                            FontSizeType.small,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                // 纯装饰的 @ 徽标：整行已有 Semantics(label: name)，
                // 这里再读一次 "@" 只会让读屏更啰嗦。
                ExcludeSemantics(child: _AtBadge(colorScheme: colorScheme)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    BuildContext context,
    MentionCandidate candidate,
    String name,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    if (candidate.isAllMention) {
      return Container(
        width: _avatarSize,
        height: _avatarSize,
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.group, size: 24, color: colorScheme.primary),
      );
    }

    // avatarImageProvider 内置 object_key / presign 授权链（func.dart），
    // 不可换成裸 Image.network。
    if (candidate.avatar.isNotEmpty) {
      return ClipOval(
        child: Image(
          image: avatarImageProvider(candidate.avatar),
          width: _avatarSize,
          height: _avatarSize,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildDefaultAvatar(context, name),
        ),
      );
    }

    return _buildDefaultAvatar(context, name);
  }

  Widget _buildDefaultAvatar(BuildContext context, String name) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: _avatarSize,
      height: _avatarSize,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: context.textStyle(
            FontSizeType.large,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// 搜索无结果提示。
class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.regular,
      ),
      child: Text(
        text,
        style: context.textStyle(
          FontSizeType.small,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 角色标签（群主 / 管理员）。
class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.candidate});
  final MentionCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.tiny,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: candidate.roleBackgroundColor(colorScheme),
        borderRadius: AppRadius.borderRadiusTiny,
      ),
      child: Text(
        candidate.roleText,
        style: context.textStyle(
          FontSizeType.tiny,
          color: candidate.roleTextColor(colorScheme),
        ),
      ),
    );
  }
}

/// 行尾的 @ 徽标（纯视觉提示）。
class _AtBadge extends StatelessWidget {
  const _AtBadge({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.small,
        vertical: AppSpacing.tiny,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: AppRadius.borderRadiusTiny,
      ),
      child: Text(
        '@',
        style: context.textStyle(
          FontSizeType.normal,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
