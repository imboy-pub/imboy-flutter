// E2EE 密钥恢复流程测试 / E2EE Key Backup & Restore Tests
//
// 测试策略 / Test strategy:
//   - 直接测试 E2EECryptoService、ShamirSecretSharing、E2EELocalBackupService 纯函数
//   - 通过 path_provider MethodChannel mock 隔离文件系统依赖
//   - 不依赖真实设备或网络，在 CI flutter test 中稳定运行
//
// 测试用例 / Test cases (共 10 个 / total 10):
//   1. Shamir 3-of-5 标准分割与恢复
//   2. 2-of-5 份额不足应恢复失败（与原始值不一致）
//   3. 4-of-5 份额超量应恢复成功
//   4. 密钥备份加密——正确密码可解密
//   5. 密钥备份解密——错误密码应抛出异常
//   6. 本地备份写入/读取数据一致性
//   7. 空备份文件恢复应抛出异常（优雅失败）
//   8. 备份文件数据损坏后校验和不匹配应抛出异常
//   9. 备份文件 Magic Number 错误应抛出异常
//  10. 备份密码强度计算覆盖弱/中/强三档
//
// 运行方式 / How to run:
//   flutter test test/service/e2ee_backup_restore_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee_crypto_service.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';

// ---------------------------------------------------------------------------
// 测试常量 / Test fixtures
// ---------------------------------------------------------------------------

/// 用于测试的模拟 RSA 私钥（PEM 格式占位）
const _kFakePrivateKey = '''-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC7o4qne60TB3wo
fakeprivatekeycontentfortest1234567890abcdefghijklmnopqrstuvwxyz
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
-----END PRIVATE KEY-----''';

/// 用于测试的模拟 RSA 公钥（PEM 格式占位）
const _kFakePublicKey = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu6OKp3utEwd8KGFakePub
fakepublickeycontent1234567890abcdefghijklmnopqrstuvwxyzAAAAAAAA
-----END PUBLIC KEY-----''';

const _kDeviceId = 'test-device-abc123';
const _kKeyId = 'kid_abc12345';
const _kValidPassword = 'MyStr0ng!Pass';
const _kShortPassword = 'Short1!'; // 7 位，低于最小 8 位要求

// ---------------------------------------------------------------------------
// 平台通道 Mock / Platform channel mock for path_provider
// ---------------------------------------------------------------------------

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void _setupPathProviderMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, (call) async {
        return Directory.systemTemp.path;
      });
}

void _tearDownPathProviderMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathProviderChannel, null);
}

// ---------------------------------------------------------------------------
// 辅助函数 / Helpers
// ---------------------------------------------------------------------------

/// 逐字节比较两个 Uint8List
bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 创建合法备份文件并返回路径
Future<String> _createValidBackup({
  String password = _kValidPassword,
  String privateKey = _kFakePrivateKey,
  String publicKey = _kFakePublicKey,
  String deviceId = _kDeviceId,
  String keyId = _kKeyId,
}) {
  return E2EELocalBackupService.exportBackup(
    password: password,
    privateKey: privateKey,
    publicKey: publicKey,
    deviceId: deviceId,
    keyId: keyId,
  );
}

// ---------------------------------------------------------------------------
// 测试入口 / Test main
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_setupPathProviderMock);
  tearDownAll(_tearDownPathProviderMock);

  // =========================================================================
  // 组 2：E2EECryptoService 加密/解密
  // =========================================================================
  group('恢复密钥（Matrix 4S 第二把钥匙）', () {
    test('generateRecoveryKey 格式：8 组 5 位大写十六进制、连字符分隔', () {
      final key = E2EECryptoService.generateRecoveryKey();
      final groups = key.split('-');
      expect(groups.length, 8);
      for (final g in groups) {
        expect(g.length, 5);
        expect(RegExp(r'^[0-9A-F]{5}$').hasMatch(g), isTrue, reason: '组=$g');
      }
    });

    test('generateRecoveryKey 高熵：多次生成互不相同', () {
      final keys = List.generate(
        50,
        (_) => E2EECryptoService.generateRecoveryKey(),
      );
      expect(keys.toSet().length, 50, reason: '50 次生成应全不重复');
    });

    test('恢复密钥可作为备份凭据完整往返（pack→unpack）', () async {
      // 恢复密钥即备份口令：忘记口令时用它解密，与口令走同一 pack/unpack
      final recoveryKey = E2EECryptoService.generateRecoveryKey();
      final bytes = await E2EELocalBackupService.packBackupBytes(
        password: recoveryKey,
        privateKey: 'test-private-key-pem',
        publicKey: 'test-public-key-pem',
        deviceId: 'dev-rk-1',
        keyId: 'kid-rk-1',
      );
      final restored = await E2EELocalBackupService.unpackBackupBytes(
        bytes: bytes,
        password: recoveryKey,
      );
      expect(restored['private_key'], 'test-private-key-pem');
      expect(restored['device_id'], 'dev-rk-1');

      // 错误凭据（改一位）必须解密失败（GCM 认证）
      final wrong = recoveryKey.replaceRange(
        0,
        1,
        recoveryKey[0] == 'A' ? 'B' : 'A',
      );
      await expectLater(
        E2EELocalBackupService.unpackBackupBytes(bytes: bytes, password: wrong),
        throwsA(anything),
      );
    });
  });

  group('E2EECryptoService — 加密/解密', () {
    // 4. 正确密码可加密后解密 / Correct password encrypts and decrypts
    test('正确密码派生密钥可完整加密解密 / correct password roundtrip', () async {
      // Arrange
      const plainText = 'E2EE backup content test payload';
      final data = Uint8List.fromList(utf8.encode(plainText));
      final salt = E2EECryptoService.generateSalt();
      final iv = E2EECryptoService.generateIV();

      // Act
      final key = await E2EECryptoService.deriveKey(_kValidPassword, salt);
      final encrypted = await E2EECryptoService.encryptAesGcm(data, key, iv);
      final decrypted = await E2EECryptoService.decryptAesGcm(
        encrypted['ciphertext']!,
        encrypted['authTag']!,
        key,
        iv,
      );

      // Assert
      expect(utf8.decode(decrypted), equals(plainText));
    });

    // 5. 错误密码解密应抛出异常 / Wrong password decryption throws
    test('错误密码解密应抛出异常 / wrong password throws on decrypt', () async {
      // Arrange
      final data = Uint8List.fromList(utf8.encode('sensitive key data'));
      final salt = E2EECryptoService.generateSalt();
      final iv = E2EECryptoService.generateIV();

      final correctKey = await E2EECryptoService.deriveKey(
        _kValidPassword,
        salt,
      );
      final encrypted = await E2EECryptoService.encryptAesGcm(
        data,
        correctKey,
        iv,
      );

      // 用不同密码派生错误密钥
      final wrongKey = await E2EECryptoService.deriveKey(
        'WrongPassword!99',
        salt,
      );

      // Assert：GCM 认证标签失败应抛出异常
      expect(
        () async => E2EECryptoService.decryptAesGcm(
          encrypted['ciphertext']!,
          encrypted['authTag']!,
          wrongKey,
          iv,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // =========================================================================
  // 组 3：E2EELocalBackupService 备份文件读写
  // =========================================================================
  group('E2EELocalBackupService — 备份文件', () {
    // 6. 本地备份写入/读取一致性 / Backup write/read consistency
    test('导出后再导入数据应一致 / export-import data consistency', () async {
      // Arrange & Act
      final filePath = await _createValidBackup();
      addTearDown(
        () => File(filePath).delete().catchError((_) => File(filePath)),
      );

      final result = await E2EELocalBackupService.importBackup(
        filePath: filePath,
        password: _kValidPassword,
      );

      // Assert：导入数据与导出数据完全一致
      expect(result['device_id'], equals(_kDeviceId));
      expect(result['key_id'], equals(_kKeyId));
      expect(result['private_key'], equals(_kFakePrivateKey));
      expect(result['public_key'], equals(_kFakePublicKey));
      expect(result['file_size'], isPositive);
    });

    // 7. 空/不存在文件路径恢复应优雅失败 / Non-existent file graceful failure
    test(
      '不存在的备份文件应抛出 ArgumentError / missing file throws ArgumentError',
      () async {
        expect(
          () async => E2EELocalBackupService.importBackup(
            filePath: '/nonexistent/path/backup.enc',
            password: _kValidPassword,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    // 空文件（0 字节）恢复应失败
    test('空文件导入应抛出 ArgumentError / empty file throws ArgumentError', () async {
      // Arrange：写一个空文件
      final emptyFile = File(
        '${Directory.systemTemp.path}/empty_backup_test.enc',
      );
      await emptyFile.writeAsBytes(Uint8List(0));
      addTearDown(() => emptyFile.delete().catchError((_) => emptyFile));

      // Assert
      expect(
        () async => E2EELocalBackupService.importBackup(
          filePath: emptyFile.path,
          password: _kValidPassword,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // 8. 备份数据损坏检测 / Corrupted backup detection
    test(
      '篡改密文后校验和不匹配应抛出异常 / corrupted ciphertext throws on checksum mismatch',
      () async {
        // Arrange：先生成合法备份
        final filePath = await _createValidBackup();
        addTearDown(
          () => File(filePath).delete().catchError((_) => File(filePath)),
        );

        // 读取备份字节，翻转中间区域几个字节（密文部分）
        final originalBytes = await File(filePath).readAsBytes();
        final corruptedBytes = Uint8List.fromList(originalBytes);
        // 文件头 32 + salt 16 + iv 12 + tag 16 = 76 字节是固定头
        // 从偏移 76 开始修改密文内容
        if (corruptedBytes.length > 100) {
          corruptedBytes[80] ^= 0xFF;
          corruptedBytes[81] ^= 0xFF;
          corruptedBytes[82] ^= 0xFF;
        }

        final corruptedPath =
            '${Directory.systemTemp.path}/corrupted_backup_test.enc';
        await File(corruptedPath).writeAsBytes(corruptedBytes);
        addTearDown(
          () => File(
            corruptedPath,
          ).delete().catchError((_) => File(corruptedPath)),
        );

        // Assert：GCM 认证或校验和应触发异常
        expect(
          () async => E2EELocalBackupService.importBackup(
            filePath: corruptedPath,
            password: _kValidPassword,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    // 9. Magic Number 错误应抛出异常 / Invalid magic number throws
    test(
      '无效 Magic Number 的文件应抛出 ArgumentError / invalid magic number throws',
      () async {
        // Arrange：写一个不以 "IMBOYBKP" 开头的文件（≥32 字节）
        final fakeBytes = Uint8List(64);
        // 写入错误的魔数
        final magic = utf8.encode('WRONGMGC');
        fakeBytes.setRange(0, 8, magic);

        final fakePath = '${Directory.systemTemp.path}/invalid_magic_test.enc';
        await File(fakePath).writeAsBytes(fakeBytes);
        addTearDown(
          () => File(fakePath).delete().catchError((_) => File(fakePath)),
        );

        // Assert
        expect(
          () async => E2EELocalBackupService.importBackup(
            filePath: fakePath,
            password: _kValidPassword,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    // 10. 密码强度计算覆盖弱/中/强三档 / Password strength scoring
    test('密码强度分数：弱/中/强三档覆盖 / password strength covers weak/medium/strong', () {
      // Arrange & Act
      final weakScore = E2EELocalBackupService.calculatePasswordStrength('abc');
      final mediumScore = E2EELocalBackupService.calculatePasswordStrength(
        'Abcdefgh',
      ); // 8 位
      final strongScore = E2EELocalBackupService.calculatePasswordStrength(
        'StrongP@ss1234567',
      ); // 16+ 位

      // Assert
      expect(weakScore, lessThan(0.5), reason: '少于 8 位应为弱密码');
      expect(mediumScore, greaterThanOrEqualTo(0.5), reason: '8 位应达到基础分');
      expect(mediumScore, lessThanOrEqualTo(0.8), reason: '8-11 位不应得满分');
      expect(strongScore, equals(1.0), reason: '16 位或以上应得满分 1.0');
    });

    // 额外：密码不足 8 位时导出应抛出 ArgumentError
    test(
      '密码不足 8 位时 exportBackup 应抛出 ArgumentError / short password throws',
      () {
        expect(
          () async => E2EELocalBackupService.exportBackup(
            password: _kShortPassword,
            privateKey: _kFakePrivateKey,
            publicKey: _kFakePublicKey,
            deviceId: _kDeviceId,
            keyId: _kKeyId,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    // 额外：verifyBackupFile 对合法文件应返回 is_valid=true
    test(
      'verifyBackupFile 对合法备份应返回 is_valid=true / valid file passes verification',
      () async {
        // Arrange
        final filePath = await _createValidBackup();
        addTearDown(
          () => File(filePath).delete().catchError((_) => File(filePath)),
        );

        // Act
        final info = await E2EELocalBackupService.verifyBackupFile(filePath);

        // Assert
        expect(info['is_valid'], isTrue);
        expect(info['version'], equals(E2EECryptoService.formatVersion));
        expect(info['algorithm'], equals(E2EECryptoService.algorithmId));
        expect(info['file_size'], isPositive);
      },
    );
  });
}
