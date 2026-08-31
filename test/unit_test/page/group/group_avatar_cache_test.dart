import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/group/group_avatar_cache.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';

/// GroupAvatarMemberCache 契约测试（计划 W1/W4，2026-08-31）。
///
/// 用注入时钟的独立实例测缓存行为，不碰全局单例；
/// 事件联动用 AppEventBus 真 fire（cache 构造内订阅）。
void main() {
  group('GroupAvatarMemberCache 缓存命中与 TTL', () {
    late DateTime now;
    late GroupAvatarMemberCache cache;
    var loaderCalls = 0;

    setUp(() {
      now = DateTime(2026, 8, 31, 12, 0);
      loaderCalls = 0;
      cache = GroupAvatarMemberCache(now: () => now);
      addTearDown(cache.dispose);
    });

    test('首次 load 调 loader，TTL 内二次 load 命中缓存不再调', () async {
      Future<List<String>> loader(String gid) async {
        loaderCalls++;
        return ['$gid-a', '$gid-b'];
      }

      final first = await cache.load('g1', loader);
      expect(first, ['g1-a', 'g1-b']);
      expect(loaderCalls, 1);

      now = now.add(const Duration(minutes: 4));
      final second = await cache.load('g1', loader);
      expect(second, same(first)); // 命中同一份缓存数据
      expect(loaderCalls, 1);
    });

    test('TTL 过期后重新调 loader 拿新数据', () async {
      Future<List<String>> loader(String gid) async {
        loaderCalls++;
        return ['v$loaderCalls'];
      }

      await cache.load('g1', loader);
      now = now.add(GroupAvatarMemberCache.ttl);
      final second = await cache.load('g1', loader);
      expect(second, ['v2']);
      expect(loaderCalls, 2);
    });

    test('peek：TTL 内命中返回列表，过期/未加载返回 null', () async {
      expect(cache.peek('g1'), isNull);
      await cache.load('g1', (gid) async => ['x']);
      expect(cache.peek('g1'), ['x']);

      now = now.add(GroupAvatarMemberCache.ttl);
      expect(cache.peek('g1'), isNull);
    });

    test('同 gid 并发 load 只发起一次底层查询（in-flight 去重）', () async {
      final started = Completer<void>();
      Future<List<String>> slowLoader(String gid) async {
        loaderCalls++;
        await started.future;
        return ['slow'];
      }

      final f1 = cache.load('g1', slowLoader);
      final f2 = cache.load('g1', slowLoader);
      started.complete();

      expect(await f1, ['slow']);
      expect(await f2, ['slow']);
      expect(loaderCalls, 1);

      // in-flight 结束后缓存已写，后续 load 命中缓存
      expect(await cache.load('g1', slowLoader), ['slow']);
      expect(loaderCalls, 1);
    });

    test('loader 失败不写缓存，下次 load 重试', () async {
      var fail = true;
      Future<List<String>> flaky(String gid) async {
        loaderCalls++;
        if (fail) throw StateError('db down');
        return ['ok'];
      }

      await expectLater(cache.load('g1', flaky), throwsStateError);
      expect(cache.peek('g1'), isNull);

      fail = false;
      expect(await cache.load('g1', flaky), ['ok']);
      expect(loaderCalls, 2);
    });

    test('invalidate 单群失效，其他群不受影响', () async {
      await cache.load('g1', (gid) async => ['a']);
      await cache.load('g2', (gid) async => ['b']);
      cache.invalidate('g1');
      expect(cache.peek('g1'), isNull);
      expect(cache.peek('g2'), ['b']);
    });

    test('invalidateAll 全部失效（refresh_conversations 兜底）', () async {
      await cache.load('g1', (gid) async => ['a']);
      await cache.load('g2', (gid) async => ['b']);
      cache.invalidateAll();
      expect(cache.peek('g1'), isNull);
      expect(cache.peek('g2'), isNull);
    });

    test('缓存返回的列表不可变，调用方改不动（防御共享引用）', () async {
      await cache.load('g1', (gid) async => ['a', 'b']);
      final urls = cache.peek('g1')!;
      expect(() => urls.add('c'), throwsUnsupportedError);
    });
  });

  group('GroupAvatarMemberCache 事件联动', () {
    test('GroupMemberUpdateEvent fire → 对应群缓存失效', () async {
      final cache = GroupAvatarMemberCache();
      addTearDown(cache.dispose);

      await cache.load('g1', (gid) async => ['a']);
      await cache.load('g2', (gid) async => ['b']);
      expect(cache.peek('g1'), isNotNull);

      AppEventBus.fire(
        GroupMemberUpdateEvent(groupId: 'g1', userId: '9', changeType: 'join'),
      );
      // broadcast 流异步分发，让出一轮微任务再断言
      await Future<void>.delayed(Duration.zero);
      expect(cache.peek('g1'), isNull);
      expect(cache.peek('g2'), isNotNull);
    });

    test('dispose 后不再响应事件（订阅已释放）', () async {
      final cache = GroupAvatarMemberCache();
      await cache.load('g1', (gid) async => ['a']);
      cache.dispose();

      AppEventBus.fire(
        GroupMemberUpdateEvent(groupId: 'g1', userId: '9', changeType: 'leave'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cache.peek('g1'), isNotNull);
    });
  });
}
