import 'package:imboy/component/ui/badge_widget.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/subscribed_channel_strip_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 会话列表顶部订阅频道置顶区
///
/// - 最多展示 [_kMaxVisible] 条，其余隐藏（可按需扩展"查看全部"）
/// - 空态（未订阅任何频道）时整块不渲染
/// - 加载中/加载失败时也不渲染，不影响主会话列表
class SubscribedChannelStrip extends ConsumerWidget {
  const SubscribedChannelStrip({super.key});

  static const _kMaxVisible = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscribedChannelStripProvider);

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (summaries) {
        if (summaries.isEmpty) return const SizedBox.shrink();
        final visible = summaries.take(_kMaxVisible).toList();
        return _ChannelStripBody(summaries: visible);
      },
    );
  }
}

class _ChannelStripBody extends StatelessWidget {
  const _ChannelStripBody({required this.summaries});

  final List<SubscribedChannelSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surfaceContainerLowest;

    return ColoredBox(
      color: bgColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 分区标题行
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.campaign, size: 14, color: AppColors.primary),
                AppSpacing.horizontalTiny,
                Text(
                  t.channel.title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          // 频道条目列表
          ...summaries.map((s) => _ChannelTile(summary: s)),
          const Divider(height: 1, thickness: 1),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.summary});

  final SubscribedChannelSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => context.push('/channel/${summary.channelId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 头像 + 未读角标
            _ChannelAvatar(
              avatar: summary.avatar,
              name: summary.name,
              unreadCount: summary.unreadCount,
            ),
            AppSpacing.horizontalMedium,
            // 频道名 + 消息预览
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (summary.lastMessageTime != null)
                        Text(
                          _formatTime(summary.lastMessageTime!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (summary.lastMessagePreview != null)
                    Text(
                      summary.lastMessagePreview!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int epochMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs).toLocal();
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }
}

class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({
    required this.avatar,
    required this.name,
    required this.unreadCount,
  });

  final String? avatar;
  final String name;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final Widget avatarWidget = SizedBox(
      width: 42,
      height: 42,
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusMedium,
        child: avatar != null && avatar!.isNotEmpty
            ? Image(
                image: cachedImageProvider(avatar!, w: 84),
                fit: BoxFit.cover,
                errorBuilder: (ctx, e, _) => _placeholder(ctx),
              )
            : _placeholder(context),
      ),
    );

    if (unreadCount <= 0) return avatarWidget;

    return BadgeWidget(
      content: Text(
        unreadCount > 99 ? '99+' : unreadCount.toString(),
        style: TextStyle(
          color: AppColors.onPrimary,
          fontSize: FontSizeType.tiny.size,
          fontWeight: FontWeight.w600,
        ),
      ),
      color: AppColors.messageFailed,
      borderRadius: AppRadius.borderRadiusMedium,
      child: avatarWidget,
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: FontSizeType.large.size,
          ),
        ),
      ),
    );
  }
}
