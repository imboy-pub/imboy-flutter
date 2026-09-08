import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/cupertino_modal_surface.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/safety_number_page.dart';
import 'package:imboy/page/group/group_detail/remove_member_provider.dart';
import 'package:imboy/page/group/group_member/group_member_mute_rules.dart';
import 'package:imboy/page/group/group_member/mute_duration_rules.dart';
import 'package:imboy/page/group/group_member/mute_remaining_badge.dart';
import 'package:imboy/service/group_member_mute_service.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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

class _GroupMemberDetailPageState extends ConsumerState<GroupMemberDetailPage> {
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
      iPrint('[GroupMemberDetail] 加载成员详情失败: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        AppLoading.showError(t.common.loadError);
      }
    }
  }

  // ── 禁言操作 ──────────────────────────────────────────────────────────────

  Future<void> _onMuteTap() async {
    final member = _member;
    if (member == null) return;

    final seconds = await _showDurationPicker();
    if (seconds == null || !mounted) return;

    AppLoading.show();
    try {
      final result = await GroupMemberMuteService().mute(
        gid: widget.groupId,
        userId: widget.userId,
        durationSec: seconds,
      );
      if (!mounted) return;
      AppLoading.dismiss();

      switch (result) {
        case MuteSuccess(:final muteUntilMs):
          setState(() {
            _member = _member!.copyWith(muteUntilMs: muteUntilMs);
            _anyChange = true;
          });
          AppLoading.showSuccess(t.common.muteMemberSuccess);
        case MuteValidationError():
          AppLoading.showError(t.common.muteMemberFailed);
        case MuteApiFailure():
          // 服务端中文错误消息已由 GroupMemberApi.mute 透传（AppLoading.showError(resp.msg)），
          // 此处不再覆盖为兜底文案，避免吞掉真实原因。
          break;
      }
    } catch (e) {
      iPrint('[GroupMemberDetail] 禁言失败: $e');
      AppLoading.dismiss();
      if (mounted) AppLoading.showError(t.common.muteMemberFailed);
    }
  }

  Future<void> _onUnmuteTap() async {
    final confirmed = await _showConfirmDialog(
      title: t.chat.unmuteMember,
      content: t.common.unmuteMemberConfirm,
    );
    if (confirmed != true || !mounted) return;

    AppLoading.show();
    try {
      final result = await GroupMemberMuteService().unmute(
        gid: widget.groupId,
        userId: widget.userId,
      );
      if (!mounted) return;
      AppLoading.dismiss();

      switch (result) {
        case UnmuteSuccess():
          setState(() {
            _member = _member!.copyWith(clearMuteUntil: true);
            _anyChange = true;
          });
          AppLoading.showSuccess(t.common.unmuteMemberSuccess);
        case UnmuteValidationError():
          AppLoading.showError(t.common.unmuteMemberFailed);
        case UnmuteApiFailure():
          // 服务端中文错误消息已由 GroupMemberApi.unmute 透传，此处不再覆盖兜底文案。
          break;
      }
    } catch (e) {
      iPrint('[GroupMemberDetail] 解除禁言失败: $e');
      AppLoading.dismiss();
      if (mounted) AppLoading.showError(t.common.unmuteMemberFailed);
    }
  }

  // ── 底部弹出时长选择器（Cupertino 风格） ─────────────────────────────────────

  Future<int?> _showDurationPicker() async {
    return showCupertinoModalPopup<int>(
      context: context,
      builder: (ctx) {
        return CupertinoModalSurface(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.regular,
                ),
                child: Text(
                  t.common.muteDuration,
                  style: ThemeManager.instance.getTextStyle(
                    FontSizeType.large,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...muteDurationOptions.map(
                (opt) => CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xLarge,
                    vertical: AppSpacing.medium,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(opt.seconds),
                  child: Text(
                    _labelForKey(opt.labelKey),
                    style: context.textStyle(FontSizeType.body),
                  ),
                ),
              ),
              AppSpacing.verticalSmall,
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
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.common.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              t.common.confirm,
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
      'muteDuration5min' => t.common.muteDuration5min,
      'muteDuration10min' => t.common.muteDuration10min,
      'muteDuration30min' => t.common.muteDuration30min,
      'muteDuration1hour' => t.common.muteDuration1hour,
      'muteDuration1day' => t.common.muteDuration1day,
      'muteDuration7days' => t.common.muteDuration7days,
      'muteDuration30days' => t.common.muteDuration30days,
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
        appBar: CupertinoNavigationBar(
          middle: Text(t.main.memberDetail),
          border: Border(
            bottom: BorderSide(
              color: AppColors.getIosSeparator(
                Theme.of(context).brightness,
              ).withValues(alpha: 0.4),
              width: 0.33,
            ),
          ),
          // 纯图标按钮须显式 Semantics，CupertinoButton 无 tooltip 参数。
          leading: Semantics(
            button: true,
            label: t.common.buttonBack,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.pop(_anyChange),
              child: const Icon(CupertinoIcons.back, size: 22),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _buildBody(colorScheme),
      ),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    final member = _member;
    if (member == null) {
      return Center(child: Text(t.common.noData));
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
      padding: const EdgeInsets.all(AppSpacing.regular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 成员头像 & 基本信息 ──
          _buildProfileCard(member, colorScheme),
          AppSpacing.verticalRegular,

          // ── 禁言状态 ──
          _buildInfoRow(
            label: t.chat.muted,
            value: isMuted ? t.chat.muted : t.common.notMuted,
            trailing: MuteRemainingBadge(
              muteUntilMs: member.muteUntilMs,
              nowMs: DateTime.now().millisecondsSinceEpoch,
            ),
            colorScheme: colorScheme,
          ),
          AppSpacing.verticalRegular,

          // ── 安全码验证（群成员级 E2EE 身份校验，审计阶段 2） ──
          // 每个成员详情页独立入口，复用 C2C 安全码页（对端取主设备 identity）。
          _buildActionButton(
            label: t.main.safetyNumberTitle,
            color: colorScheme.primary,
            isDestructive: false,
            onTap: () => Navigator.push(
              context,
              CupertinoPageRoute<void>(
                builder: (_) =>
                    SafetyNumberPage(peerUid: member.userId.toString()),
              ),
            ),
          ),
          AppSpacing.verticalRegular,

          // ── 管理员操作区（底部 ActionSheet 聚合） ──
          if (canMute) ...[
            if (isMuted)
              _buildActionButton(
                label: t.chat.unmuteMember,
                color: colorScheme.primary,
                onTap: _onUnmuteTap,
              )
            else
              _buildActionButton(
                label: t.chat.muteMember,
                color: AppColors.iosOrange,
                onTap: _onMuteTap,
              ),
            AppSpacing.verticalRegular,
            // 更多管理操作（设管理员 / 移出群聊）
            _buildActionButton(
              // TODO(i18n): t.common.moreActions
              label: t.group.moreActions,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              isDestructive: false,
              onTap: () => _showManageSheet(member),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileCard(GroupMemberModel member, ColorScheme colorScheme) {
    final displayName = member.alias.isNotEmpty
        ? member.alias
        : member.nickname;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMedium),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.regular),
        child: Row(
          children: [
            Avatar(imgUri: member.avatar, width: 56, height: 56),
            AppSpacing.horizontalMedium,
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
                    AppSpacing.verticalTiny,
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.medium,
      ),
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
    required VoidCallback? onTap,
    required Color color,
    bool isDestructive = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: isDestructive
          ? CupertinoButton(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(vertical: 12),
              borderRadius: AppRadius.borderRadiusMedium,
              color: color.withValues(alpha: 0.1),
              onPressed: onTap,
              child: Text(
                label,
                style: context.textStyle(
                  FontSizeType.body,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            )
          : CupertinoButton.filled(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(vertical: 12),
              borderRadius: AppRadius.borderRadiusMedium,
              onPressed: onTap,
              child: Text(
                label,
                style: context.textStyle(
                  FontSizeType.body,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
    );
  }

  /// 更多管理操作（底部 ActionSheet）
  void _showManageSheet(GroupMemberModel member) {
    final currentUid = UserRepoLocal.to.currentUid;
    final isOwner = _myRole == 4;
    final isTargetSelf = member.userId.toString() == currentUid;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          // 设为/取消管理员（仅群主可操作，且不能操作自己）
          if (isOwner && !isTargetSelf)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmToggleAdmin(member);
              },
              child: Text(
                member.role == 3 ? t.common.removeAdmin : t.group.setAdmin,
              ),
            ),
          // 移出群聊（仅管理员/群主，不能操作自己/群主）
          if (canMuteGroupMember(
                currentUserId: currentUid,
                currentRole: _myRole,
                targetUserId: member.userId.toString(),
                targetRole: member.role,
              ) &&
              !isTargetSelf &&
              member.role != 4)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _confirmKickMember(member);
              },
              child: Text(t.common.removeMember),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: Text(t.common.buttonCancel),
        ),
      ),
    );
  }

  /// 确认设为/取消管理员（role: 1 成员  3 管理员）
  Future<void> _confirmToggleAdmin(GroupMemberModel member) async {
    final isCurrentlyAdmin = member.role == 3;
    final newRole = isCurrentlyAdmin ? 1 : 3;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(isCurrentlyAdmin ? t.common.removeAdmin : t.group.setAdmin),
        content: Text(
          isCurrentlyAdmin
              ? t.common.removeAdminConfirm
              : t.common.setAdminConfirm,
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    AppLoading.show();
    try {
      final ok = await GroupMemberApi().updateRole(
        gid: widget.groupId,
        userId: member.userId.toString(),
        role: newRole,
      );
      if (!mounted) return;
      AppLoading.dismiss();

      if (ok) {
        setState(() {
          _member = _member!.copyWith(role: newRole);
          _anyChange = true;
        });
        AppLoading.showSuccess(
          isCurrentlyAdmin
              ? t.common.removeAdminSuccess
              : t.common.setAdminSuccess,
        );
      }
      // 失败提示已由 GroupMemberApi.updateRole 透传服务端 msg，无需兜底文案。
    } on Exception catch (e) {
      iPrint('[GroupMemberDetail] 设置管理员失败: $e');
      AppLoading.dismiss();
      if (mounted) {
        AppLoading.showError(
          isCurrentlyAdmin
              ? t.common.removeAdminFailed
              : t.common.setAdminFailed,
        );
      }
    }
  }

  /// 确认移出群聊
  Future<void> _confirmKickMember(GroupMemberModel member) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(t.common.removeMember),
        content: Text(t.common.kickMemberConfirm),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.common.buttonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    AppLoading.show();
    try {
      final ok = await RemoveMemberService().leaveGroup(widget.groupId, [
        member.userId.toString(),
      ]);
      if (!mounted) return;
      AppLoading.dismiss();

      if (ok) {
        _anyChange = true;
        AppLoading.showSuccess(t.common.kickMemberSuccess);
        if (mounted) context.pop(true);
      }
      // 失败提示已由 GroupMemberApi.leave 透传服务端 msg，无需兜底文案。
    } on Exception catch (e) {
      iPrint('[GroupMemberDetail] 踢出成员失败: $e');
      AppLoading.dismiss();
      if (mounted) AppLoading.showError(t.common.kickMemberFailed);
    }
  }
}
