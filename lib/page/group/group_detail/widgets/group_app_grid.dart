import 'package:flutter/material.dart';

import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 单个群应用入口定义。
class GroupAppItem {
  const GroupAppItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = false,
    this.color = AppColors.iosBlue,
  });

  /// 图标（CupertinoIcons 或 Icons）
  final IconData icon;

  /// 显示名称
  final String label;

  /// 点击回调
  final VoidCallback onTap;

  /// 是否显示红点徽章（有新动态时）
  final bool badge;

  /// 图标背景主题色
  final Color color;
}

/// 群应用九宫格（对标 QQ 群应用面板）。
///
/// 把原先散落在群详情设置列表各处的协作功能（公告/文件/相册/投票/日程/任务/
/// 标签/分类/二维码）聚合为一个 3 列网格，每项含图标 + 名称 + 可选红点徽章。
/// 这是群详情页体验重构的核心：让用户一眼看到群的所有能力，而非在设置列表
/// 里逐行寻找。
class GroupAppGrid extends StatelessWidget {
  const GroupAppGrid({super.key, required this.items});

  final List<GroupAppItem> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.regular,
        horizontal: AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.medium,
        crossAxisSpacing: 0,
        // 九宫格每项固定高度，保证图标+名称垂直居中
        childAspectRatio: 0.95,
        children: items.map((item) => _AppGridCell(item: item)).toList(),
      ),
    );
  }
}

class _AppGridCell extends StatelessWidget {
  const _AppGridCell({required this.item});

  final GroupAppItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标圆角方块（对标 QQ 群应用），红点叠在右上角
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: isDark ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(item.icon, size: 24, color: item.color),
              ),
              if (item.badge)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.iosRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.tiny),
          Text(
            item.label,
            style: context.textStyle(
              FontSizeType.footnote,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
