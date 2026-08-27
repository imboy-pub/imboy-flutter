/// T2 (WP1) / T8 (WP5) — ChatShell 业务接线层（experience 消费 + 现有首页注入）
///
/// 把现有 Chat 首页原样包进 ChatShell：
/// - `experience = chat` → [ChatShellPage]，内容区注入现有两个入口
///   （移动端 BottomNavigationPage / 桌面端 WebShellBootstrap），与挂载
///   进路由前的实例化方式完全一致（纯包装，零业务逻辑改动）
/// - `experience = workspace` → [WorkspaceShellBootstrap]（WP5/T8）：
///   五项导航（Overview/Projects/Channels/Groups/Members）+ 全局 DM 区，
///   无工作区时空态运行（创建入口）；branding 主题作用域见 T12
///
/// experience 的来源链路见 `experience_provider.dart`（/api/v1/init 下发 →
/// initConfig 写 StorageService 缓存 → provider 读取；缺失/未知值降级 chat）。
///
/// 无单元测试：本 widget 是简单接线层，关键逻辑全在
/// [productExperienceProvider]（纯函数 + 缓存链路已测）与 [ChatShellPage]
/// （断点分发已测）；真实 BottomNavigationPage / WebShellBootstrap 的完整
/// mount 依赖 4 子页 init + WebSocket + SQLite 副作用（见
/// bottom_navigation_page_test.dart 头注），由 E2E/真机验证。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_bootstrap.dart';

import 'chat_shell_page.dart';
import 'experience_provider.dart';

/// Chat 体验壳业务接线层（路由挂载点消费的 widget）。
class ChatShellBootstrap extends ConsumerWidget {
  const ChatShellBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experience = ref.watch(productExperienceProvider);
    return switch (experience) {
      // 现状包壳：移动端底部导航 / 桌面三栏，宽度自适应见 chat_shell_breakpoint
      ProductExperience.chat => const ChatShellPage(
        mobileEntry: BottomNavigationPage(),
        desktopEntry: WebShellBootstrap(),
      ),
      // WP5/T8：Workspace 体验壳（五项导航 IA + 空态运行 + T12 branding 作用域）
      ProductExperience.workspace => const WorkspaceShellBootstrap(),
    };
  }
}
