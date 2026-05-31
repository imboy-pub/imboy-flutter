import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';

/// BottomNavigationPage + Provider 契约测试
///
/// 完整 widget mount 因 4 子页（ConversationPage / ContactPage / ChannelListPage /
/// MinePage）同时 init + WebSocketService.openSocket 副作用 + SqliteService 多源依赖
/// 超出 ROI 范围，本文件聚焦：
///   1. **provider 单元测试**（bottomNavigationProvider 默认 state /
///     newFriendRemindProvider 默认 Set）
///   2. **类型契约**（const widget / ConsumerStatefulWidget / 无构造参数）
///
/// 不测 changeIndex（依赖 WebSocketService 单例链）/ 完整 widget tree（4 子页副作用）。
void main() {
  group('BottomNavigationPage construction contract', () {
    test('widget is const-constructible (no required args)', () {
      const page = BottomNavigationPage();
      expect(page, isA<StatefulWidget>());
      expect(page, isA<BottomNavigationPage>());
    });

    test('default key is null', () {
      const page = BottomNavigationPage();
      expect(page.key, isNull);
    });

    test('accepts custom key', () {
      const key = ValueKey('test_key');
      const page = BottomNavigationPage(key: key);
      expect(page.key, key);
    });
  });

  group('bottomNavigationProvider default state', () {
    test('default index = 0 (消息 Tab)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final index = container.read(bottomNavigationProvider);
      expect(index, 0, reason: '默认 Tab 是消息 (index 0)');
    });

    test('NotifierProvider exposes Notifier with state setter', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 仅验证 notifier 可读取，不调 changeIndex（避开 WebSocket 副作用）
      final notifier = container.read(bottomNavigationProvider.notifier);
      expect(notifier, isNotNull);
      expect(notifier.state, 0);
    });
  });

  group('newFriendRemindProvider default state', () {
    test('default state is empty Set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(newFriendRemindProvider);
      expect(state, isA<Set<String>>());
      expect(state, isEmpty);
    });

    test('Set 默认 length=0 → bottom bar badge 不显示', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final remindCount = container.read(newFriendRemindProvider).length;
      expect(remindCount, 0, reason: '默认无新朋友请求，contact tab badge 应隐藏');
    });

    test('notifier 类型为 NewFriendRemindNotifier', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(newFriendRemindProvider.notifier);
      expect(notifier, isA<NewFriendRemindNotifier>());
    });
  });

  group('provider 跨容器状态隔离', () {
    test('两个独立 container 的 bottomNavigationProvider 互不影响', () {
      final c1 = ProviderContainer();
      final c2 = ProviderContainer();
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      expect(c1.read(bottomNavigationProvider), 0);
      expect(c2.read(bottomNavigationProvider), 0);
      // 不同 container 读取的是各自独立的 Notifier 实例
      expect(
        c1.read(bottomNavigationProvider.notifier),
        isNot(same(c2.read(bottomNavigationProvider.notifier))),
      );
    });

    test('两个独立 container 的 newFriendRemindProvider 各持有独立 Set', () {
      final c1 = ProviderContainer();
      final c2 = ProviderContainer();
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      final s1 = c1.read(newFriendRemindProvider);
      final s2 = c2.read(newFriendRemindProvider);
      expect(s1, isEmpty);
      expect(s2, isEmpty);
      expect(
        identical(s1, s2),
        isFalse,
        reason: '不同 container 应持有各自独立的默认 Set 实例',
      );
    });
  });
}
