/// 企业布局接线：加载工作区并应用企业品牌主题。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/page/workspace_shell/workspace_branding_theme.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

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
      if (mounted &&
          ref.read(workspaceShellProvider).organizationId.isNotEmpty) {
        ref.read(workspaceShellProvider.notifier).initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider.select((user) => user?.uid ?? ''), (_, uid) {
      if (uid.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(workspaceShellProvider).organizationId.isNotEmpty) {
          ref.read(workspaceShellProvider.notifier).initialize();
        }
      });
    });
    final shell = ref.watch(workspaceShellProvider);
    final current = shell.current;
    if (shell.organizationId.isEmpty ||
        current == null ||
        !current.belongsToOrg(shell.organizationId)) {
      return const WorkspaceShellPage();
    }
    return WorkspaceBrandingScope(
      key: ValueKey('workspace-branding-scope-${current.id}'),
      branding: current.branding,
      child: const WorkspaceShellPage(),
    );
  }
}
