/// E2EE-025 — Replay, Counter and Epoch Sequence Validation Tests.
///
/// Ref: 22-claude-code-execution-state.md (E2EE-025)
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

    test(
      'negative path: duplicate sequence number causes replay_detected rejection',
      () async {
        final m1 = await buildEnvelope(1, 'sess-2');
        final m1Duplicate = await buildEnvelope(1, 'sess-2');

        // First delivery passes
        final r1 = await E2EEService.decryptIncomingPayload(payload: m1);
        expect(r1['_e2ee_failed'], isNot(true));

        // Replay delivery fails closed
        final r2 = await E2EEService.decryptIncomingPayload(
          payload: m1Duplicate,
        );
        expect(r2['_e2ee_failed'], isTrue);
        expect(r2['_e2ee_reason'], equals('replay_detected'));
      },
    );

    test(
      'negative path: lower sequence number causes replay_detected rejection',
      () async {
        final mHigh = await buildEnvelope(10, 'sess-3');
        final mLow = await buildEnvelope(5, 'sess-3');

        // Higher sequence (seq = 10) passes first
        final r1 = await E2EEService.decryptIncomingPayload(payload: mHigh);
        expect(r1['_e2ee_failed'], isNot(true));

        // Lower sequence (seq = 5) gets rejected as a delayed/replayed message
        final r2 = await E2EEService.decryptIncomingPayload(payload: mLow);
        expect(r2['_e2ee_failed'], isTrue);
        expect(r2['_e2ee_reason'], equals('replay_detected'));
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
