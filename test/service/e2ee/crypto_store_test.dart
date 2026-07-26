/// S2.3: Transactional CryptoStore — TDD 测试
///
/// 验证原子性保证：
/// - ratchet advance + session persist 在同一事务
/// - outbox write + session persist 在同一事务（发送侧）
/// - dedupe check + session persist 在同一事务（接收侧）
/// - 崩溃恢复：outbox 中未确认条目可重发
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/service/e2ee/crypto_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late CryptoStore store;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    store = CryptoStore(db);
    await store.ensureSchema();
  });

  tearDown(() async {
    await db.close();
  });

  group('CryptoStore schema', () {
    test('ensureSchema 幂等：重复调用不抛', () async {
      await store.ensureSchema();
      await store.ensureSchema();
      // 不抛即通过
    });

    test('三张表存在', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'crypto_%'",
      );
      final names = tables.map((r) => r['name'] as String).toSet();
      expect(
        names,
        containsAll([
          'crypto_olm_session',
          'crypto_outbox',
          'crypto_inbox_dedupe',
        ]),
      );
    });
  });

  group('Olm session 持久化', () {
    test('persistSession + loadSession 往返', () async {
      await store.persistSession(
        peerUid: '200',
        peerDeviceId: 'dev-A',
        pickle: 'pickle-bytes-abc',
      );

      final loaded = await store.loadSession(
        peerUid: '200',
        peerDeviceId: 'dev-A',
      );
      expect(loaded, equals('pickle-bytes-abc'));
    });

    test('loadSession 不存在返回 null', () async {
      final loaded = await store.loadSession(
        peerUid: '999',
        peerDeviceId: 'dev-X',
      );
      expect(loaded, isNull);
    });

    test('persistSession 覆盖旧 pickle（ratchet advance）', () async {
      await store.persistSession(
        peerUid: '200',
        peerDeviceId: 'dev-A',
        pickle: 'v1',
      );
      await store.persistSession(
        peerUid: '200',
        peerDeviceId: 'dev-A',
        pickle: 'v2',
      );

      final loaded = await store.loadSession(
        peerUid: '200',
        peerDeviceId: 'dev-A',
      );
      expect(loaded, equals('v2'));
    });

    test('不同设备独立存储', () async {
      await store.persistSession(
        peerUid: '200',
        peerDeviceId: 'dev-A',
        pickle: 'pA',
      );
      await store.persistSession(
        peerUid: '200',
        peerDeviceId: 'dev-B',
        pickle: 'pB',
      );

      expect(
        await store.loadSession(peerUid: '200', peerDeviceId: 'dev-A'),
        equals('pA'),
      );
      expect(
        await store.loadSession(peerUid: '200', peerDeviceId: 'dev-B'),
        equals('pB'),
      );
    });
  });

  group('Outbox（发送侧原子性）', () {
    test('persistSessionWithOutbox 原子写入：session + outbox 同事务', () async {
      await store.persistSessionWithOutbox(
        peerUid: '200',
        peerDeviceId: 'dev-A',
        pickle: 'ratchet-v2',
        outboxId: 'msg-001',
        payload: '{"e2ee":{},"payload":"ct"}',
      );

      // session 已持久化
      expect(
        await store.loadSession(peerUid: '200', peerDeviceId: 'dev-A'),
        equals('ratchet-v2'),
      );
      // outbox 条目存在且状态为 pending
      final entry = await store.getOutboxEntry('msg-001');
      expect(entry, isNotNull);
      expect(entry!['status'], equals('pending'));
      expect(entry['payload'], equals('{"e2ee":{},"payload":"ct"}'));
    });

    test('confirmOutbox 标记已发送', () async {
      await store.persistSessionWithOutbox(
        peerUid: '200',
        peerDeviceId: 'dev-A',
        pickle: 'p',
        outboxId: 'msg-002',
        payload: 'x',
      );

      await store.confirmOutbox('msg-002');
      final entry = await store.getOutboxEntry('msg-002');
      expect(entry!['status'], equals('sent'));
      expect(entry['sent_at'], isNotNull);
    });

    test('pendingOutbox 返回所有未确认条目（崩溃恢复）', () async {
      await store.persistSessionWithOutbox(
        peerUid: '200',
        peerDeviceId: 'd1',
        pickle: 'p1',
        outboxId: 'msg-A',
        payload: 'a',
      );
      await store.persistSessionWithOutbox(
        peerUid: '200',
        peerDeviceId: 'd2',
        pickle: 'p2',
        outboxId: 'msg-B',
        payload: 'b',
      );
      await store.confirmOutbox('msg-A');

      final pending = await store.pendingOutbox();
      expect(pending.length, equals(1));
      expect(pending.first['id'], equals('msg-B'));
    });

    test('purgeOutbox 清理已确认条目', () async {
      await store.persistSessionWithOutbox(
        peerUid: '200',
        peerDeviceId: 'd1',
        pickle: 'p',
        outboxId: 'msg-C',
        payload: 'c',
      );
      await store.confirmOutbox('msg-C');
      await store.purgeOutbox(olderThanMs: 0);

      expect(await store.getOutboxEntry('msg-C'), isNull);
    });
  });

  group('Inbox dedupe（接收侧原子性）', () {
    test('dedupeAndPersistSession 原子：首次处理返回 true', () async {
      final accepted = await store.dedupeAndPersistSession(
        messageId: 'inbound-001',
        peerUid: '100',
        peerDeviceId: 'dev-S',
        pickle: 'ratchet-adv',
      );

      expect(accepted, isTrue);
      expect(
        await store.loadSession(peerUid: '100', peerDeviceId: 'dev-S'),
        equals('ratchet-adv'),
      );
    });

    test('dedupeAndPersistSession 重复消息返回 false（不推进 ratchet）', () async {
      await store.dedupeAndPersistSession(
        messageId: 'inbound-002',
        peerUid: '100',
        peerDeviceId: 'dev-S',
        pickle: 'v1',
      );

      // 重复投递：不应覆盖 session
      final accepted = await store.dedupeAndPersistSession(
        messageId: 'inbound-002',
        peerUid: '100',
        peerDeviceId: 'dev-S',
        pickle: 'v2-should-not-persist',
      );

      expect(accepted, isFalse);
      expect(
        await store.loadSession(peerUid: '100', peerDeviceId: 'dev-S'),
        equals('v1'),
      );
    });

    test('isDuplicate 独立查询', () async {
      expect(await store.isDuplicate('msg-new'), isFalse);

      await store.dedupeAndPersistSession(
        messageId: 'msg-new',
        peerUid: '100',
        peerDeviceId: 'dev-S',
        pickle: 'p',
      );

      expect(await store.isDuplicate('msg-new'), isTrue);
    });

    test('purgeDedupe 清理旧记录', () async {
      await store.dedupeAndPersistSession(
        messageId: 'old-msg',
        peerUid: '100',
        peerDeviceId: 'dev-S',
        pickle: 'p',
      );

      await store.purgeDedupe(olderThanMs: 0);
      expect(await store.isDuplicate('old-msg'), isFalse);
    });
  });

  group('事务原子性验证', () {
    test('persistSessionWithOutbox 事务内失败时 session 不写入', () async {
      // 模拟：outbox payload 为 null 触发 NOT NULL 约束失败
      // 由于 SQLite 事务回滚，session 也不应被写入
      try {
        await store.persistSessionWithOutbox(
          peerUid: '300',
          peerDeviceId: 'dev-Z',
          pickle: 'should-rollback',
          outboxId: 'msg-fail',
          payload: null as dynamic, // 触发 NOT NULL 约束
        );
      } catch (_) {
        // 预期抛异常
      }

      // 事务回滚：session 未写入
      expect(
        await store.loadSession(peerUid: '300', peerDeviceId: 'dev-Z'),
        isNull,
      );
      // outbox 也未写入
      expect(await store.getOutboxEntry('msg-fail'), isNull);
    });
  });
}
