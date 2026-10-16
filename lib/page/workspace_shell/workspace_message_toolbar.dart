/// 企业壳「消息」页顶部工具条（2026-10 飞书风格改版）：
///
/// 行 1 —— 内容态 tab：筛选chip | 日程 | 待办，竖 hairline 分隔。
///
/// 筛选 chip 的下拉是「视图 + 筛选」统一菜单（2026-10-16 用户拍板）：
/// - 视图段：全部 / 日程 / 待办——选中即切内容态视图，弹窗成为与顶栏
///   tab 等价的第二入口；
/// - 筛选段：真实可用的会话筛选（见 [kVisibleWorkspaceMessageFilters]），
///   选中先切回「消息」视图再落筛选——此前筛选只在消息内容态内生效，
///   停在日程/待办时点筛选项毫无可见变化，被判定为「筛选不可用」。
/// - 顶部 chip 文案/图标始终反映当前所在视图（全部/日程/待办/未读/…）。
/// - 计数胶囊：全部/未读来自会话快照；日程/待办来自聚合 provider
///   （build 侧 eager watch 预热，弹窗打开时读快照）。
library;

import 'dart:async' show unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/popover_menu.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_group_agenda_views.dart';
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

  /// 当前选择（视图 + 筛选）的文案与图标口径：菜单项与顶部 chip 共用，
  /// 保证 chip 始终反映用户所在视图（2026-10-16 用户反馈：停在日程/
  /// 待办视图时 chip 仍显示「全部」，让筛选显得不可用）。
  String _selectionLabel() => switch (widget.tab) {
    WorkspaceMessageTab.message => _filterLabel(widget.filter),
    WorkspaceMessageTab.schedule => t.workspace.tabSchedule,
    WorkspaceMessageTab.todo => t.workspace.tabTodo,
  };

  ({IconData? icon, String? glyph}) _selectionIconSpec() =>
      switch (widget.tab) {
        WorkspaceMessageTab.message => _filterIcon(widget.filter),
        WorkspaceMessageTab.schedule => (
          icon: CupertinoIcons.calendar,
          glyph: null,
        ),
        WorkspaceMessageTab.todo => (
          icon: CupertinoIcons.checkmark_circle,
          glyph: null,
        ),
      };

  void _openFilterDropdown() {
    final renderBox =
        _filterTabKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    // 文案与计数在弹出时快照（瞬时浮层）；动作捕获页面级 context。
    final pageContext = context;
    final primary = Theme.of(pageContext).colorScheme.primary;
    final idle = Theme.of(pageContext).colorScheme.onSurfaceVariant;
    final (allCount, unreadCount) = _counts();
    final (scheduleCount, todoCount) = _agendaSnapshotCounts();
    // TODO 广州第一期交付后实现：筛选下拉的「编辑」动作（批量整理会话）。
    // 恢复时取消下方注释与 app_loading.dart import。
    // Future<void> onEdit() async {
    //   await AppLoading.showToast(t.workspace.featureComingSoon);
    // }

    // 点任一菜单项 = 同时落定「视图 + 筛选」两个维度；筛选项会先把
    // 视图切回「消息」，保证点哪个都有可见变化（见文件头注释）。
    void select(WorkspaceMessageTab tab, WorkspaceMessageFilter filter) {
      if (filter != widget.filter) widget.onFilterChanged(filter);
      if (tab != widget.tab) widget.onTabChanged(tab);
    }

    bool isCurrent(WorkspaceMessageTab tab, WorkspaceMessageFilter filter) =>
        widget.tab == tab &&
        (tab != WorkspaceMessageTab.message || widget.filter == filter);

    Widget? badge(int count) => count > 0 ? PopoverCountBadge(count) : null;

    PopoverMenuEntry entry({
      required String title,
      required IconData icon,
      required bool selected,
      required VoidCallback action,
      Widget? trailing,
    }) => PopoverMenuEntry(
      icon: Icon(icon, size: 20, color: selected ? primary : idle),
      title: title,
      foreground: selected ? primary : null,
      selected: selected,
      trailing: trailing,
      action: action,
    );

    unawaited(
      showPopoverMenu(
        pageContext,
        anchor: renderBox.localToGlobal(Offset.zero) & renderBox.size,
        side: PopoverMenuSide.topLeft,
        entries: [
          // —— 视图段（内容态）：全部 / 日程 / 待办。——
          entry(
            title: t.common.all,
            icon: CupertinoIcons.chat_bubble,
            selected: isCurrent(
              WorkspaceMessageTab.message,
              WorkspaceMessageFilter.all,
            ),
            trailing: badge(allCount),
            action: () =>
                select(WorkspaceMessageTab.message, WorkspaceMessageFilter.all),
          ),
          entry(
            title: t.workspace.tabSchedule,
            icon: CupertinoIcons.calendar,
            selected: isCurrent(
              WorkspaceMessageTab.schedule,
              WorkspaceMessageFilter.all,
            ),
            trailing: badge(scheduleCount),
            action: () => select(
              WorkspaceMessageTab.schedule,
              WorkspaceMessageFilter.all,
            ),
          ),
          entry(
            title: t.workspace.tabTodo,
            icon: CupertinoIcons.checkmark_circle,
            selected: isCurrent(
              WorkspaceMessageTab.todo,
              WorkspaceMessageFilter.all,
            ),
            trailing: badge(todoCount),
            action: () =>
                select(WorkspaceMessageTab.todo, WorkspaceMessageFilter.all),
          ),
          // —— 筛选段（消息内容态内的会话筛选）。——
          // 只展示真实可用的筛选项；@我/单聊/内部/外部/标记为「功能开发中」，
          // 枚举值先保留、待服务端补字段后经 kVisibleWorkspaceMessageFilters 点亮。
          for (final filter in kVisibleWorkspaceMessageFilters)
            if (filter != WorkspaceMessageFilter.all)
              entry(
                title: _filterLabel(filter),
                icon: _filterIcon(filter).icon ?? CupertinoIcons.circle,
                selected: isCurrent(WorkspaceMessageTab.message, filter),
                trailing: filter == WorkspaceMessageFilter.unread
                    ? badge(unreadCount)
                    : null,
                action: () => select(WorkspaceMessageTab.message, filter),
              ),
          // TODO 广州第一期交付后实现：「编辑」动作入口，恢复时取消注释。
          // PopoverMenuEntry(
          //   icon: Icon(
          //     CupertinoIcons.slider_horizontal_3,
          //     size: 20,
          //     color: Theme.of(pageContext).colorScheme.onSurface,
          //   ),
          //   title: t.workspace.filterEdit,
          //   action: onEdit,
          // ),
        ],
      ),
    );
  }

  /// 日程/待办计数快照（弹窗胶囊）：build 侧已 watch 预热，这里只读
  /// 缓存；加载中/失败不显示胶囊（不阻塞菜单）。
  (int, int) _agendaSnapshotCounts() {
    final wsId = ref.read(currentWorkspaceProvider)?.id ?? '';
    if (wsId.isEmpty) return (0, 0);
    final schedules =
        ref.read(workspaceGroupSchedulesProvider(wsId)).asData?.value ??
        const [];
    final todos =
        ref.read(workspaceGroupTodosProvider(wsId)).asData?.value ?? const [];
    return (schedules.length, todos.length);
  }

  Widget _iconBody(
    ({IconData? icon, String? glyph}) spec, {
    required bool primary,
  }) {
    final color = primary
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
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
    // 预热日程/待办聚合（弹窗胶囊常备 + 视图秒开）；失败静默，胶囊隐藏。
    final wsId = ref.watch(
      currentWorkspaceProvider.select((ws) => ws?.id ?? ''),
    );
    if (wsId.isNotEmpty) {
      ref.watch(workspaceGroupSchedulesProvider(wsId));
      ref.watch(workspaceGroupTodosProvider(wsId));
    }

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
                // chip 文案/图标跟随当前视图（消息视图下跟随当前筛选）。
                icon: _iconBody(_selectionIconSpec(), primary: filterActive),
                label: _selectionLabel(),
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
