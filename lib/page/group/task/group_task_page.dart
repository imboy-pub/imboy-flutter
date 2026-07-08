import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_task_service.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群作业/任务页面
class GroupTaskPage extends ConsumerStatefulWidget {
  final String groupId;

  const GroupTaskPage({super.key, required this.groupId});

  @override
  ConsumerState<GroupTaskPage> createState() => _GroupTaskPageState();
}

class _GroupTaskPageState extends ConsumerState<GroupTaskPage> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  int _currentFilter = 0; // 0: 全部, 1: 待完成, 2: 已完成

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    int? status;
    if (_currentFilter == 1) {
      status = 1; // 待完成（in-progress）
    } else if (_currentFilter == 2) {
      status = 2; // 已完成（completed）
    }

    final tasks = await GroupTaskService.to.getTasks(
      groupId: widget.groupId,
      status: status,
    );

    if (mounted) {
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  Future<void> _createTask() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('create_task_dialog'),
        title: Text(t.groupTask.createTask),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('task_title_field'),
              controller: titleController,
              decoration: InputDecoration(labelText: t.groupTask.taskTitle),
            ),
            const SizedBox(height: AppSpacing.regular),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t.groupTask.taskDescription,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            key: const Key('create_task_confirm'),
            onPressed: () {
              // 标题为空时阻止关闭 / Prevent close when title is empty
              if (titleController.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      final task = await GroupTaskService.to.createTask(
        groupId: widget.groupId,
        title: titleController.text,
        description: descController.text,
      );
      if (task != null && mounted) {
        _loadTasks();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: GlassAppBar(
        title: t.groupTask.title,
        automaticallyImplyLeading: true,
        rightDMActions: [
          IconButton(
            key: const Key('create_task_fab'),
            icon: const Icon(Icons.add),
            onPressed: _createTask,
            tooltip: t.groupTask.createTask,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _currentFilter,
          thumbColor: AppColors.getIosBlue(Theme.of(context).brightness),
          padding: const EdgeInsets.all(3),
          children: {
            0: _segmentLabel(t.groupTask.all, _currentFilter == 0),
            1: _segmentLabel(t.groupTask.pending, _currentFilter == 1),
            2: _segmentLabel(t.groupTask.completed, _currentFilter == 2),
          },
          onValueChanged: (v) {
            if (v != null && v != _currentFilter) {
              setState(() => _currentFilter = v);
              _loadTasks();
            }
          },
        ),
      ),
    );
  }

  /// 分段控件标签
  Widget _segmentLabel(String text, bool selected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: context.textStyle(
          FontSizeType.footnote,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          color: selected ? AppColors.onPrimary : AppColors.iosGray,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasks.isEmpty) {
      return NoDataView(
        key: const Key('group_task_empty'),
        text: t.groupTask.noTask,
        onTop: _loadTasks,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return _buildTaskItem(task);
        },
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    final status = task['status'] ?? 0;
    // deadline 可能来自 API（int 时间戳秒）或本地测试数据（String / null），统一安全转换
    // deadline may be int (unix seconds from API) or String/null in local data — cast safely
    final deadline = task['deadline'] is int ? task['deadline'] as int : null;
    final taskId = _resolveTaskRouteId(task);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.small,
      ),
      child: InkWell(
        onTap: () async {
          if (taskId.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(t.groupTask.taskIdMissing)));
            return;
          }
          final encodedId = Uri.encodeComponent(taskId);
          await context.push('/group/${widget.groupId}/task/$encodedId');
          if (mounted) {
            _loadTasks();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.regular),
          child: Row(
            children: [
              Checkbox(
                value: status == 1,
                onChanged: (value) async {
                  if (value == true) {
                    final submitTaskId = _resolveTaskSubmitId(task);
                    if (submitTaskId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t.groupTask.taskIdMissingSubmit),
                        ),
                      );
                      return;
                    }
                    await GroupTaskService.to.submitTask(
                      groupId: widget.groupId,
                      taskId: submitTaskId,
                    );
                    _loadTasks();
                  }
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task['title'] as String? ?? '',
                      style: context
                          .textStyle(FontSizeType.medium)
                          .copyWith(
                            decoration: status == 1
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                    ),
                    if (task['description'] != null) ...[
                      AppSpacing.verticalTiny,
                      Text(
                        task['description'] as String,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (deadline != null) ...[
                      AppSpacing.verticalTiny,
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: _getDeadlineColor(context, deadline),
                          ),
                          AppSpacing.horizontalTiny,
                          Text(
                            _formatDeadline(deadline),
                            style: context.textStyle(
                              FontSizeType.small,
                              color: _getDeadlineColor(context, deadline),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDeadlineColor(BuildContext context, int deadline) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (deadline < now) {
      return AppColors.getIosRed(Theme.of(context).brightness);
    } else if (deadline < now + 86400) {
      return AppColors.iosOrange;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String _formatDeadline(int deadline) {
    final dt = DateTime.fromMillisecondsSinceEpoch(deadline * 1000);
    final now = DateTime.now();
    final diff = dt.difference(now);

    if (diff.isNegative) {
      return t.groupTask.overdue;
    } else if (diff.inDays > 0) {
      return t.groupTask.daysLeft(days: diff.inDays);
    } else if (diff.inHours > 0) {
      return t.groupTask.hoursLeft(hours: diff.inHours);
    } else {
      return t.groupTask.dueSoon;
    }
  }

  String _toText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  String _resolveTaskRouteId(Map<String, dynamic> task) {
    final taskId = _toText(task['id']);
    if (taskId.isNotEmpty) {
      return taskId;
    }
    return _toText(task['task_id']);
  }

  String _resolveTaskSubmitId(Map<String, dynamic> task) {
    final taskId = _toText(task['task_id']);
    if (taskId.isNotEmpty) {
      return taskId;
    }
    return _toText(task['id']);
  }
}
