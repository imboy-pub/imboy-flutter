import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/group_schedule_service.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 参与人的显示名。
///
/// 后端 `group_schedule_repo:list_participants/1` 只查
/// `id,schedule_id,user_id,status,created_at` —— **不返回昵称**，
/// 所以原先的「nickname 为空就显示 user_id」等于把内部 uid 摆给用户看
/// （真机实测参与人一栏显示成「50」）。
/// 优先级：后端昵称 → 本地群成员表（群内别名 > 昵称）→ 通用占位。
/// 任何一档都不回退到 uid。
String resolveParticipantName(
  Map<String, dynamic> participant,
  Map<String, String> memberNames,
) {
  final fromServer = (participant['nickname'] ?? '').toString().trim();
  if (fromServer.isNotEmpty) return fromServer;
  final uid = (participant['user_id'] ?? '').toString().trim();
  final local = memberNames[uid] ?? '';
  if (local.isNotEmpty) return local;
  return t.main.unnamed;
}

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

  /// uid -> 群内显示名，用来补后端参与人列表缺失的昵称，见
  /// [resolveParticipantName]。
  Map<String, String> _memberNames = const {};

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  /// 从本地群成员表建 uid -> 显示名映射（群内别名优先于昵称）。
  Future<Map<String, String>> _loadMemberNames() async {
    try {
      final members = await GroupMemberRepo().page(
        where: '${GroupMemberRepo.groupId} = ?',
        whereArgs: [int.tryParse(widget.groupId) ?? 0],
      );
      return {
        for (final m in members)
          m.userId.toString(): m.alias.trim().isNotEmpty
              ? m.alias.trim()
              : m.nickname.trim(),
      };
    } on Exception {
      // 补名字失败不该拖垮整个详情页，退化为占位名即可。
      return const {};
    }
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
      final names = await _loadMemberNames();
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _memberNames = names;
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
    try {
      final success = await GroupScheduleService.to.confirmSchedule(
        groupId: widget.groupId,
        scheduleId: widget.scheduleId,
        confirm: confirm,
      );
      if (!mounted) return;
      // 原先用 ScaffoldMessenger.showSnackBar，真机上完全看不到；
      // 改用项目主流的 AppLoading（EasyLoading），全项目 290 处在用。
      if (success) {
        AppLoading.showSuccess(t.common.operationSuccessful);
        await _loadDetail();
      } else {
        AppLoading.showError(t.common.operationFailedAgainLater);
      }
    } finally {
      // 没有 finally 时，只要上面任何一步抛出（哪怕是 mounted 检查后的
      // setState），_isSubmitting 就永久卡在 true，此后每一次点击都会被
      // 方法开头的 `if (_isSubmitting) return` 静默吞掉 —— 表现正是
      // "按钮彻底失灵、零请求、零日志"。
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cancelSchedule() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final success = await GroupScheduleService.to.cancelSchedule(
        groupId: widget.groupId,
        scheduleId: widget.scheduleId,
      );
      if (!mounted) return;
      // 同上：SnackBar 在真机不可见，统一改用 AppLoading。
      if (success) {
        AppLoading.showSuccess(t.groupSchedule.cancelSuccess);
        await _loadDetail();
      } else {
        AppLoading.showError(t.groupSchedule.cancelFailed);
      }
    } finally {
      // 同 _confirm：缺 finally 时一次异常就让按钮永久失灵。
      if (mounted) setState(() => _isSubmitting = false);
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
                    leading: const Icon(CupertinoIcons.person, size: 18),
                    title: Text(resolveParticipantName(item, _memberNames)),
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
