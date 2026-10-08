import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/file/group_file_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// Source picker over authoritative workspace membership, never an all-org claim.
class WorkspaceAttachmentsPage extends ConsumerStatefulWidget {
  const WorkspaceAttachmentsPage({super.key});
  @override
  ConsumerState<WorkspaceAttachmentsPage> createState() =>
      _WorkspaceAttachmentsPageState();
}

class _WorkspaceAttachmentsPageState
    extends ConsumerState<WorkspaceAttachmentsPage> {
  String _keyword = '';
  @override
  Widget build(BuildContext context) {
    final t = context.t.attachmentManager;
    final ws = ref.watch(currentWorkspaceProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.allRegular,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.groupSource,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AppSpacing.verticalSmall,
                Text(t.enterpriseHint),
                AppSpacing.verticalSmall,
                Text(
                  t.enterpriseBoundary,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                AppSpacing.verticalRegular,
                CupertinoSearchTextField(
                  placeholder: t.searchGroupsHint,
                  onChanged: (value) =>
                      setState(() => _keyword = value.trim().toLowerCase()),
                ),
              ],
            ),
          ),
          Expanded(
            child: ws == null
                ? WorkspaceEmptyView(
                    icon: CupertinoIcons.folder,
                    title: t.title,
                    subtitle: context.t.workspace.emptyNoWorkspace,
                  )
                : _groups(ws.id),
          ),
        ],
      ),
    );
  }

  Widget _groups(String workspaceId) {
    final groups = ref.watch(workspaceGroupsProvider(workspaceId));
    return groups.when(
      loading: () => const WorkspaceLoadingView(),
      error: (error, _) => WorkspaceErrorView(
        message: workspaceErrorMessage(error),
        onRetry: () => ref.invalidate(workspaceGroupsProvider(workspaceId)),
      ),
      data: (items) {
        final visible = items
            .where((item) => item.displayTitle.toLowerCase().contains(_keyword))
            .toList();
        return RefreshIndicator(
          onRefresh: () async {
            final future = ref.refresh(
              workspaceGroupsProvider(workspaceId).future,
            );
            await future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (visible.isEmpty)
                Padding(
                  padding: AppSpacing.allRegular,
                  child: Text(context.t.workspace.groupsEmptyTitle),
                ),
              for (final group in visible)
                CupertinoListTile(
                  key: ValueKey('workspace-attachment-group-${group.groupId}'),
                  padding: AppSpacing.allRegular,
                  leading: const Icon(CupertinoIcons.folder),
                  title: Text(group.displayTitle),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => GroupFilePage(
                        groupId: group.groupId.toString(),
                        displayTitle: context.t.attachmentManager.title,
                        scopeHint: group.displayTitle,
                        readOnly: true,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
