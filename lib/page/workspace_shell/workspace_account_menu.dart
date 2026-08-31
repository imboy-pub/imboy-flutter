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
    // CupertinoButton(padding: zero)：与右侧导航工具按钮同款解剖，44px 热区
    return CupertinoButton(
      key: const ValueKey('workspace-shell-account-entry'),
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: () => _openAccountSheet(context, ref),
      child: CircleAvatar(
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

/// 全局区工作区切换 chip：左上角常驻（2026-08-31 三轮收敛：恢复切换入口
/// 可见性——只藏在账户 Sheet 里用户找不到）。Slack / Notion 惯例位：
/// 左上 = 工作区上下文（图标 + 名称 + 下箭头），点击进「我的工作区」切换页。
class WorkspaceSwitcherChip extends ConsumerWidget {
  const WorkspaceSwitcherChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final current = ref.watch(workspaceShellProvider.select((s) => s.current));
    return CupertinoButton(
      key: const ValueKey('workspace-shell-switcher'),
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: () => context.push('/workspace'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.square_grid_2x2,
              size: 17,
              color: theme.colorScheme.onSurface,
            ),
            AppSpacing.horizontalTiny,
            Flexible(
              child: Text(
                current?.name ?? t.workspace.pickerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AppSpacing.horizontalTiny,
            Icon(
              CupertinoIcons.chevron_down,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
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
            // 工作模式直达切换（镜像 MinePage 同名入口：只有两种模式，
            // 点「切换到个人」直接切，免二次弹层）
            _SheetActionTile(
              icon: CupertinoIcons.person_circle,
              label: t.workspace.switchToPersonal,
              onTap: () => unawaited(
                _switchExperience(ProductExperience.chat, context, ref),
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

  /// 工作模式一键切换（本机首页偏好，可逆无损）。
  ///
  /// select 成功后 watch provider 的 ChatShellBootstrap 自动切壳，再收掉
  /// 账户 sheet（全程用 sheet 自己的 context，不提前 pop——context 关闭
  /// 即 unmount，先关会导致 select 被 mounted 守卫拦截，见设置页镜像实现）。
  static Future<void> _switchExperience(
    ProductExperience target,
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      await ref.read(productExperienceProvider.notifier).select(target);
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (context.mounted) {
        AppLoading.showError(context.t.common.settingFailedPleaseTryAgain);
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
