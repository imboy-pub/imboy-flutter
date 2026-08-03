import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';

import '../channel_detail_rules.dart';

/// 频道头部信息条
///
/// 从详情页抽出的 [ChannelDetailPage._buildStatsHeader] 升级版。
/// 对标公众号主页头部：封面 + 频道名 + 简介 + 统计栏。
class ChannelHeaderBar extends StatelessWidget {
  final ChannelModel channel;
  final ChannelStatsModel? stats;

  /// 点击订阅/管理按钮回调
  final VoidCallback? onActionTap;

  const ChannelHeaderBar({
    super.key,
    required this.channel,
    this.stats,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = AppColors.getTextColor(
      Theme.of(context).brightness,
      isSecondary: true,
    );
    final surface = Theme.of(context).colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.getIosSeparator(Theme.of(context).brightness),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面 + 频道名 + 简介
          Padding(
            padding: AppSpacing.allRegular,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(isDark),
                AppSpacing.horizontalRegular,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              channel.name,
                              style: context.textStyle(
                                FontSizeType.large,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (channel.isVerified)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                      if (channel.description != null &&
                          channel.description!.isNotEmpty) ...[
                        AppSpacing.verticalTiny,
                        Text(
                          channel.description!,
                          style: context.textStyle(
                            FontSizeType.small,
                            color: secondaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // 标签
                      if (channel.tags != null && channel.tags!.isNotEmpty) ...[
                        AppSpacing.verticalSmall,
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: channel.tags!
                              .take(5)
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: context.textStyle(
                                      FontSizeType.tiny,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 订阅/管理操作行
          if (onActionTap != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.regular,
                right: AppSpacing.regular,
                bottom: AppSpacing.small,
              ),
              child: SizedBox(
                width: double.infinity,
                child: channel.isManaged
                    ? OutlinedButton.icon(
                        onPressed: onActionTap,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text(t.main.manage),
                      )
                    : (channel.isSubscribed
                          ? OutlinedButton.icon(
                              onPressed: onActionTap,
                              icon: const Icon(Icons.check, size: 16),
                              label: Text(t.channel.subscribed),
                            )
                          : FilledButton.icon(
                              onPressed: onActionTap,
                              icon: const Icon(
                                Icons.notifications_active_outlined,
                                size: 16,
                              ),
                              label: Text(t.channel.subscribe),
                            )),
              ),
            ),
          // 紧凑统计信息：一行文字与图标表示，对齐内容定位，省空间
          if (stats != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.regular,
                right: AppSpacing.regular,
                bottom: AppSpacing.regular,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Icon(Icons.people_outline, size: 14, color: secondaryColor),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatNumber(stats?.subscriberCount ?? 0)} ${t.channel.subscribers}',
                      style: context.textStyle(
                        FontSizeType.small,
                        color: secondaryColor,
                      ),
                    ),
                    Text('  ·  ', style: TextStyle(color: secondaryColor)),
                    Icon(
                      Icons.article_outlined,
                      size: 14,
                      color: secondaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatNumber(stats?.totalMessages ?? 0)} ${t.channel.messages}',
                      style: context.textStyle(
                        FontSizeType.small,
                        color: secondaryColor,
                      ),
                    ),
                    if ((stats?.totalViews ?? 0) > 0) ...[
                      Text('  ·  ', style: TextStyle(color: secondaryColor)),
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 14,
                        color: secondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatNumber(stats?.totalViews ?? 0)} ${t.channel.views}',
                        style: context.textStyle(
                          FontSizeType.small,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                    if ((stats?.totalReactions ?? 0) > 0) ...[
                      Text('  ·  ', style: TextStyle(color: secondaryColor)),
                      Icon(
                        Icons.thumb_up_outlined,
                        size: 14,
                        color: secondaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatNumber(stats?.totalReactions ?? 0)} ${t.channel.reactions}',
                        style: context.textStyle(
                          FontSizeType.small,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    final hasAvatar = channel.avatar != null && channel.avatar!.isNotEmpty;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderRadiusMedium,
        color: AppColors.primary.withValues(alpha: 0.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasAvatar
          ? Image(
              image: cachedImageProvider(channel.avatar!, w: 128),
              fit: BoxFit.cover,
              width: 56,
              height: 56,
              // 加载失败降级占位，避免默认红叉方框（QA#28）
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
            )
          : Center(
              child: Text(
                channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  String _formatNumber(int number) => formatChannelNumber(number);
}
