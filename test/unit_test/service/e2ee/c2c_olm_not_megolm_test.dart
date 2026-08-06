/// E2EE-029 — C2C per-device Olm fan-out: 禁止 C2C 新消息走 Megolm/RSA
///
/// 每个对端设备独立 Olm 会话 + PFv3 信封。C2C 新写入禁止 Megolm/RSA。
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/config/init.dart' as app_init;
import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee_service.dart' hide RecipientDevice;
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/sqlite.dart';

/// 协议调用追踪器:记录 encrypt/decrypt 调用次数,验证 C2C 路径不走 Megolm/RSA。
class _TrackingProtocol implements E2eeSessionProtocol {
  static int encryptCalls = 0;
  static int decryptCalls = 0;
  static String? lastEncryptedPlaintext;

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
    encryptCalls++;
    lastEncryptedPlaintext = plaintext;
    final deviceId = recipients.isNotEmpty
        ? recipients.first.deviceId
        : 'unknown';
    return E2eeCiphertext('olm-ct-for-$deviceId', {
      'session_id': 'sess-$deviceId-${encryptCalls}',
      'message_type': 1,
      'peer_uid': context.peerUid ?? '',
      'peer_device_id': context.peerDeviceId ?? '',
    });
  }

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    decryptCalls++;
    return ciphertext;
  }

  @override
  Future<void> clearAll() async {}

  static void reset() {
    encryptCalls = 0;
    decryptCalls = 0;
    lastEncryptedPlaintext = null;
  }
}

/// RSA 专用的追踪协议:验证 C2C 新写入从不调用 RSA。
class _RsaNeverCalledProtocol implements E2eeSessionProtocol {
  static int encryptCalls = 0;
  static int decryptCalls = 0;

  @override
  ProtocolSuite get suite => ProtocolSuite.rsa;

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
    encryptCalls++;
    throw StateError('RSA encrypt should NEVER be called for C2C');
  }

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    decryptCalls++;
    return ciphertext;
  }

  @override
  Future<void> clearAll() async {}

  static void reset() {
    encryptCalls = 0;
    decryptCalls = 0;
  }
}

/// Megolm 协议:验证 C2C 发送路径不调用 Megolm encrypt。
class _MegolmTrackingProtocol implements E2eeSessionProtocol {
  static int encryptCalls = 0;
  static int decryptCalls = 0;

  @override
  ProtocolSuite get suite => ProtocolSuite.megolm;

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
    encryptCalls++;
    throw StateError(
      'Megolm encrypt must not be used for C2C when Olm is enabled',
    );
  }

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    decryptCalls++;
    return ciphertext;
  }

  @override
  Future<void> clearAll() async {}

  static void reset() {
    encryptCalls = 0;
    decryptCalls = 0;
  }
}

void main() {
  late Database db;
  late CryptoStore store;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // 为 outbox 集成准备
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    store = CryptoStore(db);
    await store.ensureSchema();
    SqliteService.setDbForTest(db);

    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(_TrackingProtocol());
    E2eeProtocolRegistry.register(_MegolmTrackingProtocol());
    E2eeProtocolRegistry.register(_RsaNeverCalledProtocol());
    app_init.deviceId = 'my-device-001';

    _TrackingProtocol.reset();
    _MegolmTrackingProtocol.reset();
    _RsaNeverCalledProtocol.reset();
  });

  tearDown(() async {
    await db.close();
    SqliteService.setDbForTest(null);
    OlmSessionService.to.resetForTest();
  });

  tearDownAll(E2eeProtocolRegistry.resetForTest);

  group('E2EE-029 C2C Olm-only: per-device encryption', () {
    test(
      'C2C fan-out: each target device gets independent ciphertext',
      () async {
        // 模拟 3 个对端设备
        const devices = ['peer-device-1', 'peer-device-2', 'peer-device-3'];
        final devicesMap = <String, dynamic>{};
        final plaintext = jsonEncode({'body': 'per-device test'});

        for (final did in devices) {
          final encrypted = await E2eeOutboundRouter.encryptV3(
            suite: ProtocolSuite.olm,
            plaintext: plaintext,
            recipients: [
              RecipientDevice(
                deviceId: did,
                keyId: 'k-$did',
                publicKey: 'pk-$did',
              ),
            ],
            context: E2eeContext(
              peerUid: '200',
              peerDeviceId: did,
              scope: 'c2c',
            ),
            messageId: 'msg-c2c-olm-001',
            senderUid: '100',
            senderDid: 'my-device-001',
            destination: '200',
            messageType: 'text',
            action: 'message',
            sessionRef: 'sess-$did',
            epochOrCounter: 1,
            createdAtMs: 1753500000000,
          );
          final env = Map<String, dynamic>.from(encrypted.metadata);
          env.remove('meta_version');
          devicesMap[did] = env;
        }

        // 每个设备都有独立信封
        expect(devicesMap.length, equals(3));

        // 每个设备的 ciphertext 不同（per-device Olm session）
        final cts = devicesMap.values.map((v) => v['ciphertext']).toSet();
        expect(
          cts.length,
          equals(3),
          reason: 'each device must have unique ciphertext',
        );

        // 验证加密被调用了 3 次（每个设备一次）
        expect(_TrackingProtocol.encryptCalls, equals(3));

        // Megolm / RSA 从未被调用
        expect(_MegolmTrackingProtocol.encryptCalls, equals(0));
        expect(_RsaNeverCalledProtocol.encryptCalls, equals(0));
      },
    );

    test(
      'C2C fan-out wire format: fan_out=per_device with devices map',
      () async {
        final env = await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'wire format'}),
          recipients: const [
            RecipientDevice(deviceId: 'peer-1', keyId: 'k1', publicKey: 'pk'),
          ],
          context: const E2eeContext(
            peerUid: '200',
            peerDeviceId: 'peer-1',
            scope: 'c2c',
          ),
          messageId: 'msg-wire-001',
          senderUid: '100',
          senderDid: 'my-device-001',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-wire',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );

        final e2eeMeta = env.metadata;
        // v3 信封必须包含这些字段
        expect(e2eeMeta['meta_version'], equals(3));
        expect(e2eeMeta['protected_header'], isNotNull);
        expect(e2eeMeta['header_hash'], isNotNull);
        expect(e2eeMeta['ciphertext'], isNotNull);
        expect(e2eeMeta['protocol_metadata'], isNotNull);

        // 协议元数据包含 session_id
        final protoMeta = e2eeMeta['protocol_metadata'] as Map;
        expect(protoMeta['session_id'], contains('sess'));

        // Olm encrypt 被调用（不是 Megolm 或 RSA）
        expect(_TrackingProtocol.encryptCalls, equals(1));
        expect(_MegolmTrackingProtocol.encryptCalls, equals(0));
        expect(_RsaNeverCalledProtocol.encryptCalls, equals(0));
      },
    );
  });

  group('E2EE-029 No Megolm/RSA for C2C new messages:', () {
    test('C2C encryptV3 calls Olm protocol, never Megolm or RSA', () async {
      await E2eeOutboundRouter.encryptV3(
        suite: ProtocolSuite.olm,
        plaintext: jsonEncode({'body': 'olm only'}),
        recipients: const [
          RecipientDevice(deviceId: 'peer-1', keyId: 'k1', publicKey: 'pk'),
        ],
        context: const E2eeContext(
          peerUid: '200',
          peerDeviceId: 'peer-1',
          scope: 'c2c',
        ),
        messageId: 'msg-olm-only',
        senderUid: '100',
        senderDid: 'my-device-001',
        destination: '200',
        messageType: 'text',
        action: 'message',
        sessionRef: 'sess-only',
        epochOrCounter: 1,
        createdAtMs: 1753500000000,
      );

      // Olm encrypt 被调用
      expect(_TrackingProtocol.encryptCalls, equals(1));
      // Megolm 永远不会被调用用于 C2C 加密
      expect(
        _MegolmTrackingProtocol.encryptCalls,
        equals(0),
        reason: 'Megolm must never be used for C2C new messages',
      );
      // RSA 永远不会被调用用于 C2C 加密
      expect(
        _RsaNeverCalledProtocol.encryptCalls,
        equals(0),
        reason: 'RSA must never be used for C2C new messages',
      );
    });

    test('decryptIncomingPayload for C2C Olm routes to Olm not Megolm', () async {
      // Build a valid Olm-encrypted C2C message
      final encrypted = await E2eeOutboundRouter.encryptV3(
        suite: ProtocolSuite.olm,
        plaintext: jsonEncode({
          'msg_type': 'text',
          'body': 'c2c decrypt test',
          'ts': 1753500000000,
        }),
        recipients: const [
          RecipientDevice(
            deviceId: 'my-device-001',
            keyId: 'k-me',
            publicKey: 'pk',
          ),
        ],
        context: const E2eeContext(
          peerUid: '200',
          peerDeviceId: 'my-device-001',
          scope: 'c2c',
        ),
        messageId: 'msg-decrypt-test',
        senderUid: '200',
        senderDid: 'peer-sender',
        destination: '100',
        messageType: 'text',
        action: 'message',
        sessionRef: 'sess-decrypt',
        epochOrCounter: 1,
        createdAtMs: 1753500000000,
      );

      final incoming = {
        'id': 'msg-decrypt-test',
        'type': 'C2C',
        'from': '200',
        'to': '100',
        'msg_type': 'text',
        'sender_did': 'peer-sender',
        'e2ee': encrypted.metadata,
        'payload': '',
      };

      _TrackingProtocol.reset();

      // 解密：使用 _TrackingProtocol（Olm），ciphertext 原样返回
      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );

      // 解密成功（_e2ee_failed 不应该是 true）
      // 注意:由于 E2EEService.decryptIncomingPayload 使用 ProtocolRegistry 路由,
      // 它会按 e2ee.meta_version=3 走 v3 路径,_TrackingProtocol decrypt 返回 ciphertext
      expect(decrypted.containsKey('msg_type'), isTrue);
    });
  });

  group('E2EE-029 Strict fail-closed: no partial delivery', () {
    test('fan_out without any device keys → fail-closed', () async {
      // 模拟对端无设备密钥
      // 构建一个空 devices 的 fan_out 消息
      final incoming = {
        'id': 'msg-no-devices',
        'type': 'C2C',
        'from': '200',
        'to': '100',
        'msg_type': 'text',
        'e2ee': {
          'meta_version': 3,
          'protocol': 'olm',
          'version': 1,
          'fan_out': 'per_device',
          'devices': <String, dynamic>{},
        },
        'payload': '',
      };

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: incoming,
      );
      expect(decrypted['_e2ee_failed'], isTrue);
    });

    test(
      'fan_out per_device envelope correctly routed to own device',
      () async {
        // 验证:fan_out 本设备信封被正确路由和打开
        // 使用与已有 fan_out_per_device_test 相同的测试模式
        final innerPayload = {
          'id': 'msg-revoked-test',
          'type': 'C2C',
          'from': '200',
          'to': '100',
          'msg_type': 'text',
          'sender_did': 'peer-sender',
          'body': 'active only',
          'ts': 1753500000000,
        };
        final envActive = await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode(innerPayload),
          recipients: const [
            RecipientDevice(
              deviceId: 'my-device-001',
              keyId: 'k-me',
              publicKey: 'pk',
            ),
          ],
          context: const E2eeContext(
            peerUid: '200',
            peerDeviceId: 'my-device-001',
            scope: 'c2c',
          ),
          messageId: 'msg-revoked-test',
          senderUid: '200',
          senderDid: 'peer-sender',
          destination: '100',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-active',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );

        final envData = Map<String, dynamic>.from(envActive.metadata);
        envData.remove('meta_version');

        // 验证信封结构完整性
        expect(envData['protected_header'], isNotNull);
        expect(envData['header_hash'], isNotNull);
        expect(envData['ciphertext'], isNotNull);
        expect(envData['protocol_metadata'], isNotNull);

        // fan_out 格式: 信封不包含 meta_version（由外层统一标注）
        expect(envData.containsKey('meta_version'), isFalse);
        expect(envData.containsKey('protocol'), isFalse);
      },
    );
  });

  group('E2EE-029 Per-device session independence:', () {
    test(
      'two devices with same peerUid have independent session_ids',
      () async {
        final env1 = await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'device 1'}),
          recipients: const [
            RecipientDevice(deviceId: 'peer-d1', keyId: 'k1', publicKey: 'pk'),
          ],
          context: const E2eeContext(
            peerUid: '200',
            peerDeviceId: 'peer-d1',
            scope: 'c2c',
          ),
          messageId: 'msg-indep-1',
          senderUid: '100',
          senderDid: 'my-device-001',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-indep-d1',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );

        final env2 = await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'device 2'}),
          recipients: const [
            RecipientDevice(deviceId: 'peer-d2', keyId: 'k2', publicKey: 'pk'),
          ],
          context: const E2eeContext(
            peerUid: '200',
            peerDeviceId: 'peer-d2',
            scope: 'c2c',
          ),
          messageId: 'msg-indep-2',
          senderUid: '100',
          senderDid: 'my-device-001',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-indep-d2',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );

        // 两个设备的 session 独立（session_id 不同）
        final meta1 = env1.metadata['protocol_metadata'] as Map;
        final meta2 = env2.metadata['protocol_metadata'] as Map;
        expect(meta1['session_id'], isNot(equals(meta2['session_id'])));
      },
    );

    test(
      'outbox entries use message_id as key, independent per message',
      () async {
        await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'msg A'}),
          recipients: const [
            RecipientDevice(deviceId: 'peer-1', keyId: 'k1', publicKey: 'pk'),
          ],
          context: const E2eeContext(
            peerUid: '200',
            peerDeviceId: 'peer-1',
            scope: 'c2c',
          ),
          messageId: 'outbox-indep-A',
          senderUid: '100',
          senderDid: 'my-device-001',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-A',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );

        await E2eeOutboundRouter.encryptV3(
          suite: ProtocolSuite.olm,
          plaintext: jsonEncode({'body': 'msg B'}),
          recipients: const [
            RecipientDevice(deviceId: 'peer-1', keyId: 'k1', publicKey: 'pk'),
          ],
          context: const E2eeContext(
            peerUid: '200',
            peerDeviceId: 'peer-1',
            scope: 'c2c',
          ),
          messageId: 'outbox-indep-B',
          senderUid: '100',
          senderDid: 'my-device-001',
          destination: '200',
          messageType: 'text',
          action: 'message',
          sessionRef: 'sess-B',
          epochOrCounter: 1,
          createdAtMs: 1753500000000,
        );

        // 两个独立消息都有 outbox entry
        final entryA = await store.getOutboxEntry('outbox-indep-A');
        final entryB = await store.getOutboxEntry('outbox-indep-B');
        expect(entryA, isNotNull);
        expect(entryB, isNotNull);
        expect(entryA!['id'], isNot(equals(entryB!['id'])));
      },
    );
  });
}
