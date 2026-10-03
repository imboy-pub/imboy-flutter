import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/db_encryption_key_service.dart';

/// C05：SQLCipher DB key 生命周期 fail-closed 合成测试。
///
/// 契约（Keychain/Keystore 不可用时**不得静默降级明文库**）：
/// 1. secure storage read 抛异常 → getOrCreateKey 必须向上抛；
/// 2. key 不存在且 write 抛异常 → 必须抛（绝不返回未持久化的新 key，
///    否则下次启动换 key，旧库永久打不开）；
/// 3. 正常路径返回的 key 恒为 64 位 hex（256-bit）；
/// 4. sqlite.dart 对 getOrCreateKey 的调用无 catch 降级（源码断言）；
/// 5. openEncryptedDatabase 在加密平台不会静默丢密码（源码断言）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final hex64 = RegExp(r'^[0-9a-f]{64}$');

  void mockChannel({Object? Function(MethodCall)? onCall}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (onCall != null) return onCall(call);
          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('read 抛异常（Keychain 不可用）：getOrCreateKey fail-closed 向上抛', () async {
    mockChannel(
      onCall: (call) => throw PlatformException(
        code: 'errSecMissingEntitlement',
        details: -34018,
      ),
    );
    await expectLater(
      DbEncryptionKeyService.getOrCreateKey('u1'),
      throwsA(isA<PlatformException>()),
    );
  });

  test('key 缺失且 write 失败：不得返回未持久化的新 key', () async {
    mockChannel(
      onCall: (call) {
        switch (call.method) {
          case 'read':
            return null; // key 不存在
          case 'write':
            throw PlatformException(code: 'keychain_unavailable');
        }
        return null;
      },
    );
    await expectLater(
      DbEncryptionKeyService.getOrCreateKey('u1'),
      throwsA(isA<PlatformException>()),
    );
  });

  test('正常路径：生成 256-bit hex key 并可读回', () async {
    final store = <String, String>{};
    mockChannel(
      onCall: (call) {
        switch (call.method) {
          case 'read':
            return store[call.arguments['key'] as String];
          case 'write':
            store[call.arguments['key'] as String] =
                call.arguments['value'] as String;
            return null;
          case 'delete':
            store.remove(call.arguments['key'] as String);
            return null;
          case 'containsKey':
            return store.containsKey(call.arguments['key']);
        }
        return null;
      },
    );

    final key = await DbEncryptionKeyService.getOrCreateKey('u1');
    expect(hex64.hasMatch(key), isTrue, reason: 'key 应为 64 hex 字符: $key');
    // 幂等：第二次取到同一把
    expect(await DbEncryptionKeyService.getOrCreateKey('u1'), key);
    expect(await DbEncryptionKeyService.hasKey('u1'), isTrue);
    expect(await DbEncryptionKeyService.hasKey('u2'), isFalse);

    await DbEncryptionKeyService.deleteKey('u1');
    expect(await DbEncryptionKeyService.hasKey('u1'), isFalse);
  });

  test('key 为空串时视为缺失并重新生成（不留空密码口子）', () async {
    final store = <String, String>{'db_cipher_key_u1': ''};
    mockChannel(
      onCall: (call) {
        switch (call.method) {
          case 'read':
            return store[call.arguments['key'] as String];
          case 'write':
            store[call.arguments['key'] as String] =
                call.arguments['value'] as String;
            return null;
        }
        return null;
      },
    );
    final key = await DbEncryptionKeyService.getOrCreateKey('u1');
    expect(hex64.hasMatch(key), isTrue);
    expect(store['db_cipher_key_u1'], key);
  });

  test('hasKey 在存储异常时向上抛（不静默报 false）', () async {
    mockChannel(onCall: (call) => throw PlatformException(code: 'unavailable'));
    await expectLater(
      DbEncryptionKeyService.hasKey('u1'),
      throwsA(isA<PlatformException>()),
    );
  });

  // ─── 源码级 fail-closed 断言 ──────────────────────────────────────────────

  test('sqlite.dart：getOrCreateKey 调用无 catch 降级为空密码', () {
    final source = File('lib/service/sqlite.dart').readAsStringSync();
    // 取密钥行必须原样存在（无 try 包裹/无 ?? '' 兜底）
    expect(
      source.contains(
        'password = await DbEncryptionKeyService.getOrCreateKey(uid);',
      ),
      isTrue,
      reason: 'getOrCreateKey 调用形态被改动，需复核 fail-closed 语义',
    );
    // 打开句柄必须直接使用该 password（而非重算/置空）
    expect(source.contains('password: password,'), isTrue);
    // 不允许出现「密钥异常 → 置空重试」的降级形态
    expect(source, isNot(contains('password = null')));
    expect(source, isNot(contains('password ?? \'\'')));
  });

  test('openEncryptedDatabase：加密平台不静默丢弃密码', () {
    final source = File('lib/service/sqflite_init_stub.dart')
        .readAsStringSync();
    expect(
      source.contains(
        'final effectivePassword = isEncryptionSupported ? password : null;',
      ),
      isTrue,
      reason: '密码透传逻辑被改动：加密平台上 password 必须原样生效',
    );
    // 桌面（Windows/Linux）当前为明文库——已知现状，记录于 C05 矩阵，
    // 此处仅锁定「显式声明」不被无声删除。
    expect(source, contains('isEncryptionSupported'));
  });
}
