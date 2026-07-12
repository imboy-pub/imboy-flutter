import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee_crypto_service.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/e2ee_server_backup_service.dart';

/// E2EE 云端备份服务单测（P0-B B3）
///
/// 覆盖：pack→unpack 字节级往返、错口令失败、hash 篡改检出、
/// salt 固定偏移提取与服务端契约一致。
/// 加密核与本地文件备份共用（packBackupBytes/unpackBackupBytes）。
void main() {
  const password = 'Test-Passw0rd!';
  // 假 PEM fixture，仅测字节往返，非真实密钥
  const privateKey =
      '-----BEGIN RSA PRIVATE KEY-----\nMIIfake-private\n-----END RSA PRIVATE KEY-----'; // gitleaks:allow
  const publicKey =
      '-----BEGIN PUBLIC KEY-----\nMIIfake-public\n-----END PUBLIC KEY-----';
  const deviceId = 'device-b3-test';
  const keyId = 'key-b3-test';

  Future<Uint8List> packBytes() {
    return E2EELocalBackupService.packBackupBytes(
      password: password,
      privateKey: privateKey,
      publicKey: publicKey,
      deviceId: deviceId,
      keyId: keyId,
    );
  }

  group('packBackupBytes / unpackBackupBytes', () {
    test('打包后解包还原全部密钥字段（字节级往返）', () async {
      final bytes = await packBytes();
      // 格式：[头 32] + [salt 16] + [iv 12] + [authTag 16] + [密文]
      expect(bytes.length, greaterThan(76));

      final result = await E2EELocalBackupService.unpackBackupBytes(
        bytes: bytes,
        password: password,
      );
      expect(result['private_key'], privateKey);
      expect(result['public_key'], publicKey);
      expect(result['device_id'], deviceId);
      expect(result['key_id'], keyId);
    });

    test('错口令解包抛 ArgumentError（GCM 认证失败，非崩溃）', () async {
      final bytes = await packBytes();
      await expectLater(
        E2EELocalBackupService.unpackBackupBytes(
          bytes: bytes,
          password: 'Wrong-Passw0rd!',
        ),
        throwsArgumentError,
      );
    });

    test('salt 位于固定偏移 32，且与服务端契约提取方式一致', () async {
      final bytes = await packBytes();
      final salt = bytes.sublist(32, 32 + E2EECryptoService.saltLength);
      expect(salt.length, E2EECryptoService.saltLength);
      // 同一 salt + 口令可独立派生密钥（服务端存的 kdf_salt 足以支撑恢复端派生）
      final key = await E2EECryptoService.deriveKey(
        password,
        Uint8List.fromList(salt),
      );
      expect(key.length, 32);
    });
  });

  group('payloadHash / verifyPayloadHash', () {
    test('hash 一致时校验通过', () async {
      final bytes = await packBytes();
      final payload = base64.encode(bytes);
      final hash = E2EEServerBackupService.payloadHash(payload);
      expect(
        () => E2EEServerBackupService.verifyPayloadHash(payload, hash),
        returnsNormally,
      );
      // 大小写不敏感
      expect(
        () => E2EEServerBackupService.verifyPayloadHash(
          payload,
          hash.toUpperCase(),
        ),
        returnsNormally,
      );
    });

    test('密文被篡改时校验抛 ArgumentError', () async {
      final bytes = await packBytes();
      final payload = base64.encode(bytes);
      final hash = E2EEServerBackupService.payloadHash(payload);
      final tampered = '${payload.substring(0, payload.length - 4)}AAAA';
      expect(
        () => E2EEServerBackupService.verifyPayloadHash(tampered, hash),
        throwsArgumentError,
      );
    });

    test('缺少 hash 时拒绝恢复', () {
      expect(
        () => E2EEServerBackupService.verifyPayloadHash('cGF5bG9hZA==', null),
        throwsArgumentError,
      );
      expect(
        () => E2EEServerBackupService.verifyPayloadHash('cGF5bG9hZA==', ''),
        throwsArgumentError,
      );
    });
  });
}
