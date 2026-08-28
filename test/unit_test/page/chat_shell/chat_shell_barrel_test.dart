/// T2 (WP1) — Chat Shell barrel export 契约测试
///
/// 通过单一 import 验证所有公共 API 可访问（镜像 `web_shell_barrel_test.dart`），
/// 避免未来重构时从 barrel 漏掉某个 export 导致调用方 import 失败。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// 仅一个 import — 验证 barrel 完整性
import 'package:imboy/page/chat_shell/chat_shell.dart';

void main() {
  group('chat_shell.dart barrel — 断点 API', () {
    test('exports ChatShellLayout enum (2 values)', () {
      expect(ChatShellLayout.values, hasLength(2));
      expect(ChatShellLayout.mobile.index, 0);
      expect(ChatShellLayout.desktop.index, 1);
    });

    test('exports resolveChatShellLayout(double)', () {
      expect(resolveChatShellLayout(800), ChatShellLayout.mobile);
      expect(resolveChatShellLayout(1000), ChatShellLayout.desktop);
    });
  });

  group('chat_shell.dart barrel — 导航项声明层 API', () {
    test('exports ChatShellDestination enum + 工厂 + 常量', () {
      expect(ChatShellDestination.values, hasLength(4));
      expect(kChatShellDestinationCount, 4);

      final items = buildChatShellNavItems(
        conversationsLabel: 'm',
        contactsLabel: 'c',
        channelsLabel: 'h',
        mineLabel: 'i',
      );
      expect(items, hasLength(4));
      expect(items.first, isA<ChatShellNavItem>());
    });
  });

  group('chat_shell.dart barrel — experience 消费层 API', () {
    test('exports ProductExperience enum + 解析函数 + provider', () {
      expect(ProductExperience.values, hasLength(2));
      expect(ProductExperience.chat.wireName, 'chat');
      expect(ProductExperience.workspace.wireName, 'workspace');

      expect(parseProductExperience(null), ProductExperience.chat);
      expect(resolveProductExperienceFromPayload(null), ProductExperience.chat);
      expect(productExperienceProvider, isNotNull);
    });
  });

  group('chat_shell.dart barrel — widget API', () {
    testWidgets('exports ChatShellPage（占位 entry 可渲染）', (tester) async {
      await tester.pumpWidget(
        const ChatShellPage(
          mobileEntry: SizedBox(key: ValueKey('barrel-mobile')),
          desktopEntry: SizedBox(key: ValueKey('barrel-desktop')),
        ),
      );
      // 默认测试视口为 800x600（< 900）→ mobile 分支
      expect(find.byKey(const ValueKey('barrel-mobile')), findsOneWidget);
    });

    test('exports ChatShellBootstrap（const 可构造）', () {
      const bootstrap = ChatShellBootstrap();
      expect(bootstrap, isA<ConsumerWidget>());
    });
  });

  group('barrel 与 web_shell 命名隔离（product_profile 语义防混淆）', () {
    test('experience 值域是 chat|workspace（非 community|enterprise）', () {
      // §4.1 术语约束：product_experience 与既有 product_profile（版本/销售
      // 档位）是两个概念，wire 值不得混用
      expect(ProductExperience.values.map((e) => e.wireName).toSet(), {
        'chat',
        'workspace',
      });
    });
  });
}
