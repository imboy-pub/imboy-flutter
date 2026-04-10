import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/db_encryption_key_service.dart';

/// DbEncryptionKeyService 单元测试
///
/// 测试数据库加密密钥的生成、持久化、查询和删除。
/// 通过 Mock flutter_secure_storage MethodChannel 实现隔离测试。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  final store = <String, String?>{};

  setUpAll(() {
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
            case 'containsKey':
              final key = call.arguments['key'] as String;
              return store.containsKey(key);
            default:
              return null;
          }
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  setUp(() {
    store.clear();
  });

  group('DbEncryptionKeyService', () {
    group('getOrCreateKey', () {
      test('generates and persists a new key on first call', () async {
        final key = await DbEncryptionKeyService.getOrCreateKey('user_001');

        // 256-bit key = 32 bytes = 64 hex chars
        expect(key.length, 64);
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);

        // Verify persisted in store
        expect(store['db_cipher_key_user_001'], key);
      });

      test('returns same key on subsequent calls', () async {
        final key1 = await DbEncryptionKeyService.getOrCreateKey('user_002');
        final key2 = await DbEncryptionKeyService.getOrCreateKey('user_002');

        expect(key1, key2);
      });

      test('generates different keys for different uids', () async {
        final keyA = await DbEncryptionKeyService.getOrCreateKey('uid_a');
        final keyB = await DbEncryptionKeyService.getOrCreateKey('uid_b');

        expect(keyA, isNot(equals(keyB)));
      });

      test('returns existing key when storage has value', () async {
        // Pre-populate storage
        store['db_cipher_key_user_pre'] = 'aabbccdd' * 8; // 64 hex chars
        final key = await DbEncryptionKeyService.getOrCreateKey('user_pre');

        expect(key, 'aabbccdd' * 8);
      });

      test('generates new key when stored value is empty string', () async {
        store['db_cipher_key_user_empty'] = '';
        final key = await DbEncryptionKeyService.getOrCreateKey('user_empty');

        expect(key.length, 64);
        expect(key, isNot(isEmpty));
      });
    });

    group('hasKey', () {
      test('returns false when no key exists', () async {
        final result = await DbEncryptionKeyService.hasKey('no_such_user');

        expect(result, isFalse);
      });

      test('returns true after key creation', () async {
        await DbEncryptionKeyService.getOrCreateKey('user_has');
        final result = await DbEncryptionKeyService.hasKey('user_has');

        expect(result, isTrue);
      });

      test('returns false when stored value is empty string', () async {
        store['db_cipher_key_user_blank'] = '';
        final result = await DbEncryptionKeyService.hasKey('user_blank');

        expect(result, isFalse);
      });
    });

    group('deleteKey', () {
      test('removes key from storage', () async {
        await DbEncryptionKeyService.getOrCreateKey('user_del');
        expect(await DbEncryptionKeyService.hasKey('user_del'), isTrue);

        await DbEncryptionKeyService.deleteKey('user_del');
        expect(await DbEncryptionKeyService.hasKey('user_del'), isFalse);
      });

      test('does not throw when deleting non-existent key', () async {
        // Should complete without error
        await DbEncryptionKeyService.deleteKey('nonexistent');
      });

      test('does not affect other users keys', () async {
        await DbEncryptionKeyService.getOrCreateKey('user_keep');
        await DbEncryptionKeyService.getOrCreateKey('user_remove');

        await DbEncryptionKeyService.deleteKey('user_remove');

        expect(await DbEncryptionKeyService.hasKey('user_keep'), isTrue);
        expect(await DbEncryptionKeyService.hasKey('user_remove'), isFalse);
      });
    });

    group('key format', () {
      test('key is valid hex string of 64 characters', () async {
        // Generate multiple keys and verify format
        for (var i = 0; i < 5; i++) {
          final key = await DbEncryptionKeyService.getOrCreateKey('fmt_$i');
          expect(key.length, 64, reason: 'Key $i should be 64 hex chars');
          expect(
            RegExp(r'^[0-9a-f]{64}$').hasMatch(key),
            isTrue,
            reason: 'Key $i should be lowercase hex',
          );
        }
      });

      test('generated keys are unique across calls with different uids',
          () async {
        final keys = <String>{};
        for (var i = 0; i < 10; i++) {
          final key = await DbEncryptionKeyService.getOrCreateKey('uniq_$i');
          keys.add(key);
        }
        // All 10 keys should be unique
        expect(keys.length, 10);
      });
    });

    group('storage key naming', () {
      test('uses db_cipher_key_ prefix with uid', () async {
        await DbEncryptionKeyService.getOrCreateKey('12345');

        expect(store.containsKey('db_cipher_key_12345'), isTrue);
        // Should NOT use other key formats
        expect(store.containsKey('12345'), isFalse);
        expect(store.containsKey('cipher_key_12345'), isFalse);
      });
    });
  });
}
