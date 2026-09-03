/// T9 (WP5) — Workspace 视图共享组件（空态/加载态/错误态/归档横幅/角色徽标）
///
/// Day-1 Bar：所有区块必须有可见的空态与加载态设计，禁止空白占位；
/// 颜色/间距/字号全部经 AppColors / AppSpacing / FontSizeType 消费。
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/http/http_exceptions.dart' show HttpException;
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/store/model/workspace_model.dart';

/// 归档横幅（T9 archived 规则：archived workspace 显示横幅 + 写操作禁用）。
class WorkspaceArchivedBanner extends StatelessWidget {
  const WorkspaceArchivedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('workspace-archived-banner'),
      width: double.infinity,
      padding: AppSpacing.allMedium,
      color: AppColors.warning.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.archivebox,
            size: 18,
            color: AppColors.warning,
          ),
          AppSpacing.horizontalSmall,
          Expanded(
            child: Text(
              t.workspace.archivedBanner,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用区块卡片（Overview / 列表区块容器）。
class WorkspaceSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const WorkspaceSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: AppSpacing.allRegular,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.regular),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          AppSpacing.verticalRegular,
          child,
        ],
      ),
    );
  }
}

/// 空态视图（icon + 主文案 + 副文案 + 可选动作区）。
class WorkspaceEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const WorkspaceEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.allXLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            AppSpacing.verticalRegular,
            Text(title, style: theme.textTheme.titleSmall),
            AppSpacing.verticalSmall,
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (actions.isNotEmpty) ...[AppSpacing.verticalRegular, ...actions],
          ],
        ),
      ),
    );
  }
}

/// 错误态视图（消息 + 重试按钮）。
class WorkspaceErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final List<Widget> actions;

  const WorkspaceErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: AppSpacing.allXLarge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 48,
              color: AppColors.iosRed,
            ),
            AppSpacing.verticalRegular,
            Text(
              message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalRegular,
            OutlinedButton(
              key: const ValueKey('workspace-error-retry'),
              onPressed: onRetry,
              child: Text(t.common.buttonRetry),
            ),
            if (actions.isNotEmpty) ...[AppSpacing.verticalSmall, ...actions],
          ],
        ),
      ),
    );
  }
}

/// 加载态（列表骨架占位，非空白）。
class WorkspaceLoadingView extends StatelessWidget {
  const WorkspaceLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xLarge),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

/// 工作区成员角色徽标（Owner / Member / Guest）。
///
/// 跨域术语约束：仅描述「工作区成员」角色，与群成员/频道订阅者无关。
class WorkspaceRoleBadge extends StatelessWidget {
  final WorkspaceMemberRole role;

  const WorkspaceRoleBadge({super.key, required this.role});

  Color get _color {
    switch (role) {
      case WorkspaceMemberRole.owner:
        return AppColors.primary;
      case WorkspaceMemberRole.member:
        return AppColors.success;
      case WorkspaceMemberRole.guest:
        return AppColors.slateText;
    }
  }

  String label(WorkspaceMemberRole r) {
    switch (r) {
      case WorkspaceMemberRole.owner:
        return t.workspace.roleOwner;
      case WorkspaceMemberRole.member:
        return t.workspace.roleMember;
      case WorkspaceMemberRole.guest:
        return t.workspace.roleGuest;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('workspace-role-badge-${role.wireName}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.medium,
        vertical: AppSpacing.tiny,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.tiny * 3),
      ),
      child: Text(
        label(role),
        // 徽标小字：注释档 caption2（11px）
        style: TextStyle(fontSize: FontSizeType.caption2.size, color: _color),
      ),
    );
  }
}

/// 归档写守卫提示（服务端 980 错误码消息原样透出）。
void showWorkspaceArchivedToast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
  );
}

/// 统一异常转用户消息（WorkspaceApiException 用服务端中文消息）。
String workspaceErrorMessage(Object error) {
  if (error is WorkspaceApiException) return error.message;
  // 组件 http 异常（断网 NetworkException 等）自带人话 message，直接取；
  // 不要走 toString()（会显示 "Instance of X" 字面量）。
  if (error is HttpException) return error.message;
  return error.toString();
}
