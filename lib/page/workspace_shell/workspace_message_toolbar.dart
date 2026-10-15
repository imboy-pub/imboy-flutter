/// 企业壳「消息」页顶部工具条（2026-10 飞书风格改版）：
///
/// 行 1 —— 内容态 tab：筛选(全部⌄) | 日程 | 待办 | 会议，竖 hairline
/// 分隔；第一项展示当前筛选并负责唤起下拉菜单（参考稿②③）。
///
/// 下拉菜单为通用 [showPopoverMenu] 气泡：九项筛选 + 「编辑」动作；
/// 全部/未读行尾带计数胶囊（数据来自 workspaceConversationsProvider，
/// 加载中/失败时胶囊隐藏，不阻塞筛选本身）。
library;

import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/popover_menu.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_message_filter.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 筛选 tab 的锚点，供下拉菜单定位与测试定位。
const ValueKey<String> kWorkspaceMessageFilterTabKey = ValueKey<String>(
  'workspace-message-filter-tab',
);

class WorkspaceMessageFilterBar extends ConsumerStatefulWidget {
  const WorkspaceMessageFilterBar({
    super.key,
    required this.tab,
    required this.filter,
    required this.onTabChanged,
    required this.onFilterChanged,
  });

  final WorkspaceMessageTab tab;
  final WorkspaceMessageFilter filter;
  final ValueChanged<WorkspaceMessageTab> onTabChanged;
  final ValueChanged<WorkspaceMessageFilter> onFilterChanged;

  @override
  ConsumerState<WorkspaceMessageFilterBar> createState() =>
      _WorkspaceMessageFilterBarState();
}

class _WorkspaceMessageFilterBarState
    extends ConsumerState<WorkspaceMessageFilterBar> {
  final _filterTabKey = GlobalKey();

  String _filterLabel(WorkspaceMessageFilter filter) => switch (filter) {
    WorkspaceMessageFilter.all => t.common.all,
    WorkspaceMessageFilter.unread => t.workspace.filterUnread,
    WorkspaceMessageFilter.mentions => t.workspace.filterMentions,
    WorkspaceMessageFilter.dm => t.workspace.filterDm,
    WorkspaceMessageFilter.group => t.chat.groupChat,
    WorkspaceMessageFilter.channel => t.channel.title,
    WorkspaceMessageFilter.internal => t.workspace.filterInternalChat,
    WorkspaceMessageFilter.external => t.workspace.filterExternalChat,
    WorkspaceMessageFilter.flagged => t.workspace.filterFlagged,
  };

  ({IconData? icon, String? glyph}) _filterIcon(
    WorkspaceMessageFilter filter,
  ) => switch (filter) {
    WorkspaceMessageFilter.all => (
      icon: CupertinoIcons.chat_bubble,
      glyph: null,
    ),
    WorkspaceMessageFilter.unread => (
      icon: CupertinoIcons.app_badge,
      glyph: null,
    ),
    WorkspaceMessageFilter.mentions => (icon: null, glyph: '@'),
    WorkspaceMessageFilter.dm => (
      icon: CupertinoIcons.person_crop_circle,
      glyph: null,
    ),
    WorkspaceMessageFilter.group => (
      icon: CupertinoIcons.person_2,
      glyph: null,
    ),
    WorkspaceMessageFilter.channel => (
      icon: CupertinoIcons.speaker_2,
      glyph: null,
    ),
    WorkspaceMessageFilter.internal => (
      icon: CupertinoIcons.ellipses_bubble,
      glyph: null,
    ),
    WorkspaceMessageFilter.external => (
      icon: CupertinoIcons.bubble_left_bubble_right,
      glyph: null,
    ),
    WorkspaceMessageFilter.flagged => (icon: CupertinoIcons.star, glyph: null),
  };

  void _openFilterDropdown() {
    final renderBox =
        _filterTabKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    // 文案与计数在弹出时快照（瞬时浮层）；动作捕获页面级 context。
    final pageContext = context;
    final (allCount, unreadCount) = _counts();
    Future<void> onEdit() async {
      await AppLoading.showToast(t.workspace.featureComingSoon);
    }

    unawaited(
      showPopoverMenu(
        pageContext,
        anchor: renderBox.localToGlobal(Offset.zero) & renderBox.size,
        side: PopoverMenuSide.topLeft,
        entries: [
          for (final filter in WorkspaceMessageFilter.values)
            PopoverMenuEntry(
              icon: _filterIconBody(filter, primary: filter == widget.filter),
              title: _filterLabel(filter),
              foreground: filter == widget.filter
                  ? Theme.of(pageContext).colorScheme.primary
                  : null,
              selected: filter == widget.filter,
              trailing: filter == WorkspaceMessageFilter.all && allCount > 0
                  ? PopoverCountBadge(allCount)
                  : filter == WorkspaceMessageFilter.unread && unreadCount > 0
                  ? PopoverCountBadge(unreadCount)
                  : null,
              action: () {
                if (filter != widget.filter) widget.onFilterChanged(filter);
              },
            ),
          PopoverMenuEntry(
            icon: Icon(
              CupertinoIcons.slider_horizontal_3,
              size: 20,
              color: Theme.of(pageContext).colorScheme.onSurface,
            ),
            title: t.workspace.filterEdit,
            action: onEdit,
          ),
        ],
      ),
    );
  }

  Widget _filterIconBody(
    WorkspaceMessageFilter filter, {
    required bool primary,
  }) {
    final color = primary
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final spec = _filterIcon(filter);
    if (spec.icon != null) {
      return Icon(spec.icon, size: 20, color: color);
    }
    return Center(
      child: Text(
        spec.glyph ?? '',
        style: context.textStyle(
          FontSizeType.medium,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  (int, int) _counts() {
    // 仅在弹出回调里快照（瞬时浮层），用 read 不订阅。
    final wsId = ref.read(currentWorkspaceProvider)?.id ?? '';
    if (wsId.isEmpty) return (0, 0);
    final list = ref.read(workspaceConversationsProvider(wsId)).asData?.value;
    if (list == null) return (0, 0);
    final unread = list.where((row) => row.unreadCount > 0).length;
    return (list.length, unread);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = theme.colorScheme.primary;
    final idleColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final idleIconColor = AppColors.iosGray;
    final filterActive = widget.tab == WorkspaceMessageTab.message;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.getIosSeparator(theme.brightness)
                .withValues(alpha: 0.4),
            width: 0.33,
          ),
        ),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: _BarItem(
                key: _filterTabKey,
                itemKey: kWorkspaceMessageFilterTabKey,
                icon: _filterIconBody(widget.filter, primary: filterActive),
                label: _filterLabel(widget.filter),
                showChevron: true,
                chevronUp: false,
                active: filterActive,
                activeColor: activeColor,
                idleColor: idleColor,
                onTap: _openFilterDropdown,
              ),
            ),
            for (final tab in const [
              (WorkspaceMessageTab.schedule, CupertinoIcons.calendar),
              (WorkspaceMessageTab.todo, CupertinoIcons.checkmark_circle),
            ]) ...[
              _verticalHairline(theme.brightness),
              Expanded(
                child: _BarItem(
                  icon: Icon(
                    tab.$2,
                    size: 20,
                    color: widget.tab == tab.$1 ? activeColor : idleIconColor,
                  ),
                  label: switch (tab.$1) {
                    WorkspaceMessageTab.schedule => t.workspace.tabSchedule,
                    WorkspaceMessageTab.todo => t.workspace.tabTodo,
                    WorkspaceMessageTab.message => t.chat.titleMessage,
                  },
                  active: widget.tab == tab.$1,
                  activeColor: activeColor,
                  idleColor: idleColor,
                  onTap: () => widget.onTabChanged(tab.$1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _verticalHairline(Brightness brightness) => Container(
    width: 0.5,
    margin: const EdgeInsets.symmetric(vertical: 14),
    color: AppColors.getIosSeparator(brightness).withValues(alpha: 0.5),
  );
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.idleColor,
    required this.onTap,
    this.showChevron = false,
    this.chevronUp = false,
    this.itemKey,
  });

  final Widget icon;
  final String label;
  final bool active;
  final Color activeColor;
  final Color idleColor;
  final VoidCallback onTap;
  final bool showChevron;
  final bool chevronUp;
  final Key? itemKey;

  @override
  Widget build(BuildContext context) {
    final tint = active ? activeColor : idleColor;
    return CupertinoButton(
      key: itemKey,
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 44),
      pressedOpacity: 0.55,
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          AppSpacing.horizontalTiny,
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.subheadline,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: tint,
              ),
            ),
          ),
          if (showChevron) ...[
            AppSpacing.horizontalTiny,
            Icon(
              chevronUp
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              size: 12,
              color: tint,
            ),
          ],
        ],
      ),
    );
  }
}
