import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/task/group_task_form.dart';
import 'package:imboy/service/group_task_service.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群任务详情页
class GroupTaskDetailPage extends ConsumerStatefulWidget {
  final String groupId;
  final String taskId;

  const GroupTaskDetailPage({
    super.key,
    required this.groupId,
    required this.taskId,
  });

  @override
  ConsumerState<GroupTaskDetailPage> createState() =>
      _GroupTaskDetailPageState();
}

class _GroupTaskDetailPageState extends ConsumerState<GroupTaskDetailPage> {
  Map<String, dynamic>? _task;
  int _pendingReviewCount = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isSaving = false;
  Object? _error;

  bool _isCreator(Map<String, dynamic> task) {
    final uid = UserRepoLocal.to.currentUid;
    return uid.isNotEmpty && _toText(task['creator_id']) == uid;
  }

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _toText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final task = await GroupTaskService.to.getTask(
        groupId: widget.groupId,
        taskId: widget.taskId,
      );

      int pendingCount = 0;
      if (task != null && _isCreator(task)) {
        final taskRouteId = _toText(task['task_id']).isNotEmpty
            ? _toText(task['task_id'])
            : widget.taskId;
        final pending = await GroupTaskService.to.getPendingReview(
          taskId: taskRouteId,
        );
        pendingCount = pending.length;
      }

      if (!mounted) return;
      setState(() {
        _task = task;
        _pendingReviewCount = pendingCount;
        _isLoading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  String _formatDeadline(dynamic raw) {
    final sec = _toInt(raw);
    if (sec <= 0) return context.t.groupTask.noDeadline;
    final dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submitTask() async {
    if (_isSubmitting || _task == null || _assignmentStatus >= 2) return;
    setState(() => _isSubmitting = true);

    final success = await GroupTaskService.to.submitTask(
      groupId: widget.groupId,
      taskId: widget.taskId,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    AppLoading.showToast(
      success
          ? context.t.groupTask.taskSubmitted
          : context.t.groupTask.submitFailed,
    );
    if (success) {
      await _loadDetail();
    }
  }

  /// 创建者编辑作业（与后端 update 规则一致：仅创建者、已截止不可改）。
  ///
  /// 后端 update 的 task_id 只认内部数字主键（normalize_id），
  /// 详情接口返回的原始行里带 `id`，优先取它，避免把形如
  /// task.xxxx 的对外 uid 传过去被解析成 0 而报"作业ID必填"。
  Future<void> _editTask() async {
    final task = _task;
    if (task == null || _isSaving) return;
    final t = context.t;

    final form = await showGroupTaskFormDialog(
      context,
      dialogTitle: t.groupTask.editTask,
      initialTitle: _toText(task['title']),
      initialDescription: _toText(task['description']),
      confirmKey: const Key('edit_task_confirm'),
      titleFieldKey: const Key('edit_task_title_field'),
    );
    if (form == null || !mounted) return;

    setState(() => _isSaving = true);
    final updateId = _toText(task['id']).isNotEmpty
        ? _toText(task['id'])
        : widget.taskId;
    final success = await GroupTaskService.to.updateTask(
      groupId: widget.groupId,
      taskId: updateId,
      title: form.title,
      description: form.description,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    AppLoading.showToast(success ? t.common.saveSuccess : t.common.saveFailed);
    if (success) {
      await _loadDetail();
    }
  }

  /// 是否可编辑：创建者 + 作业未截止（status 枚举 3=已截止）。
  bool get _canEdit {
    final task = _task;
    if (task == null) return false;
    return _isCreator(task) && _toInt(task['status']) != 3;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: GlassAppBar(
        title: t.groupTask.title,
        automaticallyImplyLeading: true,
        rightDMActions: [
          if (_canEdit)
            IconButton(
              key: const Key('edit_task_action'),
              icon: const Icon(CupertinoIcons.pencil, size: 22),
              onPressed: _isSaving ? null : _editTask,
              tooltip: t.groupTask.editTask,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return AsyncStateView(
      isLoading: _isLoading,
      error: _error,
      isEmpty: _task == null,
      onRetry: _loadDetail,
      emptyText: context.t.groupTask.noTask,
      child: _task == null ? const SizedBox.shrink() : _buildDetailContent(),
    );
  }

  int get _assignmentStatus {
    final assignment = _task?['my_assignment'];
    return assignment is Map ? _toInt(assignment['status']) : 0;
  }

  Widget _buildDetailContent() {
    final status = _toInt(_task!['status']);
    // group_task.status 枚举是 1待完成 2进行中 3已截止（见 foundation 迁移的列注释），
    // 只有 3 才是「不能再提交」。原先写成 `status == 1 || status == 3`，把**待完成**
    // 判成了已完成 —— 新建作业恒为 1，于是提交按钮永远不出现，群作业提交功能
    // 对最常见的状态 100% 不可用。疑似与 group_task_assignment.status
    //（0待完成 1进行中 2已提交 3已批改）的枚举混淆。
    final isCompleted = status == 3;
    final isSubmitted = _assignmentStatus == 2;
    final isReviewed = _assignmentStatus == 3;

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _loadDetail),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.regular),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _toText(_task!['title']),
                  style: context.textStyle(
                    FontSizeType.extraLarge,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                _iosChip(
                  isSubmitted
                      ? context.t.groupTask.taskSubmitted
                      : isCompleted || isReviewed
                      ? context.t.groupTask.completed
                      : context.t.groupTask.pending,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
                const SizedBox(height: AppSpacing.medium),
                if (_toText(_task!['description']).isNotEmpty)
                  _InfoLine(
                    label: context.t.groupTask.taskDescription,
                    value: _toText(_task!['description']),
                  ),
                _InfoLine(
                  label: context.t.groupTask.deadline,
                  value: _formatDeadline(_task!['deadline']),
                ),
                // 不展示 task_id：那是内部标识（形如 task.5yPMVuT6W5P03.c），
                // 对用户没有任何意义，只会让详情页看起来像调试面板。
                if (_isCreator(_task!))
                  _InfoLine(
                    label: context.t.groupTask.pendingReview,
                    value: _pendingReviewCount.toString(),
                  ),
                const SizedBox(height: AppSpacing.regular),
                if (!isCompleted && !isSubmitted && !isReviewed)
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton.filled(
                      minimumSize: const Size(0, 44),
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: _isSubmitting ? null : _submitTask,
                      child: _isSubmitting
                          ? const CupertinoActivityIndicator()
                          : Text(context.t.groupTask.submitTask),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.body,
                color: AppColors.iosGray,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// iOS 风格信息标签
Widget _iosChip(String label, {required bool isDark}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: FontSizeType.footnote.size,
        color: isDark
            ? AppColors.darkTextSecondary
            : AppColors.lightTextSecondary,
      ),
    ),
  );
}
