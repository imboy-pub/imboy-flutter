/// ChannelListNotifier 对 ChannelStateChangedEvent 的响应契约：
/// - channel_unsubscribed / channel_deleted：本地过滤对应频道（不触发网络）
/// - channel_subscribed：触发权威拉取（这里不落测网络副作用，仅验证事件不把本地误删）
///
/// 这些行为保证多端一致性：设备 A 退订/被删后，设备 B 收到 S2C 推送时
/// 本端列表会立即对齐，不依赖用户手动下拉。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/channel_model.dart';

ChannelModel _channel(int id, String name) => ChannelModel(
      id: id,
      name: name,
      creatorId: 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2),
    );

void main() {
  group('ChannelListNotifier auto-sync via ChannelStateChangedEvent', () {
    late ProviderContainer container;
    late ChannelListNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      // Riverpod 3 auto-dispose：不 listen 则 `container.read(provider)` 会
      // 在无订阅者时重建 state，导致外部通过 `notifier.state = ...` 写入的
      // 瞬态状态被清空。测试阶段主动订阅保活。
      container.listen(channelListProvider, (_, _) {});
      notifier = container.read(channelListProvider.notifier);
    });

    tearDown(() => container.dispose());

    test(
      'channel_unsubscribed filters the channel out locally',
      () async {
        notifier.state = notifier.state.copyWith(channels: [
          _channel(1001, 'A'),
          _channel(1002, 'B'),
          _channel(1003, 'C'),
        ]);

        AppEventBus.fire(ChannelStateChangedEvent(
          channelId: '1002',
          action: 'channel_unsubscribed',
          payload: const {},
        ));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final state = container.read(channelListProvider);
        expect(state.channels.map((c) => c.id), [1001, 1003]);
      },
    );

    test(
      'channel_deleted filters the channel out locally',
      () async {
        notifier.state = notifier.state.copyWith(channels: [
          _channel(1001, 'A'),
          _channel(1002, 'B'),
        ]);

        AppEventBus.fire(ChannelStateChangedEvent(
          channelId: '1001',
          action: 'channel_deleted',
          payload: const {},
        ));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final state = container.read(channelListProvider);
        expect(state.channels.map((c) => c.id), [1002]);
      },
    );

    test(
      'unknown action does not mutate state',
      () async {
        final before = [_channel(1001, 'A')];
        notifier.state = notifier.state.copyWith(channels: before);

        AppEventBus.fire(ChannelStateChangedEvent(
          channelId: '9999',
          action: 'something_unrelated',
          payload: const {},
        ));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final state = container.read(channelListProvider);
        expect(state.channels.map((c) => c.id), [1001]);
      },
    );

    test(
      'channel_unsubscribed for an id not in the list is a no-op',
      () async {
        final before = [_channel(1001, 'A'), _channel(1002, 'B')];
        notifier.state = notifier.state.copyWith(channels: before);

        AppEventBus.fire(ChannelStateChangedEvent(
          channelId: '9999',
          action: 'channel_unsubscribed',
          payload: const {},
        ));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final state = container.read(channelListProvider);
        expect(state.channels.map((c) => c.id), [1001, 1002]);
      },
    );
  });
}
