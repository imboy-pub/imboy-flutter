/// E2EE-025 — Replay / Counter / Epoch 语义测试（**选项 C 定案后已重写**）。
///
/// Ref: `22-claude-code-execution-state.md` (E2EE-025)、
///      `25-proposal-replay-counter-semantics.md` §3 选项 C（2026-07-28 人工签字）
///
/// ⚠️ 本文件原先断言「重复/较小的 `epoch_or_counter` → `replay_detected`」。
/// 该语义已被选项 C **明确废止**，原因不是"为了变绿"，而是：
///   1. 生产发送侧 counter 恒 0，严格单调会让首条合法消息即被误判 replay
///      （提案 §1.2 的 P2）——旧断言之所以能过，是测试**手工**递增了 counter，
///      生产从来不会；
///   2. 离线批量投递与 WS 重连乱序是 IMBoy 常态，严格单调必然误杀真实消息
///      （提案 §1.2 的 P3）；
///   3. 重放防护职责改由 `message_id` dedupe（位于**受认证**的
///      protected_header 内，ADR 15 §7.1）+ Olm ratchet「message key 用后即毁」
///      承担，二者在生产上均已接线生效。
///
/// 因此本文件现在守护的是**选项 C 的正确语义**：Olm/Megolm 不做序列检查，
/// 且 counter 乱序不得导致拒收；同时保留原有的正向与会话隔离用例。
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/e2ee_service.dart' hide RecipientDevice;

/// Identity Protocol for testing (原样解密).
class _IdentityProtocol implements E2eeSessionProtocol {
  static String activeSessionId = 'sess-xyz';

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
    return E2eeCiphertext(plaintext, {'session_id': activeSessionId});
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

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(_IdentityProtocol());
  });

  setUp(() async {
    OlmSessionService.to.resetForTest();
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    // Initialize CryptoStore schema
    final store = await OlmSessionService.to.cryptoStore;
    expect(store, isNotNull);
  });

  tearDown(() async {
    await db.close();
    SqliteService.setDbForTest(null);
    OlmSessionService.to.resetForTest();
  });

  tearDownAll(E2eeProtocolRegistry.resetForTest);

  group('E2EE-025 Sequence Counter and Replay Prevention Tests', () {
    const originalPayload = {
      'msg_type': 'text',
      'body': 'replay test payload',
      'ts': 1753500000000,
    };

    Future<Map<String, dynamic>> buildEnvelope(
      int sequence,
      String sessionId,
    ) async {
      _IdentityProtocol.activeSessionId = sessionId;

      final result = await E2eeOutboundRouter.encryptV3(
        suite: ProtocolSuite.olm,
        plaintext: jsonEncode(originalPayload),
        recipients: const [
          RecipientDevice(deviceId: 'dev-1', keyId: 'k1', publicKey: 'pk-1'),
        ],
        context: const E2eeContext(peerUid: '200', scope: 'c2c'),
        messageId: 'msg-001',
        senderUid: '100',
        senderDid: 'dev-sender',
        destination: '200',
        messageType: 'text',
        action: 'message',
        sessionRef: sessionId,
        epochOrCounter: sequence,
        createdAtMs: 1753500000000,
      );

      return {
        'id': 'msg-001',
        'type': 'C2C',
        'from': '100',
        'to': '200',
        'msg_type': 'text',
        'e2ee': result.metadata,
        'payload': result.ciphertext,
        'sender_did': 'dev-sender',
        'sender_dtype': 'ios',
      };
    }

    test('positive path: sequential messages decrypt successfully', () async {
      final m1 = await buildEnvelope(1, 'sess-1');
      final m2 = await buildEnvelope(2, 'sess-1');
      final m3 = await buildEnvelope(3, 'sess-1');

      // Message 1 (seq = 1) -> Decrypts successfully
      final r1 = await E2EEService.decryptIncomingPayload(payload: m1);
      print('> r1: $r1');
      expect(r1['_e2ee_failed'], isNot(true));

      // Message 2 (seq = 2) -> Decrypts successfully
      final r2 = await E2EEService.decryptIncomingPayload(payload: m2);
      expect(r2['_e2ee_failed'], isNot(true));

      // Message 3 (seq = 3) -> Decrypts successfully
      final r3 = await E2EEService.decryptIncomingPayload(payload: m3);
      expect(r3['_e2ee_failed'], isNot(true));
    });

    // 选项 C：重复的 epoch_or_counter 不再是拒收理由。
    // 旧断言（replay_detected）与生产实况冲突——生产 counter 恒 0，
    // 按旧语义**每一条**消息都会重复，等于全线不可读。
    test(
      'option C: duplicate sequence number must NOT be rejected as replay',
      () async {
        final m1 = await buildEnvelope(1, 'sess-2');
        final m1SameSeq = await buildEnvelope(1, 'sess-2');

        final r1 = await E2EEService.decryptIncomingPayload(payload: m1);
        expect(r1['_e2ee_failed'], isNot(true));

        final r2 = await E2EEService.decryptIncomingPayload(payload: m1SameSeq);
        expect(
          r2['_e2ee_reason'],
          isNot(equals('replay_detected')),
          reason: 'Olm/Megolm 不做序列检查；重放防护归 message_id dedupe + ratchet',
        );
      },
    );

    // 选项 C：较小的 epoch_or_counter 是合法的乱序投递，必须可读。
    test(
      'option C: lower sequence number is legitimate out-of-order, must be readable',
      () async {
        final mHigh = await buildEnvelope(10, 'sess-3');
        final mLow = await buildEnvelope(5, 'sess-3');

        final r1 = await E2EEService.decryptIncomingPayload(payload: mHigh);
        expect(r1['_e2ee_failed'], isNot(true));

        final r2 = await E2EEService.decryptIncomingPayload(payload: mLow);
        expect(r2['_e2ee_reason'], isNot(equals('replay_detected')));
        expect(
          r2['_e2ee_failed'],
          isNot(true),
          reason: '离线批量与 WS 重连乱序是常态，严格单调会误杀真实消息（提案 §1.2 P3）',
        );
      },
    );

    test(
      'isolation: different session_ids maintain independent sequence counters',
      () async {
        final mSess1Seq1 = await buildEnvelope(1, 'sess-4a');
        final mSess2Seq1 = await buildEnvelope(1, 'sess-4b');

        // Session A seq = 1 passes
        final r1 = await E2EEService.decryptIncomingPayload(
          payload: mSess1Seq1,
        );
        expect(r1['_e2ee_failed'], isNot(true));

        // Session B seq = 1 passes because it has independent session tracking
        final r2 = await E2EEService.decryptIncomingPayload(
          payload: mSess2Seq1,
        );
        expect(r2['_e2ee_failed'], isNot(true));
      },
    );
  });
}
