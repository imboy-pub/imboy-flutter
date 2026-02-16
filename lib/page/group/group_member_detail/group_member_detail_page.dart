import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/easy_dialog.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_member_detail/group_member_detail_provider.dart';
import 'package:imboy/page/group/group_member_detail/group_member_detail_service.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 群成员详情服务 Provider
final groupMemberDetailServiceProvider = Provider<GroupMemberDetailService>(
  (ref) => GroupMemberDetailService(),
);

/// 群成员详情页面
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
  StreamSubscription? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final notifier = ref.read(groupMemberDetailProvider.notifier);
    final service = ref.read(groupMemberDetailServiceProvider);

    notifier.setLoading(true);

    // 获取成员信息
    GroupMemberModel? member = await service.getMemberInfo(
      groupId: widget.groupId,
      userId: widget.userId,
    );

    if (member == null) {
      notifier.setError(t.noData);
      return;
    }

    notifier.setMember(member);

    // 获取当前用户角色
    int myRole = await service.getMyRole(widget.groupId);
    notifier.setMyRole(myRole);

    notifier.setLoading(false);

    if (mounted) {
      setState(() {});
    }
  }

  /// 构建角色标签
  Widget _buildRoleBadge(int role) {
    final t = context.t;
    String label;
    Color color;

    switch (role) {
      case 4:
        label = t.groupOwner;
        color = Colors.orange;
        break;
      case 3:
        label = t.groupAdmin;
        color = Colors.blue;
        break;
      default:
        label = t.groupMember;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: ThemeManager.instance.getTextStyle(
              FontSizeType.medium,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: ThemeManager.instance.getTextStyle(
              FontSizeType.medium,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final buttonColor = color ?? (isDestructive ? Colors.red : theme.colorScheme.primary);

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderRadiusMedium,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: buttonColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: ThemeManager.instance.getTextStyle(
                FontSizeType.medium,
                color: buttonColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  /// 显示禁言时长选择
  Future<void> _showMuteDurationDialog() async {
    final t = context.t;
    final service = ref.read(groupMemberDetailServiceProvider);
    final notifier = ref.read(groupMemberDetailProvider.notifier);
    final state = ref.read(groupMemberDetailProvider);

    final durations = [
      {'label': t.muteDuration1hour, 'value': 3600},
      {'label': t.muteDuration6hours, 'value': 21600},
      {'label': t.muteDuration12hours, 'value': 43200},
      {'label': t.muteDuration1day, 'value': 86400},
      {'label': t.muteDuration3days, 'value': 259200},
      {'label': t.muteDuration7days, 'value': 604800},
      {'label': t.muteDurationPermanent, 'value': 31536000}, // 1 year as "permanent"
    ];

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  t.muteDuration,
                  style: ThemeManager.instance.getTextStyle(
                    FontSizeType.large,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...durations.map((item) {
                return ListTile(
                  title: Text(item['label'] as String),
                  onTap: () async {
                    Navigator.pop(context);
                    EasyLoading.show(status: t.loading);

                    bool success = await service.muteMember(
                      groupId: widget.groupId,
                      userId: widget.userId,
                      duration: item['value'] as int,
                    );

                    EasyLoading.dismiss();

                    if (success) {
                      EasyLoading.showSuccess(t.muteMemberSuccess);
                      notifier.setMuteStatus(
                        true,
                        mutedUntil: DateTime.now().millisecondsSinceEpoch ~/ 1000 + (item['value'] as int),
                      );
                      if (mounted) setState(() {});
                    } else {
                      EasyLoading.showError(t.muteMemberFailed);
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// 设置管理员
  Future<void> _setAdmin() async {
    final t = context.t;
    final service = ref.read(groupMemberDetailServiceProvider);
    final notifier = ref.read(groupMemberDetailProvider.notifier);

    EasyDialog.showWarning(
      context: context,
      title: t.tipTips,
      content: Text(t.setAdminConfirm),
      confirmText: t.buttonConfirm,
      cancelText: t.buttonCancel,
      onConfirm: () async {
        EasyLoading.show(status: t.loading);

        bool success = await service.setAdmin(
          groupId: widget.groupId,
          userId: widget.userId,
        );

        EasyLoading.dismiss();

        if (success) {
          EasyLoading.showSuccess(t.setAdminSuccess);
          notifier.updateMemberRole(3);
          if (mounted) setState(() {});
        } else {
          EasyLoading.showError(t.setAdminFailed);
        }
      },
    );
  }

  /// 取消管理员
  Future<void> _removeAdmin() async {
    final t = context.t;
    final service = ref.read(groupMemberDetailServiceProvider);
    final notifier = ref.read(groupMemberDetailProvider.notifier);

    EasyDialog.showWarning(
      context: context,
      title: t.tipTips,
      content: Text(t.removeAdminConfirm),
      confirmText: t.buttonConfirm,
      cancelText: t.buttonCancel,
      onConfirm: () async {
        EasyLoading.show(status: t.loading);

        bool success = await service.removeAdmin(
          groupId: widget.groupId,
          userId: widget.userId,
        );

        EasyLoading.dismiss();

        if (success) {
          EasyLoading.showSuccess(t.removeAdminSuccess);
          notifier.updateMemberRole(1);
          if (mounted) setState(() {});
        } else {
          EasyLoading.showError(t.removeAdminFailed);
        }
      },
    );
  }

  /// 禁言成员
  Future<void> _muteMember() async {
    await _showMuteDurationDialog();
  }

  /// 取消禁言
  Future<void> _unmuteMember() async {
    final t = context.t;
    final service = ref.read(groupMemberDetailServiceProvider);
    final notifier = ref.read(groupMemberDetailProvider.notifier);

    EasyDialog.showWarning(
      context: context,
      title: t.tipTips,
      content: Text(t.unmuteMemberConfirm),
      confirmText: t.buttonConfirm,
      cancelText: t.buttonCancel,
      onConfirm: () async {
        EasyLoading.show(status: t.loading);

        bool success = await service.muteMember(
          groupId: widget.groupId,
          userId: widget.userId,
          duration: 0, // 0 表示取消禁言
        );

        EasyLoading.dismiss();

        if (success) {
          EasyLoading.showSuccess(t.unmuteMemberSuccess);
          notifier.setMuteStatus(false);
          if (mounted) setState(() {});
        } else {
          EasyLoading.showError(t.unmuteMemberFailed);
        }
      },
    );
  }

  /// 踢出成员
  Future<void> _kickMember() async {
    final t = context.t;
    final service = ref.read(groupMemberDetailServiceProvider);

    EasyDialog.showWarning(
      context: context,
      title: t.warning,
      content: Text(t.kickMemberConfirm),
      confirmText: t.buttonConfirm,
      cancelText: t.buttonCancel,
      onConfirm: () async {
        EasyLoading.show(status: t.loading);

        bool success = await service.kickMember(
          groupId: widget.groupId,
          userId: widget.userId,
        );

        EasyLoading.dismiss();

        if (success) {
          EasyLoading.showSuccess(t.kickMemberSuccess);
          if (mounted) {
            context.pop(true); // 返回 true 表示成员已被移除
          }
        } else {
          EasyLoading.showError(t.kickMemberFailed);
        }
      },
    );
  }

  /// 转让群主
  Future<void> _transferGroup() async {
    final t = context.t;
    final service = ref.read(groupMemberDetailServiceProvider);

    EasyDialog.showWarning(
      context: context,
      title: t.warning,
      content: Text(t.transferGroupConfirm),
      confirmText: t.buttonConfirm,
      cancelText: t.buttonCancel,
      onConfirm: () async {
        EasyLoading.show(status: t.loading);

        bool success = await service.transferGroup(
          groupId: widget.groupId,
          newOwnerUid: widget.userId,
        );

        EasyLoading.dismiss();

        if (success) {
          EasyLoading.showSuccess(t.transferGroupSuccess);
          if (mounted) {
            context.pop(true); // 返回 true 表示群主已转让
          }
        } else {
          EasyLoading.showError(t.transferGroupFailed);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(groupMemberDetailProvider);
    final member = state.member;

    // 检查是否是自己
    bool isSelf = widget.userId == UserRepoLocal.to.currentUid;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.memberDetail,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : member == null
              ? Center(child: Text(t.noData))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 成员信息卡片
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: AppRadius.borderRadiusRegular,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // 头像和昵称
                            Row(
                              children: [
                                Avatar(
                                  imgUri: member.avatar,
                                  width: 70,
                                  height: 70,
                                  onTap: () {
                                    context.push(
                                      '/people_info/${member.userId}',
                                      extra: {'scene': 'group_member'},
                                    );
                                  },
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              member.alias.isEmpty
                                                  ? member.nickname
                                                  : member.alias,
                                              style: ThemeManager.instance
                                                  .getTextStyle(
                                                FontSizeType.xLarge,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          _buildRoleBadge(member.role),
                                        ],
                                      ),
                                      if (member.alias.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          '${t.remark}: ${member.alias}',
                                          style: ThemeManager.instance
                                              .getTextStyle(
                                            FontSizeType.small,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                      if (member.sign.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          member.sign,
                                          style: ThemeManager.instance
                                              .getTextStyle(
                                            FontSizeType.small,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.6),
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
                          ],
                        ),
                      ),

                      // 成员信息
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: AppRadius.borderRadiusRegular,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              icon: Icons.person_outline,
                              label: t.memberRole,
                              value: member.role == 4
                                  ? t.groupOwner
                                  : member.role == 3
                                      ? t.groupAdmin
                                      : t.groupMember,
                            ),
                            ModernDivider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: colorScheme.outline.withValues(alpha: 0.1),
                            ),
                            _buildInfoRow(
                              icon: Icons.access_time,
                              label: t.joinTime,
                              value: DateTimeHelper.formatDateTime(
                                member.createdAt,
                              ),
                            ),
                            if (state.isMuted && state.mutedUntil != null) ...[
                              ModernDivider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: colorScheme.outline
                                    .withValues(alpha: 0.1),
                              ),
                              _buildInfoRow(
                                icon: Icons.volume_off_outlined,
                                label: t.muteUntil,
                                value: DateTimeHelper.formatDateTime(
                                  state.mutedUntil!,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // 管理操作（仅管理员和群主可见，且不是自己）
                      if (state.amAdmin && !isSelf) ...[
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            t.manage,
                            style: ThemeManager.instance.getTextStyle(
                              FontSizeType.medium,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: AppRadius.borderRadiusRegular,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // 设置/取消管理员（仅群主可见）
                              if (state.canSetAdmin && member.role == 1)
                                _buildActionButton(
                                  icon: Icons.admin_panel_settings_outlined,
                                  label: t.setAdmin,
                                  onTap: _setAdmin,
                                ),
                              if (state.canRemoveAdmin)
                                _buildActionButton(
                                  icon: Icons.remove_moderator_outlined,
                                  label: t.removeAdmin,
                                  onTap: _removeAdmin,
                                ),
                              if (state.canRemoveAdmin ||
                                  (state.canSetAdmin && member.role == 1))
                                ModernDivider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color:
                                      colorScheme.outline.withValues(alpha: 0.1),
                                ),
                              // 禁言/取消禁言
                              if (state.canMute)
                                state.isMuted
                                    ? _buildActionButton(
                                        icon: Icons.volume_up_outlined,
                                        label: t.unmuteMember,
                                        onTap: _unmuteMember,
                                      )
                                    : _buildActionButton(
                                        icon: Icons.volume_off_outlined,
                                        label: t.muteMember,
                                        onTap: _muteMember,
                                      ),
                              if (state.canMute)
                                ModernDivider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color:
                                      colorScheme.outline.withValues(alpha: 0.1),
                                ),
                              // 踢出成员
                              if (state.canKick)
                                _buildActionButton(
                                  icon: Icons.person_remove_outlined,
                                  label: t.kickMember,
                                  onTap: _kickMember,
                                  isDestructive: true,
                                ),
                            ],
                          ),
                        ),
                      ],

                      // 转让群主（仅群主可见，且不是自己）
                      if (state.canTransfer) ...[
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            t.groupManagement,
                            style: ThemeManager.instance.getTextStyle(
                              FontSizeType.medium,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: AppRadius.borderRadiusRegular,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: _buildActionButton(
                            icon: Icons.swap_horiz,
                            label: t.transferGroup,
                            onTap: _transferGroup,
                            color: Colors.orange,
                          ),
                        ),
                      ],

                      // 发送消息按钮
                      const SizedBox(height: 24),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              context.push('/chat/C2C/${member.userId}');
                            },
                            icon: const Icon(Icons.message_outlined),
                            label: Text(t.messageCall),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.borderRadiusRegular,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}
