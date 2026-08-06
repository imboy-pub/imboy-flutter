/// S8: 加密审计日志 — TDD 测试
///
/// 防御 T2/T8（Trust State 审计）：所有安全相关事件（identity 固定/变化、
/// capability 降级、KDF 迁移、设备验证）写入 append-only 哈希链日志，
/// 可独立审计、防篡改。
/// 验证：
/// - append + recent 往返
/// - seq 单调递增
/// - 哈希链：每条 event_hash 绑定 prev_hash
/// - verifyChain 完整日志返回 true
/// - 篡改检测：修改/删除任一事件 → verifyChain 返回 false
/// - 创世事件 prev_hash 为固定 genesis 值
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/service/e2ee/crypto_audit_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late CryptoAuditLog log;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    log = CryptoAuditLog(db);
    await log.ensureSchema();
  });

  tearDown(() async => db.close());

  group('CryptoAuditLog 基础', () {
    test('ensureSchema 幂等', () async {
      await log.ensureSchema();
      await log.ensureSchema();
    });

    test('crypto_audit_log 表存在', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = 'crypto_audit_log'",
      );
      expect(tables.length, equals(1));
    });

    test('append + recent 往返', () async {
      await log.append(
        AuditEventType.identityPinned,
        peerUid: '100',
        peerDeviceId: 'dev-1',
        detail: 'fp=abc',
      );

      final events = await log.recent(limit: 10);
      expect(events.length, equals(1));
      expect(events.first.eventType, equals(AuditEventType.identityPinned));
      expect(events.first.peerUid, equals('100'));
      expect(events.first.peerDeviceId, equals('dev-1'));
      expect(events.first.detail, equals('fp=abc'));
    });

    test('seq 单调递增', () async {
      await log.append(AuditEventType.identityPinned, peerUid: '1');
      await log.append(AuditEventType.identityChanged, peerUid: '2');
      await log.append(AuditEventType.kdfMigrated, peerUid: '3');

      final events = await log.recent(limit: 10);
      expect(events.map((e) => e.seq).toList(), equals([1, 2, 3]));
    });

    test('recent 按 limit 截断且按 seq 升序', () async {
      for (var i = 0; i < 5; i++) {
        await log.append(AuditEventType.identityPinned, peerUid: '$i');
      }
      final events = await log.recent(limit: 3);
      expect(events.length, equals(3));
      // 升序：最早的 3 条
      expect(events.first.seq, equals(1));
      expect(events.last.seq, equals(3));
    });
  });

  group('CryptoAuditLog 哈希链', () {
    test('创世事件 prev_hash 为 genesis 常量', () async {
      await log.append(AuditEventType.identityPinned, peerUid: '100');
      final events = await log.recent(limit: 1);
      expect(events.first.prevHash, equals(CryptoAuditLog.genesisHash));
      expect(events.first.eventHash, isNotEmpty);
    });

    test('后续事件 prev_hash == 前一条 event_hash（链式绑定）', () async {
      await log.append(AuditEventType.identityPinned, peerUid: '1');
      await log.append(AuditEventType.identityChanged, peerUid: '1');

      final events = await log.recent(limit: 10);
      expect(events[1].prevHash, equals(events[0].eventHash));
    });

    test('verifyChain 完整日志返回 true', () async {
      await log.append(AuditEventType.identityPinned, peerUid: '1');
      await log.append(AuditEventType.capabilityDowngraded, peerUid: '1');
      await log.append(AuditEventType.kdfMigrated, peerUid: '1');
      await log.append(AuditEventType.trustStateVerified, peerUid: '1');

      expect(await log.verifyChain(), isTrue);
    });

    test('空日志 verifyChain 返回 true', () async {
      expect(await log.verifyChain(), isTrue);
    });

    test('篡改 detail → verifyChain 返回 false', () async {
      await log.append(
        AuditEventType.identityPinned,
        peerUid: '1',
        detail: 'original',
      );
      await log.append(AuditEventType.identityChanged, peerUid: '1');

      // 直接改库（模拟攻击者篡改）
      await db.rawUpdate(
        "UPDATE crypto_audit_log SET detail = 'tampered' WHERE seq = 1",
      );

      expect(await log.verifyChain(), isFalse);
    });

    test('删除中间事件 → verifyChain 返回 false', () async {
      await log.append(AuditEventType.identityPinned, peerUid: '1');
      await log.append(AuditEventType.identityChanged, peerUid: '1');
      await log.append(AuditEventType.kdfMigrated, peerUid: '1');

      // 删除第 2 条（破坏链连续性）
      await db.rawDelete('DELETE FROM crypto_audit_log WHERE seq = 2');

      expect(await log.verifyChain(), isFalse);
    });
  });

  group('CryptoAuditLog 事件类型', () {
    test('所有事件类型可写入并读回', () async {
      const types = [
        AuditEventType.identityPinned,
        AuditEventType.identityChanged,
        AuditEventType.capabilityDowngraded,
        AuditEventType.kdfMigrated,
        AuditEventType.trustStateVerified,
        AuditEventType.sessionEstablished,
      ];
      for (final t in types) {
        await log.append(t, peerUid: '1');
      }
      final events = await log.recent(limit: 100);
      expect(events.map((e) => e.eventType).toSet(), equals(types.toSet()));
    });
  });
}
