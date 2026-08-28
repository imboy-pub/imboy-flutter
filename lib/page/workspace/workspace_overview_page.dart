/// T9 (WP5) — Workspace Overview 视图（导航枢纽，§4.2 IA）
///
/// 区块（后端 overview 端点有什么就展示什么）：
/// - 资源摘要：projects / groups / channels 计数（点击跳对应导航）
/// - Channel 置顶内容：overview 契约未提供 → 空态说明（I12：不聚合
///   Group Notice，Group 公告只属于群）
/// - 最近文件：overview 契约未提供 → 空态说明（附件在各频道内查看）
/// - 成员预览：member_preview（头像 + 昵称 + 角色徽标）
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_nav_items.dart';

class WorkspaceOverviewPage extends ConsumerWidget {
  const WorkspaceOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ws = ref.watch(currentWorkspaceProvider);
    final wsId = ws?.id ?? '';
    if (wsId.isEmpty) {
      return WorkspaceEmptyView(
        icon: CupertinoIcons.chart_bar_alt_fill,
        title: t.workspace.overviewTitle,
        subtitle: t.workspace.emptyNoWorkspace,
      );
    }
    final overview = ref.watch(workspaceOverviewProvider(wsId));
    return overview.when(
      loading: () => const WorkspaceLoadingView(),
      error: (e, _) => WorkspaceErrorView(
        message: workspaceErrorMessage(e),
        onRetry: () => ref.invalidate(workspaceOverviewProvider(wsId)),
      ),
      data: (data) => _OverviewBody(wsId: wsId, data: data),
    );
  }
}

class _OverviewBody extends ConsumerWidget {
  final EntityId wsId;
  final WorkspaceOverview data;

  const _OverviewBody({required this.wsId, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.allRegular,
      children: [
        WorkspaceSectionCard(
          title: t.workspace.overviewResources,
          child: Row(
            children: [
              Expanded(
                child: _CountTile(
                  key: const ValueKey('workspace-overview-projects'),
                  icon: CupertinoIcons.folder,
                  count: data.projectCount,
                  label: t.workspace.navProjects,
                  onTap: () => ref
                      .read(workspaceShellProvider.notifier)
                      .selectDestination(WorkspaceShellDestination.projects),
                ),
              ),
              Expanded(
                child: _CountTile(
                  key: const ValueKey('workspace-overview-groups'),
                  icon: CupertinoIcons.person_2,
                  count: data.groupCount,
                  label: t.workspace.navGroups,
                  onTap: () => ref
                      .read(workspaceShellProvider.notifier)
                      .selectDestination(WorkspaceShellDestination.groups),
                ),
              ),
              Expanded(
                child: _CountTile(
                  key: const ValueKey('workspace-overview-channels'),
                  icon: CupertinoIcons.antenna_radiowaves_left_right,
                  count: data.channelCount,
                  label: t.workspace.navChannels,
                  onTap: () => ref
                      .read(workspaceShellProvider.notifier)
                      .selectDestination(WorkspaceShellDestination.channels),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.verticalRegular,
        WorkspaceSectionCard(
          title: t.workspace.overviewPinnedContent,
          child: _pinnedEmptyHint(theme: theme),
        ),
        AppSpacing.verticalRegular,
        WorkspaceSectionCard(
          title: t.workspace.overviewRecentFiles,
          child: Text(
            t.workspace.overviewRecentFilesEmpty,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        AppSpacing.verticalRegular,
        WorkspaceSectionCard(
          title: t.workspace.membersTitle,
          child: _MemberPreview(members: data.memberPreview),
        ),
      ],
    );
  }

  Widget _pinnedEmptyHint({required ThemeData theme}) {
    // I12：Channel 置顶区块只承载频道置顶帖；Group Notice 不聚合进来。
    return Text(
      t.workspace.overviewPinnedEmpty,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 资源计数瓦片（点击切换到对应导航目的地）。
class _CountTile extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;

  const _CountTile({
    super.key,
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.small),
      child: Padding(
        padding: AppSpacing.allMedium,
        child: Column(
          children: [
            Icon(icon, size: 24, color: theme.colorScheme.primary),
            AppSpacing.verticalSmall,
            Text(
              count.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.verticalTiny,
            Text(
              label,
              // 计数副标签：脚注档 footnote（13px）
              style: TextStyle(
                fontSize: FontSizeType.footnote.size,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberPreview extends StatelessWidget {
  final List<WorkspaceMemberModel> members;

  const _MemberPreview({required this.members});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text(
        t.workspace.membersEmpty,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Wrap(
      spacing: AppSpacing.regular,
      runSpacing: AppSpacing.small,
      children: [
        for (final m in members.take(8))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: m.avatar.isNotEmpty
                    ? NetworkImage(m.avatar)
                    : null,
                child: m.avatar.isEmpty
                    ? Text(
                        m.nickname.isEmpty ? '?' : m.nickname.substring(0, 1),
                        // 头像占位字：超小档 tiny（10px）
                        style: TextStyle(
                          fontSize: FontSizeType.tiny.size,
                          color: AppColors.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              AppSpacing.horizontalSmall,
              Text(m.nickname.isEmpty ? m.account : m.nickname),
              AppSpacing.horizontalTiny,
              WorkspaceRoleBadge(role: m.role),
            ],
          ),
      ],
    );
  }
}
