/// E2EE-024 — Systematic Mutation Matrix and Context Binding Guard Verification.
///
/// Ref: 22-claude-code-execution-state.md (E2EE-024)
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee_service.dart' hide RecipientDevice;

/// Identity Protocol for testing (原样解密).
class _IdentityProtocol implements E2eeSessionProtocol {
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
    return E2eeCiphertext(plaintext, const {'session_id': 'sess-xyz'});
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
  TestWidgetsFlutterBinding.ensureInitialized();

  // E2EE-027: encryptV3 提交 immutable outbox 后才交出可发送信封，
  // 故生产加密路径需要可用的事务存储（真实 SQLite ffi in-memory）。
  late Database db;

  setUpAll(sqfliteFfiInit);

  // 逐用例独立 DB：crypto_session_sequence 是跨消息单调状态，
  // 共享 DB 会让用例结果依赖执行顺序。
  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(_IdentityProtocol());
  });

  tearDown(() async {
    E2eeProtocolRegistry.resetForTest();
    SqliteService.setDbForTest(null);
    await db.close();
  });

  group('E2EE-024 Mutation Matrix Tests', () {
    const originalPayload = {
      'msg_type': 'text',
      'body': 'mutation matrix test payload',
      'ts': 1753500000000,
    };

    Future<Map<String, dynamic>> buildValidEnvelope() async {
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
        sessionRef: 'sess-xyz',
        epochOrCounter: 1,
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

    test('Systematic Mutation Matrix yields 100% Rejection Rate', () async {
      final validEnvelope = await buildValidEnvelope();

      // Define mutation strategies (modifying specific keys or deep metadata paths)
      final List<Map<String, dynamic> Function(Map<String, dynamic>)>
      mutationMatrix = [
        // 1. Mutate transport id
        (env) => env..['id'] = 'forged-msg-id',
        // 2. Mutate transport from
        (env) => env..['from'] = '999',
        // 3. Mutate transport to
        (env) => env..['to'] = '999',
        // 4. Mutate transport type
        (env) => env..['type'] = 'C2G',
        // 5. Mutate transport msg_type
        (env) => env..['msg_type'] = 'image',
        // 6. Mutate transport sender_did
        (env) => env..['sender_did'] = 'forged-did',
        // 7. Mutate transport session_id
        (env) {
          final e2ee = Map<String, dynamic>.from(env['e2ee']);
          final proto = Map<String, dynamic>.from(e2ee['protocol_metadata']);
          proto['session_id'] = 'forged-session-ref';
          e2ee['protocol_metadata'] = proto;
          env['e2ee'] = e2ee;
          return env;
        },
        // 8. Mutate header_hash
        (env) {
          final e2ee = Map<String, dynamic>.from(env['e2ee']);
          e2ee['header_hash'] = 'forged-header-hash-value';
          env['e2ee'] = e2ee;
          return env;
        },
        // 9. Mutate ciphertext
        (env) {
          final e2ee = Map<String, dynamic>.from(env['e2ee']);
          e2ee['ciphertext'] = 'forged-ciphertext-value';
          env['e2ee'] = e2ee;
          return env;
        },
        // 10. Mutate meta_version to invalid number
        (env) {
          final e2ee = Map<String, dynamic>.from(env['e2ee']);
          e2ee['meta_version'] = 99;
          env['e2ee'] = e2ee;
          return env;
        },
        // 11. Omit id entirely
        (env) => env..remove('id'),
        // 12. Omit from entirely
        (env) => env..remove('from'),
        // 13. Omit to entirely
        (env) => env..remove('to'),
        // 14. Omit type entirely
        (env) => env..remove('type'),
        // 15. Omit msg_type entirely
        (env) => env..remove('msg_type'),
      ];

      var mutationsRun = 0;
      var mutationsRejected = 0;

      for (var i = 0; i < mutationMatrix.length; i++) {
        // deep-copy the valid envelope so mutations are isolated
        final freshEnvelope =
            jsonDecode(jsonEncode(validEnvelope)) as Map<String, dynamic>;
        final mutatedEnvelope = mutationMatrix[i](freshEnvelope);

        mutationsRun++;

        final decrypted = await E2EEService.decryptIncomingPayload(
          payload: mutatedEnvelope,
        );

        if (decrypted['_e2ee_failed'] == true) {
          mutationsRejected++;
        } else {
          fail('Mutation Case $i bypassed the Context Binding Guard!');
        }
      }

      final rejectionRate = (mutationsRejected / mutationsRun) * 100;
      expect(
        rejectionRate,
        equals(100.0),
        reason: 'Rejection rate must be exactly 100%',
      );
      expect(mutationsRun, equals(mutationMatrix.length));
    });
  });
}
