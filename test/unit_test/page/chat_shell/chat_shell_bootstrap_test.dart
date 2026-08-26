/// T2 (WP1) — ChatShellBootstrap 接线层测试
///
/// 完整 widget mount 因 ChatShellPage 内的 BottomNavigationPage /
/// WebShellBootstrap 拉 4 子页 init + WebSocketService.openSocket 副作用 +
/// SqliteService 多源依赖超出 ROI（镜像 bottom_navigation_page_test.dart
/// 头注决策），本文件聚焦：
///   1. **构造契约**（const widget / ConsumerWidget / 无构造参数）
///   2. **experience 分发的组合覆盖说明**：
///      - 默认 experience=chat → experience_provider_test（无缓存 → chat）
///      - chat → ChatShellPage（mobile/desktop 断点分发）→
///        chat_shell_page_test
///      - 未知值/字段缺失降级 → experience_provider_test
///      完整链路（登录 → /bottom_navigation → 壳 → 首页）由 E2E/真机验证。
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat_shell/chat_shell_bootstrap.dart';
import 'package:imboy/page/chat_shell/chat_shell_page.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';

void main() {
  group('ChatShellBootstrap construction contract', () {
    test('widget is const-constructible (no required args)', () {
      const bootstrap = ChatShellBootstrap();
      expect(bootstrap, isA<ConsumerWidget>());
      expect(bootstrap, isA<ChatShellBootstrap>());
    });

    test('default key is null', () {
      const bootstrap = ChatShellBootstrap();
      expect(bootstrap.key, isNull);
    });

    test('accepts custom key', () {
      const key = ValueKey('chat_shell_bootstrap_test');
      const bootstrap = ChatShellBootstrap(key: key);
      expect(bootstrap.key, key);
    });
  });

  group('experience=chat 渲染 ChatShell 的组合前提（组合覆盖）', () {
    test('默认（无缓存）experience=chat（见 experience_provider_test 全量用例）', () {
      // StorageService 由 flutter_test_config 全局初始化；本用例不写缓存，
      // 固化「默认 chat」前提——ChatShellBootstrap.build 对该值 switch 后
      // 渲染 ChatShellPage（chat 分支）。
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(productExperienceProvider), ProductExperience.chat);
    });

    test('ChatShellPage 可被 bootstrap 的 chat 分支构造（const 组合）', () {
      // 与 bootstrap 内部 const 表达式同构：证明两个 entry 均 const 可构造
      // （BottomNavigationPage / WebShellBootstrap 的 const 契约在各自模块测试）
      const page = ChatShellPage(
        mobileEntry: _ConstMarker(),
        desktopEntry: _ConstMarker(),
      );
      expect(page.mobileEntry, isA<_ConstMarker>());
      expect(page.desktopEntry, isA<_ConstMarker>());
    });
  });
}

class _ConstMarker extends ConsumerWidget {
  const _ConstMarker();

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SizedBox();
}
