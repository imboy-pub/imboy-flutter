/// Phase 1.1.h.0 — Web Nav Items Factory 纯函数测试
///
/// 覆盖：
/// - 输出长度 = 4 (固定)
/// - 4 个 item 的图标与 BottomNavigationPage 一致（icon / activeIcon 契约）
/// - label 透传
/// - badge 计数透传 + 默认 0 + mine 不可配 (永远 0)
/// - 顺序与 kWebNavTab* 常量对齐
/// - 工厂常量值契约
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_nav_items_factory.dart';

void main() {
  group('buildWebNavItems — 长度与顺序契约', () {
    test('始终返回 4 个 items', () {
      final items = buildWebNavItems(
        messageLabel: 'm',
        contactLabel: 'c',
        channelLabel: 'h',
        mineLabel: 'i',
      );
      expect(items, hasLength(kWebNavItemCount));
      expect(items, hasLength(4));
    });

    test('顺序：消息 → 联系人 → 频道 → 我的', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
      );
      expect(items[kWebNavTabMessage].label, 'M');
      expect(items[kWebNavTabContact].label, 'C');
      expect(items[kWebNavTabChannel].label, 'H');
      expect(items[kWebNavTabMine].label, 'I');
    });
  });

  group('buildWebNavItems — 图标契约（与 BottomNavigationPage 对齐）', () {
    test('Tab 0 消息：chat_bubble_outline / chat_bubble', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
      );
      expect(items[0].icon, Icons.chat_bubble_outline);
      expect(items[0].activeIcon, Icons.chat_bubble);
    });

    test('Tab 1 联系人：people_alt_outlined / people_alt', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
      );
      expect(items[1].icon, Icons.people_alt_outlined);
      expect(items[1].activeIcon, Icons.people_alt);
    });

    test('Tab 2 频道：campaign_outlined / campaign', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
      );
      expect(items[2].icon, Icons.campaign_outlined);
      expect(items[2].activeIcon, Icons.campaign);
    });

    test('Tab 3 我的：person_outline / person', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
      );
      expect(items[3].icon, Icons.person_outline);
      expect(items[3].activeIcon, Icons.person);
    });
  });

  group('buildWebNavItems — label 透传', () {
    test('label 字段精确透传（含 i18n 占位 / 中文 / emoji）', () {
      final items = buildWebNavItems(
        messageLabel: '消息',
        contactLabel: 'Contacts',
        channelLabel: '频道 📢',
        mineLabel: 'Me',
      );
      expect(items[0].label, '消息');
      expect(items[1].label, 'Contacts');
      expect(items[2].label, '频道 📢');
      expect(items[3].label, 'Me');
    });

    test('空 label 不被特殊处理', () {
      final items = buildWebNavItems(
        messageLabel: '',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
      );
      expect(items[0].label, '');
    });
  });

  group('buildWebNavItems — badge 计数', () {
    test('默认所有 badgeCount = 0', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
      );
      for (final item in items) {
        expect(item.badgeCount, 0);
      }
    });

    test('messageBadgeCount 透传', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
        messageBadgeCount: 5,
      );
      expect(items[kWebNavTabMessage].badgeCount, 5);
      expect(items[kWebNavTabContact].badgeCount, 0);
      expect(items[kWebNavTabChannel].badgeCount, 0);
      expect(items[kWebNavTabMine].badgeCount, 0);
    });

    test('contactBadgeCount 透传', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
        contactBadgeCount: 3,
      );
      expect(items[kWebNavTabContact].badgeCount, 3);
      expect(items[kWebNavTabMessage].badgeCount, 0);
      expect(items[kWebNavTabChannel].badgeCount, 0);
      expect(items[kWebNavTabMine].badgeCount, 0);
    });

    test('channelBadgeCount 透传', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
        channelBadgeCount: 99,
      );
      expect(items[kWebNavTabChannel].badgeCount, 99);
      expect(items[kWebNavTabMessage].badgeCount, 0);
      expect(items[kWebNavTabContact].badgeCount, 0);
      expect(items[kWebNavTabMine].badgeCount, 0);
    });

    test('多个 badge 同时设置不互相干扰', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
        messageBadgeCount: 5,
        contactBadgeCount: 3,
        channelBadgeCount: 1,
      );
      expect(items[kWebNavTabMessage].badgeCount, 5);
      expect(items[kWebNavTabContact].badgeCount, 3);
      expect(items[kWebNavTabChannel].badgeCount, 1);
      expect(items[kWebNavTabMine].badgeCount, 0);
    });

    test('mine badge 不可配（无 mineBadgeCount 入参，永远 0）', () {
      final items = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
        messageBadgeCount: 999,
        contactBadgeCount: 999,
        channelBadgeCount: 999,
      );
      expect(items[kWebNavTabMine].badgeCount, 0,
          reason: 'mine tab 不应显示 unread badge');
    });
  });

  group('buildWebNavItems — 工厂常量契约', () {
    test('kWebNavItemCount = 4', () {
      expect(kWebNavItemCount, 4);
    });

    test('kWebNavTabMessage..Mine 0..3', () {
      expect(kWebNavTabMessage, 0);
      expect(kWebNavTabContact, 1);
      expect(kWebNavTabChannel, 2);
      expect(kWebNavTabMine, 3);
    });

    test('kWebNavTab* 常量值唯一', () {
      final values = {
        kWebNavTabMessage,
        kWebNavTabContact,
        kWebNavTabChannel,
        kWebNavTabMine,
      };
      expect(values, hasLength(4));
    });
  });

  group('buildWebNavItems — 不可变结果', () {
    test('两次相同输入返回相等的 items 列表（== 语义）', () {
      final a = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
        messageBadgeCount: 5,
      );
      final b = buildWebNavItems(
        messageLabel: 'M',
        contactLabel: 'C',
        channelLabel: 'H',
        mineLabel: 'I',
        messageBadgeCount: 5,
      );
      expect(a, equals(b));
      // 单个 item 也应相等（依赖 1.1.e WebNavItem 实现的 ==/hashCode）
      expect(a[0], equals(b[0]));
    });
  });
}
