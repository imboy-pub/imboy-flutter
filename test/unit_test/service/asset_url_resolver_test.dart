/// AssetUrlResolver 单元测试
///
/// 测试目标：
/// 1. TTL 缓存命中（未过期复用，不重复网络）
/// 2. 并发合并（同 key 并发请求复用一次 fetch）
/// 3. resolveForDisplay 双模（legacy 完整 URL 不 fetch；object_key 走 fetch）
/// 4. 错误路径清理 inflight（失败后可重试）
/// 5. TTL 过期后重新 fetch
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/asset_url_resolver.dart';

void main() {
  late AssetUrlResolver resolver;
  late int fetchCount;
  late int fakeNow;

  setUp(() {
    resolver = AssetUrlResolver.forTest();
    fetchCount = 0;
    fakeNow = 1000;
    resolver.nowSeconds = () => fakeNow;
    resolver.fetcherOverride = (objectKey) async {
      fetchCount++;
      return 'https://garage.local/$objectKey?sig=$fetchCount';
    };
  });

  group('resolve - TTL 缓存', () {
    test('主动打开不复用进行中的旧签发', () async {
      const key = 'u1/file_1_a/x.png';
      final oldResult = Completer<String>();
      resolver.fetcherOverride = (_) => oldResult.future;
      final oldRequest = resolver.resolve(key);
      resolver.fetcherOverride = (_) async => 'https://example.com/fresh';
      expect(await resolver.resolveFresh(key), 'https://example.com/fresh');
      oldResult.complete('https://example.com/old');
      await oldRequest;
    });

    test('主动打开每次重新签发，不使用缓存', () async {
      const key = 'u1/file_1_a/x.png';
      await resolver.resolve(key);
      await resolver.resolveFresh(key);
      await resolver.resolveFresh(key);
      expect(fetchCount, 3);
    });

    test('已有缓存时，新授权失败仍然失败', () async {
      const key = 'u1/file_1_a/x.png';
      await resolver.resolve(key);
      resolver.fetcherOverride = (_) async => throw Exception('forbidden');
      await expectLater(resolver.resolveFresh(key), throwsException);
    });

    test('首次 fetch，二次命中缓存（不重复网络）', () async {
      const key = 'u1/file_1_a/x.png';
      final url1 = await resolver.resolve(key);
      final url2 = await resolver.resolve(key);
      expect(fetchCount, 1);
      expect(url1, url2);
    });

    test('TTL 过期后重新 fetch', () async {
      const key = 'u1/file_1_a/x.png';
      await resolver.resolve(key);
      expect(fetchCount, 1);
      // 缓存 540s；推进到 541s 后应过期
      fakeNow += 541;
      await resolver.resolve(key);
      expect(fetchCount, 2);
    });

    test('未到过期点仍命中缓存', () async {
      const key = 'u1/file_1_a/x.png';
      await resolver.resolve(key);
      fakeNow += 539; // < 540
      await resolver.resolve(key);
      expect(fetchCount, 1);
    });
  });

  group('resolve - 并发合并', () {
    test('同 key 并发请求复用一次 fetch', () async {
      const key = 'u1/file_1_a/x.png';
      final results = await Future.wait<String>([
        resolver.resolve(key),
        resolver.resolve(key),
        resolver.resolve(key),
      ]);
      expect(fetchCount, 1);
      expect(results.toSet().length, 1); // 三者同值
    });

    test('不同 key 各自 fetch', () async {
      await Future.wait<String>([
        resolver.resolve('u1/file_1_a/x.png'),
        resolver.resolve('u1/file_2_b/y.png'),
      ]);
      expect(fetchCount, 2);
    });
  });

  group('resolveForDisplay - 双模', () {
    test('legacy 完整 URL 不走 fetch（同步授权）', () async {
      final out = await resolver.resolveForDisplay(
        'https://fs.imboy.pub/g1/a.png',
      );
      expect(fetchCount, 0);
      expect(out.startsWith('https://fs.imboy.pub/'), isTrue);
    });

    test('object_key 走 fetch', () async {
      final out = await resolver.resolveForDisplay('u1/file_1_a/x.png');
      expect(fetchCount, 1);
      expect(out.contains('garage.local'), isTrue);
    });
  });

  group('错误路径', () {
    test('fetch 失败后抛出，且清理 inflight（可重试）', () async {
      const key = 'u1/file_1_a/x.png';
      var shouldFail = true;
      resolver.fetcherOverride = (objectKey) async {
        fetchCount++;
        if (shouldFail) throw Exception('network down');
        return 'https://ok/$objectKey';
      };

      await expectLater(resolver.resolve(key), throwsException);
      expect(fetchCount, 1);

      // inflight 已清理 → 第二次可重新 fetch（这次成功）
      shouldFail = false;
      final url = await resolver.resolve(key);
      expect(fetchCount, 2);
      expect(url.startsWith('https://ok/'), isTrue);
    });

    test('空 url 视为失败', () async {
      resolver.fetcherOverride = (objectKey) async => '';
      await expectLater(resolver.resolve('u1/file_1_a/x.png'), throwsException);
    });
  });

  group('invalidate / clear', () {
    test('invalidate 后重新 fetch', () async {
      const key = 'u1/file_1_a/x.png';
      await resolver.resolve(key);
      resolver.invalidate(key);
      await resolver.resolve(key);
      expect(fetchCount, 2);
    });

    test(
      'clear rejects late signatures without deleting the new request',
      () async {
        const key = 'u1/file_1_a/x.png';
        final old = Completer<String>();
        resolver.fetcherOverride = (_) => old.future;
        final previous = resolver.resolve(key);
        resolver.clear();
        final next = Completer<String>();
        resolver.fetcherOverride = (_) => next.future;
        final current = resolver.resolve(key);
        final denied = expectLater(previous, throwsStateError);
        old.complete('https://example.com/old');
        await denied;
        expect(identical(current, resolver.resolve(key)), isTrue);
        next.complete('https://example.com/new');
        expect(await current, 'https://example.com/new');
        expect(await resolver.resolve(key), 'https://example.com/new');
      },
    );

    test('clear also rejects a pending fresh signature', () async {
      final pending = Completer<String>();
      resolver.fetcherOverride = (_) => pending.future;
      final request = resolver.resolveFresh('u1/file_1_a/x.png');
      resolver.clear();
      final denied = expectLater(request, throwsStateError);
      pending.complete('https://example.com/old');
      await denied;
    });

    test('clear 清空全部缓存', () async {
      await resolver.resolve('u1/file_1_a/x.png');
      await resolver.resolve('u1/file_2_b/y.png');
      resolver.clear();
      await resolver.resolve('u1/file_1_a/x.png');
      expect(fetchCount, 3);
    });
  });
}
