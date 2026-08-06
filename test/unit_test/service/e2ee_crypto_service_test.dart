import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee_crypto_service.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';

void main() {
  // 初始化 Flutter 测试绑定（用于 path_provider 等插件）
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (methodCall) async {
          switch (methodCall.method) {
            case 'getTemporaryDirectory':
            case 'getApplicationDocumentsDirectory':
            case 'getApplicationSupportDirectory':
            case 'getLibraryDirectory':
            case 'getDownloadsDirectory':
              return Directory.systemTemp.path;
            default:
              return Directory.systemTemp.path;
          }
        });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  // 辅助函数：比较两个列表是否相等
  bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  test('E2EE Crypto Service - Derive Key', () async {
    final password = 'TestPassword123!';
    final salt = E2EECryptoService.generateSalt();

    expect(salt.length, equals(16));

    final derivedKey = await E2EECryptoService.deriveKey(password, salt);

    expect(derivedKey.length, equals(32));
  });

  test('E2EE Crypto Service - Encrypt/Decrypt', () async {
    final plaintext = utf8.encode('Hello, E2EE World!');
    final password = 'TestPassword123!';
    final salt = E2EECryptoService.generateSalt();
    final iv = E2EECryptoService.generateIV();

    // 派生密钥
    final key = await E2EECryptoService.deriveKey(password, salt);

    // 加密
    final encrypted = await E2EECryptoService.encryptAesGcm(
      Uint8List.fromList(plaintext),
      key,
      iv,
    );

    expect(encrypted['ciphertext'], isNotEmpty);
    expect(encrypted['authTag'], isNotEmpty);
    expect(encrypted['authTag']!.length, equals(16));

    // 解密
    final decrypted = await E2EECryptoService.decryptAesGcm(
      encrypted['ciphertext']!,
      encrypted['authTag']!,
      key,
      iv,
    );

    expect(decrypted, equals(plaintext));
  });

  test('E2EE Crypto Service - Checksum', () {
    final data = utf8.encode('Test data for checksum');

    final checksum1 = E2EECryptoService.calculateChecksum(
      Uint8List.fromList(data),
    );
    final checksum2 = E2EECryptoService.calculateChecksum(
      Uint8List.fromList(data),
    );

    expect(checksum1, equals(checksum2));
    expect(checksum1.length, equals(64)); // SHA-256 = 64 hex chars
  });

  test('E2EE Crypto Service - Random Generation', () {
    final salt1 = E2EECryptoService.generateSalt();
    final salt2 = E2EECryptoService.generateSalt();
    final iv1 = E2EECryptoService.generateIV();
    final iv2 = E2EECryptoService.generateIV();

    expect(salt1.length, equals(16));
    expect(salt2.length, equals(16));
    expect(listEquals(salt1, salt2), isFalse); // Salt 应该随机

    expect(iv1.length, equals(12));
    expect(iv2.length, equals(12));
    expect(listEquals(iv1, iv2), isFalse); // IV 应该随机
  });

  test('E2EE Local Backup Service - Password Validation', () async {
    // 太短 - 应该抛出异常
    expect(
      () => E2EELocalBackupService.exportBackup(
        password: 'Short1!',
        privateKey: 'test-key',
        publicKey: 'test-pub',
        deviceId: 'test-device',
        keyId: 'test-key-id',
      ),
      throwsArgumentError,
    );

    // 当前实现只校验最小长度，长度足够时允许导出备份
    final filePath = await E2EELocalBackupService.exportBackup(
      password: 'weakpassword',
      privateKey: 'test-key',
      publicKey: 'test-pub',
      deviceId: 'test-device',
      keyId: 'test-key-id',
    );
    expect(filePath, contains('imboy_e2ee_backup_'));
    await File(filePath).delete().catchError((_) => File(filePath));
  });

  test('E2EE Local Backup Service - Password Strength', () {
    final weak1 = E2EELocalBackupService.calculatePasswordStrength('weak');
    expect(weak1, lessThan(0.3));

    final medium = E2EELocalBackupService.calculatePasswordStrength(
      'Med1um!23',
    );
    expect(medium, greaterThan(0.3));
    expect(medium, lessThan(0.7));

    final strong = E2EELocalBackupService.calculatePasswordStrength(
      'Str0ng!Pass123',
    );
    expect(strong, greaterThan(0.7));
  });

  // 注意：完整流程测试需要平台通道支持，需要在集成测试环境中运行
  // 以下测试被跳过，因为 unit test 不支持 path_provider 等插件
}
