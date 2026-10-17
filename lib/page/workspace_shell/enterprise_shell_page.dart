import 'package:imboy/app_core/feature_flags/feature_revision_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_oa/public.dart';
import 'package:imboy/modules/organization/public.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_entry.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_conversations_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/modules/attachments/workspace_attachments_page.dart';
import 'package:imboy/page/workspace/workspace_projects_page.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace/workspace_group_agenda_views.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/workspace_shell/workspace_drawer_menu.dart';
import 'package:imboy/page/workspace_shell/workspace_message_filter.dart';
import 'package:imboy/page/workspace_shell/workspace_message_toolbar.dart';
import 'package:imboy/page/workspace_shell/workspace_plus_menu.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/ui/badge_widget.dart';

// WorkspaceSwitcherChip 定义于此（账号 Sheet 文件）；会话页 standalone
// 模式仍在使用。
import 'workspace_shell_breakpoint.dart';
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
/// 拍板）；左上汉堡按钮唤起深蓝抽屉（身份/我的名片/企业带/高级功能/
/// 创建加入企业/设置/切换到个人/退出登录）；消息 tab 顶部挂内容态
/// tab（筛选/日程/待办），日程·待办聚合企业群数据。
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
    final desktop =
        resolveWorkspaceShellLayout(MediaQuery.sizeOf(context).width) ==
        WorkspaceShellLayout.desktop;
    return _frame(
      destinations,
      labels,
      icons,
      index,
      desktop,
      select,
      _content(destinations, configs, entries, index, labels[index]),
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
        button: true,
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
  ) {
    return Column(
      children: [
        WorkspaceTopBar(
          title: title,
          leading: _selected == EnterpriseShellDestination.messages
              ? const _ShellMenuButton()
              : null,
          actions: switch (_selected) {
            EnterpriseShellDestination.messages => const [
              WorkspacePlusButton(),
            ],
            EnterpriseShellDestination.contacts => [_inviteColleaguesAction()],
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
    bool desktop,
    ValueChanged<int> select,
    Widget content,
  ) {
    return Scaffold(
      drawer: WorkspaceDrawerMenu(organizationId: widget.organizationId),
      body: Row(
        children: [
          if (desktop)
            NavigationRail(
              key: const ValueKey('enterprise-shell-rail'),
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
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              key: const ValueKey('enterprise-shell-bottom-nav'),
              selectedIndex: index,
              onDestinationSelected: select,
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(
                    icon: _navigationIcon(destinations[i], icons[i]),
                    label: labels[i],
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
    final workspace = ref.watch(currentWorkspaceProvider)?.id ?? '';
    final rows = workspace.isEmpty
        ? null
        : ref.watch(workspaceConversationsProvider(workspace));
    final count = rows == null || rows.isLoading || rows.hasError
        ? 0
        : (rows.asData?.value ?? []).fold<int>(
            0,
            (total, row) => total + row.unreadCount,
          );
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
            const CsWorkspaceEntryTile(),
            if (ref.watch(currentWorkspaceProvider) != null) ...[
              if (AppFeatureRegistry.isEnabled(FeatureKeys.project))
                _resourceEntry(
                  t.workspace.navProjects,
                  const WorkspaceProjectsPage(),
                ),
              _resourceEntry(
                t.workspace.navGroups,
                const WorkspaceGroupsPage(),
              ),
              _resourceEntry(t.channel.title, const WorkspaceChannelsPage()),
              _resourceEntry(
                t.attachmentManager.title,
                const WorkspaceAttachmentsPage(),
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
      enterpriseEntry: CupertinoListTile(
        key: const ValueKey('enterprise-mine-organization-entry'),
        leading: const Icon(CupertinoIcons.building_2_fill),
        title: Text(
          canManage ? t.organization.manage.entry : t.organization.home.tabOrg,
        ),
        trailing: const CupertinoListTileChevron(),
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
          onTabChanged: (tab) => setState(() => _messageTab = tab),
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

  Widget _resourceEntry(String title, Widget page) => CupertinoListTile(
    title: Text(title),
    trailing: const CupertinoListTileChevron(),
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

/// 左上角汉堡按钮：唤起企业抽屉（参考稿①）。
///
/// 图标为参考稿的两杠不等长样式（上长下短），比三点/三杠更轻盈；
/// Scaffold.of 依赖本按钮元素位于 Scaffold 子树内。
class _ShellMenuButton extends StatelessWidget {
  const _ShellMenuButton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    return CupertinoButton(
      key: const ValueKey('enterprise-shell-menu-button'),
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: () => Scaffold.of(context).openDrawer(),
      child: Semantics(
        label: t.common.buttonMore,
        button: true,
        child: SizedBox(
          width: 22,
          height: 22,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18,
                height: 2,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 12,
                height: 2,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
