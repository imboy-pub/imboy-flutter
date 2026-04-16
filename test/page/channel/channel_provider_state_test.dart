/// ChannelListState / ChannelDetailState / CreateChannelState copyWith 契约测试
///
/// CPS-1  ChannelListState.copyWith — clearCursor flag / error 直接覆盖
/// CPS-2  ChannelDetailState.copyWith — clearChannel flag / error 直接覆盖
/// CPS-3  CreateChannelState.copyWith — clearCreatedChannel flag / error 直接覆盖
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';

// ─── 测试工厂 ───────────────────────────────────────────────────────────────

ChannelModel _channel(int id) => ChannelModel(
      id: id,
      name: 'ch$id',
      creatorId: 1,
      createdAt: DateTime.utc(2025),
      updatedAt: DateTime.utc(2025),
    );

ChannelMessageModel _msg(int id) => ChannelMessageModel(
      id: id,
      channelId: 1,
      content: 'x',
      msgType: 'channel_text',
      createdAt: DateTime.utc(2025),
    );

void main() {
  // ── CPS-1  ChannelListState ────────────────────────────────────────────────
  group('CPS-1 ChannelListState.copyWith', () {
    test('默认值：空列表、全 false、cursor/error 为 null', () {
      const state = ChannelListState();
      expect(state.channels, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.hasMore, isFalse);
      expect(state.cursor, isNull);
      expect(state.error, isNull);
    });

    test('覆盖普通字段', () {
      const state = ChannelListState();
      final updated = state.copyWith(isLoading: true, hasMore: true);
      expect(updated.isLoading, isTrue);
      expect(updated.hasMore, isTrue);
      expect(updated.channels, isEmpty); // 未覆盖字段不变
    });

    test('clearCursor=true → cursor 强制置 null', () {
      final state = const ChannelListState().copyWith(cursor: 'abc');
      expect(state.cursor, 'abc');

      final cleared = state.copyWith(clearCursor: true);
      expect(cleared.cursor, isNull);
    });

    test('clearCursor=false（默认）+ cursor 参数 → 更新 cursor', () {
      const state = ChannelListState(cursor: 'old');
      final updated = state.copyWith(cursor: 'new');
      expect(updated.cursor, 'new');
    });

    test('clearCursor=true 优先于 cursor 参数', () {
      const state = ChannelListState(cursor: 'old');
      final cleared = state.copyWith(cursor: 'new', clearCursor: true);
      expect(cleared.cursor, isNull);
    });

    test('error 为直接覆盖：传 null 可清除已有 error', () {
      final state = const ChannelListState().copyWith(error: 'oops');
      expect(state.error, 'oops');

      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('不传 error 时 error 归 null（非 ??）', () {
      // copyWith 中 error 直接赋值 `error`（不是 error ?? this.error），
      // 因此不传 error 参数等价于传 null，会清除旧 error。
      final withError = const ChannelListState().copyWith(error: 'err');
      final copyNoError = withError.copyWith(isLoading: false);
      expect(copyNoError.error, isNull);
    });

    test('channels 字段正常覆盖', () {
      final channels = [_channel(1), _channel(2)];
      final state = const ChannelListState().copyWith(channels: channels);
      expect(state.channels, hasLength(2));
    });
  });

  // ── CPS-2  ChannelDetailState ──────────────────────────────────────────────
  group('CPS-2 ChannelDetailState.copyWith', () {
    test('默认值：channel null、空消息列表、hasMore=true', () {
      const state = ChannelDetailState();
      expect(state.channel, isNull);
      expect(state.messages, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.isPublishing, isFalse);
      expect(state.hasMore, isTrue); // 默认 true（便于首次加载）
      expect(state.error, isNull);
    });

    test('覆盖普通字段', () {
      const state = ChannelDetailState();
      final updated = state.copyWith(isLoading: true, isPublishing: true, hasMore: false);
      expect(updated.isLoading, isTrue);
      expect(updated.isPublishing, isTrue);
      expect(updated.hasMore, isFalse);
    });

    test('clearChannel=true → channel 强制置 null', () {
      final ch = _channel(1);
      final state = ChannelDetailState(channel: ch);
      expect(state.channel, isNotNull);

      final cleared = state.copyWith(clearChannel: true);
      expect(cleared.channel, isNull);
    });

    test('clearChannel=false（默认）+ channel 参数 → 更新 channel', () {
      final state = ChannelDetailState(channel: _channel(1));
      final updated = state.copyWith(channel: _channel(2));
      expect(updated.channel!.id, 2);
    });

    test('clearChannel=true 优先于 channel 参数', () {
      final state = ChannelDetailState(channel: _channel(1));
      final cleared = state.copyWith(channel: _channel(2), clearChannel: true);
      expect(cleared.channel, isNull);
    });

    test('error 为直接覆盖：传 null 可清除已有 error', () {
      final state = ChannelDetailState().copyWith(error: 'err');
      final cleared = state.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('不传 error 时 error 归 null', () {
      final withErr = const ChannelDetailState().copyWith(error: 'err');
      final copy = withErr.copyWith(isLoading: false);
      expect(copy.error, isNull);
    });

    test('messages 字段正常覆盖', () {
      final msgs = [_msg(1), _msg(2), _msg(3)];
      final state = ChannelDetailState().copyWith(messages: msgs);
      expect(state.messages, hasLength(3));
    });
  });

  // ── CPS-3  CreateChannelState ──────────────────────────────────────────────
  group('CPS-3 CreateChannelState.copyWith', () {
    test('默认值：isCreating=false、createdChannel null、error null', () {
      const state = CreateChannelState();
      expect(state.isCreating, isFalse);
      expect(state.createdChannel, isNull);
      expect(state.error, isNull);
    });

    test('覆盖 isCreating', () {
      const state = CreateChannelState();
      expect(state.copyWith(isCreating: true).isCreating, isTrue);
    });

    test('clearCreatedChannel=true → createdChannel 强制置 null', () {
      final ch = _channel(5);
      final state = CreateChannelState(createdChannel: ch);
      expect(state.createdChannel, isNotNull);

      final cleared = state.copyWith(clearCreatedChannel: true);
      expect(cleared.createdChannel, isNull);
    });

    test('clearCreatedChannel=false（默认）+ createdChannel 参数 → 更新', () {
      final state = CreateChannelState(createdChannel: _channel(1));
      final updated = state.copyWith(createdChannel: _channel(2));
      expect(updated.createdChannel!.id, 2);
    });

    test('clearCreatedChannel=true 优先于 createdChannel 参数', () {
      final state = CreateChannelState(createdChannel: _channel(1));
      final cleared = state.copyWith(
        createdChannel: _channel(9),
        clearCreatedChannel: true,
      );
      expect(cleared.createdChannel, isNull);
    });

    test('error 为直接覆盖：传 null 可清除', () {
      final state = const CreateChannelState().copyWith(error: 'fail');
      expect(state.copyWith(error: null).error, isNull);
    });

    test('不传 error 时 error 归 null', () {
      final withErr = const CreateChannelState().copyWith(error: 'fail');
      final copy = withErr.copyWith(isCreating: false);
      expect(copy.error, isNull);
    });
  });
}
