/// workspace 首页只承载企业布局；未选择企业时返回个人布局。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/chat_shell/chat_shell_page.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import 'enterprise_shell_page.dart';

class WorkspaceShellPage extends ConsumerWidget {
  const WorkspaceShellPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shell = ref.watch(workspaceShellProvider);
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    if (uid.isEmpty || shell.organizationId.isEmpty) {
      return const ChatShellPage(
        mobileEntry: BottomNavigationPage(),
        desktopEntry: WebShellBootstrap(),
      );
    }
    return EnterpriseShellPage(
      key: ValueKey((uid, shell.organizationId, shell.currentWorkspaceId)),
      accountKey: uid,
      organizationId: shell.organizationId,
    );
  }
}
