import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import 'package:imboy/service/db_encryption_key_service.dart';
import 'package:imboy/service/sqflite_init.dart';

/// SQLCipher 加密与 fail-closed 打开集成测试
///
/// 测试加密相关的完整流程：
/// - 新用户首次创建加密密钥
/// - 已有加密库拒绝错误密钥且保留原文件
/// - 平台加密能力检测
///
/// 本文件必须在项目声明支持 SQLCipher 的真实设备上运行；本地单元测试和
/// 模拟器结果不构成发布验收证据。
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
    test('new user gets encryption key on first database open', () async {
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

    test('encryption key survives app restart simulation', () async {
      const uid = 'restart_user';

      final key1 = await DbEncryptionKeyService.getOrCreateKey(uid);

      // Simulate "restart" - key should persist in secure storage
      final key2 = await DbEncryptionKeyService.getOrCreateKey(uid);
      expect(key2, key1);
    });
  });

  group('SQLCipher Migration - Upgrade User Flow', () {
    test('existing user without key gets new key on upgrade', () async {
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

  group('SQLCipher Existing Database - Fail Closed', () {
    test(
      'wrong key is rejected without replacing or backing up the database',
      () async {
        expect(
          isEncryptionSupported,
          isTrue,
          reason: '该验收只能在项目声明支持 SQLCipher 的真实设备执行',
        );

        final root = await getTemporaryDirectory();
        final runDir = await Directory(
          p.join(
            root.path,
            'imboy_sqlcipher_${DateTime.now().microsecondsSinceEpoch}',
          ),
        ).create();
        final dbPath = p.join(runDir.path, 'existing.db');
        const correctKey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        const wrongKey =
            'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
        final canary = _randomCanary();
        Database? db;
        Database? wrongKeyDb;

        try {
          db = await openEncryptedDatabase(
            dbPath,
            password: correctKey,
            version: 1,
            onCreate: (createdDb, _) async {
              await createdDb.execute(
                'CREATE TABLE proof (value TEXT NOT NULL)',
              );
            },
          );
          await db.insert('proof', {'value': canary});
          await db.close();
          db = null;

          final originalBytes = await File(dbPath).readAsBytes();
          Object? wrongKeyError;
          try {
            wrongKeyDb = await openEncryptedDatabase(
              dbPath,
              password: wrongKey,
            );
            await wrongKeyDb.rawQuery('SELECT value FROM proof');
          } catch (e) {
            wrongKeyError = e;
          } finally {
            if (wrongKeyDb != null && wrongKeyDb.isOpen) {
              await wrongKeyDb.close();
            }
            wrongKeyDb = null;
          }

          expect(wrongKeyError, isNotNull);
          expect(
            await File(dbPath).readAsBytes(),
            orderedEquals(originalBytes),
          );
          expect(await File('$dbPath.plain.bak').exists(), isFalse);
          expect(await File('$dbPath.pre_encrypt.bak').exists(), isFalse);

          db = await openEncryptedDatabase(dbPath, password: correctKey);
          final rows = await db.rawQuery('SELECT value FROM proof');
          expect(rows.single['value'], canary);
        } finally {
          if (db != null && db.isOpen) await db.close();
          if (wrongKeyDb != null && wrongKeyDb.isOpen) {
            await wrongKeyDb.close();
          }
          if (await runDir.exists()) await runDir.delete(recursive: true);
        }
      },
    );
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

String _randomCanary() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
