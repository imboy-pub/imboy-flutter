import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/service/storage_secure.dart';

/// 生成本设备的真实 E2EE 密钥对，走生产同款入口 E2EEKeyService.generateKeyPair
/// （而非 RSAService.publicKey()）。
///
/// 此前本文件全部测试都用 RSAService.publicKey() 构造 RecipientDevice，但
/// RSAService 自身的 _initialize() 把私钥存在 "private_key"/"public_key"
/// 这两个原始 key 下；而 decryptE2EEMessage 走
/// StorageSecureService.getPrivateKeyByKid(kid) 查询的是 "e2ee_private_key"
/// （且要求 setKeyId 注册过对应 kid）——两条存储路径完全不通。生产环境实际
/// 的设备密钥初始化入口是 E2EEKeyService.generateKeyPair()
/// （passport_notifier.dart 登录/注册流程调用），它才会正确调用
/// savePrivateKey/setKeyId/savePublicKey/setDeviceId 落到 StorageSecureService
/// 的 "e2ee_" 前缀存储。此前测试传入写死的 keyId: 'key_v1'，与真实生成的
/// key_id 不匹配，解密必然查不到私钥（之前的失败：'私钥不存在 (kid: key_v1)'
/// / 解密静默失败落回 '[加密消息]' 占位符）。改用生产同款入口后，用真实
/// 返回的 device_id/key_id 构造 RecipientDevice，才是名副其实的端到端往返测试。
Future<Map<String, dynamic>> _setupDeviceKey() async {
  final keyInfo = await E2EEKeyService.generateKeyPair();
  // generateKeyPair 的返回值不含 public_key（只回传 device_id/key_id 等
  // 元信息），公钥需要另外从它刚写入的 StorageSecureService 读回。
  final publicKey = await StorageSecureService.to.getPublicKey();
  return {...keyInfo, 'public_key': publicKey};
}

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
      final keyInfo = await _setupDeviceKey();
      final recipients = [
        RecipientDevice(
          deviceId: keyInfo['device_id'] as String,
          keyId: keyInfo['key_id'] as String,
          publicKey: keyInfo['public_key'] as String,
        ),
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
      expect(decrypted['_e2ee'], isA<Map<String, dynamic>>());
    });

    test('decryptIncomingPayload 对非法密文格式返回失败标记', () async {
      final keyInfo = await _setupDeviceKey();
      final recipients = [
        RecipientDevice(
          deviceId: keyInfo['device_id'] as String,
          keyId: keyInfo['key_id'] as String,
          publicKey: keyInfo['public_key'] as String,
        ),
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

    test('AES-GCM 认证标签被篡改时应优雅失败而非崩溃', () async {
      // 与"非法密文格式"不同：这里保持 base64(nonce).base64(ciphertext)
      // 两段式格式合法，只翻转 GCM 密文本体（含认证标签）中的 1 个字节，
      // 验证 decryptIncomingPayload 走到 AES-GCM 解密这一步时能优雅兜底，
      // 而不是抛出未捕获异常。此前只测过"格式非法"和"找不到设备密钥"两条
      // 防线，密文/认证标签被篡改这条路径此前完全没有测试覆盖。
      final keyInfo = await _setupDeviceKey();
      final recipients = [
        RecipientDevice(
          deviceId: keyInfo['device_id'] as String,
          keyId: keyInfo['key_id'] as String,
          publicKey: keyInfo['public_key'] as String,
        ),
      ];
      final encrypted = await E2EEService.buildE2EEData(
        plaintext: jsonEncode({'msg_type': 'text', 'text': 'x'}),
        recipients: recipients,
      );

      final ciphertext = encrypted['ciphertext'] as String;
      final parts = ciphertext.split('.');
      expect(parts, hasLength(2));
      final nonceB64 = parts[0];
      final ctBytes = base64Decode(parts[1]);
      final tamperedBytes = List<int>.from(ctBytes);
      tamperedBytes[tamperedBytes.length - 1] ^= 0xFF; // 翻转最后一字节（落在 GCM tag 内）
      final tamperedCiphertext = '$nonceB64.${base64Encode(tamperedBytes)}';

      final payload = <String, dynamic>{
        'msg_type': 'text',
        'e2ee': encrypted['e2ee'],
        'payload': tamperedCiphertext,
      };

      final decrypted = await E2EEService.decryptIncomingPayload(
        payload: payload,
      );

      expect(decrypted['_e2ee_failed'], true);
      expect(decrypted['_e2ee_reason'], isNotNull);
    });

    test('decryptIncomingPayload 找不到当前设备密钥时应失败', () async {
      // 这里刻意加密给一个"other_device"，与当前测试设备（deviceId 全局变量）
      // 不一致，只需要一把合法的公钥用于加密，不需要私钥可解析
      // （查私钥前就应在"找同 did 的 key"这一步失败），故仍可直接用
      // RSAService.publicKey() 产出的公钥。
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
      final keyInfo = await _setupDeviceKey();

      final recipients = [
        RecipientDevice(
          deviceId: keyInfo['device_id'] as String,
          keyId: keyInfo['key_id'] as String,
          publicKey: keyInfo['public_key'] as String,
        ),
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
      expect(key['did'], keyInfo['device_id']);
      expect(key['kid'], keyInfo['key_id']);
      expect(key['wrap_alg'], 'RSA-OAEP-256');
      expect(key.containsKey('ek'), true);
    });

    test('decryptE2EEMessage correctly decrypts v2.0 format', () async {
      final keyInfo = await _setupDeviceKey();

      final recipients = [
        RecipientDevice(
          deviceId: keyInfo['device_id'] as String,
          keyId: keyInfo['key_id'] as String,
          publicKey: keyInfo['public_key'] as String,
        ),
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
