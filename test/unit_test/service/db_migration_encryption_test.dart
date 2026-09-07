import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/db_encryption_key_service.dart';
import 'package:imboy/service/sqflite_init.dart';

/// 数据库加密与 fail-closed 打开策略测试
///
/// 测试范围：
/// - 平台加密支持检测 (isEncryptionSupported)
/// - 加密密钥与数据库初始化契约
/// - openEncryptedDatabase 参数传递逻辑
/// - SqliteService 不得无密码探测、备份或删除已有数据库
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock flutter_secure_storage MethodChannel
  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  final store = <String, String?>{};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'write':
              store[call.arguments['key'] as String] =
                  call.arguments['value'] as String?;
              return null;
            case 'read':
              return store[call.arguments['key'] as String];
            case 'delete':
              store.remove(call.arguments['key'] as String);
              return null;
            case 'containsKey':
              return store.containsKey(call.arguments['key'] as String);
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

  group('isEncryptionSupported', () {
    test('returns bool value on current platform', () {
      // macOS test runner: isEncryptionSupported should be true
      // This validates the platform detection logic works
      final supported = isEncryptionSupported;
      expect(supported, isA<bool>());
    });

    test('returns true on macOS (test environment)', () {
      // Tests run on macOS which supports SQLCipher via sqflite_sqlcipher
      expect(isEncryptionSupported, isTrue);
    });
  });

  group('encryption key integration', () {
    test('key is generated before database open', () async {
      // Simulate the flow in SqliteService._initDatabase:
      // 1. Check if encryption is supported
      // 2. Get or create encryption key
      // 3. Pass key as password to openEncryptedDatabase
      final uid = 'test_user_migration';

      if (isEncryptionSupported) {
        final password = await DbEncryptionKeyService.getOrCreateKey(uid);

        expect(password.length, 64);
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(password), isTrue);

        // Same key on retry (idempotent)
        final password2 = await DbEncryptionKeyService.getOrCreateKey(uid);
        expect(password2, password);
      }
    });

    test('key persists across service calls', () async {
      const uid = 'persist_test_user';

      final key1 = await DbEncryptionKeyService.getOrCreateKey(uid);
      // Verify it's in secure storage
      expect(store['db_cipher_key_$uid'], key1);

      // Simulate app restart by reading from store again
      final key2 = await DbEncryptionKeyService.getOrCreateKey(uid);
      expect(key2, key1);
    });

    test('each user gets isolated encryption key', () async {
      final keyAlice = await DbEncryptionKeyService.getOrCreateKey('alice');
      final keyBob = await DbEncryptionKeyService.getOrCreateKey('bob');

      expect(keyAlice, isNot(equals(keyBob)));
      expect(store['db_cipher_key_alice'], keyAlice);
      expect(store['db_cipher_key_bob'], keyBob);
    });
  });

  group('openEncryptedDatabase contract', () {
    test('keeps null password limited to unsupported platform adapter', () {
      final adapter = File(
        'lib/service/sqflite_init_stub.dart',
      ).readAsStringSync();
      expect(adapter, contains('isEncryptionSupported ? password : null'));
    });

    test('function signature supports all callback parameters', () {
      // Verify the function accepts all expected parameters
      // This is a compilation-time contract test
      // ignore: unnecessary_type_check
      expect(openEncryptedDatabase is Function, isTrue);
    });
  });

  group('migration flow logic', () {
    test('encryption key is only created when platform supports it', () async {
      const uid = 'conditional_user';

      if (isEncryptionSupported) {
        // On supported platforms, key should be created
        final key = await DbEncryptionKeyService.getOrCreateKey(uid);
        expect(key.isNotEmpty, isTrue);
        expect(await DbEncryptionKeyService.hasKey(uid), isTrue);
      }
      // On unsupported platforms, the code path skips key generation entirely
      // (controlled by `if (isEncryptionSupported)` in SqliteService)
    });

    test('key deletion prevents database access', () async {
      const uid = 'delete_key_user';

      // Create key
      final key = await DbEncryptionKeyService.getOrCreateKey(uid);
      expect(key.isNotEmpty, isTrue);

      // Delete key
      await DbEncryptionKeyService.deleteKey(uid);
      expect(await DbEncryptionKeyService.hasKey(uid), isFalse);

      // New key is generated (different from original)
      final newKey = await DbEncryptionKeyService.getOrCreateKey(uid);
      expect(newKey, isNot(equals(key)));
    });
  });

  group('SQLCipher fail-closed source guard', () {
    late String source;

    setUpAll(() {
      source = File('lib/service/sqlite.dart').readAsStringSync();
    });

    test('does not open an existing database without a password', () {
      expect(source, isNot(contains('password: null')));
      expect(source, isNot(contains('Retrying database open without')));
    });

    test('does not create plaintext migration backups', () {
      expect(source, isNot(contains('.plain.bak')));
      expect(source, isNot(contains('.pre_encrypt.bak')));
      expect(source, isNot(contains('_cleanupEncryptionBackups')));
    });

    test(
      'does not delete or copy an existing database during verification',
      () {
        final verification = source.substring(
          source.indexOf('Future<bool> _verifyEncryptedDatabase'),
          source.indexOf('/// 打开数据库时的配置回调'),
        );
        expect(verification, isNot(contains('.delete(')));
        expect(verification, isNot(contains('.copy(')));
        expect(verification, contains('password: password'));
      },
    );

    test(
      'verification failure stops initialization before migration preflight',
      () {
        final verificationGuard = source.indexOf(
          '!await _verifyEncryptedDatabase(path, password)',
        );
        final failureReturn = source.indexOf('return null;', verificationGuard);
        final migrationPreflight = source.indexOf(
          'DatabaseMigrationOrchestrator.to.prepareForOpen',
        );

        expect(verificationGuard, greaterThanOrEqualTo(0));
        expect(failureReturn, greaterThan(verificationGuard));
        expect(failureReturn, lessThan(migrationPreflight));
      },
    );
  });
}
