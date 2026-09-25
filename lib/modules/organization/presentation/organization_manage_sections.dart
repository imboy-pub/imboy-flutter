/// ENT-APP-06 — 企业管理页「群与频道」资源区（从 organization_manage_page
/// 等价拆出，保持文件 < 800 行与既有测试锚点 key）。
///
/// 本组件只做展示与动作分发；权限与数据事实由宿主页注入（宿主页口径：
/// 群/频道动作权限 = 群主/创建者**或**本企业 owner/admin（GZAPP-03 双授权
/// 源），客户端不区分，失败按服务端文案透出）。
///
/// ENT-APP-06 新增闭包：
/// - 群行：重命名（group/edit title）+ 成员与角色（深链既有群详情页）+
///   解散（既有）；
/// - 频道行：重命名/管理员/订阅者（深链既有 channel 子路由）+ 归档（既有）；
///   归档频道行保留恢复入口（既有）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 资源区子标题行（标题 + 可选动作按钮）。
class OrgManageSubHeader extends StatelessWidget {
  const OrgManageSubHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (actionLabel != null)
            TextButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// 企业群块：每行菜单 = 重命名 / 成员与角色（深链群详情）/ 解散。
class OrgManageGroupBlock extends StatelessWidget {
  const OrgManageGroupBlock({
    super.key,
    required this.groups,
    required this.onCreate,
    required this.onRename,
    required this.onOpenDetail,
    required this.onDissolve,
  });

  final List<GroupModel> groups;
  final VoidCallback onCreate;
  final void Function(GroupModel g) onRename;
  final void Function(GroupModel g) onOpenDetail;
  final void Function(GroupModel g) onDissolve;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrgManageSubHeader(
          title: t.organization.manage.groupSection,
          actionLabel: t.organization.manage.createGroup,
          actionKey: const ValueKey('org-manage-create-group'),
          onAction: onCreate,
        ),
        if (groups.isEmpty)
          ListTile(title: Text(t.organization.manage.groupEmpty))
        else
          for (final g in groups)
            ListTile(
              key: ValueKey('org-manage-group-${g.groupId}'),
              leading: const Icon(CupertinoIcons.person_2),
              title: Text(
                g.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                t.organization.manage.groupMembers(count: g.memberCount),
              ),
              trailing: _groupMenu(context, g),
            ),
      ],
    );
  }

  Widget _groupMenu(BuildContext context, GroupModel g) =>
      PopupMenuButton<String>(
        key: ValueKey('org-manage-group-menu-${g.groupId}'),
        tooltip: t.organization.common.moreActions,
        onSelected: (value) {
          switch (value) {
            case 'rename':
              onRename(g);
            case 'govern':
              onOpenDetail(g);
            case 'dissolve':
              onDissolve(g);
          }
        },
        itemBuilder: (_) => _groupMenuItems(context, g),
      );

  List<PopupMenuEntry<String>> _groupMenuItems(
    BuildContext context,
    GroupModel g,
  ) => [
    PopupMenuItem<String>(
      key: ValueKey('org-manage-rename-${g.groupId}'),
      value: 'rename',
      child: Text(t.organization.manage.renameGroup),
    ),
    PopupMenuItem<String>(
      key: ValueKey('org-manage-govern-${g.groupId}'),
      value: 'govern',
      child: Text(t.organization.manage.groupGovernance),
    ),
    PopupMenuItem<String>(
      key: ValueKey('org-manage-dissolve-${g.groupId}'),
      value: 'dissolve',
      child: Text(
        t.organization.manage.dissolveGroup,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  ];
}

/// 企业频道块：活动频道菜单 = 重命名 / 管理员 / 订阅者 / 归档；
/// 归档频道保留恢复入口（原锚点 key 不变）。
class OrgManageChannelBlock extends StatelessWidget {
  const OrgManageChannelBlock({
    super.key,
    required this.activeChannels,
    required this.archivedChannels,
    required this.onCreate,
    required this.onRename,
    required this.onOpenAdmins,
    required this.onOpenSubscribers,
    required this.onArchive,
    required this.onRestore,
  });

  final List<ChannelModel> activeChannels;
  final List<ChannelModel> archivedChannels;
  final VoidCallback onCreate;
  final void Function(ChannelModel c) onRename;
  final void Function(ChannelModel c) onOpenAdmins;
  final void Function(ChannelModel c) onOpenSubscribers;
  final void Function(ChannelModel c) onArchive;
  final void Function(ChannelModel c) onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrgManageSubHeader(
          title: t.organization.manage.channelSection,
          actionLabel: t.organization.manage.createChannel,
          actionKey: const ValueKey('org-manage-create-channel'),
          onAction: onCreate,
        ),
        ListTile(
          dense: true,
          leading: const Icon(CupertinoIcons.info),
          title: Text(t.organization.manage.channelPolicyNote),
        ),
        if (activeChannels.isEmpty)
          ListTile(title: Text(t.organization.manage.channelEmpty))
        else
          for (final c in activeChannels)
            ListTile(
              key: ValueKey('org-manage-channel-${c.id}'),
              leading: const Icon(CupertinoIcons.speaker_3),
              title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                t.organization.manage.channelSubscribers(
                  count: c.subscriberCount,
                ),
              ),
              trailing: _channelMenu(context, c),
            ),
        if (archivedChannels.isNotEmpty) ...[
          const Divider(),
          OrgManageSubHeader(
            title: t.organization.manage.archivedChannelSection,
          ),
          for (final c in archivedChannels)
            ListTile(
              key: ValueKey('org-manage-archived-channel-${c.id}'),
              leading: Icon(
                CupertinoIcons.archivebox,
                color: Theme.of(context).disabledColor,
              ),
              title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(t.organization.manage.archivedBadge),
              trailing: TextButton(
                key: ValueKey('org-manage-restore-${c.id}'),
                onPressed: () => onRestore(c),
                child: Text(t.organization.manage.restoreChannel),
              ),
            ),
        ],
      ],
    );
  }

  Widget _channelMenu(BuildContext context, ChannelModel c) =>
      PopupMenuButton<String>(
        key: ValueKey('org-manage-channel-menu-${c.id}'),
        tooltip: t.organization.common.moreActions,
        onSelected: (value) {
          switch (value) {
            case 'rename':
              onRename(c);
            case 'admins':
              onOpenAdmins(c);
            case 'subscribers':
              onOpenSubscribers(c);
            case 'archive':
              onArchive(c);
          }
        },
        itemBuilder: (_) => _channelMenuItems(context, c),
      );

  List<PopupMenuEntry<String>> _channelMenuItems(
    BuildContext context,
    ChannelModel c,
  ) => [
    PopupMenuItem<String>(
      key: ValueKey('org-manage-channel-rename-${c.id}'),
      value: 'rename',
      child: Text(t.organization.manage.renameChannel),
    ),
    PopupMenuItem<String>(
      key: ValueKey('org-manage-channel-admins-${c.id}'),
      value: 'admins',
      child: Text(t.organization.manage.channelAdmins),
    ),
    PopupMenuItem<String>(
      key: ValueKey('org-manage-channel-subscribers-${c.id}'),
      value: 'subscribers',
      child: Text(t.organization.manage.channelSubscribersEntry),
    ),
    PopupMenuItem<String>(
      key: ValueKey('org-manage-archive-${c.id}'),
      value: 'archive',
      child: Text(
        t.organization.manage.archiveChannel,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  ];
}
