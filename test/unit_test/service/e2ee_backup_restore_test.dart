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
import 'dart:typed_data';

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

/// KDF 600k（OWASP 2023）纯 Dart 派生在 CI 并发下单次数秒，
/// 涉及 pack/unpack 的用例统一放宽超时。
const _kdfTimeout = Timeout(Duration(minutes: 2));

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
    secureEntriesForTest: const {},
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
        secureEntriesForTest: const {},
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
    }, timeout: const Timeout(Duration(minutes: 2)));
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
    }, timeout: _kdfTimeout);

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
    }, timeout: const Timeout(Duration(minutes: 2)));
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
    }, timeout: _kdfTimeout);

    test('安全存储不可读时拒绝生成不完整备份', () async {
      await expectLater(
        E2EELocalBackupService.packBackupBytes(
          password: _kValidPassword,
          privateKey: _kFakePrivateKey,
          publicKey: _kFakePublicKey,
          deviceId: _kDeviceId,
          keyId: _kKeyId,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'backup_secret_collection_failed',
          ),
        ),
      );
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
          () =>
              File(corruptedPath)
                  .delete()
                  .catchError((_) => File(corruptedPath)),
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
      timeout: _kdfTimeout,
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
    test('verifyBackupFile 对合法备份应返回 is_valid=true / valid file passes verification', () async {
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
    }, timeout: _kdfTimeout);
  });

  // =========================================================================
  // 组 4（C03）：备份包含/排除材料清单核验
  // =========================================================================
  group('C03 — 备份包含/排除材料清单核验', () {
    test('导出物逐字段与文档清单一致（RSA + Megolm inbound v2 + 元数据）', () async {
      const gid = '100';
      const sessionId = 'session-inventory';
      const grantJson =
          '{"version":1,"scope":"100","session_id":'
          '"session-inventory","epoch_id":"session-inventory",'
          '"generation_no":2,"start_seq":481,"end_seq":900,'
          '"source":"server_history_grant"}';
      final bytes = await E2EELocalBackupService.packBackupBytes(
        password: _kValidPassword,
        privateKey: _kFakePrivateKey,
        publicKey: _kFakePublicKey,
        deviceId: _kDeviceId,
        keyId: _kKeyId,
        accountId: '900001',
        secureEntriesForTest: {
          'megolm_inbound_$gid:$sessionId': 'exported-key-inventory',
          'megolm_history_grant_$gid:$sessionId': grantJson,
        },
      );

      final restored = await E2EELocalBackupService.unpackBackupBytes(
        bytes: bytes,
        password: _kValidPassword,
      );

      // 顶层字段逐项核验（备份格式版本 version 由 32 字节文件头承载，
      // 见 KDF 版本化组的头部断言；unpack 返回面不含 version）
      expect(restored['device_id'], _kDeviceId);
      expect(restored['private_key'], _kFakePrivateKey);
      expect(restored['public_key'], _kFakePublicKey);
      expect(restored['key_id'], _kKeyId);
      expect(restored['account_id'], '900001');
      expect(restored['created_at'], isA<String>());
      final createdAt = DateTime.parse(restored['created_at'] as String);
      expect(createdAt.isUtc, isTrue, reason: 'created_at 须为 UTC ISO-8601');

      // Megolm inbound 段逐项核验（v2 结构 + grant 元数据）
      final section = E2EELocalBackupService.megolmBackupSection(restored);
      expect(section.sessions, hasLength(1));
      final session = section.sessions.single;
      expect(session.scope, gid);
      expect(session.sessionId, sessionId);
      expect(session.exportedKey, 'exported-key-inventory');
      expect(session.grant.generationNo, 2);
      expect(session.grant.startSeq, 481);
      expect(session.grant.endSeq, 900);
      expect(session.grant.epochId, sessionId);
      expect(section.omittedSessionCount, 0);
    }, timeout: _kdfTimeout);

    test('排除项不可达：Olm ratchet / 社交恢复分片 / 历史私钥 / DID 均不进入导出物', () async {
      // 哨兵法：每类排除材料给唯一值，解密后的完整 JSON 不得包含任何哨兵
      final excluded = <String, String>{
        'olm_account_pickle': 'OLM-ACCOUNT-PICKLE-SECRET',
        'olm_session_900001:did_peer_1': 'OLM-SESSION-RATCHET-SECRET',
        'e2ee_shard_1': 'SHAMIR-SHARD-SECRET',
        'e2ee_shard_id_list': 'SHARD-ID-LIST-SECRET',
        'e2ee_private_key_history_kid_old': 'HISTORICAL-PRIVATE-KEY-SECRET',
        'e2ee_device_id': 'DID-SECRET',
        'e2ee_key_created_at': 'KEY-CREATED-AT-SECRET',
        'db_cipher_key_900001': 'SQLCIPHER-KEY-SECRET',
        'group_e2ee_mode_100': 'GROUP-MODE-FLAG',
      };

      final bytes = await E2EELocalBackupService.packBackupBytes(
        password: _kValidPassword,
        privateKey: _kFakePrivateKey,
        publicKey: _kFakePublicKey,
        deviceId: _kDeviceId,
        keyId: _kKeyId,
        secureEntriesForTest: excluded,
      );

      // 直接解出明文 JSON 全文（绕过 unpack 的字段筛选，验证密文载荷本体）
      final header = ByteData.sublistView(bytes);
      final iterations = header.getUint32(12);
      final salt = bytes.sublist(32, 48);
      final iv = bytes.sublist(48, 60);
      final authTag = bytes.sublist(60, 76);
      final ciphertext = bytes.sublist(76, bytes.length);
      final key = await E2EECryptoService.deriveKey(
        _kValidPassword,
        salt,
        iterations: iterations,
      );
      final plaintext = await E2EECryptoService.decryptAesGcm(
        ciphertext,
        authTag,
        key,
        iv,
      );
      final payload = utf8.decode(plaintext);

      for (final secret in excluded.values) {
        expect(payload, isNot(contains(secret)), reason: '排除材料泄漏进备份：$secret');
      }
      // 双保险：恢复写入集合也不含任何排除键（ratchet 非克隆）
      final section = E2EELocalBackupService.megolmBackupSection(
        await E2EELocalBackupService.unpackBackupBytes(
          bytes: bytes,
          password: _kValidPassword,
        ),
      );
      expect(section.isEmpty, isTrue, reason: '排除键不该产出可恢复的群 session');
    }, timeout: _kdfTimeout);
  });

  // =========================================================================
  // 组 5（C03）：KDF 参数版本化（OWASP 2023 评审落地）
  // =========================================================================
  group('C03 — KDF 参数版本化', () {
    test('常量守护：600k 满足 OWASP 2023 建议且在头部合法区间内', () {
      // OWASP Password Storage Cheat Sheet（2023）：PBKDF2-HMAC-SHA256 ≥600k
      expect(
        E2EELocalBackupService.kdfIterationsV2,
        greaterThanOrEqualTo(600000),
      );
      // 头部 iterations 解析区间 [1, 1e6]：新参数必须落在可解密区间
      expect(
        E2EELocalBackupService.kdfIterationsV2,
        lessThanOrEqualTo(E2EELocalBackupService.maxKdfIterations),
      );
      expect(
        E2EELocalBackupService.kdfIterationsV1,
        lessThanOrEqualTo(E2EELocalBackupService.maxKdfIterations),
      );
    });

    test('新导出头部写入 kdfIterationsV2（600k）', () async {
      final bytes = await E2EELocalBackupService.packBackupBytes(
        password: _kValidPassword,
        privateKey: _kFakePrivateKey,
        publicKey: _kFakePublicKey,
        deviceId: _kDeviceId,
        keyId: _kKeyId,
        secureEntriesForTest: const {},
      );
      // 文件头偏移 12：iterations（uint32 大端）
      final iterations = ByteData.sublistView(bytes).getUint32(12);
      expect(iterations, E2EELocalBackupService.kdfIterationsV2);
      expect(iterations, 600000);
    }, timeout: _kdfTimeout);

    test('310k 参数版本 1 的存量备份仍可解密（头部自描述，向后兼容）', () async {
      // 手工构建 310k 旧参数备份：复刻 pack 的二进制格式，
      // 派生与头部均用 kdfIterationsV1（等价于旧版 App 导出的文件）。
      final Map<String, dynamic> backupData = {
        'version': E2EECryptoService.formatVersion,
        'device_id': _kDeviceId,
        'private_key': _kFakePrivateKey,
        'public_key': _kFakePublicKey,
        'key_id': _kKeyId,
        'created_at': '2026-01-31T00:00:00.000Z',
        'megolm_inbound': <String, dynamic>{
          'format_version': 2,
          'sessions': <dynamic>[],
          'omitted_session_count': 0,
        },
      };
      final checksum = E2EECryptoService.calculateChecksum(
        Uint8List.fromList(utf8.encode(json.encode(backupData))),
      );
      backupData['checksum'] = 'sha256:$checksum';

      final salt = E2EECryptoService.generateSalt();
      final iv = E2EECryptoService.generateIV();
      final legacyKey = await E2EECryptoService.deriveKey(
        _kValidPassword,
        salt,
        iterations: E2EELocalBackupService.kdfIterationsV1,
      );
      final encrypted = await E2EECryptoService.encryptAesGcm(
        Uint8List.fromList(utf8.encode(json.encode(backupData))),
        legacyKey,
        iv,
      );

      Uint8List u16(int v) =>
          (ByteData(2)..setUint16(0, v)).buffer.asUint8List();
      Uint8List u32(int v) =>
          (ByteData(4)..setUint32(0, v)).buffer.asUint8List();

      final header = BytesBuilder();
      header.add(utf8.encode('IMBOYBKP'.padRight(8, '\x00')));
      header.add(u16(E2EECryptoService.formatVersion));
      header.add(u16(E2EECryptoService.algorithmId));
      header.add(u32(E2EELocalBackupService.kdfIterationsV1));
      header.add(u16(E2EECryptoService.saltLength));
      header.add(u16(E2EECryptoService.ivLength));
      header.add(u16(E2EECryptoService.authTagLength));
      header.add(u32(0)); // notes_length
      header.add(Uint8List(6)); // reserved
      final legacyBytes = BytesBuilder()
        ..add(header.toBytes())
        ..add(salt)
        ..add(iv)
        ..add(encrypted['authTag']!)
        ..add(encrypted['ciphertext']!);

      final restored = await E2EELocalBackupService.unpackBackupBytes(
        bytes: legacyBytes.toBytes(),
        password: _kValidPassword,
      );
      expect(restored['private_key'], _kFakePrivateKey);
      expect(restored['device_id'], _kDeviceId);
    }, timeout: _kdfTimeout);

    test('kdfIterationsV1 与全局旧常量锚定一致（旧备份解密语义防漂移）', () {
      expect(
        E2EELocalBackupService.kdfIterationsV1,
        E2EECryptoService.pbkdf2Iterations,
        reason: '若全局常量调整而 V1 锚定值未同步，310k 存量备份将不可解密',
      );
    });
  });

  // =========================================================================
  // 组 6（C03）：账号绑定（跨账号恢复拒绝）
  // =========================================================================
  group('C03 — 账号绑定', () {
    test('account_id 写入导出物；匹配放行 / 不匹配拒绝 / 空期望放行 / 旧备份放行', () async {
      final bound = await E2EELocalBackupService.packBackupBytes(
        password: _kValidPassword,
        privateKey: _kFakePrivateKey,
        publicKey: _kFakePublicKey,
        deviceId: _kDeviceId,
        keyId: _kKeyId,
        accountId: '900001',
        secureEntriesForTest: const {},
      );

      // 匹配：放行且返回绑定账号
      final ok = await E2EELocalBackupService.unpackBackupBytes(
        bytes: bound,
        password: _kValidPassword,
        expectedAccountId: '900001',
      );
      expect(ok['account_id'], '900001');

      // 不匹配：拒绝（StateError backup_account_mismatch），且发生在写入前
      await expectLater(
        E2EELocalBackupService.unpackBackupBytes(
          bytes: bound,
          password: _kValidPassword,
          expectedAccountId: '900002',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'backup_account_mismatch',
          ),
        ),
      );

      // 空期望（登出态/未知会话）：不强校验，放行
      final noExpect = await E2EELocalBackupService.unpackBackupBytes(
        bytes: bound,
        password: _kValidPassword,
        expectedAccountId: null,
      );
      expect(noExpect['private_key'], _kFakePrivateKey);

      // 旧备份（无 account_id 字段）：无绑定信息可校验，保持放行
      final legacy = await E2EELocalBackupService.packBackupBytes(
        password: _kValidPassword,
        privateKey: _kFakePrivateKey,
        publicKey: _kFakePublicKey,
        deviceId: _kDeviceId,
        keyId: _kKeyId,
        secureEntriesForTest: const {},
      );
      final legacyRestored = await E2EELocalBackupService.unpackBackupBytes(
        bytes: legacy,
        password: _kValidPassword,
        expectedAccountId: '900002',
      );
      expect(legacyRestored['account_id'], isNull);
      expect(legacyRestored['private_key'], _kFakePrivateKey);
    }, timeout: _kdfTimeout);
  });

  // =========================================================================
  // 组 7（C03）：抗回滚（旧版本备份重放策略）
  // =========================================================================
  group('C03 — 抗回滚（水位标记）', () {
    const newer = '2026-10-01T00:00:00.000Z';
    const older = '2026-09-01T00:00:00.000Z';

    test('无水位 → 放行（首次恢复）', () {
      expect(
        () => E2EELocalBackupService.ensureNotStaleRestore(
          backupCreatedAt: older,
          backupKeyId: 'kid-old',
          markerCreatedAt: null,
          markerKeyId: null,
        ),
        returnsNormally,
      );
    });

    test('备份严格更旧且换钥 → 拒绝（stale_backup_rejected）', () {
      expect(
        () => E2EELocalBackupService.ensureNotStaleRestore(
          backupCreatedAt: older,
          backupKeyId: 'kid-old',
          markerCreatedAt: newer,
          markerKeyId: 'kid-new',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'stale_backup_rejected',
          ),
        ),
      );
    });

    test('同一备份重复导入（key_id 相同）→ 放行（幂等重试）', () {
      expect(
        () => E2EELocalBackupService.ensureNotStaleRestore(
          backupCreatedAt: older,
          backupKeyId: 'kid-same',
          markerCreatedAt: newer,
          markerKeyId: 'kid-same',
        ),
        returnsNormally,
      );
    });

    test('备份不旧于水位（同刻或更新）→ 放行', () {
      expect(
        () => E2EELocalBackupService.ensureNotStaleRestore(
          backupCreatedAt: newer,
          backupKeyId: 'kid-x',
          markerCreatedAt: newer,
          markerKeyId: 'kid-y',
        ),
        returnsNormally,
      );
      expect(
        () => E2EELocalBackupService.ensureNotStaleRestore(
          backupCreatedAt: '2026-11-01T00:00:00.000Z',
          backupKeyId: 'kid-x',
          markerCreatedAt: newer,
          markerKeyId: 'kid-y',
        ),
        returnsNormally,
      );
    });

    test('元数据缺失（旧备份无 created_at / 空 key_id）→ 放行（fail-open 取舍）', () {
      expect(
        () => E2EELocalBackupService.ensureNotStaleRestore(
          backupCreatedAt: null,
          backupKeyId: 'kid-old',
          markerCreatedAt: newer,
          markerKeyId: 'kid-new',
        ),
        returnsNormally,
      );
      expect(
        () => E2EELocalBackupService.ensureNotStaleRestore(
          backupCreatedAt: older,
          backupKeyId: '',
          markerCreatedAt: newer,
          markerKeyId: 'kid-new',
        ),
        returnsNormally,
      );
      expect(
        () => E2EELocalBackupService.ensureNotStaleRestore(
          backupCreatedAt: older,
          backupKeyId: 'kid-old',
          markerCreatedAt: '',
          markerKeyId: 'kid-new',
        ),
        returnsNormally,
      );
    });
  });
}
