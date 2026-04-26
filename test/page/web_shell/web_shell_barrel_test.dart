/// Phase 1.1.j — Web Shell barrel export 契约测试
///
/// 通过单一 import 验证所有公共 API 可访问。这避免未来重构时不小心从
/// barrel 漏掉某个 export（导致下游 1.1.h.1 调用方 import 失败）。
///
/// 测试策略：每个被导出的符号（enum / class / function / const / typedef）
/// 都在测试中至少被引用一次，编译通过即代表 export 完整。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 仅一个 import — 验证 barrel 完整性
import 'package:imboy/page/web_shell/web_shell.dart';

void main() {
  group('web_shell.dart barrel — 1.1.a 断点 API', () {
    test('exports WebShellLayout enum (3 values)', () {
      expect(WebShellLayout.values, hasLength(3));
      expect(WebShellLayout.mobile.index, 0);
      expect(WebShellLayout.twoColumn.index, 1);
      expect(WebShellLayout.threeColumn.index, 2);
    });

    test('exports resolveShellLayout(double)', () {
      expect(resolveShellLayout(800), WebShellLayout.mobile);
      expect(resolveShellLayout(1000), WebShellLayout.twoColumn);
      expect(resolveShellLayout(1500), WebShellLayout.threeColumn);
    });
  });

  group('web_shell.dart barrel — 1.1.b 状态 + sealed selection API', () {
    test('exports WebShellState with default ctor', () {
      const state = WebShellState();
      expect(state.currentTab, 0);
      expect(state.selectedItem, isNull);
    });

    test('exports WebSelection sealed + 4 variants', () {
      const WebSelection chat =
          ChatSelection(peerId: 'p', chatType: 'C2C');
      const WebSelection contact = ContactSelection(uid: 'u');
      const WebSelection channel = ChannelSelection(channelId: 'c');
      const WebSelection mine = MineSelection();
      // 编译通过即代表 sealed + 4 子类全部 exported
      expect(chat, isA<ChatSelection>());
      expect(contact, isA<ContactSelection>());
      expect(channel, isA<ChannelSelection>());
      expect(mine, isA<MineSelection>());
    });
  });

  group('web_shell.dart barrel — 1.1.c Riverpod API', () {
    test('exports webShellProvider + WebShellNotifier', () {
      // 仅检查类型存在性（不创建 ProviderContainer 避免引入额外开销）
      expect(webShellProvider, isNotNull);
      expect(WebShellNotifier.maxTabIndex, 3);
    });
  });

  group('web_shell.dart barrel — 1.1.d-g widget API', () {
    test('exports WebWelcomePanel', () {
      const widget = WebWelcomePanel(title: 'T');
      expect(widget, isA<StatelessWidget>());
    });

    test('exports WebNavRail + WebNavItem', () {
      const item = WebNavItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'M',
      );
      expect(item, isA<WebNavItem>());

      final rail = WebNavRail(
        items: const [item, item],
        currentIndex: 0,
        onTap: (_) {},
      );
      expect(rail, isA<StatelessWidget>());
    });

    test('exports WebMiddlePanel', () {
      // 不能用 const：构造器 assert(tabs.length >= 2) 在 const 上下文中
      // 无法编译期求值（List.length 是运行时属性）
      final panel = WebMiddlePanel(
        currentTab: 0,
        tabs: const [SizedBox(), SizedBox()],
      );
      expect(panel, isA<StatelessWidget>());
    });

    test('exports WebMainPanel', () {
      final panel = WebMainPanel(
        selection: null,
        welcome: const SizedBox(),
        chatBuilder: (_) => const SizedBox(),
        contactBuilder: (_) => const SizedBox(),
        channelBuilder: (_) => const SizedBox(),
        mineBuilder: (_) => const SizedBox(),
      );
      expect(panel, isA<StatelessWidget>());
    });
  });

  group('web_shell.dart barrel — 1.1.h.0 工厂 API', () {
    test('exports buildWebNavItems function', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
      );
      expect(items, hasLength(4));
    });

    test('exports kWebNavItemCount + kWebNavTab* 常量', () {
      expect(kWebNavItemCount, 4);
      expect(kWebNavTabMessage, 0);
      expect(kWebNavTabContact, 1);
      expect(kWebNavTabChannel, 2);
      expect(kWebNavTabMine, 3);
    });
  });

  group('web_shell.dart barrel — 端到端组合（确保 API 协同可用）', () {
    test('用 barrel 内 API 完整组合一个 navItems + state', () {
      // 构造 nav items
      final items = buildWebNavItems(
        messageLabel: '消息',
        contactLabel: '联系人',
        channelLabel: '频道',
        mineLabel: '我的',
        messageBadgeCount: 5,
      );
      expect(items[kWebNavTabMessage].label, '消息');
      expect(items[kWebNavTabMessage].badgeCount, 5);

      // 构造 state
      final state = const WebShellState().copyWith(
        currentTab: kWebNavTabContact,
        selectedItem: const ContactSelection(uid: 'u1'),
      );
      expect(state.currentTab, 1);
      expect(state.selectedItem, const ContactSelection(uid: 'u1'));

      // 验证布局
      final layout = resolveShellLayout(1200);
      expect(layout, WebShellLayout.threeColumn);
    });
  });
}
