/// T8 (WP5) — Workspace 壳全局区「账户 Sheet」（顶栏右侧 / 侧栏底部头像入口）
///
/// 形态（2026-08-31 UX 收敛二轮，用户拍板 T1+A1）：
/// 半屏 modal sheet 而非路由页面——上滑即返回，根除「个人资料无返回键」
/// 问题（此前 push 的 MinePage 是 tab 根页设计，无返回键）。
/// 与 personal 模式「我的」页差异化：不搬运钱包/红包等个人社交内容，
/// 身份卡展示「我在当前工作区的角色」，并内置工作区切换列表。
///
/// 结构：
/// - 身份卡：头像 / 昵称 / ID + 当前工作区角色徽标（Owner/Member/Guest，
///   经 workspaceMembersProvider 匹配当前 uid；未命中不显示）
/// - 工作区列表：当前项高亮，点击即切换（Slack You 页同构）
/// - 动作：编辑个人资料(/personal_info) / 我的收藏 / 设置
/// - 底部：工作模式（二级 ActionSheet） / 退出登录（destructive）
library;

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart'
    show WorkspaceRoleBadge;
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 全局区头像按钮：点击弹出账户 Sheet（顶栏右侧 / 侧栏底部复用）。
class WorkspaceAccountButton extends ConsumerWidget {
  const WorkspaceAccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userRepoProvider).currentUser;
    final avatar = user?.avatar ?? '';
    final initial = _initialOf(user?.nickname, user?.account);
    return IconButton(
      key: const ValueKey('workspace-shell-account-entry'),
      tooltip: context.t.account.profile,
      padding: EdgeInsets.zero,
      icon: CircleAvatar(
        radius: 14,
        backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar.isEmpty
            ? Text(
                initial,
                // 头像占位字：注释档 caption2（11px）
                style: TextStyle(fontSize: FontSizeType.caption2.size),
              )
            : null,
      ),
      onPressed: () => _openAccountSheet(context, ref),
    );
  }

  static String _initialOf(String? nickname, String? account) {
    final n = nickname ?? '';
    if (n.isNotEmpty) return n.substring(0, 1);
    final a = account ?? '';
    if (a.isNotEmpty) return a.substring(0, 1);
    return '?';
  }
}

Future<void> _openAccountSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    // 多工作区时列表可能超屏：受控高度 + 内部滚动
    isScrollControlled: true,
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => const _WorkspaceAccountSheet(),
  );
}

/// 账户 Sheet 本体（消费壳状态与成员数据，非路由——滑掉即返回）。
class _WorkspaceAccountSheet extends ConsumerWidget {
  const _WorkspaceAccountSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final shell = ref.watch(workspaceShellProvider);
    final user = ref.watch(userRepoProvider).currentUser;
    final current = shell.current;
    final myRole = _myRole(ref, current?.id ?? '', user?.uid ?? '');

    return SafeArea(
      top: false,
      child: Padding(
        padding: AppSpacing.allRegular,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IdentityCard(
              nickname: user?.nickname ?? '',
              account: user?.account ?? '',
              avatar: user?.avatar ?? '',
              role: myRole,
            ),
            AppSpacing.verticalSmall,
            // 工作区列表：当前项高亮，点击即切换
            _WorkspaceList(
              workspaces: shell.workspaces,
              currentId: shell.currentWorkspaceId,
              onSelect: (wsId) {
                Navigator.pop(context);
                ref.read(workspaceShellProvider.notifier).selectWorkspace(wsId);
              },
            ),
            AppSpacing.verticalSmall,
            _SheetActionTile(
              icon: CupertinoIcons.person_crop_circle,
              label: t.account.profile,
              onTap: () => _popAndPush(context, '/personal_info'),
            ),
            _SheetActionTile(
              icon: CupertinoIcons.star_fill,
              label: t.main.myFavorites,
              onTap: () => _popAndPush(context, '/favorites'),
            ),
            _SheetActionTile(
              icon: CupertinoIcons.gear,
              label: t.main.setting,
              onTap: () => _popAndPush(context, '/mine/setting'),
            ),
            const Divider(height: AppSpacing.xLarge),
            // 工作模式：叠层弹出二级弹层（不先关账户 sheet——sheet 的
            // context 关闭即 unmount，先关会导致 select 永远不执行）
            _SheetActionTile(
              icon: CupertinoIcons.rectangle_stack,
              label: t.workspace.experienceModeEntry,
              onTap: () => unawaited(
                _openExperienceModeSheet(context, ref, closeAccountSheet: true),
              ),
            ),
            _SheetActionTile(
              icon: CupertinoIcons.square_arrow_right,
              label: t.account.logOut,
              isDestructive: true,
              onTap: () => _popAndPush(context, '/logout_account'),
            ),
          ],
        ),
      ),
    );
  }

  /// 当前用户在当前工作区的角色；列表未命中（加载中/越页）→ null 不显示。
  WorkspaceMemberRole? _myRole(WidgetRef ref, String wsId, String uid) {
    if (wsId.isEmpty || uid.isEmpty) return null;
    return ref
        .watch(workspaceMembersProvider(wsId))
        .whenOrNull(
          data: (page) {
            for (final m in page.list) {
              if (m.userId == uid) return m.role;
            }
            return null;
          },
        );
  }

  static void _popAndPush(BuildContext context, String location) {
    Navigator.pop(context);
    context.push(location);
  }

  /// 工作模式二级选择（镜像设置页同名入口的本机偏好切换语义）。
  ///
  /// [closeAccountSheet]：选择成功后是否连带关闭账户 sheet（本 sheet 内
  /// 调用时传 true；ChatShellBootstrap watch provider 会自动切壳，
  /// 悬在 root navigator 上的账户 sheet 需手动收掉）。
  ///
  /// 注意全程使用账户 sheet 自己的 context：二级弹层返回结果时它必须
  /// 仍 mounted（不提前 pop），否则 select 会被 `!context.mounted` 拦截。
  static Future<void> _openExperienceModeSheet(
    BuildContext context,
    WidgetRef ref, {
    bool closeAccountSheet = false,
  }) async {
    final t = context.t;
    final current = ref.read(productExperienceProvider);
    final selected = await showCupertinoModalPopup<ProductExperience>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(t.workspace.experienceModeEntry),
        message: Text(t.workspace.experienceModeHint),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: current == ProductExperience.chat,
            onPressed: () =>
                Navigator.pop(sheetContext, ProductExperience.chat),
            child: Text(t.workspace.experienceModePersonal),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: current == ProductExperience.workspace,
            onPressed: () =>
                Navigator.pop(sheetContext, ProductExperience.workspace),
            child: Text(t.workspace.experienceModeWorkspace),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: Text(t.common.buttonCancel),
        ),
      ),
    );
    if (selected == null || selected == current || !context.mounted) return;
    try {
      await ref.read(productExperienceProvider.notifier).select(selected);
      // watch productExperienceProvider 的 ChatShellBootstrap 已自动切壳；
      // 无需 context.go（当前就在 /bottom_navigation，go 同路径是 no-op）
      if (closeAccountSheet && context.mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (context.mounted) {
        AppLoading.showError(t.common.settingFailedPleaseTryAgain);
      }
    }
  }
}

/// 身份卡：头像 + 昵称/ID + 工作区角色徽标。
class _IdentityCard extends StatelessWidget {
  final String nickname;
  final String account;
  final String avatar;
  final WorkspaceMemberRole? role;

  const _IdentityCard({
    required this.nickname,
    required this.account,
    required this.avatar,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? Text(
                  WorkspaceAccountButton._initialOf(nickname, account),
                  style: theme.textTheme.titleMedium,
                )
              : null,
        ),
        AppSpacing.horizontalRegular,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      nickname.isEmpty ? account : nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (role != null) ...[
                    AppSpacing.horizontalTiny,
                    WorkspaceRoleBadge(role: role!),
                  ],
                ],
              ),
              if (account.isNotEmpty)
                Text(
                  'ID: $account',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 工作区列表：当前项高亮 + check，点击即切换（Slack You 页同构）。
class _WorkspaceList extends StatelessWidget {
  final List<WorkspaceModel> workspaces;
  final String currentId;
  final ValueChanged<String> onSelect;

  const _WorkspaceList({
    required this.workspaces,
    required this.currentId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    if (workspaces.length <= 1) {
      // 单工作区：不渲染列表区（切换入口由概览页工作区卡片兜底）
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.medium,
            bottom: AppSpacing.tiny,
          ),
          child: Text(
            t.workspace.switchWorkspace,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final ws in workspaces)
          ListTile(
            key: ValueKey('workspace-account-sheet-ws-${ws.id}'),
            dense: true,
            title: Text(
              ws.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            trailing: ws.id == currentId
                ? Icon(
                    CupertinoIcons.check_mark,
                    color: theme.colorScheme.primary,
                  )
                : null,
            onTap: ws.id == currentId ? null : () => onSelect(ws.id),
          ),
      ],
    );
  }
}

/// Sheet 动作行（列表项）。
class _SheetActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SheetActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: color),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(color: color),
      ),
      trailing: const Icon(CupertinoIcons.chevron_right, size: 14),
      onTap: onTap,
    );
  }
}
