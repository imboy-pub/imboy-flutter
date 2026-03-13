import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/service/group_task_service.dart';
import 'package:imboy/i18n/strings.g.dart';

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
      status = 0; // 待完成
    } else if (_currentFilter == 2) {
      status = 1; // 已完成
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
        title: Text(t.groupTask.createTask),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: t.groupTask.taskTitle),
            ),
            const SizedBox(height: 16),
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
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.confirm),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(0, t.groupTask.all),
          const SizedBox(width: 8),
          _buildFilterChip(1, t.groupTask.pending),
          const SizedBox(width: 8),
          _buildFilterChip(2, t.groupTask.completed),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _currentFilter == index;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (!isSelected) {
          setState(() => _currentFilter = index);
          _loadTasks();
        }
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasks.isEmpty) {
      return NoDataView(text: t.groupTask.noTask, onTop: _loadTasks);
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
    final deadline = task['deadline'] as int?;
    final taskId = _resolveTaskRouteId(task);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          if (taskId.isEmpty) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('任务ID缺失，无法查看详情')));
            return;
          }
          final encodedId = Uri.encodeComponent(taskId);
          await context.push('/group/${widget.groupId}/task/$encodedId');
          if (mounted) {
            _loadTasks();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Checkbox(
                value: status == 1,
                onChanged: (value) async {
                  if (value == true) {
                    final submitTaskId = _resolveTaskSubmitId(task);
                    if (submitTaskId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('任务ID缺失，无法提交')),
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
                      task['title'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        decoration: status == 1
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task['description'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        task['description'],
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (deadline != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: _getDeadlineColor(deadline),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDeadline(deadline),
                            style: TextStyle(
                              fontSize: 12,
                              color: _getDeadlineColor(deadline),
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

  Color _getDeadlineColor(int deadline) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (deadline < now) {
      return Colors.red;
    } else if (deadline < now + 86400) {
      return Colors.orange;
    }
    return Colors.grey;
  }

  String _formatDeadline(int deadline) {
    final dt = DateTime.fromMillisecondsSinceEpoch(deadline * 1000);
    final now = DateTime.now();
    final diff = dt.difference(now);

    if (diff.isNegative) {
      return '已过期';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} 天后截止';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} 小时后截止';
    } else {
      return '即将截止';
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
