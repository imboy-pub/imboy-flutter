import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_schedule_service.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群日程详情页
class GroupScheduleDetailPage extends ConsumerStatefulWidget {
  final String groupId;
  final String scheduleId;

  const GroupScheduleDetailPage({
    super.key,
    required this.groupId,
    required this.scheduleId,
  });

  @override
  ConsumerState<GroupScheduleDetailPage> createState() =>
      _GroupScheduleDetailPageState();
}

class _GroupScheduleDetailPageState
    extends ConsumerState<GroupScheduleDetailPage> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;
  bool _isSubmitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  String _toText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  List<Map<String, dynamic>> _toMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await GroupScheduleService.to.getSchedule(
        groupId: widget.groupId,
        scheduleId: widget.scheduleId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
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

  Future<void> _confirm(bool confirm) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final success = await GroupScheduleService.to.confirmSchedule(
      groupId: widget.groupId,
      scheduleId: widget.scheduleId,
      confirm: confirm,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.t.common.operationSuccessful
              : context.t.common.operationFailedAgainLater,
        ),
      ),
    );
    if (success) {
      await _loadDetail();
    }
  }

  Future<void> _cancelSchedule() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final success = await GroupScheduleService.to.cancelSchedule(
      groupId: widget.groupId,
      scheduleId: widget.scheduleId,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.t.groupSchedule.cancelSuccess
              : context.t.groupSchedule.cancelFailed,
        ),
      ),
    );
    if (success) {
      await _loadDetail();
    }
  }

  String _formatTimestamp(dynamic raw) {
    final sec = _toInt(raw);
    if (sec <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: GlassAppBar(
        title: t.groupSchedule.title,
        automaticallyImplyLeading: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return AsyncStateView(
      isLoading: _isLoading,
      error: _error,
      isEmpty: _detail == null,
      onRetry: _loadDetail,
      emptyText: context.t.groupSchedule.noSchedule,
      child: _detail == null ? const SizedBox.shrink() : _buildDetailContent(),
    );
  }

  Widget _buildDetailContent() {
    final scheduleRaw = _detail!['schedule'];
    final schedule = scheduleRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(scheduleRaw)
        : Map<String, dynamic>.from(_detail!);
    final participants = _toMapList(_detail!['participants']);

    final status = _toInt(schedule['status']);
    final startTime = _formatTimestamp(
      schedule['start_time'] ?? schedule['start_at'],
    );
    final endTime = _formatTimestamp(
      schedule['end_time'] ?? schedule['end_at'],
    );
    final location = _toText(schedule['location']);
    final description = _toText(schedule['description']);

    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.regular),
        children: [
          Text(
            _toText(schedule['title']),
            style: context.textStyle(
              FontSizeType.extraLarge,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          Chip(
            label: Text(
              status == 4
                  ? context.t.groupSchedule.statusCancelled
                  : context.t.groupSchedule.statusInProgress,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          _InfoLine(label: context.t.groupSchedule.startTime, value: startTime),
          _InfoLine(label: context.t.groupSchedule.endTime, value: endTime),
          if (location.isNotEmpty)
            _InfoLine(label: context.t.groupSchedule.location, value: location),
          if (description.isNotEmpty)
            _InfoLine(
              label: context.t.groupTask.taskDescription,
              value: description,
            ),
          const SizedBox(height: AppSpacing.medium),
          _InfoLine(
            label: context.t.groupSchedule.participants,
            value: _toInt(_detail!['participant_count']).toString(),
          ),
          if (participants.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.small),
            Text(
              context.t.group.groupMembers,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.small),
            ...participants
                .take(20)
                .map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person, size: 18),
                    title: Text(
                      _toText(item['nickname']).isEmpty
                          ? _toText(item['user_id'])
                          : _toText(item['nickname']),
                    ),
                  ),
                ),
          ],
          const SizedBox(height: AppSpacing.regular),
          if (status != 4)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _confirm(true),
                    child: Text(context.t.groupSchedule.confirmAttend),
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : () => _confirm(false),
                    child: Text(context.t.groupSchedule.declineAttend),
                  ),
                ),
              ],
            ),
          if (status != 4) const SizedBox(height: AppSpacing.medium),
          if (status != 4)
            OutlinedButton(
              onPressed: _isSubmitting ? null : _cancelSchedule,
              child: Text(context.t.groupSchedule.cancelSchedule),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
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
