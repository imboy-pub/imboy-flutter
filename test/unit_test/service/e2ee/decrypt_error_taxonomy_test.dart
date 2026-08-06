/// v3 接收侧错误分类（ADR 15 §5「返回稳定、无秘密的错误分类」）。
///
/// `e2ee_service` 的 v3 解密段用 `catch (_)` 兜住了所有异常并一律归类为
/// `decrypt_error`，把两类语义完全不同的信号压平了：
/// - `DuplicateMessageException`：重复投递。ADR 15 §7.1 要求「重复密文幂等返回，
///   不重复推进 ratchet」——调用方需要能识别它并静默跳过，而不是当成解密失败报错。
/// - `OlmStateCommitException`（E2EE-030）：密码学状态无法原子提交。这是**可重试**的
///   本地存储故障，不是密文有问题；压成 decrypt_error 会让上层把可恢复故障当作
///   永久失败处理。
///
/// 两者都不放松安全（消息都不会被当作明文展示），但错误分类丢失违反 ADR 15 §5。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee_service.dart' hide RecipientDevice;
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/sqlite.dart';

/// 加密恒成功；解密抛出 [onDecrypt] 指定的异常（null 则原样返回）。
class _ThrowingProtocol implements E2eeSessionProtocol {
  _ThrowingProtocol();

  Object? onDecrypt;

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
  }) async => E2eeCiphertext(plaintext, const {'session_id': 'sess-tax'});

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    final err = onDecrypt;
    if (err != null) throw err;
    return ciphertext;
  }

  @override
  Future<void> clearAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late _ThrowingProtocol protocol;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    // OlmSessionService 缓存 CryptoStore 句柄，跨用例复用会指向已关闭的 DB
    OlmSessionService.to.resetForTest();
    protocol = _ThrowingProtocol();
    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(protocol);
  });

  tearDown(() async {
    E2eeProtocolRegistry.resetForTest();
    OlmSessionService.to.resetForTest();
    SqliteService.setDbForTest(null);
    await db.close();
  });

  Future<Map<String, dynamic>> buildIncoming() async {
    final result = await E2eeOutboundRouter.encryptV3(
      suite: ProtocolSuite.olm,
      plaintext: jsonEncode({'msg_type': 'text', 'body': 'hi'}),
      recipients: const [
        RecipientDevice(deviceId: 'dev-1', keyId: 'k1', publicKey: 'pk-1'),
      ],
      context: const E2eeContext(peerUid: '200', scope: 'c2c'),
      messageId: 'msg-tax-001',
      senderUid: '100',
      senderDid: 'dev-sender',
      destination: '200',
      messageType: 'text',
      action: 'message',
      sessionRef: 'sess-tax',
      epochOrCounter: 1,
      createdAtMs: 1780000000000,
    );
    return {
      'id': 'msg-tax-001',
      'type': 'C2C',
      'from': '100',
      'to': '200',
      'msg_type': 'text',
      'e2ee': result.metadata,
      'payload': result.ciphertext,
      'sender_did': 'dev-sender',
    };
  }

  group('v3 接收侧错误分类（ADR 15 §5）', () {
    test('重复投递必须可识别，不得压成 decrypt_error', () async {
      final incoming = await buildIncoming();
      protocol.onDecrypt = DuplicateMessageException('msg-tax-001');

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      expect(decrypted['_e2ee_failed'], isTrue);
      expect(
        decrypted['_e2ee_reason'],
        equals('duplicate_message'),
        reason: 'ADR 15 §7.1 幂等：上层需能识别重复投递并静默跳过',
      );
    });

    test('CryptoStore 提交故障必须可识别为可重试，不得压成 decrypt_error', () async {
      final incoming = await buildIncoming();
      protocol.onDecrypt = OlmStateCommitException('store unavailable');

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      expect(decrypted['_e2ee_failed'], isTrue);
      expect(
        decrypted['_e2ee_reason'],
        equals('crypto_store_unavailable'),
        reason: 'E2EE-030 fail-closed 是可重试的本地故障，不是密文损坏',
      );
    });

    test('真实解密失败仍归类为 decrypt_error（分类不过度细化）', () async {
      final incoming = await buildIncoming();
      protocol.onDecrypt = const E2eeDecryptException('bad_mac');

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      expect(decrypted['_e2ee_failed'], isTrue);
      expect(decrypted['_e2ee_reason'], equals('decrypt_error'));
    });

    test('错误分类不得泄漏秘密细节', () async {
      final incoming = await buildIncoming();
      protocol.onDecrypt = Exception('pickle key = SUPERSECRET');

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      expect(
        decrypted['_e2ee_reason'].toString(),
        isNot(contains('SUPERSECRET')),
      );
    });
  });
}
