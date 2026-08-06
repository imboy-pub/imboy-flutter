import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/service/e2ee_crypto_service.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';

/// lib/page/settings/e2ee_backup_export_page.dart 与
/// e2ee_backup_import_page.dart 的可提纯逻辑单测。
///
/// 页面本身不可 widget 渲染测试：两页在交互路径上直接调用
/// StorageSecureService.to（flutter_secure_storage 平台通道）与
/// E2EELocalBackupService.exportBackup（文件系统 + 平台通道），
/// 无 Provider 注入点，无法用 ProviderScope override（与
/// test/page/user_tag/user_tag_states_test.dart 头注释同样的原因）。
/// 故此处覆盖页面直接依赖的纯逻辑：
/// - calculatePasswordStrength（export 页强度条数据源）
/// - verifyBackupFile 文件头解析（import 页选择文件后的校验）
void main() {
  group('calculatePasswordStrength（export 页强度条）', () {
    test('空密码与短密码强度为 0', () {
      expect(E2EELocalBackupService.calculatePasswordStrength(''), 0.0);
      expect(E2EELocalBackupService.calculatePasswordStrength('1234567'), 0.0);
    });

    test('长度 8-11 位强度为 0.5', () {
      expect(E2EELocalBackupService.calculatePasswordStrength('12345678'), 0.5);
      expect(
        E2EELocalBackupService.calculatePasswordStrength('12345678901'),
        0.5,
      );
    });

    test('长度 12-15 位强度为 0.8', () {
      expect(
        E2EELocalBackupService.calculatePasswordStrength('123456789012'),
        closeTo(0.8, 1e-9),
      );
      expect(
        E2EELocalBackupService.calculatePasswordStrength('123456789012345'),
        closeTo(0.8, 1e-9),
      );
    });

    test('长度 >= 16 位强度为 1.0（clamp 上限）', () {
      expect(
        E2EELocalBackupService.calculatePasswordStrength('1234567890123456'),
        1.0,
      );
      expect(E2EELocalBackupService.calculatePasswordStrength('x' * 100), 1.0);
    });

    test('强度取值集合与页面分档契约', () {
      // export 页 _getStrengthLabel 分档: <0.3 弱 / <0.6 中 / <0.8 强 / 其余极强。
      // 强度函数可达值仅 {0.0, 0.5, 0.8, 1.0}：
      //   0.0 → 弱, 0.5 → 中, 0.8/1.0 → 极强。
      // 注意 [0.6, 0.8) "强" 分档实际不可达（见汇报，非 bug 但是死分支）。
      final reachable = <double>{
        for (final len in List.generate(30, (i) => i))
          E2EELocalBackupService.calculatePasswordStrength('a' * len),
      };
      expect(reachable, {0.0, 0.5, closeTo(0.8, 1e-9), 1.0});
      for (final s in reachable) {
        expect(s >= 0.6 && s < 0.8, isFalse, reason: '"强" 分档应不可达');
      }
    });
  });

  group('verifyBackupFile（import 页文件校验）', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('e2ee_backup_test_');
    });

    tearDown(() async {
      await tmpDir.delete(recursive: true);
    });

    /// 按 E2EELocalBackupService._buildFileHeader 的 32 字节格式构造文件头
    Uint8List buildHeader({String magic = E2EECryptoService.magicNumber}) {
      final header = Uint8List(32);
      final bd = ByteData.sublistView(header);
      final magicBytes = magic.padRight(8, '\x00').codeUnits;
      header.setRange(0, 8, magicBytes);
      bd.setUint16(8, E2EECryptoService.formatVersion);
      bd.setUint16(10, E2EECryptoService.algorithmId);
      bd.setUint32(12, E2EECryptoService.pbkdf2Iterations);
      bd.setUint16(16, E2EECryptoService.saltLength);
      bd.setUint16(18, E2EECryptoService.ivLength);
      bd.setUint16(20, E2EECryptoService.authTagLength);
      // 其余 10 字节 reserved 保持 0
      return header;
    }

    test('合法文件头返回完整元信息且 is_valid 为 true', () async {
      final file = File('${tmpDir.path}/valid.enc');
      final body = Uint8List(64); // 模拟 salt/iv/tag/密文占位
      await file.writeAsBytes([...buildHeader(), ...body]);

      final info = await E2EELocalBackupService.verifyBackupFile(file.path);

      expect(info['version'], E2EECryptoService.formatVersion);
      expect(info['algorithm'], E2EECryptoService.algorithmId);
      expect(info['iterations'], E2EECryptoService.pbkdf2Iterations);
      expect(info['salt_length'], E2EECryptoService.saltLength);
      expect(info['iv_length'], E2EECryptoService.ivLength);
      expect(info['tag_length'], E2EECryptoService.authTagLength);
      expect(info['file_size'], 32 + 64);
      expect(info['is_valid'], isTrue);
    });

    test('Magic Number 错误抛 ArgumentError', () async {
      final file = File('${tmpDir.path}/bad_magic.enc');
      await file.writeAsBytes(buildHeader(magic: 'NOTIMBOY'));

      expect(
        () => E2EELocalBackupService.verifyBackupFile(file.path),
        throwsArgumentError,
      );
    });

    test('文件不足 32 字节抛 ArgumentError', () async {
      final file = File('${tmpDir.path}/tiny.enc');
      await file.writeAsBytes(List.filled(16, 0));

      expect(
        () => E2EELocalBackupService.verifyBackupFile(file.path),
        throwsArgumentError,
      );
    });

    test('文件不存在抛 ArgumentError', () async {
      expect(
        () => E2EELocalBackupService.verifyBackupFile(
          '${tmpDir.path}/missing.enc',
        ),
        throwsArgumentError,
      );
    });
  });
}
