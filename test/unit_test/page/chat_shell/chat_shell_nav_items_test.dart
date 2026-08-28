/// T2 (WP1) — Chat Shell 导航项声明层纯函数测试
///
/// 镜像 `web_nav_items_factory_test.dart`：
/// - 输出长度与顺序契约（conversations → contacts → channels → mine）
/// - 图标与 BottomNavigationPage 逐项一致（Cupertino 系）
/// - label 透传
/// - channel 项受特性开关裁剪
/// - 值相等契约
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat_shell/chat_shell_nav_items.dart';

void main() {
  List<ChatShellNavItem> build({bool channelTabEnabled = true}) =>
      buildChatShellNavItems(
        conversationsLabel: 'M',
        contactsLabel: 'C',
        channelsLabel: 'H',
        mineLabel: 'I',
        channelTabEnabled: channelTabEnabled,
      );

  group('buildChatShellNavItems — 长度与顺序契约', () {
    test('channel 开启时返回 4 个 items（固定总数）', () {
      final items = build();
      expect(items, hasLength(kChatShellDestinationCount));
      expect(items, hasLength(4));
    });

    test('顺序：会话 → 联系人 → 频道 → 我的（对齐 BottomNavigationPage）', () {
      final items = build();
      expect(items.map((i) => i.destination).toList(), [
        ChatShellDestination.conversations,
        ChatShellDestination.contacts,
        ChatShellDestination.channels,
        ChatShellDestination.mine,
      ]);
    });

    test('label 透传', () {
      final items = build();
      expect(items[0].label, 'M');
      expect(items[1].label, 'C');
      expect(items[2].label, 'H');
      expect(items[3].label, 'I');
    });
  });

  group('buildChatShellNavItems — 图标契约（与 BottomNavigationPage 对齐）', () {
    test('会话：chat_bubble / chat_bubble_fill', () {
      final items = build();
      expect(items[0].icon, CupertinoIcons.chat_bubble);
      expect(items[0].activeIcon, CupertinoIcons.chat_bubble_fill);
    });

    test('联系人：person_2 / person_2_fill', () {
      final items = build();
      expect(items[1].icon, CupertinoIcons.person_2);
      expect(items[1].activeIcon, CupertinoIcons.person_2_fill);
    });

    test('频道：antenna_radiowaves_left_right（两态同图标）', () {
      final items = build();
      expect(items[2].icon, CupertinoIcons.antenna_radiowaves_left_right);
      expect(items[2].activeIcon, CupertinoIcons.antenna_radiowaves_left_right);
    });

    test('我的：person_circle / person_circle_fill', () {
      final items = build();
      expect(items[3].icon, CupertinoIcons.person_circle);
      expect(items[3].activeIcon, CupertinoIcons.person_circle_fill);
    });
  });

  group('buildChatShellNavItems — channel 特性开关', () {
    test('channelTabEnabled=false → 频道项被裁剪，其余 3 项保持顺序', () {
      final items = build(channelTabEnabled: false);
      expect(items, hasLength(3));
      expect(items.map((i) => i.destination).toList(), [
        ChatShellDestination.conversations,
        ChatShellDestination.contacts,
        ChatShellDestination.mine,
      ]);
    });
  });

  group('ChatShellNavItem 值契约', () {
    test('== / hashCode 按全部字段', () {
      const a = ChatShellNavItem(
        destination: ChatShellDestination.mine,
        icon: CupertinoIcons.person_circle,
        activeIcon: CupertinoIcons.person_circle_fill,
        label: 'I',
      );
      const b = ChatShellNavItem(
        destination: ChatShellDestination.mine,
        icon: CupertinoIcons.person_circle,
        activeIcon: CupertinoIcons.person_circle_fill,
        label: 'I',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('label 不同则不相等', () {
      const a = ChatShellNavItem(
        destination: ChatShellDestination.mine,
        icon: CupertinoIcons.person_circle,
        activeIcon: CupertinoIcons.person_circle_fill,
        label: 'I',
      );
      const b = ChatShellNavItem(
        destination: ChatShellDestination.mine,
        icon: CupertinoIcons.person_circle,
        activeIcon: CupertinoIcons.person_circle_fill,
        label: 'Me',
      );
      expect(a, isNot(b));
    });
  });

  group('ChatShellDestination 枚举契约', () {
    test('恰好 4 个值且按 BottomNavigationPage Tab 顺序', () {
      expect(ChatShellDestination.values, [
        ChatShellDestination.conversations,
        ChatShellDestination.contacts,
        ChatShellDestination.channels,
        ChatShellDestination.mine,
      ]);
    });
  });
}
