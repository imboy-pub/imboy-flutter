import 'package:flutter/material.dart';

import 'package:imboy/component/helper/func.dart' show cachedImageProvider;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_comment_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 频道评论相对时间格式化（评论列表 / 阅读页共用）。
String channelRelativeTime(BuildContext context, DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return context.t.common.justNow;
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} ${context.t.common.minutesAgo}';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} ${context.t.common.hoursAgo}';
  }
  if (diff.inDays < 7) return '${diff.inDays} ${context.t.channel.daysAgo}';
  return '${dt.month}-${dt.day.toString().padLeft(2, '0')}';
}

/// 频道评论条目（头像/昵称/回复引用/内容/时间/回复/点赞/删除）。
///
/// 由评论页与频道阅读页共用，避免两处重复维护同一渲染逻辑。
/// 「我的」徽章与删除权限依据当前登录用户在内部判定。
class ChannelCommentTile extends StatelessWidget {
  final ChannelCommentModel comment;
  final VoidCallback onReply;
  final VoidCallback onToggleLike;
  final VoidCallback onDelete;

  const ChannelCommentTile({
    super.key,
    required this.comment,
    required this.onReply,
    required this.onToggleLike,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUid = int.tryParse(UserRepoLocal.to.currentUid) ?? 0;
    final isMine = comment.userId == currentUid;
    final hasAvatar = comment.userAvatar.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: AppSpacing.allSmall,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.borderRadiusSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: hasAvatar
                ? cachedImageProvider(comment.userAvatar, w: 64)
                : null,
            child: !hasAvatar
                ? Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
                        : '?',
                    style: context.textStyle(FontSizeType.normal),
                  )
                : null,
          ),
          AppSpacing.horizontalSmall,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: context.textStyle(
                        FontSizeType.subheadline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isMine) ...[
                      AppSpacing.horizontalTiny,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          context.t.common.me,
                          style: context.textStyle(
                            FontSizeType.tiny,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                AppSpacing.verticalTiny,
                if (comment.replyToName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '@${comment.replyToName}',
                      style: context.textStyle(
                        FontSizeType.small,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                Text(
                  comment.content,
                  style: context
                      .textStyle(FontSizeType.body)
                      .copyWith(height: 1.4),
                ),
                AppSpacing.verticalSmall,
                Row(
                  children: [
                    Text(
                      channelRelativeTime(context, comment.createdAt),
                      style: context.textStyle(
                        FontSizeType.caption2,
                        color: AppColors.getTextColor(
                          Theme.of(context).brightness,
                          isSecondary: true,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _actionChip(
                      context,
                      icon: Icons.reply,
                      label: context.t.channel.reply,
                      onTap: onReply,
                    ),
                    AppSpacing.horizontalSmall,
                    _actionChip(
                      context,
                      icon: comment.isLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      label: comment.likeCount > 0
                          ? '${comment.likeCount}'
                          : context.t.channel.like,
                      onTap: onToggleLike,
                    ),
                    if (isMine) ...[
                      AppSpacing.horizontalSmall,
                      _actionChip(
                        context,
                        icon: Icons.delete_outline,
                        label: '',
                        onTap: onDelete,
                        color: AppColors.iosRed,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c =
        color ??
        AppColors.getTextColor(Theme.of(context).brightness, isSecondary: true);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: c),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                label,
                style: context.textStyle(FontSizeType.caption2, color: c),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
