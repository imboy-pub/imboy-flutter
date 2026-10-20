import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/resource_entry_tile.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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

/// Group existing capabilities by reading and collaboration, without fixed cells.
class GroupAppGrid extends StatelessWidget {
  const GroupAppGrid({super.key, required this.items});
  final List<GroupAppItem> items;

  @override
  Widget build(BuildContext context) {
    final content = items.take(3).toList();
    final collaboration = items.skip(3).take(3).toList();
    final more = items.skip(6).toList();
    Widget section(String title, List<GroupAppItem> entries) =>
        ImBoySettingsSection(
          header: Text(title),
          children: [
            for (final item in entries)
              ResourceEntryTile(
                showDivider: false,
                title: item.label,
                icon: item.icon,
                trailing: item.badge
                    ? const Icon(
                        CupertinoIcons.circle_fill,
                        size: AppSpacing.small,
                        color: AppColors.iosRed,
                      )
                    : null,
                onTap: item.onTap,
              ),
          ],
        );
    return Column(
      children: [
        if (content.isNotEmpty)
          section(context.t.organization.experienceUi.groupContent, content),
        if (collaboration.isNotEmpty)
          section(
            context.t.organization.experienceUi.groupCollaboration,
            collaboration,
          ),
        if (more.isNotEmpty) section(context.t.main.setting, more),
      ],
    );
  }
}
