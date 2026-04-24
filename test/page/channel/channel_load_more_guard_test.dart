/// ChannelListNotifier.loadMoreSubscribedChannels 守卫契约测试（CLM-1）
///
/// CLM-1  三种 early-return 守卫：isLoading=true / hasMore=false / cursor=null
///        → 均不改变当前 state（不发起网络请求）
///
/// 守卫源码位置：
///   channel_provider.dart:202
///   if (state.isLoading || !state.hasMore || state.cursor == null) return;
///
/// 为何不测试 success 路径：
///   `_api` 字段在 build() 中写死为 ChannelApi.to 单例，
///   无注入点；发起真实网络调用会超时。
///   success/error 路径已由 CH-6 service 层测试全面覆盖。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/store/model/channel_model.dart';

// ─── helper ──────────────────────────────────────────────────────────────────

ChannelModel _ch(int id) => ChannelModel(
      id: id,
      name: 'ch$id',
      creatorId: 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

// ─── tests ───────────────────────────────────────────────────────────────────

void main() {
  group('CLM-1 loadMoreSubscribedChannels 守卫', () {
    late ProviderContainer container;
    late ChannelListNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      // 保活订阅，防止 Riverpod 3 auto-dispose 清空瞬态 state
      container.listen(channelListProvider, (_, _) {});
      notifier = container.read(channelListProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('isLoading=true → 不改变 state，立即返回', () async {
      notifier.state = ChannelListState(
        channels: [_ch(1)],
        isLoading: true,
        hasMore: true,
        cursor: 'cursor-abc',
      );

      await notifier.loadMoreSubscribedChannels();

      final state = container.read(channelListProvider);
      expect(state.isLoading, isTrue,
          reason: '守卫触发后 isLoading 不应被重置为 false');
      expect(state.cursor, 'cursor-abc',
          reason: '守卫触发后 cursor 不应被清空');
      expect(state.channels, hasLength(1),
          reason: '守卫触发后 channels 不应被追加或清空');
    });

    test('hasMore=false → 不改变 state，立即返回', () async {
      notifier.state = ChannelListState(
        channels: [_ch(1), _ch(2)],
        isLoading: false,
        hasMore: false,
        cursor: 'cursor-xyz',
      );

      await notifier.loadMoreSubscribedChannels();

      final state = container.read(channelListProvider);
      expect(state.hasMore, isFalse);
      expect(state.channels, hasLength(2));
      // isLoading 不应被变成 true（没有发起加载）
      expect(state.isLoading, isFalse);
    });

    test('cursor=null → 不改变 state，立即返回', () async {
      notifier.state = const ChannelListState(
        isLoading: false,
        hasMore: true,
        // cursor 不传 → null（默认值）
      );

      await notifier.loadMoreSubscribedChannels();

      final state = container.read(channelListProvider);
      expect(state.cursor, isNull);
      expect(state.isLoading, isFalse,
          reason: '守卫触发后 isLoading 不应被置 true');
    });

    test('三守卫全满足（isLoading + !hasMore + cursor=null）→ 不改变', () async {
      notifier.state = const ChannelListState(
        isLoading: true,
        hasMore: false,
        // cursor = null
      );

      await notifier.loadMoreSubscribedChannels();

      final state = container.read(channelListProvider);
      expect(state.isLoading, isTrue);
      expect(state.hasMore, isFalse);
      expect(state.cursor, isNull);
    });
  });
}
