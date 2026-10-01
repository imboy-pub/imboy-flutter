import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _Account extends Notifier<UserModel?> {
  @override
  UserModel? build() => UserModel(uid: '1', account: 'synthetic');
  void select(String uid, {String nickname = ''}) => state = uid.isEmpty
      ? null
      : UserModel(uid: uid, account: 'synthetic', nickname: nickname);
}

final _account = NotifierProvider<_Account, UserModel?>(_Account.new);

class _Navigation extends BottomNavigationNotifier {
  void selectForTest(int value) => state = value;
}

/// BottomNavigationPage + Provider 契约测试
///
/// 完整 widget mount 因 4 子页（ConversationPage / ContactPage / ChannelListPage /
/// MinePage）同时 init + WebSocketService.openSocket 副作用 + SqliteService 多源依赖
/// 超出 ROI 范围，本文件聚焦：
///   1. **provider 单元测试**（bottomNavigationProvider 默认 state /
///     newFriendRemindProvider 默认 Set）
///   2. **类型契约**（const widget / ConsumerStatefulWidget / 无构造参数）
///   3. **resolveInitialIndex / normalizeIndex 纯函数**（路由 query 解析 + 越界归一化；
///      deep link ?index=N 经 Splash 重定向后 query 丢失，真机不可达，单测固化契约）
///
/// 不测 changeIndex（依赖 WebSocketService 单例链）/ 完整 widget tree（4 子页副作用）。
void main() {
  test('个人标签离开首页后保留，账号变化或退出时重置', () async {
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(_account)),
        bottomNavigationProvider.overrideWith(_Navigation.new),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(bottomNavigationProvider, (_, _) {});
    (container.read(bottomNavigationProvider.notifier) as _Navigation)
        .selectForTest(2);
    subscription.close();
    await container.pump();
    expect(container.read(bottomNavigationProvider), 2);
    container.read(_account.notifier).select('1', nickname: 'updated');
    await container.pump();
    expect(container.read(bottomNavigationProvider), 2);
    container.read(_account.notifier).select('2');
    await container.pump();
    expect(container.read(bottomNavigationProvider), 0);
    (container.read(bottomNavigationProvider.notifier) as _Navigation)
        .selectForTest(3);
    container.read(_account.notifier).select('');
    await container.pump();
    expect(container.read(bottomNavigationProvider), 0);
  });
  test('返回个人页复用当前标签，显式路由仍可覆盖且越界归一', () {
    expect(resolveInitialIndex({}, 4, fallback: 2), 2);
    expect(resolveInitialIndex({'index': '1'}, 4, fallback: 2), 1);
    expect(resolveInitialIndex({'index': 'invalid'}, 4, fallback: 2), 0);
    expect(resolveInitialIndex({}, 3, fallback: 3), 2);
  });
  const tabCount = 4; // 消息/联系人/频道/我的

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

  group('resolveInitialIndex 路由参数解析', () {
    test('缺失 index 参数 → 0', () {
      expect(resolveInitialIndex(const {}, tabCount), 0);
    });

    test('index=2 → 2（频道 tab）', () {
      expect(resolveInitialIndex(const {'index': '2'}, tabCount), 2);
    });

    test('index=99 越界 → 归一化到最后一个 tab', () {
      expect(resolveInitialIndex(const {'index': '99'}, tabCount), 3);
    });

    test('index=-1 负值越界 → 0', () {
      expect(resolveInitialIndex(const {'index': '-1'}, tabCount), 0);
    });

    test('index=abc 非数字 → 0', () {
      expect(resolveInitialIndex(const {'index': 'abc'}, tabCount), 0);
    });
  });

  group('normalizeIndex 顶层契约', () {
    test('合法值原样返回', () {
      expect(normalizeIndex(0, 4), 0);
      expect(normalizeIndex(3, 4), 3);
    });

    test('上下越界各归一到边界', () {
      expect(normalizeIndex(99, 4), 3);
      expect(normalizeIndex(-5, 4), 0);
    });
  });
}
