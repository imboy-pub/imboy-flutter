import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_member/group_member_mute_rules.dart';
import 'package:imboy/page/group/group_member/mute_duration_rules.dart';
import 'package:imboy/page/group/group_member/mute_remaining_badge.dart';
import 'package:imboy/service/group_member_mute_service.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群成员详情页（slice-10）。
///
/// 功能：展示成员基本信息 + 管理员可执行禁言/解禁操作。
/// 路由：`/group/member_detail`，extra `{'groupId': String, 'userId': dynamic}`
class GroupMemberDetailPage extends ConsumerStatefulWidget {
  final String groupId;
  final String userId;

  const GroupMemberDetailPage({
    super.key,
    required this.groupId,
    required this.userId,
  });

  @override
  ConsumerState<GroupMemberDetailPage> createState() =>
      _GroupMemberDetailPageState();
}

class _GroupMemberDetailPageState
    extends ConsumerState<GroupMemberDetailPage> {
  GroupMemberModel? _member;
  int _myRole = 1;
  bool _isLoading = true;
  bool _anyChange = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final repo = GroupMemberRepo();
      final currentUid = UserRepoLocal.to.currentUid;

      final results = await Future.wait([
        repo.findByUserId(widget.groupId, widget.userId),
        repo.findByUserId(widget.groupId, currentUid),
      ]);

      final member = results[0];
      final me = results[1];
      if (mounted) {
        setState(() {
          _member = member;
          _myRole = me?.role ?? 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        EasyLoading.showError(t.loadError);
      }
    }
  }

  // ── 禁言操作 ──────────────────────────────────────────────────────────────

  Future<void> _onMuteTap() async {
    final member = _member;
    if (member == null) return;

    final seconds = await _showDurationPicker();
    if (seconds == null || !mounted) return;

    EasyLoading.show();
    try {
      final result = await GroupMemberMuteService().mute(
        gid: widget.groupId,
        userId: widget.userId,
        durationSec: seconds,
      );
      if (!mounted) return;
      EasyLoading.dismiss();

      switch (result) {
        case MuteSuccess(:final muteUntilMs):
          setState(() {
            _member!.muteUntilMs = muteUntilMs;
            _anyChange = true;
          });
          EasyLoading.showSuccess(t.muteMemberSuccess);
        case MuteValidationError():
          EasyLoading.showError(t.muteMemberFailed);
        case MuteApiFailure():
          EasyLoading.showError(t.muteMemberFailed);
      }
    } catch (e) {
      EasyLoading.dismiss();
      if (mounted) EasyLoading.showError(t.muteMemberFailed);
    }
  }

  Future<void> _onUnmuteTap() async {
    final confirmed = await _showConfirmDialog(
      title: t.unmuteMember,
      content: t.unmuteMemberConfirm,
    );
    if (confirmed != true || !mounted) return;

    EasyLoading.show();
    try {
      final result = await GroupMemberMuteService().unmute(
        gid: widget.groupId,
        userId: widget.userId,
      );
      if (!mounted) return;
      EasyLoading.dismiss();

      switch (result) {
        case UnmuteSuccess():
          setState(() {
            _member!.muteUntilMs = null;
            _anyChange = true;
          });
          EasyLoading.showSuccess(t.unmuteMemberSuccess);
        case UnmuteValidationError():
          EasyLoading.showError(t.unmuteMemberFailed);
        case UnmuteApiFailure():
          EasyLoading.showError(t.unmuteMemberFailed);
      }
    } catch (e) {
      EasyLoading.dismiss();
      if (mounted) EasyLoading.showError(t.unmuteMemberFailed);
    }
  }

  // ── 底部弹出时长选择器 ──────────────────────────────────────────────────────

  Future<int?> _showDurationPicker() async {
    return showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  t.muteDuration,
                  style: ThemeManager.instance.getTextStyle(
                    FontSizeType.large,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...muteDurationOptions.map((opt) => ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    title: Text(_labelForKey(opt.labelKey)),
                    onTap: () => Navigator.of(ctx).pop(opt.seconds),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              t.confirm,
              style: const TextStyle(color: AppColors.iosRed),
            ),
          ),
        ],
      ),
    );
  }

  // ── i18n 时长文案 ─────────────────────────────────────────────────────────

  String _labelForKey(String key) {
    return switch (key) {
      'muteDuration5min'  => t.muteDuration5min,
      'muteDuration10min' => t.muteDuration10min,
      'muteDuration30min' => t.muteDuration30min,
      'muteDuration1hour' => t.muteDuration1hour,
      'muteDuration1day'  => t.muteDuration1day,
      'muteDuration7days' => t.muteDuration7days,
      'muteDuration30days' => t.muteDuration30days,
      _ => key,
    };
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && _anyChange) {
          // 通过 go_router 的 pop 返回结果在 PopScope 不易做到；
          // 调用方监听 result via context.push<bool> 的返回值。
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.memberDetail),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop(_anyChange),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _buildBody(colorScheme),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    final member = _member;
    if (member == null) {
      return Center(child: Text(t.noData));
    }

    final currentUid = UserRepoLocal.to.currentUid;
    final canMute = canMuteGroupMember(
          currentUserId: currentUid,
          currentRole: _myRole,
          targetUserId: member.userId.toString(),
          targetRole: member.role,
        );
    final isMuted = member.isMuted();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 成员头像 & 基本信息 ──
          _buildProfileCard(member, colorScheme),
          const SizedBox(height: 16),

          // ── 禁言状态 ──
          _buildInfoRow(
            label: t.muted,
            value: isMuted ? t.muted : t.notMuted,
            trailing: MuteRemainingBadge(
              muteUntilMs: member.muteUntilMs,
              nowMs: DateTime.now().millisecondsSinceEpoch,
            ),
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 16),

          // ── 管理员操作区 ──
          if (canMute) ...[
            if (isMuted)
              _buildActionButton(
                label: t.unmuteMember,
                color: colorScheme.primary,
                onTap: _onUnmuteTap,
              )
            else
              _buildActionButton(
                label: t.muteMember,
                color: AppColors.iosRed,
                onTap: _onMuteTap,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileCard(GroupMemberModel member, ColorScheme colorScheme) {
    final displayName =
        member.alias.isNotEmpty ? member.alias : member.nickname;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMedium),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Avatar(imgUri: member.avatar, width: 56, height: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: ThemeManager.instance.getTextStyle(
                      FontSizeType.large,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (member.sign.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      member.sign,
                      style: ThemeManager.instance.getTextStyle(
                        FontSizeType.small,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    Widget? trailing,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Row(
        children: [
          Text(
            label,
            style: ThemeManager.instance.getTextStyle(FontSizeType.medium),
          ),
          const Spacer(),
          ?trailing,
          Text(
            value,
            style: ThemeManager.instance.getTextStyle(
              FontSizeType.medium,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusMedium,
          ),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
