import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_task_service.dart';

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
    setState(() => _isLoading = true);

    final task = await GroupTaskService.to.getTask(
      groupId: widget.groupId,
      taskId: widget.taskId,
    );

    int pendingCount = 0;
    if (task != null) {
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
  }

  String _formatDeadline(dynamic raw) {
    final sec = _toInt(raw);
    if (sec <= 0) return context.t.groupTask.noDeadline;
    final dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submitTask() async {
    if (_isSubmitting || _task == null) return;
    setState(() => _isSubmitting = true);

    final success = await GroupTaskService.to.submitTask(
      groupId: widget.groupId,
      taskId: widget.taskId,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.t.groupTask.taskSubmitted
              : context.t.groupTask.submitFailed,
        ),
      ),
    );
    if (success) {
      await _loadDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: GlassAppBar(
        title: t.groupTask.title,
        automaticallyImplyLeading: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_task == null) {
      return NoDataView(text: context.t.groupTask.noTask, onTop: _loadDetail);
    }

    final status = _toInt(_task!['status']);
    final isCompleted = status == 1 || status == 3;

    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _toText(_task!['title']),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Chip(
            label: Text(
              isCompleted
                  ? context.t.groupTask.completed
                  : context.t.groupTask.pending,
            ),
          ),
          const SizedBox(height: 12),
          if (_toText(_task!['description']).isNotEmpty)
            _InfoLine(
              label: context.t.groupTask.taskDescription,
              value: _toText(_task!['description']),
            ),
          _InfoLine(
            label: context.t.groupTask.deadline,
            value: _formatDeadline(_task!['deadline']),
          ),
          _InfoLine(
            label: context.t.groupTask.taskId,
            value: _toText(_task!['task_id']).isEmpty
                ? widget.taskId
                : _toText(_task!['task_id']),
          ),
          _InfoLine(
            label: context.t.groupTask.pendingReview,
            value: _pendingReviewCount.toString(),
          ),
          const SizedBox(height: 16),
          if (!isCompleted)
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitTask,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.t.groupTask.taskSubmitted),
            ),
        ],
      ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
