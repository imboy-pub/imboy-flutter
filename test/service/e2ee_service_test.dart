import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/rsa.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  final store = <String, String?>{};

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'write':
              final key = call.arguments['key'] as String;
              final value = call.arguments['value'] as String?;
              store[key] = value;
              return null;
            case 'read':
              final key = call.arguments['key'] as String;
              return store[key];
            case 'delete':
              final key = call.arguments['key'] as String;
              store.remove(key);
              return null;
            case 'deleteAll':
              store.clear();
              return null;
            default:
              return null;
          }
        });
  });

  setUp(() async {
    store.clear();
    deviceId = 'did_test_device_1';
    E2EEService.clearKeyCacheForTest();
    RSAService.resetForTest();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  group('decryptIncomingPayload v2 Tests', () {
    test('decryptIncomingPayload 能解密 v2 格式并保留元数据', () async {
      final pubPem = await RSAService.publicKey();
      final recipients = [
        RecipientDevice(deviceId: deviceId, keyId: 'key_v1', publicKey: pubPem),
      ];

      final plaintext = <String, dynamic>{
        'msg_type': 'text',
        'text': 'hello',
        'n': 1,
      };
      final encrypted = await E2EEService.buildE2EEData(
        plaintext: jsonEncode(plaintext),
        recipients: recipients,
      );

      final payload = <String, dynamic>{
        'msg_type': 'text',
        'client_send_ts': 1710000000000,
        'sender_did': deviceId,
        'e2ee': encrypted['e2ee'],
        'payload': encrypted['ciphertext'],
      };

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: payload,
      );

      expect(decrypted['msg_type'], 'text');
      expect(decrypted['text'], 'hello');
      expect(decrypted['n'], 1);
      expect(decrypted['sender_did'], deviceId);
      expect(decrypted['client_send_ts'], 1710000000000);
      expect(decrypted['_e2ee'], isA<Map>());
    });

    test('decryptIncomingPayload 对非法密文格式返回失败标记', () async {
      final pubPem = await RSAService.publicKey();
      final recipients = [
        RecipientDevice(deviceId: deviceId, keyId: 'key_v1', publicKey: pubPem),
      ];
      final encrypted = await E2EEService.buildE2EEData(
        plaintext: jsonEncode({'msg_type': 'text', 'text': 'x'}),
        recipients: recipients,
      );

      final payload = <String, dynamic>{
        'msg_type': 'text',
        'e2ee': encrypted['e2ee'],
        'payload': 'invalid_ciphertext',
      };

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: payload,
      );

      expect(decrypted['_e2ee_failed'], true);
      expect(decrypted['_e2ee_reason'], 'invalid_ciphertext_format');
    });

    test('decryptIncomingPayload 找不到当前设备密钥时应失败', () async {
      final pubPem = await RSAService.publicKey();
      final recipients = [
        RecipientDevice(
          deviceId: 'other_device',
          keyId: 'key_v1',
          publicKey: pubPem,
        ),
      ];
      final encrypted = await E2EEService.buildE2EEData(
        plaintext: jsonEncode({'msg_type': 'text', 'text': 'x'}),
        recipients: recipients,
      );

      final payload = <String, dynamic>{
        'msg_type': 'text',
        'e2ee': encrypted['e2ee'],
        'payload': encrypted['ciphertext'],
      };

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: payload,
      );

      expect(decrypted['_e2ee_failed'], true);
      expect(decrypted['_e2ee_reason'], 'no_device_key');
    });
  });

  group('v2.0 API Tests', () {
    test('buildE2EEData returns separated metadata and ciphertext', () async {
      final pubPem = await RSAService.publicKey();

      final recipients = [
        RecipientDevice(deviceId: deviceId, keyId: 'key_v1', publicKey: pubPem),
      ];

      final plaintextPayload = <String, dynamic>{
        'msg_type': 'text',
        'text': 'hello v2.0',
      };

      final result = await E2EEService.buildE2EEData(
        plaintext: jsonEncode(plaintextPayload),
        recipients: recipients,
      );

      // 验证返回结构
      expect(result.containsKey('e2ee'), true);
      expect(result.containsKey('ciphertext'), true);

      // 验证 e2ee 元数据
      final e2ee = result['e2ee'] as Map<String, dynamic>;
      expect(e2ee['e2ee'], true);
      expect(e2ee['e2ee_ver'], 1);
      expect(e2ee['e2ee_suite'], 'RSA-OAEP-256+AES-256-GCM');
      expect(e2ee.containsKey('nonce'), true);
      expect(e2ee.containsKey('keys'), true);

      // 验证密文格式：base64(iv).base64(ciphertext)
      final ciphertext = result['ciphertext'] as String;
      final parts = ciphertext.split('.');
      expect(parts.length, 2);
      expect(parts[0].isNotEmpty, true); // IV
      expect(parts[1].isNotEmpty, true); // 密文

      // 验证 keys 数组
      final keys = e2ee['keys'] as List;
      expect(keys.isNotEmpty, true);
      final key = keys[0] as Map<String, dynamic>;
      expect(key['did'], deviceId);
      expect(key['kid'], 'key_v1');
      expect(key['wrap_alg'], 'RSA-OAEP-256');
      expect(key.containsKey('ek'), true);
    });

    test('decryptE2EEMessage correctly decrypts v2.0 format', () async {
      final pubPem = await RSAService.publicKey();

      final recipients = [
        RecipientDevice(deviceId: deviceId, keyId: 'key_v1', publicKey: pubPem),
      ];

      final originalPayload = <String, dynamic>{
        'msg_type': 'text',
        'text': 'hello v2.0',
        'number': 42,
      };

      // 构建加密数据
      final result = await E2EEService.buildE2EEData(
        plaintext: jsonEncode(originalPayload),
        recipients: recipients,
      );

      // 解密
      final decryptedJson = await E2EEService.decryptE2EEMessage(
        ciphertext: result['ciphertext'] as String,
        e2ee: result['e2ee'] as Map<String, dynamic>,
      );

      final decrypted = jsonDecode(decryptedJson) as Map<String, dynamic>;

      // 验证解密结果
      expect(decrypted['msg_type'], 'text');
      expect(decrypted['text'], 'hello v2.0');
      expect(decrypted['number'], 42);
    });

    test('decryptE2EEMessage throws on invalid ciphertext format', () async {
      final e2ee = <String, dynamic>{
        'e2ee': true,
        'e2ee_ver': 1,
        'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
        'nonce': 'invalid',
        'keys': <dynamic>[],
      };

      expect(
        () => E2EEService.decryptE2EEMessage(
          ciphertext: 'invalid_format_no_dot',
          e2ee: e2ee,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid ciphertext format'),
          ),
        ),
      );
    });

    test('decryptE2EEMessage throws when no key found for device', () async {
      final e2ee = <String, dynamic>{
        'e2ee': true,
        'e2ee_ver': 1,
        'e2ee_suite': 'RSA-OAEP-256+AES-256-GCM',
        'nonce': 'YWJjMTIz', // valid base64: "abc123"
        'keys': [
          {
            'did': 'other_device',
            'kid': 'key_v1',
            'wrap_alg': 'RSA-OAEP-256',
            'ek':
                'invalid_key', // This will cause a decode error after finding no matching device
          },
        ],
      };

      expect(
        () => E2EEService.decryptE2EEMessage(
          ciphertext: 'YWJjMTIz.ZGVmNDU2', // valid base64 format
          e2ee: e2ee,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No key found for device'),
          ),
        ),
      );
    });
  });

  group('RecipientDevice Tests', () {
    test('RecipientDevice constructor works correctly', () {
      final device = RecipientDevice(
        deviceId: 'device123',
        keyId: 'key_v1',
        publicKey: 'pem_content',
      );

      expect(device.deviceId, 'device123');
      expect(device.keyId, 'key_v1');
      expect(device.publicKey, 'pem_content');
    });
  });
}
