/// W2 (ZC-06) — Project 协作页共用视图组件
///
/// - [projectW2ViewMessage]：统一异常转用户消息（403 语义码 → 明确无权限
///   文案，不缓存豁免——每次进入重新校验由 autoDispose provider 保证）；
/// - [ProjectForbiddenView]：403 专属无权限态（图标 + 文案 + 重试）；
/// - [ProjectW2LoadMoreButton]：分页「加载更多」统一按钮（点击目标 ≥44pt）。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/workspace_api.dart' show WorkspaceApiException;
import 'package:imboy/page/workspace/workspace_view_widgets.dart'
    show workspaceErrorMessage;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// W2 视图错误消息：403 越权（非项目成员/非工作区成员）给明确无权限文案，
/// 其余沿用 workspace 透传规则（服务端消息原样）。
String projectW2ViewMessage(BuildContext context, Object error) {
  if (error is WorkspaceApiException && error.code == 403) {
    return context.t.workspace.projectNoPermission;
  }
  return workspaceErrorMessage(error);
}

/// error 是否为服务端 403 越权（非成员直访 / Guest 写被拒）。
bool isProjectForbiddenError(Object error) =>
    error is WorkspaceApiException && error.code == 403;

/// 403 无权限态（明确文案 + 重试；重试即重新校验，不缓存豁免）。
class ProjectForbiddenView extends StatelessWidget {
  final VoidCallback onRetry;

  const ProjectForbiddenView({super.key, required this.onRetry});

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
              CupertinoIcons.lock_shield,
              size: 48,
              color: AppColors.slateText,
            ),
            AppSpacing.verticalRegular,
            Text(
              context.t.workspace.projectNoPermission,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalRegular,
            OutlinedButton(
              key: const ValueKey('project-w2-forbidden-retry'),
              onPressed: onRetry,
              child: Text(context.t.common.buttonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

/// 统一「加载更多」按钮（TextButton 默认最小高度 44pt+）。
class ProjectW2LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ProjectW2LoadMoreButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        key: const ValueKey('project-w2-load-more'),
        onPressed: onPressed,
        child: Text(context.t.workspace.projectLoadMore),
      ),
    );
  }
}
