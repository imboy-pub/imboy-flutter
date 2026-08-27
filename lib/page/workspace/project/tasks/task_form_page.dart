/// WP6 (T10b) — 任务创建 / 编辑表单（title + assignee 选择）
///
/// assignee 候选 = active Workspace Member（W0 硬约束，服务端 members
/// 接口只返回 active 关系；非成员指派由服务端 400 拒绝并把消息透出到
/// toast）。候选来自 [assigneeCandidatesProvider]，支持「刷新候选」——
/// 成员变化后 invalidate 即拉取最新工作区成员。
///
/// 编辑模式：路由只带 taskId 时，经 [projectTaskDetailProvider] 加载既有行
/// 后填充表单（加载失败显示错误态 + 重试）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/store/model/project_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart'
    show WorkspaceErrorView, WorkspaceLoadingView, workspaceErrorMessage;
import 'package:imboy/page/workspace/project/project_data_providers.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class TaskFormPage extends ConsumerStatefulWidget {
  final EntityId projectId;
  final EntityId workspaceId;

  /// 编辑目标任务 id（非空 = 编辑模式，内部异步加载）。
  final EntityId taskId;

  /// 直接传入的既有任务（测试/同栈导航快捷入口；优先于 [taskId] 加载）。
  final ProjectTaskModel? task;

  const TaskFormPage({
    super.key,
    required this.projectId,
    required this.workspaceId,
    this.taskId = '',
    this.task,
  });

  @override
  ConsumerState<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends ConsumerState<TaskFormPage> {
  final TextEditingController _titleCtrl = TextEditingController();
  bool _submitting = false;

  /// 是否已按加载到的既有任务初始化过表单（只做一次，防 invalidate 重置输入）。
  bool _initializedFromTask = false;

  /// 选中的 assignee；null = 未指派（编辑保存时发 clearAssignee=true）。
  EntityId? _assigneeId;

  bool get _isEdit => widget.task != null || widget.taskId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) _applyTask(widget.task!);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _applyTask(ProjectTaskModel task) {
    if (_initializedFromTask) return;
    _initializedFromTask = true;
    _titleCtrl.text = task.title;
    _assigneeId = task.hasAssignee ? task.assigneeId : null;
  }

  Future<void> _submit(ProjectTaskModel? existing) async {
    final t = context.t;
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      AppLoading.showError(t.workspace.taskTitleRequired);
      return;
    }
    if (_submitting) return; // 防抖：重复点击只提交一次
    setState(() => _submitting = true);
    try {
      final api = ref.read(projectApiProvider);
      if (existing == null) {
        final result = await api.createTask(
          projectId: widget.projectId,
          title: title,
          assigneeId: _assigneeId,
        );
        if (!mounted) return;
        AppLoading.showSuccess(
          result.isIdempotentHit
              ? t.workspace.taskExistingToast
              : t.workspace.taskCreatedToast,
        );
      } else {
        await api.updateTask(
          existing.id,
          title: title,
          // 未选择 → 清除指派（assignee_id=null）；已选 → 指派该成员
          clearAssignee: _assigneeId == null,
          assigneeId: _assigneeId,
        );
        if (!mounted) return;
        AppLoading.showSuccess(t.workspace.taskUpdatedToast);
      }
      ref.invalidate(projectTasksProvider(widget.projectId));
      ref.invalidate(assigneeCandidatesProvider(widget.workspaceId));
      if (!mounted) return;
      // 同上：无路由栈时跳过返回
      if (context.canPop()) context.pop();
    } on WorkspaceApiException catch (e) {
      // 服务端消息原样透出：400 标题校验 / 非 active 成员指派 /
      // 403 Guest / 980 归档。禁止静默失败。
      if (mounted) AppLoading.showBackendError(e.message);
    } catch (e) {
      if (mounted) AppLoading.showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);

    // autoDispose family 页面级 watch 保活；进入表单即取当前 active 成员，
    // 「刷新候选」按钮 invalidate 后重拉（成员变化后候选即时更新）。
    final candidatesAsync = ref.watch(
      assigneeCandidatesProvider(widget.workspaceId),
    );

    Widget body;
    ProjectTaskModel? existing;
    if (widget.task != null) {
      body = _buildForm(context, candidatesAsync, widget.task);
      existing = widget.task;
    } else if (!_isEdit) {
      body = _buildForm(context, candidatesAsync, null);
    } else {
      // 编辑模式：taskId 异步加载既有任务行
      final taskAsync = ref.watch(projectTaskDetailProvider(widget.taskId));
      existing = taskAsync.value;
      if (existing != null) _applyTask(existing);
      body = taskAsync.when(
        loading: () => const WorkspaceLoadingView(),
        error: (e, _) => WorkspaceErrorView(
          message: workspaceErrorMessage(e),
          onRetry: () =>
              ref.invalidate(projectTaskDetailProvider(widget.taskId)),
        ),
        data: (task) => _buildForm(context, candidatesAsync, task),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? t.workspace.taskFormEditTitle
              : t.workspace.taskFormCreateTitle,
        ),
        actions: [
          IconButton(
            key: const ValueKey('task-assignee-refresh'),
            tooltip: t.workspace.taskAssigneeRefresh,
            icon: const Icon(CupertinoIcons.refresh),
            onPressed: () =>
                ref.invalidate(assigneeCandidatesProvider(widget.workspaceId)),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.allRegular,
        children: [
          TextField(
            key: const ValueKey('task-title-field'),
            controller: _titleCtrl,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: t.workspace.taskTitleLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          AppSpacing.verticalRegular,
          Text(
            t.workspace.taskAssigneeLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.verticalTiny,
          body,
          AppSpacing.verticalRegular,
          FilledButton(
            key: const ValueKey('task-form-submit'),
            onPressed: _submitting ? null : () => _submit(existing),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isEdit
                        ? t.workspace.taskSubmitSave
                        : t.workspace.taskSubmitCreate,
                  ),
          ),
        ],
      ),
    );
  }

  /// 候选下拉（active Workspace Member）；旧 assignee 不在候选中时保留其
  /// ID 兜底行（不静默丢弃用户数据——服务端保存时会做 active 校验兜底）。
  Widget _buildForm(
    BuildContext context,
    AsyncValue<List<WorkspaceMemberModel>> candidatesAsync,
    ProjectTaskModel? task,
  ) {
    var members = candidatesAsync.value ?? const <WorkspaceMemberModel>[];
    final currentAssignee = _assigneeId ?? '';
    if (currentAssignee.isNotEmpty &&
        !members.any((m) => m.userId == currentAssignee)) {
      members = [
        ...members,
        WorkspaceMemberModel(
          workspaceId: widget.workspaceId,
          userId: currentAssignee,
          role: WorkspaceMemberRole.member,
        ),
      ];
    }
    if (members.isEmpty && candidatesAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.regular),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (members.isEmpty &&
        currentAssignee.isEmpty &&
        candidatesAsync.hasError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            workspaceErrorMessage(candidatesAsync.error!),
            key: const ValueKey('task-assignee-candidates-error'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          AppSpacing.verticalTiny,
          OutlinedButton(
            key: const ValueKey('task-assignee-retry'),
            onPressed: () =>
                ref.invalidate(assigneeCandidatesProvider(widget.workspaceId)),
            child: Text(context.t.common.buttonRetry),
          ),
        ],
      );
    }
    final items = <DropdownMenuItem<EntityId>>[
      DropdownMenuItem<EntityId>(
        key: const ValueKey('task-assignee-option-none'),
        value: null,
        child: Text(context.t.workspace.taskAssigneeNone),
      ),
      for (final m in members)
        DropdownMenuItem<EntityId>(
          key: ValueKey('task-assignee-option-${m.userId}'),
          value: m.userId,
          child: Text(m.nickname.isEmpty ? m.account : m.nickname),
        ),
    ];
    return DropdownButtonFormField<EntityId>(
      key: const ValueKey('task-assignee-dropdown'),
      initialValue: _assigneeId,
      items: items,
      decoration: const InputDecoration(border: OutlineInputBorder()),
      onChanged: (v) => setState(() => _assigneeId = v),
    );
  }
}
