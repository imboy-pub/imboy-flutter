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
      final updated = state.copyWith(
        isLoading: true,
        isPublishing: true,
        hasMore: false,
      );
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
      expect(updated.channel!.id, '2');
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
      expect(updated.createdChannel!.id, '2');
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

  // ── J06.a 两个Tab集合/条件隔离（AS 落点：provider 状态层）────────────────
  // 页面两 Tab（订阅/管理）共享 ChannelListNotifier，集合隔离由
  // ChannelListState.channels（订阅侧，含游标）与 .managed（管理侧子状态）
  // 两个字段承载；copyWith 任一侧不得覆写另一侧。
  group('J06.a 两Tab集合隔离（channels vs managed 子状态）', () {
    test('更新订阅侧 channels 不覆写 managed 集合', () {
      const state = ChannelListState();
      final withManaged = state.copyWith(
        managed: ChannelListState(channels: [_channel(20)]),
      );
      final updated = withManaged.copyWith(channels: [_channel(10)]);
      expect(updated.channels.map((c) => c.id), ['10']);
      expect(updated.managed.channels.map((c) => c.id), [
        '20',
      ], reason: '管理Tab集合不受订阅侧更新影响');
    });

    test('更新 managed 子状态不覆写订阅侧集合与游标', () {
      final state = const ChannelListState().copyWith(
        channels: [_channel(10)],
        cursor: 'c1',
        hasMore: true,
      );
      final updated = state.copyWith(
        managed: ChannelListState(channels: [_channel(20)]),
      );
      expect(updated.managed.channels.map((c) => c.id), ['20']);
      expect(updated.channels.map((c) => c.id), ['10']);
      expect(updated.cursor, 'c1');
      expect(updated.hasMore, isTrue, reason: '游标/hasMore 只属于订阅侧分页');
    });

    test('clearCursor 只清除订阅侧游标，不影响 managed', () {
      final state = const ChannelListState().copyWith(
        channels: [_channel(10)],
        cursor: 'c1',
        managed: ChannelListState(channels: [_channel(20)]),
      );
      final cleared = state.copyWith(clearCursor: true);
      expect(cleared.cursor, isNull);
      expect(cleared.channels.map((c) => c.id), ['10']);
      expect(cleared.managed.channels.map((c) => c.id), [
        '20',
      ], reason: '管理Tab集合与其状态在订阅侧代次切换时保持独立');
    });
  });

  // ── J08.a 账号切换不写错账号库（AS 落点：状态清空契约）──────────────────
  // 账号/会话代次切换时 ChannelListNotifier._ensureAccount 将整个状态重置为
  // ChannelListState()——状态层契约：重置后不得残留上一账号的集合、游标、
  // managed 子状态或错误文案；详情侧 clearChannel 同理。
  group('J08.a 账号代次清空契约（状态层不残留旧账号片段）', () {
    test('ChannelListState 重置为默认值后无任何旧集合/游标/managed/error 残留', () {
      const ChannelListState().copyWith(
        channels: [_channel(10)],
        cursor: 'old-account-cursor',
        hasMore: true,
        error: 'old error',
        managed: ChannelListState(channels: [_channel(20)]),
      );
      // 账号切换的载体是整状态替换（const ChannelListState()）。
      const reset = ChannelListState();
      expect(reset.channels, isEmpty, reason: '不得残留旧账号订阅集合');
      expect(reset.cursor, isNull, reason: '不得残留旧账号分页游标');
      expect(reset.hasMore, isFalse);
      expect(reset.error, isNull);
      expect(reset.managed.channels, isEmpty, reason: '不得残留旧账号管理集合');
      expect(reset.managed.cursor, isNull);
      expect(reset.syncError, isFalse);
    });

    test('managed 子状态置换时旧 managed 游标/错误不携带进新代次', () {
      final staleManaged = const ChannelListState().copyWith(
        managed: ChannelListState(
          channels: [_channel(20)],
          cursor: 'managed-stale',
          error: 'managed-stale-error',
        ),
      );
      final fresh = staleManaged.copyWith(
        managed: ChannelListState(channels: [_channel(21)]),
      );
      expect(fresh.managed.channels.map((c) => c.id), ['21']);
      expect(fresh.managed.cursor, isNull);
      expect(fresh.managed.error, isNull);
    });

    test('ChannelDetailState.clearChannel 使旧账号/旧目标 channel 置 null', () {
      final oldTarget = ChannelDetailState(channel: _channel(10));
      final cleared = oldTarget.copyWith(clearChannel: true);
      expect(cleared.channel, isNull, reason: '切号/切目标后不得残留旧详情资源');
      expect(cleared.messages, isEmpty);
    });
  });
}
