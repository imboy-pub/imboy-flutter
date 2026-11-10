/// 首页分发：personal 为个人布局，workspace 为企业布局。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/app_core/feature_flags/feature_revision_provider.dart';
import 'package:imboy/config/router/generated_product_feature_routes.dart';

import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_bootstrap.dart';

import 'experience_provider.dart';
import 'personal_navigation_layout.dart';

/// Chat 体验壳业务接线层（路由挂载点消费的 widget）。
class ChatShellBootstrap extends ConsumerWidget {
  const ChatShellBootstrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(featureRevisionProvider);
    final experience = ref.watch(productExperienceProvider);
    return switch (experience) {
      // 现状包壳：移动端底部导航 / 桌面三栏，宽度自适应见 chat_shell_breakpoint
      ProductExperience.personal => PersonalNavigationLayout(
        channelAvailable:
            AppFeatureRegistry.isEnabled(FeatureKeys.channel) &&
            compiledChannelListPage() != null,
        mobileBuilder: (restoredIndex) =>
            BottomNavigationPage(restoredIndex: restoredIndex),
        desktopEntry: const WebShellBootstrap(),
      ),
      // workspace 只承载企业布局。
      ProductExperience.workspace => const WorkspaceShellBootstrap(),
    };
  }
}
