/// WP6 (T10a) — 项目详情页（W0 版）
///
/// Scope Contract（Gate W=W0）：本页只有「基本信息 + 状态编辑 + 任务区块」；
/// Pinned / Resources / Activity / 关联 Channel / Project Members 全部
/// defer —— 无 tab、无区块、无空态占位（defer = 无 schema 无占位 UI）。
///
/// 权限（§1.4.2 W0）：Owner/Member 可写状态与任务；Guest 只读；可见性 =
/// active Workspace Member（服务端 403 兜底）。archived 工作区写操作禁用
/// （对齐 WP5 archived 横幅模式）+ 服务端 980 兜底。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/project_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart'
    show currentWorkspaceProvider;
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/page/workspace/project/tasks/project_tasks_view.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  final EntityId projectId;

  /// 路由携带的工作区 id（角色判定在成员列表加载完成前即可用）。
  final EntityId workspaceId;

  const ProjectDetailPage({
    super.key,
    required this.projectId,
    this.workspaceId = '',
  });

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  bool _mutating = false;

  /// 当前用户在工作区的角色（active 成员列表推导；无记录 → 只读兜底）。
  WorkspaceMemberRole? _myRole(List<WorkspaceMemberModel> members) {
    final myUid = UserRepoLocal.to.currentUid;
    for (final m in members) {
      if (m.userId == myUid) return m.role;
    }
    return null;
  }

  /// 状态切换写操作统一入口：防抖 + 成功 toast + 失败透传服务端消息。
  Future<void> _changeStatus(ProjectModel project, ProjectStatus to) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await ref.read(projectApiProvider).updateStatus(project.id, to);
      ref.invalidate(projectDetailProvider(project.id));
      ref.invalidate(projectListPageProvider((project.workspaceId, 1)));
      if (!mounted) return;
      AppLoading.showSuccess(context.t.workspace.projectStatusChanged);
    } on WorkspaceApiException catch (e) {
      if (mounted) AppLoading.showBackendError(e.message);
    } catch (e) {
      if (mounted) AppLoading.showError(e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final projectAsync = ref.watch(projectDetailProvider(widget.projectId));
    final wsId = widget.workspaceId;
    final membersAsync = wsId.isEmpty
        ? null
        : ref.watch(assigneeCandidatesProvider(wsId));

    // archived 横幅跟随壳内当前工作区状态（与 WP5 members 页同源判定）
    final currentWs = ref.watch(currentWorkspaceProvider);
    final archived =
        currentWs != null && currentWs.id == wsId && currentWs.isArchived;

    return Scaffold(
      appBar: AppBar(title: Text(t.workspace.projectDetailTitle)),
      body: Column(
        children: [
          if (archived) const WorkspaceArchivedBanner(),
          Expanded(
            child: projectAsync.when(
              loading: () => const WorkspaceLoadingView(),
              error: (e, _) => WorkspaceErrorView(
                message: workspaceErrorMessage(e),
                onRetry: () =>
                    ref.invalidate(projectDetailProvider(widget.projectId)),
              ),
              data: (project) {
                final myRole = membersAsync?.whenOrNull(
                  data: (members) => _myRole(members),
                );
                // W0 可见性/可写性：Guest 只读；角色未知（成员列表未就绪）
                // 时保守只读；archived 一律禁写。
                final writable =
                    !archived &&
                    myRole != null &&
                    myRole != WorkspaceMemberRole.guest;
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(projectDetailProvider(widget.projectId)),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppSpacing.allRegular,
                    children: [
                      _InfoCard(
                        project: project,
                        ownerName: _memberName(
                          membersAsync?.value,
                          project.ownerId,
                        ),
                        myRole: myRole,
                      ),
                      AppSpacing.verticalRegular,
                      _StatusCard(
                        project: project,
                        writable: writable,
                        mutating: _mutating,
                        onChangeStatus: (to) => _changeStatus(project, to),
                      ),
                      AppSpacing.verticalRegular,
                      ProjectTasksSection(project: project, writable: writable),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String? _memberName(List<WorkspaceMemberModel>? members, EntityId userId) {
    if (members == null || userId.isEmpty) return null;
    for (final m in members) {
      if (m.userId == userId)
        return m.nickname.isEmpty ? m.account : m.nickname;
    }
    return null;
  }
}

/// 基本信息卡：name / description / 负责人（owner 昵称）/ 时间。
/// W0 无成员区块——负责人只是归属展示，不构成成员管理 UI。
class _InfoCard extends StatelessWidget {
  final ProjectModel project;
  final String? ownerName;
  final WorkspaceMemberRole? myRole;

  const _InfoCard({required this.project, this.ownerName, this.myRole});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    return Container(
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.regular),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.folder, size: 22),
              AppSpacing.horizontalSmall,
              Expanded(
                child: Text(
                  project.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (project.description.isNotEmpty) ...[
            AppSpacing.verticalSmall,
            Text(
              project.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          AppSpacing.verticalSmall,
          Wrap(
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.tiny,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (myRole != null) WorkspaceRoleBadge(role: myRole!),
              Text(
                '${t.workspace.projectStatusLabel}: ${project.status == ProjectStatus.done ? t.workspace.projectStatusDone : t.workspace.projectStatusActive}',
                style: theme.textTheme.bodySmall,
              ),
              if (ownerName != null && ownerName!.isNotEmpty)
                Text(
                  '${t.workspace.projectOwnerLabel}: $ownerName',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 状态卡：active⇄done 切换按钮（writable=false 时整卡隐藏——Guest 只读，
/// archived 由外层横幅 + 按钮 disabled 双保险）。
class _StatusCard extends StatelessWidget {
  final ProjectModel project;
  final bool writable;
  final bool mutating;
  final void Function(ProjectStatus to) onChangeStatus;

  const _StatusCard({
    required this.project,
    required this.writable,
    required this.mutating,
    required this.onChangeStatus,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (!writable) return const SizedBox.shrink();
    return WorkspaceSectionCard(
      title: t.workspace.projectStatusLabel,
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              key: ValueKey('project-status-toggle-${project.status.wireName}'),
              onPressed: mutating
                  ? null
                  : () {
                      onChangeStatus(
                        project.status == ProjectStatus.done
                            ? ProjectStatus.active
                            : ProjectStatus.done,
                      );
                    },
              icon: Icon(
                project.status == ProjectStatus.done
                    ? CupertinoIcons.arrow_counterclockwise
                    : CupertinoIcons.checkmark_circle,
                size: 18,
              ),
              label: Text(
                project.status == ProjectStatus.done
                    ? t.workspace.projectReopen
                    : t.workspace.projectMarkDone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
