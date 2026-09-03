/// T8/T9 (WP5) — 工作区切换器（我的工作区列表）
///
/// 壳顶栏点击当前工作区名进入；选中后回壳并从 Overview 开始
/// （不同 branding 的工作区切换时主题各自生效，T12）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspacePickerPage extends ConsumerWidget {
  const WorkspacePickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final shell = ref.watch(workspaceShellProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.workspace.pickerTitle)),
      body: shell.isLoading && !shell.hasWorkspace
          ? const WorkspaceLoadingView()
          : shell.error != null && !shell.hasWorkspace
          ? WorkspaceErrorView(
              message: shell.error!,
              onRetry: () =>
                  ref.read(workspaceShellProvider.notifier).loadMine(),
            )
          : shell.workspaces.isEmpty
          ? WorkspaceEmptyView(
              icon: CupertinoIcons.rectangle_stack,
              title: t.workspace.pickerEmptyTitle,
              subtitle: t.workspace.pickerEmptySubtitle,
              actions: [
                FilledButton.tonalIcon(
                  key: const ValueKey('workspace-picker-empty-create-entry'),
                  onPressed: () => context.push('/workspace/create'),
                  icon: const Icon(CupertinoIcons.add),
                  label: Text(t.workspace.createEntry),
                ),
                AppSpacing.verticalSmall,
                OutlinedButton.icon(
                  key: const ValueKey('workspace-picker-empty-join-entry'),
                  onPressed: () => context.push('/workspace/join'),
                  icon: const Icon(CupertinoIcons.person_add),
                  label: Text(t.workspace.joinEntry),
                ),
              ],
            )
          : ListView.separated(
              padding: AppSpacing.allRegular,
              // 列表项 + 底部常驻「创建/加入」双入口 footer（Slack 模式）。
              itemCount: shell.workspaces.length + 2,
              separatorBuilder: (_, _) => AppSpacing.verticalSmall,
              itemBuilder: (context, index) {
                if (index == shell.workspaces.length) {
                  return _PickerActionTile(
                    key: const ValueKey('workspace-picker-create-entry'),
                    icon: CupertinoIcons.add,
                    label: t.workspace.createEntry,
                    onTap: () => context.push('/workspace/create'),
                  );
                }
                if (index == shell.workspaces.length + 1) {
                  return _PickerActionTile(
                    key: const ValueKey('workspace-picker-join-entry'),
                    icon: CupertinoIcons.person_add,
                    label: t.workspace.joinEntry,
                    onTap: () => context.push('/workspace/join'),
                  );
                }
                final ws = shell.workspaces[index];
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
                  ? NetworkImage(ws.logo)
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
