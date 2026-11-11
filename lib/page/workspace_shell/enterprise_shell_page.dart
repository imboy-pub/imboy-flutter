import 'package:imboy/app_core/feature_flags/feature_revision_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/ui/desktop_navigation_rail.dart';
import 'package:imboy/component/ui/glass_bottom_bar.dart';
import 'package:imboy/page/web_shell/web_nav_rail.dart';
import 'package:imboy/modules/enterprise_oa/public.dart';
import 'package:imboy/modules/organization/public.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_entry.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_tiles.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_conversations_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/modules/attachments/workspace_attachments_page.dart';
import 'package:imboy/page/workspace/workspace_projects_page.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace/workspace_group_agenda_views.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/mine/mine/mine_shortcut.dart';
import 'package:imboy/page/workspace_shell/space_switcher_button.dart';
import 'package:imboy/page/workspace_shell/workspace_message_filter.dart';
import 'package:imboy/page/workspace_shell/workspace_message_toolbar.dart';
import 'package:imboy/page/workspace_shell/workspace_plus_menu.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_breakpoints.dart';
import 'package:imboy/component/ui/resource_entry_tile.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/ui/badge_widget.dart';

// WorkspaceSwitcherChip 定义于此（账号 Sheet 文件）；会话页 standalone
// 模式仍在使用。
import 'workspace_shell_provider.dart';
import 'workspace_top_bar.dart';

final _mineOrganizationProvider = FutureProvider.autoDispose
    .family<Organization, ({String accountKey, String organizationId})>(
      (ref, scope) =>
          ref.watch(organizationApiProvider).detail(scope.organizationId),
    );

/// 企业主导航。Key 由宿主绑定账号、企业及工作区，切换时销毁旧页面。
///
/// 2026-10 飞书风格改版：底栏维持四栏（消息/通讯录/工作台/我，用户
/// 拍板）；空间入口在侧栏顶部全局常驻，窄屏放在消息顶栏；消息 tab
/// 顶部挂内容态 tab（筛选/日程/待办），日程·待办聚合企业群数据。
class EnterpriseShellPage extends ConsumerStatefulWidget {
  const EnterpriseShellPage({
    super.key,
    required this.accountKey,
    required this.organizationId,
  });
  final String accountKey;
  final String organizationId;

  @override
  ConsumerState<EnterpriseShellPage> createState() =>
      _EnterpriseShellPageState();
}

class _EnterpriseShellPageState extends ConsumerState<EnterpriseShellPage> {
  EnterpriseShellDestination _selected = EnterpriseShellDestination.messages;
  final _visited = <EnterpriseShellDestination>{
    EnterpriseShellDestination.messages,
  };
  WorkspaceMessageTab _messageTab = WorkspaceMessageTab.message;
  WorkspaceMessageFilter _filter = WorkspaceMessageFilter.all;
  bool _configurationReady = false;

  @override
  void initState() {
    super.initState();
    final navigation = ref.read(workspaceShellProvider).enterpriseNavigation;
    _selected = navigation.destination;
    _filter = navigation.filter;
    _visited.add(_selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(oaWorkbenchEntriesProvider(widget.accountKey));
      setState(() => _configurationReady = true);
    });
  }

  void _rememberNavigation() => ref
      .read(workspaceShellProvider.notifier)
      .rememberEnterpriseNavigation((destination: _selected, filter: _filter));

  ({String accountKey, String organizationId}) get _scope =>
      (accountKey: widget.accountKey, organizationId: widget.organizationId);

  AsyncValue<List<EnterpriseOaRuntimeConfig>> _entries() {
    // macOS 桌面端同样支持（WebView JSChannel/WKWebView 桥齐备，检测能列出
    // getAuthCode 即为实证）；此前仅放行 Android/iOS，macOS 上 entries 恒为
    // 空列表 → 本地裁决 app_not_configured（不发任何请求）。
    final supported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (!supported) return const AsyncData<List<EnterpriseOaRuntimeConfig>>([]);
    return _configurationReady
        ? ref.watch(oaWorkbenchEntriesProvider(widget.accountKey))
        : const AsyncLoading<List<EnterpriseOaRuntimeConfig>>();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(featureRevisionProvider);
    final entries = _entries();
    final configs =
        entries is AsyncData<List<EnterpriseOaRuntimeConfig>> &&
            !entries.isLoading &&
            !entries.hasError
        ? entries.value.where((entry) => entry.runtimeEntryEnabled).toList()
        : const <EnterpriseOaRuntimeConfig>[];
    final destinations = [
      EnterpriseShellDestination.messages,
      EnterpriseShellDestination.contacts,
      EnterpriseShellDestination.workbench,
      EnterpriseShellDestination.mine,
    ];
    final labels = destinations.map(_label).toList();
    // spec D1：顶栏上下文「企业名 · 工作区名」两级，所有 tab 稳定可见；
    // 真源为 org detail provider + currentWorkspaceProvider，缺失段自然省略。
    final orgName =
        ref.watch(_mineOrganizationProvider(_scope)).asData?.value.name ?? '';
    final wsName = ref.watch(currentWorkspaceProvider)?.name ?? '';
    final contextSubtitle = [
      if (orgName.isNotEmpty) orgName,
      if (wsName.isNotEmpty)
        t.organization.experienceUi.workspaceContext(name: wsName),
    ].join(' · ');
    final icons = destinations.map(_icon).toList();
    // 工作台始终可见，应用入口仍按实时授权配置显示。
    final index = destinations.contains(_selected)
        ? destinations.indexOf(_selected)
        : 0;
    void select(int value) => setState(() {
      _selected = destinations[value];
      if (_selected == EnterpriseShellDestination.mine) {
        ref.invalidate(_mineOrganizationProvider(_scope));
      }
      _visited.add(_selected);
      _rememberNavigation();
    });
    // 这里只决定导航呈现，与个人壳的 600pt rail 保持一致；900pt 内容壳
    // 断点仍由各自 bootstrap / resolveWorkspaceShellLayout 管理。
    final useRail = MediaQuery.sizeOf(context).width >= AppBreakpoints.mobile;
    final spaceSwitcher = SpaceSwitcherButton(
      key: ValueKey(
        useRail
            ? 'enterprise-shell-space-switcher'
            : 'enterprise-shell-menu-button',
      ),
      organizationId: widget.organizationId,
      spaceName: orgName,
      inRail: useRail,
    );
    return _frame(
      destinations,
      labels,
      icons,
      index,
      useRail,
      select,
      spaceSwitcher,
      _content(
        destinations,
        configs,
        entries,
        index,
        labels[index],
        contextSubtitle,
        useRail ? null : spaceSwitcher,
      ),
    );
  }

  String _label(EnterpriseShellDestination destination) =>
      switch (destination) {
        EnterpriseShellDestination.messages => t.chat.titleMessage,
        EnterpriseShellDestination.contacts => t.organization.directory.title,
        EnterpriseShellDestination.workbench => t.enterpriseOa.workbenchTitle,
        EnterpriseShellDestination.mine => t.common.me,
      };

  IconData _icon(EnterpriseShellDestination destination) =>
      switch (destination) {
        EnterpriseShellDestination.messages => CupertinoIcons.chat_bubble,
        EnterpriseShellDestination.contacts => CupertinoIcons.person_2,
        EnterpriseShellDestination.workbench => CupertinoIcons.square_grid_2x2,
        EnterpriseShellDestination.mine => CupertinoIcons.person_circle,
      };

  IconData _activeIcon(EnterpriseShellDestination destination) =>
      switch (destination) {
        EnterpriseShellDestination.messages => CupertinoIcons.chat_bubble_fill,
        EnterpriseShellDestination.contacts => CupertinoIcons.person_2_fill,
        EnterpriseShellDestination.workbench =>
          CupertinoIcons.square_grid_2x2_fill,
        EnterpriseShellDestination.mine => CupertinoIcons.person_circle_fill,
      };

  /// 通讯录 Tab 右上角「邀请同事」入口（APP-M02）。
  Widget _inviteColleaguesAction() {
    final orgName =
        ref.watch(_mineOrganizationProvider(_scope)).asData?.value.name ?? '';
    final query = orgName.isEmpty
        ? ''
        : '?name=${Uri.encodeComponent(orgName)}';
    return CupertinoButton(
      key: const ValueKey('enterprise-topbar-invite-colleagues'),
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: () => context.push(
        '$kOrganizationHomePath/${widget.organizationId}'
        '/invite_colleagues$query',
      ),
      child: Semantics(
        label: context.t.organization.inviteColleagues.title,
        child: Icon(
          CupertinoIcons.person_add,
          size: 22,
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkTextPrimary
              : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  Widget _content(
    List<EnterpriseShellDestination> destinations,
    List<EnterpriseOaRuntimeConfig> configs,
    AsyncValue<List<EnterpriseOaRuntimeConfig>> entries,
    int index,
    String title,
    String contextSubtitle,
    Widget? spaceSwitcher,
  ) {
    return Column(
      children: [
        // 「我」tab 不要顶栏标题行（页面自身就是身份区）：只保留与页面同底色
        // 的状态栏安全区占位，归档横幅/错误条仍落在安全区内。
        if (_selected == EnterpriseShellDestination.mine)
          ColoredBox(
            color: AppColors.getSurfaceGrouped(Theme.of(context).brightness),
            child: const SafeArea(
              bottom: false,
              child: SizedBox(width: double.infinity, height: 0),
            ),
          )
        else
          WorkspaceTopBar(
            title: title,
            subtitle: contextSubtitle.isEmpty ? null : contextSubtitle,
            // 侧栏已有全局入口时不重复；窄屏沿用消息顶栏位置。
            leading: _selected == EnterpriseShellDestination.messages
                ? spaceSwitcher
                : null,
            actions: switch (_selected) {
              EnterpriseShellDestination.messages => const [
                WorkspacePlusButton(),
              ],
              EnterpriseShellDestination.contacts => [
                _inviteColleaguesAction(),
              ],
              _ => null,
            },
          ),
        if (ref.watch(currentWorkspaceProvider)?.isArchived ?? false)
          const WorkspaceArchivedBanner(),
        if (entries.hasError)
          CupertinoListTile(
            title: Text(t.enterpriseOa.statusErrorTitle),
            trailing: CupertinoButton(
              onPressed: () =>
                  ref.invalidate(oaWorkbenchEntriesProvider(widget.accountKey)),
              child: Text(t.enterpriseOa.actionRetry),
            ),
          ),
        Expanded(
          child: IndexedStack(
            index: index,
            children: [
              for (final destination in destinations)
                KeyedSubtree(
                  key: ValueKey(destination),
                  child: _visited.contains(destination)
                      ? _page(
                          destination,
                          configs,
                          destination == destinations[index],
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _frame(
    List<EnterpriseShellDestination> destinations,
    List<String> labels,
    List<IconData> icons,
    int index,
    bool useRail,
    ValueChanged<int> select,
    Widget spaceSwitcher,
    Widget content,
  ) {
    return Scaffold(
      body: Row(
        children: [
          if (useRail &&
              usesDesktopNavigation(
                platform: defaultTargetPlatform,
                isWeb: kIsWeb,
              ))
            WebNavRail(
              key: const ValueKey('enterprise-shell-rail'),
              leading: spaceSwitcher,
              items: [
                for (var i = 0; i < destinations.length; i++)
                  WebNavItem(
                    icon: icons[i],
                    activeIcon: _activeIcon(destinations[i]),
                    label: labels[i],
                    badgeCount:
                        destinations[i] == EnterpriseShellDestination.messages
                        ? _messageUnreadCount()
                        : 0,
                    controlKey: ValueKey(
                      'enterprise-shell-nav-${destinations[i].name}',
                    ),
                  ),
              ],
              currentIndex: index,
              onTap: select,
            )
          else if (useRail)
            NavigationRail(
              key: const ValueKey('enterprise-shell-rail'),
              leading: spaceSwitcher,
              scrollable: true,
              selectedIndex: index,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationRailDestination(
                    icon: _navigationIcon(destinations[i], icons[i]),
                    label: Text(labels[i]),
                  ),
              ],
            ),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : GlassBottomNavigationBar(
              key: const ValueKey('enterprise-shell-bottom-nav'),
              currentIndex: index,
              onTap: select,
              items: [
                for (var i = 0; i < labels.length; i++)
                  GlassBottomBarItem(
                    icon: icons[i],
                    activeIcon: _activeIcon(destinations[i]),
                    label: labels[i],
                    tabKey: ValueKey(
                      'enterprise-shell-nav-${destinations[i].name}',
                    ),
                    iconBuilder: (selected) => _navigationIcon(
                      destinations[i],
                      selected ? _activeIcon(destinations[i]) : icons[i],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _navigationIcon(
    EnterpriseShellDestination destination,
    IconData icon,
  ) {
    if (destination != EnterpriseShellDestination.messages) return Icon(icon);
    final count = _messageUnreadCount();
    return BadgeWidget(
      showBadge: count > 0,
      semanticLabel: context.t.common.unreadCount(count: '$count'),
      color: Theme.of(context).brightness == Brightness.dark
          ? AppColors.iosRedDark
          : AppColors.iosRed,
      content: Text(
        count > 99 ? '99+' : '$count',
        style: context.textStyle(FontSizeType.tiny, color: AppColors.onPrimary),
      ),
      child: Icon(icon),
    );
  }

  int _messageUnreadCount() {
    final workspace = ref.watch(currentWorkspaceProvider)?.id ?? '';
    final rows = workspace.isEmpty
        ? null
        : ref.watch(workspaceConversationsProvider(workspace));
    return rows == null || rows.isLoading || rows.hasError
        ? 0
        : (rows.asData?.value ?? []).fold<int>(
            0,
            (total, row) => total + row.unreadCount,
          );
  }

  Widget _page(
    EnterpriseShellDestination destination,
    List<EnterpriseOaRuntimeConfig> configs,
    bool active,
  ) {
    switch (destination) {
      case EnterpriseShellDestination.messages:
        return _messages(active);

      case EnterpriseShellDestination.workbench:
        return EnterpriseWorkbenchPage(
          entries: configs,
          accountKey: widget.accountKey,
          organizationId: widget.organizationId,
          resourceEntries: [
            const CsWorkspaceEntryTile(showDivider: true),
            TalkRecordOrgToolEntry(organizationId: widget.organizationId),
            if (ref.watch(currentWorkspaceProvider) != null) ...[
              if (AppFeatureRegistry.isEnabled(FeatureKeys.project))
                _resourceEntry(
                  t.workspace.navProjects,
                  const WorkspaceProjectsPage(),
                  icon: CupertinoIcons.folder,
                ),
              _resourceEntry(
                t.workspace.navGroups,
                const WorkspaceGroupsPage(),
                icon: CupertinoIcons.person_2,
              ),
              _resourceEntry(
                t.channel.title,
                const WorkspaceChannelsPage(),
                icon: CupertinoIcons.speaker_2,
              ),
              _resourceEntry(
                t.attachmentManager.title,
                const WorkspaceAttachmentsPage(),
                icon: CupertinoIcons.paperclip,
              ),
            ],
          ],
        );
      case EnterpriseShellDestination.contacts:
        return HumanDirectoryBrowserPage(
          orgId: widget.organizationId,
          orgName:
              ref.watch(_mineOrganizationProvider(_scope)).asData?.value.name ??
              '',
          embedded: true,
          active: active,
        );
      case EnterpriseShellDestination.mine:
        return _mine();
    }
  }

  Widget _mine() {
    final organization = ref.watch(_mineOrganizationProvider(_scope));
    final org = organization.hasError || organization.isLoading
        ? null
        : organization.asData?.value;
    final workspace = ref.watch(currentWorkspaceProvider);
    final canManage =
        org != null &&
        org.id == widget.organizationId &&
        (org.canGovern || workspace?.ownerId == widget.accountKey);
    return MinePage(
      enterprise: true,
      enterpriseName: org?.name,
      enterpriseEntry: MineShortcut(
        key: const ValueKey('enterprise-mine-organization-entry'),
        icon: CupertinoIcons.building_2_fill,
        label: canManage
            ? t.organization.manage.entry
            : t.organization.home.tabOrg,
        onTap: () => context.push('/organization/${widget.organizationId}'),
      ),
    );
  }

  Widget _messages(bool active) {
    final shell = ref.watch(workspaceShellProvider);
    if (!shell.hasWorkspace && shell.isLoading) {
      return const WorkspaceLoadingView();
    }
    if (!shell.hasWorkspace && shell.error != null) {
      return WorkspaceErrorView(
        message: shell.error!,
        onRetry: () => ref.read(workspaceShellProvider.notifier).loadMine(),
      );
    }
    return Column(
      children: [
        WorkspaceMessageFilterBar(
          tab: _messageTab,
          filter: _filter,
          // 弹窗/顶栏切换视图与筛选都记忆导航（重挂载恢复，见 initState）。
          onTabChanged: (tab) => setState(() {
            _messageTab = tab;
            _rememberNavigation();
          }),
          onFilterChanged: (filter) {
            setState(() => _filter = filter);
            _rememberNavigation();
            if (filter == WorkspaceMessageFilter.channel) {
              final id = ref.read(currentWorkspaceProvider)?.id ?? '';
              if (id.isNotEmpty) ref.invalidate(workspaceChannelsProvider(id));
            }
          },
        ),
        Expanded(child: _messageTabContent(active)),
      ],
    );
  }

  Widget _messageTabContent(bool active) => switch (_messageTab) {
    WorkspaceMessageTab.message => IndexedStack(
      index: _filter == WorkspaceMessageFilter.channel ? 1 : 0,
      children: [
        WorkspaceConversationsPage(
          embedded: true,
          active: active && _filter != WorkspaceMessageFilter.channel,
          filter: _filter == WorkspaceMessageFilter.channel
              ? WorkspaceMessageFilter.all
              : _filter,
        ),
        if (_filter == WorkspaceMessageFilter.channel)
          const WorkspaceChannelsPage()
        else
          const SizedBox.shrink(),
      ],
    ),
    // 日程/待办聚合当前工作区内企业群的群日程与群作业。
    WorkspaceMessageTab.schedule => const WorkspaceGroupAgendaView(
      kind: WorkspaceAgendaKind.schedule,
    ),
    WorkspaceMessageTab.todo => const WorkspaceGroupAgendaView(
      kind: WorkspaceAgendaKind.todo,
    ),
  };

  Widget _resourceEntry(String title, Widget page, {IconData? icon}) =>
      ResourceEntryTile(
        title: title,
        icon: icon ?? CupertinoIcons.square_grid_2x2,
        onTap: () => Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: Text(title)),
              body: page,
            ),
          ),
        ),
      );
}
