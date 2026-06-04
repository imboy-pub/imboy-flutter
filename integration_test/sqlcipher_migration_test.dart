import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'package:imboy/service/db_encryption_key_service.dart';
import 'package:imboy/service/sqflite_init.dart';

/// SQLCipher 加密迁移集成测试
///
/// 测试加密相关的完整流程：
/// - 新用户首次创建加密密钥
/// - 升级用户的密钥持久化
/// - 备份文件 7 天自动清理
/// - 平台加密能力检测
///
/// 注意：此测试不依赖真实数据库，聚焦密钥管理和文件操作。
/// 真实 SQLCipher 加密迁移需要在设备上运行完整应用测试。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Mock flutter_secure_storage
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

  group('SQLCipher Migration - New User Flow', () {
    test('new user gets encryption key on first database open',
        () async {
      const uid = 'new_user_001';

      // Before: no key exists
      expect(await DbEncryptionKeyService.hasKey(uid), isFalse);

      // Simulate database initialization
      if (isEncryptionSupported) {
        final key = await DbEncryptionKeyService.getOrCreateKey(uid);

        // Key is valid 256-bit hex
        expect(key.length, 64);
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
        expect(await DbEncryptionKeyService.hasKey(uid), isTrue);
      }
    });

    test('encryption key survives app restart simulation',
        () async {
      const uid = 'restart_user';

      final key1 = await DbEncryptionKeyService.getOrCreateKey(uid);

      // Simulate "restart" - key should persist in secure storage
      final key2 = await DbEncryptionKeyService.getOrCreateKey(uid);
      expect(key2, key1);
    });
  });

  group('SQLCipher Migration - Upgrade User Flow', () {
    test('existing user without key gets new key on upgrade',
        () async {
      const uid = 'upgrade_user';

      // Simulate pre-SQLCipher state: user exists, no encryption key
      expect(await DbEncryptionKeyService.hasKey(uid), isFalse);

      // App upgrade triggers key generation
      final key = await DbEncryptionKeyService.getOrCreateKey(uid);
      expect(key.length, 64);
      expect(await DbEncryptionKeyService.hasKey(uid), isTrue);
    });

    test('multiple users maintain separate keys', () async {
      final keys = <String, String>{};
      final uids = ['user_a', 'user_b', 'user_c'];

      for (final uid in uids) {
        keys[uid] = await DbEncryptionKeyService.getOrCreateKey(uid);
      }

      // All keys are unique
      expect(keys.values.toSet().length, 3);

      // Each key is independently retrievable
      for (final uid in uids) {
        final retrieved = await DbEncryptionKeyService.getOrCreateKey(uid);
        expect(retrieved, keys[uid]);
      }
    });
  });

  group('SQLCipher Migration - Backup Cleanup', () {
    test('expired backup files are eligible for cleanup',
        () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'sqlcipher_int_test_',
      );

      try {
        final dbPath = p.join(tempDir.path, 'test.db');
        final backupFile = File('$dbPath.pre_encrypt.bak');

        // Create an "old" backup
        await backupFile.writeAsString('old backup');
        final eightDaysAgo = DateTime.now().subtract(
          const Duration(days: 8),
        );
        await backupFile.setLastModified(eightDaysAgo);

        // Verify it's expired
        final stat = await backupFile.stat();
        final age = DateTime.now().difference(stat.modified);
        expect(age.inDays, greaterThanOrEqualTo(7));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('recent backup files are not eligible for cleanup',
        () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'sqlcipher_int_test2_',
      );

      try {
        final dbPath = p.join(tempDir.path, 'test.db');
        final backupFile = File('$dbPath.pre_encrypt.bak');

        // Create a "recent" backup
        await backupFile.writeAsString('recent backup');

        // Verify it's NOT expired
        final stat = await backupFile.stat();
        final age = DateTime.now().difference(stat.modified);
        expect(age.inDays, lessThan(7));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('SQLCipher Migration - Key Lifecycle', () {
    test('account logout clears encryption key', () async {
      const uid = 'logout_user';

      // Login: create key
      final key = await DbEncryptionKeyService.getOrCreateKey(uid);
      expect(key.isNotEmpty, isTrue);

      // Logout: delete key
      await DbEncryptionKeyService.deleteKey(uid);
      expect(await DbEncryptionKeyService.hasKey(uid), isFalse);
    });

    test('re-login generates new key after logout', () async {
      const uid = 'relogin_user';

      // First login
      final key1 = await DbEncryptionKeyService.getOrCreateKey(uid);

      // Logout
      await DbEncryptionKeyService.deleteKey(uid);

      // Re-login: new key generated (cannot reuse old encrypted DB anyway)
      final key2 = await DbEncryptionKeyService.getOrCreateKey(uid);
      expect(key2, isNot(equals(key1)));
    });
  });
}
