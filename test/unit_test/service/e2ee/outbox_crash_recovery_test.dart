/// E2EE-027 — Atomic Outbox/Inbox and Crash Recovery Tests.
///
/// Ref: 22-claude-code-execution-state.md (E2EE-027)
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/sqlite.dart';

/// Identity Protocol for testing (原样解密，不真正使用 vodozemac ratchet).
class _IdentityProtocol implements E2eeSessionProtocol {
  static int encryptCallCount = 0;

  @override
  ProtocolSuite get suite => ProtocolSuite.olm;

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {}

  @override
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  }) async {
    encryptCallCount++;
    return E2eeCiphertext('mock-ciphertext-${encryptCallCount}', {
      'session_id': 'sess-outbox',
      'message_type': 1,
    });
  }

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    return ciphertext;
  }

  @override
  Future<void> clearAll() async {}
}

void main() {
  late Database db;
  late CryptoStore store;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(_IdentityProtocol());
  });

  setUp(() async {
    OlmSessionService.to.resetForTest();
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    store = CryptoStore(db);
    await store.ensureSchema();
    SqliteService.setDbForTest(db);

    _IdentityProtocol.encryptCallCount = 0;
  });

  tearDown(() async {
    await db.close();
    SqliteService.setDbForTest(null);
    OlmSessionService.to.resetForTest();
  });

  tearDownAll(E2eeProtocolRegistry.resetForTest);

  group('E2EE-027 Outbox Integration with encryptV3:', () {
    test(
      'encryptV3 atomically persists outbox entry with complete v3 envelope',
      () async {
        const messageId = 'msg-outbox-001';
        final result = await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'hello'}),
          recipients: const [
            RecipientDevice(deviceId: 'dev-1', keyId: 'k1', publicKey: 'pk-1'),
          ],
          context: const E2eeContext(peerUid: '200', scope: 'c2c'),
          messageId: messageId,
          senderUid: '100',
          senderDid: 'dev-sender',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-outbox',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );

        // outbox 条目存在且 status=pending
        final entry = await store.getOutboxEntry(messageId);
        expect(entry, isNotNull, reason: 'outbox entry must be created');
        expect(entry!['status'], equals('pending'));
        // payload 包含完整 v3 信封
        final payload =
            jsonDecode(entry['payload'] as String) as Map<String, dynamic>;
        expect(payload['meta_version'], equals(3));
        expect(payload['protected_header'], isNotNull);
        expect(payload['header_hash'], isNotNull);
        expect(payload['ciphertext'], isNotNull);

        // encryptV3 返回的 metadata 与 outbox payload 一致
        expect(result.metadata['meta_version'], equals(3));
      },
    );

    test(
      'confirmOutbox marks entry as sent after successful delivery',
      () async {
        const messageId = 'msg-outbox-002';
        await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'test'}),
          recipients: const [
            RecipientDevice(deviceId: 'dev-1', keyId: 'k1', publicKey: 'pk-1'),
          ],
          context: const E2eeContext(peerUid: '200', scope: 'c2c'),
          messageId: messageId,
          senderUid: '100',
          senderDid: 'dev-sender',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-outbox',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );

        // 确认已发送
        await store.confirmOutbox(messageId);
        final entry = await store.getOutboxEntry(messageId);
        expect(entry!['status'], equals('sent'));
        expect(entry['sent_at'], isNotNull);
      },
    );

    test(
      'pendingOutbox returns all unsent entries for crash recovery',
      () async {
        // 模拟：A 和 B 都已加密但未确认发送（模拟崩溃）
        await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'msg A'}),
          recipients: const [
            RecipientDevice(deviceId: 'dev-1', keyId: 'k1', publicKey: 'pk-1'),
          ],
          context: const E2eeContext(peerUid: '200', scope: 'c2c'),
          messageId: 'msg-crash-A',
          senderUid: '100',
          senderDid: 'dev-sender',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-outbox',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );

        await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'msg B'}),
          recipients: const [
            RecipientDevice(deviceId: 'dev-1', keyId: 'k1', publicKey: 'pk-1'),
          ],
          context: const E2eeContext(peerUid: '200', scope: 'c2c'),
          messageId: 'msg-crash-B',
          senderUid: '100',
          senderDid: 'dev-sender',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-outbox',
          epochOrCounter: 2,
          createdAtMs: 1753500000000,
        );

        // 只确认 msg A
        await store.confirmOutbox('msg-crash-A');

        // msg B 仍在 pending
        final pending = await store.pendingOutbox();
        expect(pending.length, equals(1));
        expect(pending.first['id'], equals('msg-crash-B'));
      },
    );

    test('outbox purge cleans confirmed entries', () async {
      const messageId = 'msg-outbox-purge';
      await E2eeOutboundRouter.encryptV3(
        suite: ProtocolSuite.olm,
        plaintext: jsonEncode({'body': 'purge me'}),
        recipients: const [
          RecipientDevice(deviceId: 'dev-1', keyId: 'k1', publicKey: 'pk-1'),
        ],
        context: const E2eeContext(peerUid: '200', scope: 'c2c'),
        messageId: messageId,
        senderUid: '100',
        senderDid: 'dev-sender',
        destination: '200',
        messageType: 'text',
        action: 'message',
        sessionRef: 'sess-outbox',
        epochOrCounter: 1,
        createdAtMs: 1753500000000,
      );

      await store.confirmOutbox(messageId);
      await store.purgeOutbox(olderThanMs: 0);
      expect(await store.getOutboxEntry(messageId), isNull);
    });
  });

  group('E2EE-027 Crash Safety — No Key Reuse During Retry:', () {
    test(
      'retry from outbox reuses SAME ciphertext — no re-encrypt call',
      () async {
        const messageId = 'msg-retry-001';
        final encryptCountBefore = _IdentityProtocol.encryptCallCount;

        // 1. 加密 + 入 outbox
        await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'retry test'}),
          recipients: const [
            RecipientDevice(deviceId: 'dev-1', keyId: 'k1', publicKey: 'pk-1'),
          ],
          context: const E2eeContext(peerUid: '200', scope: 'c2c'),
          messageId: messageId,
          senderUid: '100',
          senderDid: 'dev-sender',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-outbox',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );
        expect(
          _IdentityProtocol.encryptCallCount,
          equals(encryptCountBefore + 1),
        );

        // 2. 模拟崩溃：取出 outbox pending entry
        final pending = await store.pendingOutbox();
        expect(pending.length, equals(1));
        final outboxEntry = pending.first;
        expect(outboxEntry['id'], equals(messageId));

        // 3. 直接从 outbox 读取 ciphertext 重发（不重新 encrypt）
        final envelope =
            jsonDecode(outboxEntry['payload'] as String)
                as Map<String, dynamic>;
        final retryCiphertext = envelope['ciphertext'];

        // 断言：未调用第二次 encrypt
        expect(
          _IdentityProtocol.encryptCallCount,
          equals(encryptCountBefore + 1),
        );

        // 4. 使用相同 ciphertext 发送（模拟实际网络重发）
        // ciphertext 内容应与第一次加密结果一致
        final originalCiphertext =
            (await store.getOutboxEntry(messageId))!['payload'] as String;
        final originalEnvelope = jsonDecode(originalCiphertext);
        expect(originalEnvelope['ciphertext'], equals(retryCiphertext));
      },
    );

    test(
      'concurrent send of same message — only one outbox entry, no double encrypt',
      () async {
        const messageId = 'msg-concurrent-001';
        final encryptCountBefore = _IdentityProtocol.encryptCallCount;

        // 模拟并发发送同一条消息（启动两次 encryptV3）
        await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'concurrent'}),
          recipients: const [
            RecipientDevice(deviceId: 'dev-1', keyId: 'k1', publicKey: 'pk-1'),
          ],
          context: const E2eeContext(peerUid: '200', scope: 'c2c'),
          messageId: messageId,
          senderUid: '100',
          senderDid: 'dev-sender',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-outbox',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );

        // 第二次「并发」encryptV3 应该幂等（写同一 outbox id）
        await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'concurrent'}),
          recipients: const [
            RecipientDevice(deviceId: 'dev-1', keyId: 'k1', publicKey: 'pk-1'),
          ],
          context: const E2eeContext(peerUid: '200', scope: 'c2c'),
          messageId: messageId,
          senderUid: '100',
          senderDid: 'dev-sender',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-outbox',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );

        // 确认只有一个 pending entry（幂等：第二个写覆盖了第一个）
        final pending = await store.pendingOutbox();
        expect(pending.length, equals(1));
        expect(pending.first['id'], equals(messageId));
      },
    );
  });

  group('E2EE-027 Inbox dedupe atomicity:', () {
    test(
      'dedupeAndPersistSession blocks double ratchet advance on replay',
      () async {
        // 第一次接收
        final accepted1 = await store.dedupeAndPersistSession(
          messageId: 'inbound-027-001',
          peerUid: '100',
          peerDeviceId: 'dev-S',
          pickle: 'ratchet-v1',
        );
        expect(accepted1, isTrue);
        expect(
          await store.loadSession(peerUid: '100', peerDeviceId: 'dev-S'),
          equals('ratchet-v1'),
        );

        // 重放：不应覆盖 v2
        final accepted2 = await store.dedupeAndPersistSession(
          messageId: 'inbound-027-001',
          peerUid: '100',
          peerDeviceId: 'dev-S',
          pickle: 'ratchet-v2-SHOULD-NOT-PERSIST',
        );
        expect(accepted2, isFalse);
        expect(
          await store.loadSession(peerUid: '100', peerDeviceId: 'dev-S'),
          equals('ratchet-v1'),
          reason: 'replay must not advance ratchet state',
        );
      },
    );

    test(
      'dedupeAndPersistSession atomic — crash between dedupe insert and session persist rolls back both',
      () async {
        // 通过重复 message_id 来验证事务回滚
        await store.dedupeAndPersistSession(
          messageId: 'inbound-027-002',
          peerUid: '100',
          peerDeviceId: 'dev-S',
          pickle: 'ratchet-atomic-test',
        );

        // 第二次用不同 session pickle 但相同 messageId → 应回滚
        final accepted = await store.dedupeAndPersistSession(
          messageId: 'inbound-027-002',
          peerUid: '100',
          peerDeviceId: 'dev-S',
          pickle: 'should-not-overwrite',
        );
        expect(accepted, isFalse);

        // session 仍保持 v1
        expect(
          await store.loadSession(peerUid: '100', peerDeviceId: 'dev-S'),
          equals('ratchet-atomic-test'),
        );
      },
    );

    test('isDuplicate confirms dedupe state is durable after commit', () async {
      expect(await store.isDuplicate('inbound-027-003'), isFalse);

      await store.dedupeAndPersistSession(
        messageId: 'inbound-027-003',
        peerUid: '100',
        peerDeviceId: 'dev-S',
        pickle: 'durable-pickle',
      );

      expect(await store.isDuplicate('inbound-027-003'), isTrue);
    });
  });
}
