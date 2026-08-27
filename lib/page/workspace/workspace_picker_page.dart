/// T8/T9 (WP5) — 工作区切换器（我的工作区列表）
///
/// 壳顶栏点击当前工作区名进入；选中后回壳并从 Overview 开始
/// （不同 branding 的工作区切换时主题各自生效，T12）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            )
          : ListView.separated(
              padding: AppSpacing.allRegular,
              itemCount: shell.workspaces.length,
              separatorBuilder: (_, _) => AppSpacing.verticalSmall,
              itemBuilder: (context, index) {
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
