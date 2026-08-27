/// T8/T12 (WP5) — Workspace 体验壳业务接线层
///
/// experience=workspace 时（ChatShellBootstrap 分发，挂载点 /bottom_navigation）：
/// - 加载「我的工作区」（首次进入触发一次）
/// - 无工作区 → 空态 + 创建入口（壳可空态运行，T8 VALIDATE）
/// - 有工作区 → [WorkspaceBrandingScope]（T12：branding.primaryColor 作用域
///   覆盖，离开 workspace_shell 即还原）内渲染 [WorkspaceShellPage]
library;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_view_widgets.dart';
import 'package:imboy/page/workspace_shell/workspace_branding_theme.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class WorkspaceShellBootstrap extends ConsumerStatefulWidget {
  const WorkspaceShellBootstrap({super.key});

  @override
  ConsumerState<WorkspaceShellBootstrap> createState() =>
      _WorkspaceShellBootstrapState();
}

class _WorkspaceShellBootstrapState
    extends ConsumerState<WorkspaceShellBootstrap> {
  @override
  void initState() {
    super.initState();
    // 首帧后触发加载（避免 build 期 mutate provider）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(workspaceShellProvider.notifier).loadMine();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final shell = ref.watch(workspaceShellProvider);

    if (shell.isLoading && !shell.hasWorkspace) {
      return const Scaffold(body: WorkspaceLoadingView());
    }
    if (shell.error != null && !shell.hasWorkspace) {
      return Scaffold(
        body: WorkspaceErrorView(
          message: shell.error!,
          onRetry: () => ref.read(workspaceShellProvider.notifier).loadMine(),
        ),
      );
    }
    if (!shell.hasWorkspace) {
      return Scaffold(
        body: _NoWorkspaceEntry(
          onCreate: () => context.push('/workspace/create'),
          onRetry: () => ref.read(workspaceShellProvider.notifier).loadMine(),
        ),
      );
    }
    final current = shell.current;
    if (current == null) {
      return Scaffold(
        body: WorkspaceErrorView(
          message: t.workspace.emptyNoWorkspace,
          onRetry: () => ref.read(workspaceShellProvider.notifier).loadMine(),
        ),
      );
    }
    // T12：branding 主题作用域只包 workspace_shell 子树（离开即还原）
    return WorkspaceBrandingScope(
      key: ValueKey('workspace-branding-scope-${current.id}'),
      branding: current.branding,
      child: const WorkspaceShellPage(),
    );
  }
}

/// 空态：无任何工作区（3 分钟建站入口）。
class _NoWorkspaceEntry extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onRetry;

  const _NoWorkspaceEntry({required this.onCreate, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return WorkspaceEmptyView(
      icon: CupertinoIcons.rectangle_stack,
      title: t.workspace.pickerEmptyTitle,
      subtitle: t.workspace.pickerEmptySubtitle,
      actions: [
        FilledButton.icon(
          key: const ValueKey('workspace-empty-create-entry'),
          onPressed: onCreate,
          icon: const Icon(CupertinoIcons.add, size: 18),
          label: Text(t.workspace.createEntry),
        ),
        AppSpacing.verticalSmall,
        TextButton(onPressed: onRetry, child: Text(t.common.buttonRetry)),
      ],
    );
  }
}
