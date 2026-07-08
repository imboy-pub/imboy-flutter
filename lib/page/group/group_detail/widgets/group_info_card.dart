import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群详情页顶部信息卡片。
///
/// 对标微信群设置：群头像 + 群名 + 简介 + 成员数，整卡可点进入编辑。
/// 取代原先「群名」单独占一行的扁平设置项，把群的核心身份信息聚合为
/// 一个有视觉权重的卡片，建立信息层级。
class GroupInfoCard extends StatelessWidget {
  const GroupInfoCard({
    super.key,
    required this.group,
    required this.onTap,
    this.avatarLoader,
  });

  final GroupModel group;
  final VoidCallback onTap;

  /// 群头像合成图加载器（由调用方注入，避免本组件耦合 service）。
  final Future<List<String>> Function(String groupId)? avatarLoader;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleText = group.title.isEmpty ? group.computeTitle : group.title;
    final hasIntro = group.introduction.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          AppSpacing.regular,
          AppSpacing.large,
          AppSpacing.regular,
          AppSpacing.small,
        ),
        padding: const EdgeInsets.all(AppSpacing.regular),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            SmartGroupAvatar(
              avatar: group.avatar,
              groupId: group.groupId.toString(),
              size: 60,
              avatarLoader: avatarLoader,
            ),
            const SizedBox(width: AppSpacing.regular),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText.isEmpty ? t.main.unnamed : titleText,
                    style: context.textStyle(
                      FontSizeType.large,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.tiny),
                  Text(
                    '${group.memberCount} ${t.group.groupMembers}',
                    style: context.textStyle(
                      FontSizeType.footnote,
                      color: AppColors.iosGray,
                    ),
                  ),
                  if (hasIntro) ...[
                    const SizedBox(height: AppSpacing.tiny),
                    Text(
                      group.introduction,
                      style: context.textStyle(
                        FontSizeType.footnote,
                        color: AppColors.iosGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: AppColors.iosGray3,
            ),
          ],
        ),
      ),
    );
  }
}
