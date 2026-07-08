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
///
/// 简介超长时可点击展开/收起（3 行），避免信息被截断又不过度占空间。
class GroupInfoCard extends StatefulWidget {
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
  State<GroupInfoCard> createState() => _GroupInfoCardState();
}

class _GroupInfoCardState extends State<GroupInfoCard> {
  bool _introExpanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleText = group.title.isEmpty ? group.computeTitle : group.title;
    final hasIntro = group.introduction.isNotEmpty;

    return GestureDetector(
      onTap: widget.onTap,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SmartGroupAvatar(
              avatar: group.avatar,
              groupId: group.groupId.toString(),
              size: 60,
              avatarLoader: widget.avatarLoader,
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
                    GestureDetector(
                      // 简介点击展开/收起，不触达外层 onTap（进入编辑）
                      onTap: () =>
                          setState(() => _introExpanded = !_introExpanded),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              group.introduction,
                              style: context.textStyle(
                                FontSizeType.footnote,
                                color: AppColors.iosGray,
                              ),
                              maxLines: _introExpanded ? 5 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (group.introduction.length > 20)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                _introExpanded
                                    ? CupertinoIcons.chevron_up
                                    : CupertinoIcons.chevron_down,
                                size: 12,
                                color: AppColors.iosGray3,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.small),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: AppColors.iosGray3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
