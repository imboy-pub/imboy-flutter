import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/app_clock.dart';
import 'package:imboy/component/helper/boundary_refresh.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/schedule/group_schedule_ui.dart';
import 'package:imboy/service/group_schedule_service.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
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
///
/// 对标钉钉群日程 / 飞书日历详情：状态语义色头区 + 分区卡片
/// （时间 / 地点描述 / 参与人确认状态）+ 底部固定操作栏。
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
    extends ConsumerState<GroupScheduleDetailPage>
    with BoundaryRefreshLifecycle<GroupScheduleDetailPage> {
  Map<String, dynamic>? _detail;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showAllParticipants = false;
  Object? _error;

  /// uid -> 群内显示名，用来补后端参与人列表缺失的昵称，见
  /// [resolveParticipantName]。
  Map<String, String> _memberNames = const {};
  Map<String, String> _memberAvatars = const {};

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  /// 从本地群成员表建 uid -> 显示名/头像映射（群内别名优先于昵称）。
  Future<(Map<String, String>, Map<String, String>)>
  _loadMemberProfiles() async {
    try {
      final members = await GroupMemberRepo().page(
        where: '${GroupMemberRepo.groupId} = ?',
        whereArgs: [widget.groupId],
      );
      final names = <String, String>{};
      final avatars = <String, String>{};
      for (final m in members) {
        final uid = m.userId.toString();
        final alias = m.alias.trim();
        names[uid] = alias.isNotEmpty ? alias : m.nickname.trim();
        avatars[uid] = m.avatar.trim();
      }
      return (names, avatars);
    } on Exception {
      // 补名字失败不该拖垮整个详情页，退化为占位名即可。
      return (<String, String>{}, <String, String>{});
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
      final (names, avatars) = await _loadMemberProfiles();
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _memberNames = names;
        _memberAvatars = avatars;
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
    // R20-4：提交动作前用即时时间重验 deadline——后台静置跨过结束时间
    // 后按钮虽仍可见（stale build），但不得再提交。
    final (_, _, _, state) = _resolveSchedule();
    if (!state.isActionable) {
      if (mounted) setState(() {});
      AppLoading.showToast(t.groupSchedule.statusEnded);
      return;
    }
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
      }
      // 失败分支不再叠兜底文案：后端中文原因已由 GroupScheduleApi.confirmSchedule 透出
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
    // R20-4：同 _confirm——提交动作前即时重验，已结束/已取消不再可操作。
    final (_, _, _, state) = _resolveSchedule();
    if (!state.isActionable) {
      if (mounted) setState(() {});
      AppLoading.showToast(t.groupSchedule.statusEnded);
      return;
    }
    // 破坏性操作先确认：取消日程会影响群里所有参与人，不可误触。
    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.groupSchedule.cancelSchedule),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.groupSchedule.cancelSchedule),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(t.common.cancel),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: t.groupSchedule.title,
        automaticallyImplyLeading: true,
      ),
      bottomNavigationBar: _detail == null ? null : _buildBottomBar(),
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

  /// 从 _detail 解析展示所需的派生数据（schedule map / 起止秒 / 展示态）。
  (Map<String, dynamic>, int, int, GroupScheduleTimeState) _resolveSchedule() {
    final scheduleRaw = _detail!['schedule'];
    final schedule = scheduleRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(scheduleRaw)
        : Map<String, dynamic>.from(_detail!);
    final startAt = _toInt(schedule['start_time'] ?? schedule['start_at']);
    final endAt = _toInt(schedule['end_time'] ?? schedule['end_at']);
    // 后端 group_schedule.status 只会是 1（创建时写死）或 4（取消），
    // 2进行中/3已结束 没有任何流转逻辑 —— 所以时间态必须由客户端按
    // start/end 推导，否则三天前结束的日程会永远显示"进行中"并继续催人报名。
    // start_at/end_at 单位是**秒**不是毫秒。
    // R20-4：now 每次即时重取（appClock，服务器时间估计），不缓存 build 旧值。
    final state = resolveScheduleTimeState(
      status: _toInt(schedule['status']),
      startAtSec: startAt,
      endAtSec: endAt,
      nowSec: appClock.nowMs() ~/ 1000,
    );
    return (schedule, startAt, endAt, state);
  }

  /// R20-B：调度下一有效边界（日程开始/结束、本地午夜）触发一次重建，
  /// 让状态徽章/操作栏在静置跨边界后自动翻转；dispose 由 mixin 取消 timer。
  void _scheduleNextBoundary(int startAt, int endAt) {
    final now = DateTime.now();
    scheduleBoundaryAt(
      nextBoundary([
        if (startAt > 0) DateTime.fromMillisecondsSinceEpoch(startAt * 1000),
        if (endAt > startAt) DateTime.fromMillisecondsSinceEpoch(endAt * 1000),
        nextLocalMidnight(now),
      ], now),
    );
  }

  Widget _buildDetailContent() {
    final (schedule, startAt, endAt, state) = _resolveSchedule();
    _scheduleNextBoundary(startAt, endAt);
    final participants = _toMapList(_detail!['participants']);
    final isActionable = state.isActionable;

    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _loadDetail),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.regular,
              AppSpacing.regular,
              AppSpacing.regular,
              // 有底部操作栏时多留白，避免内容被栏遮挡产生"贴底"错觉。
              isActionable ? AppSpacing.xxxLarge : AppSpacing.xLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(schedule: schedule, startAt: startAt, state: state),
                const SizedBox(height: AppSpacing.small),
                _TimeCard(schedule: schedule, startAt: startAt, endAt: endAt),
                _buildDetailCard(schedule),
                _buildParticipantsCard(participants),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 详情卡：地点 / 描述 / 发起人，任一为空则整卡隐藏。
  Widget _buildDetailCard(Map<String, dynamic> schedule) {
    final location = _toText(schedule['location']);
    final description = _toText(schedule['description']);
    final creatorName = resolveParticipantName({
      'user_id': _toText(schedule['creator_id']),
    }, _memberNames);
    final rows = <Widget>[
      if (location.isNotEmpty)
        _IconInfoRow(icon: CupertinoIcons.location_solid, text: location),
      if (description.isNotEmpty)
        _IconInfoRow(icon: CupertinoIcons.text_quote, text: description),
      _IconInfoRow(icon: CupertinoIcons.person_crop_circle, text: creatorName),
    ];
    if (rows.length == 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.small),
      child: _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.medium),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsCard(List<Map<String, dynamic>> participants) {
    if (participants.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attending = participants
        .where((p) => _toInt(p['status']) == 1)
        .length;
    final total = _toInt(_detail!['participant_count']);
    final visible = _showAllParticipants
        ? participants
        : participants.take(6).toList();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.small),
      child: _SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.groupSchedule.allParticipants(count: total.toString()),
                    style: context.textStyle(
                      FontSizeType.normal,
                      fontWeight: FontWeight.w600,
                      color: AppColors.getTextColor(
                        isDark ? Brightness.dark : Brightness.light,
                      ),
                    ),
                  ),
                ),
                Text(
                  t.groupSchedule.attendSummary(
                    attending: attending.toString(),
                    total: total.toString(),
                  ),
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: AppColors.iosGray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            ...visible.map(_buildParticipantTile),
            if (participants.length > 6) ...[
              const SizedBox(height: AppSpacing.tiny),
              CupertinoButton(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                onPressed: () => setState(
                  () => _showAllParticipants = !_showAllParticipants,
                ),
                child: Text(
                  _showAllParticipants
                      ? t.groupSchedule.collapseParticipants
                      : t.groupSchedule.allParticipants(
                          count: participants.length.toString(),
                        ),
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: isDark ? AppColors.iosBlueDark : AppColors.iosBlue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantTile(Map<String, dynamic> participant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = _toText(participant['user_id']);
    final status = _toInt(participant['status']);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Row(
        children: [
          Avatar(imgUri: _memberAvatars[uid] ?? '', width: 36, height: 36),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Text(
              resolveParticipantName(participant, _memberNames),
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.getTextColor(
                  isDark ? Brightness.dark : Brightness.light,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            participantStateIcon(status),
            size: 14,
            color: participantStateColor(status, isDark),
          ),
          const SizedBox(width: AppSpacing.tiny),
          Text(
            participantStateLabel(context, status),
            style: context.textStyle(
              FontSizeType.footnote,
              color: participantStateColor(status, isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// 底部固定操作栏：报名操作并排，破坏性的"取消日程"放次要行。
  /// 已取消/已结束不再出现（见 isActionable）。
  Widget? _buildBottomBar() {
    final (_, _, _, state) = _resolveSchedule();
    if (!state.isActionable) return null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brightness = isDark ? Brightness.dark : Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(brightness),
        border: Border(
          top: BorderSide(color: AppColors.getDividerColor(brightness)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.regular,
            AppSpacing.small,
            AppSpacing.regular,
            AppSpacing.small,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(12),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: _isSubmitting ? null : () => _confirm(true),
                      child: Text(t.groupSchedule.confirmAttend),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      borderRadius: BorderRadius.circular(12),
                      color: isDark
                          ? AppColors.darkSurface
                          : AppColors.lightSurfaceContainer,
                      onPressed: _isSubmitting ? null : () => _confirm(false),
                      child: Text(t.groupSchedule.declineAttend),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.tiny),
              CupertinoButton(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(vertical: 8),
                onPressed: _isSubmitting ? null : _cancelSchedule,
                child: Text(
                  t.groupSchedule.cancelSchedule,
                  style: context.textStyle(
                    FontSizeType.footnote,
                    color: isDark ? AppColors.iosRedDark : AppColors.iosRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 页面头区：状态徽章 + 标题 + 相对开始时间。
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.schedule,
    required this.startAt,
    required this.state,
  });

  final Map<String, dynamic> schedule;
  final int startAt;
  final GroupScheduleTimeState state;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = (schedule['title'] ?? '').toString().trim();
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScheduleStatusBadge(state: state),
          const SizedBox(height: AppSpacing.medium),
          Text(
            title.isEmpty ? context.t.groupSchedule.untitledSchedule : title,
            style: context.textStyle(
              FontSizeType.title,
              fontWeight: FontWeight.w700,
              color: state == GroupScheduleTimeState.cancelled
                  ? AppColors.iosGray
                  : AppColors.getTextColor(
                      isDark ? Brightness.dark : Brightness.light,
                    ),
            ),
          ),
          if (startAt > 0 &&
              state != GroupScheduleTimeState.cancelled &&
              state != GroupScheduleTimeState.ended) ...[
            const SizedBox(height: AppSpacing.tiny),
            Text(
              scheduleStartsHint(context, startAt, appClock.nowMs() ~/ 1000),
              style: context.textStyle(
                FontSizeType.footnote,
                color: isDark ? AppColors.iosBlueDark : AppColors.iosBlue,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 时间卡：日期块 + 起止时间 + 时长/提醒脚注。
class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.schedule,
    required this.startAt,
    required this.endAt,
  });

  final Map<String, dynamic> schedule;
  final int startAt;
  final int endAt;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final muted = schedule['status'] == 4;
    final start = DateTime.fromMillisecondsSinceEpoch(startAt * 1000);
    // end_at 允许为空（=0）：此时隐藏结束行，不能渲染 1970 epoch。
    final hasEnd = endAt > startAt;
    final end = DateTime.fromMillisecondsSinceEpoch(
      (hasEnd ? endAt : startAt) * 1000,
    );
    final remind = _toInt(schedule['remind_before']);
    final footnotes = <String>[
      if (hasEnd)
        t.groupSchedule.duration(
          minutes: ((endAt - startAt) / 60).round().toString(),
        ),
      if (remind > 0) t.groupSchedule.remindBefore(minutes: remind.toString()),
    ];
    return _SectionCard(
      footer: footnotes.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.small),
              child: Text(
                footnotes.join(' · '),
                style: context.textStyle(
                  FontSizeType.caption2,
                  color: AppColors.iosGray,
                ),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ScheduleDateBlock(dateTime: start, muted: muted),
          const SizedBox(width: AppSpacing.regular),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TimeRow(label: t.groupSchedule.startTime, value: _hm(start)),
                if (hasEnd) ...[
                  const SizedBox(height: AppSpacing.tiny),
                  _TimeRow(label: t.groupSchedule.endTime, value: _hm(end)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _hm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.iosGray,
            ),
          ),
        ),
        Text(
          value,
          style: context.textStyle(
            FontSizeType.body,
            fontWeight: FontWeight.w600,
            color: AppColors.getTextColor(
              isDark ? Brightness.dark : Brightness.light,
            ),
          ),
        ),
      ],
    );
  }
}

/// 通用分区块卡：分组背景上的白色（暗色 elevated）圆角容器。
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.footer});

  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
        borderRadius: AppRadius.borderRadiusRegular,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [child, ?footer],
      ),
    );
  }
}

class _IconInfoRow extends StatelessWidget {
  const _IconInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.iosGray),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Text(
            text,
            style: context.textStyle(
              FontSizeType.normal,
              color: AppColors.getTextColor(
                isDark ? Brightness.dark : Brightness.light,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
