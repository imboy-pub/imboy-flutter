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
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_conversations_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/modules/attachments/workspace_attachments_page.dart';
import 'package:imboy/page/workspace/workspace_projects_page.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/ui/badge_widget.dart';

// WorkspaceSwitcherChip 定义于此（账号 Sheet 文件）；顶栏左侧切换 chip
// 仍需要它，APP-M02 只移除了右上角 WorkspaceAccountButton 的引用。
import 'workspace_account_menu.dart';
import 'workspace_shell_breakpoint.dart';
import 'workspace_segment_switcher.dart';
import 'workspace_shell_provider.dart';
import 'workspace_top_bar.dart';

final _mineOrganizationProvider = FutureProvider.autoDispose
    .family<Organization, ({String accountKey, String organizationId})>(
      (ref, scope) =>
          ref.watch(organizationApiProvider).detail(scope.organizationId),
    );

/// 企业主导航。Key 由宿主绑定账号、企业及工作区，切换时销毁旧页面。
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
  bool _channels = false;
  bool _configurationReady = false;

  @override
  void initState() {
    super.initState();
    final navigation = ref.read(workspaceShellProvider).enterpriseNavigation;
    _selected = navigation.destination;
    _channels = navigation.channels;
    _visited.add(_selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(oaWorkbenchEntriesProvider(_scope));
      setState(() => _configurationReady = true);
    });
  }

  void _rememberNavigation() =>
      ref.read(workspaceShellProvider.notifier).rememberEnterpriseNavigation((
        destination: _selected,
        channels: _channels,
      ));

  ({String accountKey, String organizationId}) get _scope =>
      (accountKey: widget.accountKey, organizationId: widget.organizationId);

  AsyncValue<List<EnterpriseOaRuntimeConfig>> _entries() {
    final supported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!supported) return const AsyncData<List<EnterpriseOaRuntimeConfig>>([]);
    return _configurationReady
        ? ref.watch(oaWorkbenchEntriesProvider(_scope))
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
        EnterpriseShellDestination.workbench => CupertinoIcons.briefcase,
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
          leading: const WorkspaceSwitcherChip(),
          // APP-M02 邀请同事：右上角不再展示当前用户头像（账号/退出入口
          // 收敛在「我」页 → 设置）；通讯录 Tab 右上角挂「邀请同事」入口。
          actions: _selected == EnterpriseShellDestination.contacts
              ? [_inviteColleaguesAction()]
              : null,
        ),
        if (ref.watch(currentWorkspaceProvider)?.isArchived ?? false)
          const WorkspaceArchivedBanner(),
        if (entries.hasError)
          CupertinoListTile(
            title: Text(t.enterpriseOa.statusErrorTitle),
            trailing: CupertinoButton(
              onPressed: () =>
                  ref.invalidate(oaWorkbenchEntriesProvider(_scope)),
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
      case EnterpriseShellDestination.contacts:
        return HumanDirectoryBrowserPage(
          orgId: widget.organizationId,
          orgName:
              ref.watch(_mineOrganizationProvider(_scope)).asData?.value.name ??
              '',
          embedded: true,
        );
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
      case EnterpriseShellDestination.mine:
        return _mine();
    }
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
        _messageFilter(),
        Expanded(
          child: IndexedStack(
            index: _channels ? 1 : 0,
            children: [
              WorkspaceConversationsPage(
                embedded: true,
                active: active && !_channels,
              ),
              if (_channels)
                const WorkspaceChannelsPage()
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _messageFilter() => WorkspaceSegmentSwitcher(
    value: _channels,
    offLabel: t.chat.groupChat,
    onLabel: t.channel.title,
    onChanged: (value) {
      setState(() => _channels = value);
      _rememberNavigation();
      final id = ref.read(currentWorkspaceProvider)?.id ?? '';
      if (value && id.isNotEmpty) {
        ref.invalidate(workspaceChannelsProvider(id));
      }
    },
  );

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
