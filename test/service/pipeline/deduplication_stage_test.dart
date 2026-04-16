/// 钉住 `MessageDeduplicator` 的去重决策契约 —— RED 阶段。
///
/// 契约（优先级从高到低）：
///   1. receiving_ttl：markReceiving 后 TTL 内同 msgId → Duplicate
///   2. content_hash：相同内容哈希 → Duplicate
///   3. db_exists：dbLookup 返回 true → Duplicate
///   4. 其余 → Pass
///
/// 本测试不依赖 Flutter / sqflite / 任何平台组件，纯 Dart。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/pipeline/deduplication_stage.dart';

void main() {
  group('MessageDeduplicator — 去重决策契约', () {
    late MessageDeduplicator dedup;

    setUp(() {
      dedup = MessageDeduplicator();
    });

    // ------------------------------------------------------------------ //
    // 1. 首次收到消息 → Pass
    // ------------------------------------------------------------------ //
    test('首次收到消息，dbLookup=false → DeduplicationPass', () async {
      final result = await dedup.check(
        msgId: 'msg-001',
        msgType: 'C2C',
        dbLookup: (_) async => false,
      );

      expect(result, isA<DeduplicationPass>());
    });

    // ------------------------------------------------------------------ //
    // 2. markReceiving 后 5 秒内再次 check → Duplicate('receiving_ttl')
    // ------------------------------------------------------------------ //
    test('markReceiving 后 TTL 内同 msgId → DeduplicationDuplicate(receiving_ttl)', () async {
      dedup.markReceiving('msg-002', 'C2C');

      final result = await dedup.check(
        msgId: 'msg-002',
        msgType: 'C2C',
        dbLookup: (_) async => false,
      );

      expect(result, isA<DeduplicationDuplicate>());
      final dup = result as DeduplicationDuplicate;
      expect(dup.reason, 'receiving_ttl');
    });

    // ------------------------------------------------------------------ //
    // 3. TTL 过期后 cleanExpired → 不再命中 receiving_ttl
    // ------------------------------------------------------------------ //
    test('cleanExpired 后同 msgId 不再命中 receiving_ttl → Pass', () async {
      // 使用可注入时钟的构造器，制造 TTL 已过期的场景
      final fakeClock = _FakeClock(nowMs: 0);
      final dedupWithClock = MessageDeduplicator(clock: fakeClock.now);

      // 在 t=0 标记接收中
      dedupWithClock.markReceiving('msg-003', 'C2C');

      // 前进 6 秒（TTL=5s），触发过期
      fakeClock.nowMs = 6000;
      dedupWithClock.cleanExpired();

      final result = await dedupWithClock.check(
        msgId: 'msg-003',
        msgType: 'C2C',
        dbLookup: (_) async => false,
      );

      expect(result, isA<DeduplicationPass>());
    });

    // ------------------------------------------------------------------ //
    // 4. dbLookup 返回 true → Duplicate('db_exists')
    // ------------------------------------------------------------------ //
    test('dbLookup=true → DeduplicationDuplicate(db_exists)', () async {
      final result = await dedup.check(
        msgId: 'msg-004',
        msgType: 'C2C',
        dbLookup: (_) async => true,
      );

      expect(result, isA<DeduplicationDuplicate>());
      final dup = result as DeduplicationDuplicate;
      expect(dup.reason, 'db_exists');
    });

    // ------------------------------------------------------------------ //
    // 5. dbLookup=false + 无其他命中 → Pass
    // ------------------------------------------------------------------ //
    test('dbLookup=false 且无其他命中 → DeduplicationPass', () async {
      final result = await dedup.check(
        msgId: 'msg-005',
        msgType: 'C2G',
        dbLookup: (_) async => false,
      );

      expect(result, isA<DeduplicationPass>());
    });

    // ------------------------------------------------------------------ //
    // 6. msgId 为空 + contentHash 非空 → 使用 contentHash 路径（不报错）
    // ------------------------------------------------------------------ //
    test('msgId 为空 + contentHash 非空 → 不报错（Pass 或 Duplicate 均合法）', () async {
      DeduplicationResult? result;
      expect(
        () async {
          result = await dedup.check(
            msgId: '',
            msgType: 'C2C',
            contentHash: 'hash-abc',
            dbLookup: (_) async => false,
          );
        },
        returnsNormally,
      );
      // 允许结果为 Pass（contentHash 首次）或 Duplicate，不允许抛异常
      await Future<void>.delayed(Duration.zero);
      expect(result, anyOf(isA<DeduplicationPass>(), isA<DeduplicationDuplicate>()));
    });

    // ------------------------------------------------------------------ //
    // 7. msgId 为空 + contentHash 为空 → Pass（不阻断主流程）
    // ------------------------------------------------------------------ //
    test('msgId 为空 + contentHash 为空 → DeduplicationPass（不阻断）', () async {
      final result = await dedup.check(
        msgId: '',
        msgType: 'C2C',
        dbLookup: (_) async => false,
      );

      expect(result, isA<DeduplicationPass>());
    });

    // ------------------------------------------------------------------ //
    // 8. receiving_ttl 按全局 msgId 去重（不区分 msgType）
    //
    // 设计决策：msgId 由服务端生成，全局唯一；以 msgId 作为单一键去重
    // 比 (msgId, msgType) 联合键更保守，避免同一消息以不同类型二次入库。
    // ------------------------------------------------------------------ //
    test('markReceiving(C2C) 后，同 msgId 的 C2G check 也命中 receiving_ttl', () async {
      dedup.markReceiving('msg-008', 'C2C');

      // 全局去重：C2G 同 msgId → 也应被拦截
      final resultC2G = await dedup.check(
        msgId: 'msg-008',
        msgType: 'C2G',
        dbLookup: (_) async => false,
      );
      expect(resultC2G, isA<DeduplicationDuplicate>());
      expect((resultC2G as DeduplicationDuplicate).reason, 'receiving_ttl');

      // 同类型 C2C 必须命中
      final resultC2C = await dedup.check(
        msgId: 'msg-008',
        msgType: 'C2C',
        dbLookup: (_) async => false,
      );
      expect(resultC2C, isA<DeduplicationDuplicate>());
      expect((resultC2C as DeduplicationDuplicate).reason, 'receiving_ttl');
    });

    // ------------------------------------------------------------------ //
    // 9. markReceiving 调用两次同一 msgId → 幂等
    // ------------------------------------------------------------------ //
    test('markReceiving 幂等：调用两次不抛异常，仍正确命中 receiving_ttl', () async {
      expect(() {
        dedup.markReceiving('msg-009', 'C2C');
        dedup.markReceiving('msg-009', 'C2C'); // 第二次调用不崩溃
      }, returnsNormally);

      final result = await dedup.check(
        msgId: 'msg-009',
        msgType: 'C2C',
        dbLookup: (_) async => false,
      );

      expect(result, isA<DeduplicationDuplicate>());
      expect((result as DeduplicationDuplicate).reason, 'receiving_ttl');
    });

    // ------------------------------------------------------------------ //
    // 10. dbLookup 抛异常 → Pass（不阻断主流程）
    // ------------------------------------------------------------------ //
    test('dbLookup 抛异常 → DeduplicationPass（不阻断主流程）', () async {
      final result = await dedup.check(
        msgId: 'msg-010',
        msgType: 'C2C',
        dbLookup: (_) async => throw Exception('DB 连接失败'),
      );

      expect(result, isA<DeduplicationPass>());
    });

    // ------------------------------------------------------------------ //
    // 11. sealed 类型穷尽验证
    // ------------------------------------------------------------------ //
    test('sealed DeduplicationResult — switch 必须穷尽', () {
      String describe(DeduplicationResult r) => switch (r) {
            DeduplicationPass() => 'pass',
            DeduplicationDuplicate(:final reason) => 'dup:$reason',
          };

      expect(describe(const DeduplicationPass()), 'pass');
      expect(describe(const DeduplicationDuplicate('receiving_ttl')), 'dup:receiving_ttl');
      expect(describe(const DeduplicationDuplicate('content_hash')), 'dup:content_hash');
      expect(describe(const DeduplicationDuplicate('db_exists')), 'dup:db_exists');
    });

    // ------------------------------------------------------------------ //
    // 12. contentHash 相同 → Duplicate('content_hash')
    // ------------------------------------------------------------------ //
    test('相同 contentHash 第二次出现 → DeduplicationDuplicate(content_hash)', () async {
      // 第一次 check 通过（没有标记过该 hash）
      await dedup.check(
        msgId: 'msg-012a',
        msgType: 'C2C',
        contentHash: 'same-hash',
        dbLookup: (_) async => false,
      );

      // 第二次带相同 contentHash → 命中
      final result = await dedup.check(
        msgId: 'msg-012b',
        msgType: 'C2C',
        contentHash: 'same-hash',
        dbLookup: (_) async => false,
      );

      expect(result, isA<DeduplicationDuplicate>());
      expect((result as DeduplicationDuplicate).reason, 'content_hash');
    });
  });
}

/// 可注入的假时钟，用于控制 TTL 过期场景。
class _FakeClock {
  int nowMs;
  _FakeClock({required this.nowMs});
  int now() => nowMs;
}
