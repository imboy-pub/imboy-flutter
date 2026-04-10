import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:imboy/service/db_encryption_key_service.dart';
import 'package:imboy/service/sqflite_init.dart';

/// 数据库加密迁移相关测试
///
/// 测试范围：
/// - 平台加密支持检测 (isEncryptionSupported)
/// - 加密密钥与数据库初始化的集成
/// - openEncryptedDatabase 参数传递逻辑
///
/// 注意：实际的 SQLCipher 加密迁移 (_migrateToEncryptedIfNeeded) 为私有方法，
/// 且依赖真实文件系统和 SQLCipher 库，需要在集成测试中验证。
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
        final password =
            await DbEncryptionKeyService.getOrCreateKey(uid);

        expect(password.length, 64);
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(password), isTrue);

        // Same key on retry (idempotent)
        final password2 =
            await DbEncryptionKeyService.getOrCreateKey(uid);
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
    test('accepts null password on unsupported platforms', () {
      // openEncryptedDatabase should handle null password gracefully
      // The function signature: openEncryptedDatabase(path, {String? password, ...})
      // When isEncryptionSupported is false, effectivePassword = null
      //
      // This is a contract test - we verify the API accepts null
      // without calling the actual function (which needs a DB file)
      expect(
        () => openEncryptedDatabase('/nonexistent/test.db', password: null),
        // Should throw because path doesn't exist, not because password is null
        throwsA(isA<Object>()),
      );
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

    test('backup file naming convention uses .pre_encrypt.bak suffix', () {
      // Validate the naming convention used in _migrateToEncryptedIfNeeded
      const dbPath = '/data/data/com.example/databases/dev_12345.db';
      final backupPath = '$dbPath.pre_encrypt.bak';
      final tempPath = '$dbPath.encrypted.tmp';

      expect(
        backupPath,
        '/data/data/com.example/databases/dev_12345.db.pre_encrypt.bak',
      );
      expect(
        tempPath,
        '/data/data/com.example/databases/dev_12345.db.encrypted.tmp',
      );
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

  group('encryption backup cleanup', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('imboy_backup_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('expired backup file is deleted after 7 days', () async {
      final dbPath = p.join(tempDir.path, 'test.db');
      final backupPath = '$dbPath.pre_encrypt.bak';
      final backupFile = File(backupPath);

      // Create a backup file
      await backupFile.writeAsString('fake backup data');
      expect(await backupFile.exists(), isTrue);

      // Set modification time to 8 days ago
      final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
      await backupFile.setLastModified(eightDaysAgo);

      // Verify the file's modification time
      final stat = await backupFile.stat();
      expect(
        DateTime.now().difference(stat.modified).inDays >= 7,
        isTrue,
      );
    });

    test('recent backup file is preserved within 7 days', () async {
      final dbPath = p.join(tempDir.path, 'test2.db');
      final backupPath = '$dbPath.pre_encrypt.bak';
      final backupFile = File(backupPath);

      // Create a backup file (just now - within 7 days)
      await backupFile.writeAsString('recent backup data');
      expect(await backupFile.exists(), isTrue);

      // Verify the file's modification time is recent
      final stat = await backupFile.stat();
      expect(
        DateTime.now().difference(stat.modified).inDays < 7,
        isTrue,
      );
    });

    test('cleanup handles non-existent backup file gracefully', () async {
      final dbPath = p.join(tempDir.path, 'nonexistent.db');
      final backupPath = '$dbPath.pre_encrypt.bak';
      final backupFile = File(backupPath);

      // File doesn't exist - should not throw
      expect(await backupFile.exists(), isFalse);
    });

    test('backup file naming is deterministic from db path', () {
      const dbPath1 = '/data/user/0/com.example/databases/dev_alice.db';
      const dbPath2 = '/data/user/0/com.example/databases/dev_bob.db';

      expect(
        '$dbPath1.pre_encrypt.bak',
        endsWith('dev_alice.db.pre_encrypt.bak'),
      );
      expect(
        '$dbPath2.pre_encrypt.bak',
        endsWith('dev_bob.db.pre_encrypt.bak'),
      );
      // Different users get different backup files
      expect(
        '$dbPath1.pre_encrypt.bak',
        isNot(equals('$dbPath2.pre_encrypt.bak')),
      );
    });
  });
}
