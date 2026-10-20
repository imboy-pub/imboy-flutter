/// T8/T9 (WP5) — 工作区切换器（我的工作区列表）
///
/// 壳顶栏点击当前工作区名进入；选中后回壳并从 Overview 开始
/// （不同 branding 的工作区切换时主题各自生效，T12）。
///
/// GZAPP-04 G9：本页降级为**企业上下文内部**的 WS 切换——顶部企业行
/// 展示当前企业（点击 → /organization/picker 企业选择器，数据源
/// Organization membership）。WS 列表按当前企业过滤：服务端 mine 行
/// 已带 organization_id，有企业指针时只显示该企业的工作区；指针缺失
/// （未加入任何企业）时维持全量已加入列表（个人域模式）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/helper/func.dart' show avatarImageProvider;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 当前账号的企业指针（无存储环境 / 未登录 → null；部分 widget 测试
/// 环境无存储，回落占位展示）。页面过滤与顶部企业行共用。
CurrentOrganizationStore? _currentOrgStore() {
  try {
    final uid = UserRepoLocal.to.currentUid;
    if (uid.isEmpty) return null;
    return CurrentOrganizationStore.forAccount(uid);
  } on Object {
    return null;
  }
}

class WorkspacePickerPage extends ConsumerWidget {
  const WorkspacePickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final shell = ref.watch(workspaceShellProvider);
    final org = _currentOrgStore()?.value;
    final visible = org == null
        ? shell.workspaces
        : shell.workspaces.where((ws) => ws.belongsToOrg(org.id)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(t.workspace.pickerTitle)),
      // GZAPP-04：顶部企业行常驻（企业切换入口，§5.1「切换企业」语义）。
      body: Column(
        children: [
          const _OrgContextTile(),
          Expanded(
            child: shell.isLoading && !shell.hasWorkspace
                ? const WorkspaceLoadingView()
                : shell.error != null && !shell.hasWorkspace
                ? WorkspaceErrorView(
                    message: shell.error!,
                    onRetry: () =>
                        ref.read(workspaceShellProvider.notifier).loadMine(),
                  )
                : visible.isEmpty
                ? WorkspaceEmptyView(
                    icon: CupertinoIcons.rectangle_stack,
                    title: t.workspace.pickerEmptyTitle,
                    subtitle: t.workspace.pickerEmptySubtitle,
                    actions: [
                      FilledButton.tonalIcon(
                        key: const ValueKey(
                          'workspace-picker-empty-create-entry',
                        ),
                        onPressed: () => context.push('/workspace/create'),
                        icon: const Icon(CupertinoIcons.add),
                        label: Text(t.workspace.createEntry),
                      ),
                      // 「加入企业」入口不在本页：顶部企业行「切换企业」
                      // → 企业选择器常驻承接（§5.1 单一入口）。
                    ],
                  )
                : ListView.separated(
                    padding: AppSpacing.allRegular,
                    // 列表项 + 底部常驻「创建工作区」入口 footer。
                    itemCount: visible.length + 1,
                    separatorBuilder: (_, _) => AppSpacing.verticalSmall,
                    itemBuilder: (context, index) {
                      if (index == visible.length) {
                        return _PickerActionTile(
                          key: const ValueKey('workspace-picker-create-entry'),
                          icon: CupertinoIcons.add,
                          label: t.workspace.createEntry,
                          onTap: () => context.push('/workspace/create'),
                        );
                      }
                      final ws = visible[index];
                      return _WorkspaceTile(
                        ws: ws,
                        selected: ws.id == shell.currentWorkspaceId,
                        onTap: () {
                          ref
                              .read(workspaceShellProvider.notifier)
                              .selectWorkspace(ws.id);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 企业上下文行：当前企业名 + 「切换企业」入口（点击打开企业选择器；
/// 指针缺失时显示占位，仍可进入选择器加入/切换企业）。
class _OrgContextTile extends StatelessWidget {
  const _OrgContextTile();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final org = _currentOrgStore()?.value;
    return ListTile(
      key: const ValueKey('workspace-picker-org-context'),
      dense: true,
      leading: Icon(
        CupertinoIcons.building_2_fill,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        org == null || org.name.isEmpty
            ? t.organization.picker.noneSelected
            : org.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.organization.experienceUi.switchSpace,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      onTap: () => context.push(kOrganizationPickerPath),
    );
  }
}

class _WorkspaceTile extends StatelessWidget {
  final WorkspaceModel ws;
  final bool selected;
  final VoidCallback onTap;

  const _WorkspaceTile({
    required this.ws,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: ValueKey('workspace-picker-tile-${ws.id}'),
      borderRadius: BorderRadius.circular(AppSpacing.regular),
      onTap: onTap,
      child: Container(
        padding: AppSpacing.allRegular,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.regular),
          border: selected
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: ws.logo.isNotEmpty
                  ? avatarImageProvider(ws.logo)
                  : null,
              child: ws.logo.isEmpty
                  ? Text(
                      ws.name.isEmpty ? '?' : ws.name.substring(0, 1),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            AppSpacing.horizontalRegular,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ws.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (ws.isArchived)
                    Text(
                      context.t.workspace.archivedBadge,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(CupertinoIcons.check_mark, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

/// 底部常驻动作入口 tile（创建/加入工作区），样式对齐 [_WorkspaceTile]。
class _PickerActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.regular),
      onTap: onTap,
      child: Container(
        padding: AppSpacing.allRegular,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.regular),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            AppSpacing.horizontalRegular,
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
