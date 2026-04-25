/// Phase 1.1.c — Web Shell NotifierProvider 行为测试
///
/// 覆盖：
/// - 默认 build state
/// - switchTab：合法值 / 非法值守卫 / 同 tab 短路 / 切 tab 清空 selection
/// - selectItem：成功更新 / 同值短路
/// - clearSelection：成功置空 / null 短路
/// - 多动作组合（典型调用链）
/// - replaceState（测试 hatch）
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_shell_provider.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';

void main() {
  group('WebShellNotifier — 默认 build', () {
    test('初始 state: currentTab=0, selectedItem=null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(webShellProvider);
      expect(state.currentTab, 0);
      expect(state.selectedItem, isNull);
    });
  });

  group('WebShellNotifier.switchTab', () {
    test('合法值 0..3 均可切换', () {
      for (final tab in [0, 1, 2, 3]) {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(webShellProvider.notifier).switchTab(tab);
        expect(container.read(webShellProvider).currentTab, tab);
      }
    });

    test('非法值 < 0 静默 no-op', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      notifier.switchTab(-1);
      expect(container.read(webShellProvider).currentTab, 0);

      notifier.switchTab(-100);
      expect(container.read(webShellProvider).currentTab, 0);
    });

    test('非法值 > 3 静默 no-op', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      notifier.switchTab(4);
      expect(container.read(webShellProvider).currentTab, 0);

      notifier.switchTab(999);
      expect(container.read(webShellProvider).currentTab, 0);
    });

    test('同 tab 且 selection 为 null → 短路（state 引用不变）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      final before = container.read(webShellProvider);
      notifier.switchTab(0);
      final after = container.read(webShellProvider);
      expect(identical(before, after), isTrue,
          reason: '同 tab + null selection 不应触发 state 替换');
    });

    test('切 tab 强制清空 selectedItem', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      notifier.selectItem(const ContactSelection(uid: 'u1'));
      expect(
        container.read(webShellProvider).selectedItem,
        const ContactSelection(uid: 'u1'),
      );

      notifier.switchTab(2);
      expect(container.read(webShellProvider).currentTab, 2);
      expect(container.read(webShellProvider).selectedItem, isNull,
          reason: '切 tab 时跨 Tab 选中语义不同，应清空避免串扰');
    });

    test('同 tab 但 selection 非 null → 仍清空（清空 selection 是 switchTab 的副作用）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      notifier.selectItem(const ContactSelection(uid: 'u1'));
      notifier.switchTab(0); // 同 tab，但有 selection

      expect(container.read(webShellProvider).currentTab, 0);
      expect(container.read(webShellProvider).selectedItem, isNull);
    });
  });

  group('WebShellNotifier.selectItem', () {
    test('成功设置 ChatSelection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      const sel = ChatSelection(peerId: 'p1', chatType: 'C2C');
      notifier.selectItem(sel);

      expect(container.read(webShellProvider).selectedItem, sel);
    });

    test('成功设置 ContactSelection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      const sel = ContactSelection(uid: 'u1');
      notifier.selectItem(sel);

      expect(container.read(webShellProvider).selectedItem, sel);
    });

    test('成功设置 ChannelSelection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      const sel = ChannelSelection(channelId: 'ch1');
      notifier.selectItem(sel);

      expect(container.read(webShellProvider).selectedItem, sel);
    });

    test('成功设置 MineSelection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      const sel = MineSelection(section: 'privacy');
      notifier.selectItem(sel);

      expect(container.read(webShellProvider).selectedItem, sel);
    });

    test('selectItem 不改 currentTab（语义对齐由 UI 调用方负责）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      notifier.switchTab(2);
      notifier.selectItem(const ContactSelection(uid: 'u1'));

      expect(container.read(webShellProvider).currentTab, 2);
      expect(
        container.read(webShellProvider).selectedItem,
        const ContactSelection(uid: 'u1'),
      );
    });

    test('selectItem 同值 → 短路（state 引用不变）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      const sel = ContactSelection(uid: 'u1');
      notifier.selectItem(sel);

      final before = container.read(webShellProvider);
      notifier.selectItem(const ContactSelection(uid: 'u1'));
      final after = container.read(webShellProvider);
      expect(identical(before, after), isTrue);
    });

    test('selectItem 替换为不同变体', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      notifier.selectItem(const ContactSelection(uid: 'u1'));
      notifier.selectItem(const ChannelSelection(channelId: 'ch1'));

      expect(
        container.read(webShellProvider).selectedItem,
        const ChannelSelection(channelId: 'ch1'),
      );
    });
  });

  group('WebShellNotifier.clearSelection', () {
    test('清空非 null selection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      notifier.selectItem(const ContactSelection(uid: 'u1'));
      notifier.clearSelection();

      expect(container.read(webShellProvider).selectedItem, isNull);
    });

    test('clearSelection 不改 currentTab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      notifier.switchTab(1);
      notifier.selectItem(const ContactSelection(uid: 'u1'));
      notifier.clearSelection();

      expect(container.read(webShellProvider).currentTab, 1);
      expect(container.read(webShellProvider).selectedItem, isNull);
    });

    test('clearSelection 在 null 状态 → 短路', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      final before = container.read(webShellProvider);
      notifier.clearSelection();
      final after = container.read(webShellProvider);
      expect(identical(before, after), isTrue);
    });
  });

  group('WebShellNotifier — 多动作组合', () {
    test('典型调用链：选会话 → 切到联系人 Tab → 选联系人 → 回会话 Tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);

      // 1. 在 Tab 0 选中会话
      notifier.selectItem(const ChatSelection(peerId: 'p1', chatType: 'C2C'));
      expect(container.read(webShellProvider).currentTab, 0);
      expect(
        container.read(webShellProvider).selectedItem,
        const ChatSelection(peerId: 'p1', chatType: 'C2C'),
      );

      // 2. 切到 Tab 1 联系人 → selection 自动清空
      notifier.switchTab(1);
      expect(container.read(webShellProvider).currentTab, 1);
      expect(container.read(webShellProvider).selectedItem, isNull);

      // 3. 在 Tab 1 选中联系人
      notifier.selectItem(const ContactSelection(uid: 'u1'));
      expect(
        container.read(webShellProvider).selectedItem,
        const ContactSelection(uid: 'u1'),
      );

      // 4. 回 Tab 0 → selection 再次清空（KISS 实现：不做 per-tab memory）
      notifier.switchTab(0);
      expect(container.read(webShellProvider).currentTab, 0);
      expect(container.read(webShellProvider).selectedItem, isNull);
    });
  });

  group('WebShellNotifier.replaceState (testing hatch)', () {
    test('整体替换 state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(webShellProvider.notifier);
      notifier.replaceState(
        const WebShellState(
          currentTab: 2,
          selectedItem: ChannelSelection(channelId: 'ch1'),
        ),
      );

      final state = container.read(webShellProvider);
      expect(state.currentTab, 2);
      expect(state.selectedItem, const ChannelSelection(channelId: 'ch1'));
    });
  });

  group('WebShellNotifier — 常量契约', () {
    test('maxTabIndex = 3 (4 个 Tab: 会话/联系人/频道/我的)', () {
      expect(WebShellNotifier.maxTabIndex, 3);
    });
  });
}
