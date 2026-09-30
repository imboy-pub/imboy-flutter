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
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/workspace/workspace_channels_page.dart';
import 'package:imboy/page/workspace/workspace_conversations_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_groups_page.dart';
import 'package:imboy/page/workspace/workspace_projects_page.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'workspace_account_menu.dart';
import 'workspace_shell_breakpoint.dart';
import 'workspace_shell_provider.dart';

enum _Destination { messages, contacts, workbench, mine }

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
  _Destination _selected = _Destination.messages;
  final _visited = <_Destination>{_Destination.messages};
  bool _channels = false;

  ({String accountKey, String organizationId}) get _scope =>
      (accountKey: widget.accountKey, organizationId: widget.organizationId);

  AsyncValue<List<EnterpriseOaRuntimeConfig>> _entries() {
    final supported =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return supported
        ? ref.watch(oaWorkbenchEntriesProvider(_scope))
        : const AsyncData<List<EnterpriseOaRuntimeConfig>>([]);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    final configs =
        entries is AsyncData<List<EnterpriseOaRuntimeConfig>> &&
            !entries.isLoading &&
            !entries.hasError
        ? entries.value.where((entry) => entry.runtimeEntryEnabled).toList()
        : const <EnterpriseOaRuntimeConfig>[];
    final destinations = [
      _Destination.messages,
      _Destination.contacts,
      if (configs.isNotEmpty) _Destination.workbench,
      _Destination.mine,
    ];
    if (!destinations.contains(_selected)) {
      _selected = _Destination.messages;
      _visited.remove(_Destination.workbench);
    }
    final labels = destinations.map(_label).toList();
    final icons = destinations.map(_icon).toList();
    final index = destinations.indexOf(_selected);
    void select(int value) => setState(() {
      _selected = destinations[value];
      _visited.add(_selected);
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

  String _label(_Destination destination) => switch (destination) {
    _Destination.messages => t.chat.titleMessage,
    _Destination.contacts => t.organization.directory.title,
    _Destination.workbench => t.enterpriseOa.workbenchTitle,
    _Destination.mine => t.common.me,
  };

  IconData _icon(_Destination destination) => switch (destination) {
    _Destination.messages => CupertinoIcons.chat_bubble,
    _Destination.contacts => CupertinoIcons.person_2,
    _Destination.workbench => CupertinoIcons.briefcase,
    _Destination.mine => CupertinoIcons.person_circle,
  };

  Widget _content(
    List<_Destination> destinations,
    List<EnterpriseOaRuntimeConfig> configs,
    AsyncValue<List<EnterpriseOaRuntimeConfig>> entries,
    int index,
    String title,
  ) {
    return Column(
      children: [
        if (_selected != _Destination.contacts)
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                const WorkspaceSwitcherChip(),
                Expanded(child: Center(child: Text(title))),
                const WorkspaceAccountButton(),
              ],
            ),
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
                      ? _page(destination, configs)
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _frame(
    List<_Destination> destinations,
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
                    icon: Icon(icons[i]),
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
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            ),
    );
  }

  Widget _page(
    _Destination destination,
    List<EnterpriseOaRuntimeConfig> configs,
  ) {
    switch (destination) {
      case _Destination.messages:
        return _messages();
      case _Destination.contacts:
        return HumanDirectoryBrowserPage(orgId: widget.organizationId);
      case _Destination.workbench:
        return EnterpriseWorkbenchPage(
          entries: configs,
          accountKey: widget.accountKey,
          organizationId: widget.organizationId,
        );
      case _Destination.mine:
        return _mine();
    }
  }

  Widget _messages() {
    return Column(
      children: [
        _messageFilter(),
        Expanded(
          child: IndexedStack(
            index: _channels ? 1 : 0,
            children: [
              WorkspaceConversationsPage(
                embedded: true,
                active: _selected == _Destination.messages && !_channels,
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

  Widget _messageFilter() => Padding(
    padding: AppSpacing.allSmall,
    child: CupertinoSlidingSegmentedControl<bool>(
      groupValue: _channels,
      children: {
        false: SizedBox(
          height: 44,
          child: Center(child: Text(t.chat.groupChat)),
        ),
        true: SizedBox(height: 44, child: Center(child: Text(t.channel.title))),
      },
      onValueChanged: (value) {
        if (value == null || value == _channels) return;
        setState(() => _channels = value);
        final id = ref.read(currentWorkspaceProvider)?.id ?? '';
        if (value && id.isNotEmpty) {
          ref.invalidate(workspaceChannelsProvider(id));
        }
      },
    ),
  );

  Widget _mine() {
    return Column(
      children: [
        CupertinoListSection.insetGrouped(
          children: [
            CupertinoListTile(
              title: Text(t.organization.manage.entry),
              trailing: const CupertinoListTileChevron(),
              onTap: () =>
                  context.push('/organization/${widget.organizationId}'),
            ),
            CupertinoListTile(
              title: Text(t.workspace.membersTitle),
              trailing: const CupertinoListTileChevron(),
              onTap: () => context.push('/workspace/members'),
            ),
            _resourceEntry(t.workspace.navGroups, const WorkspaceGroupsPage()),
            if (AppFeatureRegistry.isEnabled(FeatureKeys.project))
              _resourceEntry(
                t.workspace.navProjects,
                const WorkspaceProjectsPage(),
              ),
          ],
        ),
        const Expanded(child: MinePage()),
      ],
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
