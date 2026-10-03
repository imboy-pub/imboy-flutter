import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' show CancelToken;

import 'package:imboy/store/api/e2ee_backup_api.dart';

import 'e2ee_crypto_service.dart';
import 'e2ee_local_backup_service.dart';

/// E2EE 服务端加密密钥备份服务（4S 模式，P0-B B3）
///
/// 与本地文件备份（E2EELocalBackupService）共用同一加密核与二进制格式：
/// PBKDF2-HMAC-SHA256 派生 + AES-256-GCM 加密，服务端只存 base64
/// 密文包与 KDF 参数，全程不可解（零信任）。
///
/// KDF 参数：新上传使用 [E2EELocalBackupService.kdfIterationsV2]
/// （600k，OWASP 2023）；恢复按密文包文件头的自描述迭代数派生，
/// 310k 参数版本 1 的存量云端备份保持可解。
///
/// 换机恢复：新设备 restore(口令) → 拉最新密文包 → 校验 hash → 本地解密。
class E2EEServerBackupService {
  /// 上传新版本云端备份；版本号自动取服务端当前版本 + 1
  ///
  /// 并发撞版本（另一设备刚上传）时自动刷新版本重试一次。
  ///
  /// [accountId]：导出账号绑定（当前登录 uid），写入备份明文 JSON 的
  /// account_id——恢复端用它拒绝跨账号恢复（纵深防御：服务端虽按
  /// 登录账号隔离存取，密文包拿错/串号时仍可本地检出）。
  ///
  /// [cancelToken]：取消后不再发起 409 重试，并把在途请求一并掐断——页面
  /// 侧超时兜底与「稍后再说」都靠它终止空转。
  static Future<E2EEBackupPutResult> upload({
    required String password,
    required String privateKey,
    required String publicKey,
    required String deviceId,
    required String keyId,
    String? accountId,
    E2EEBackupApi? api,
    CancelToken? cancelToken,
  }) async {
    final backupApi = api ?? E2EEBackupApi();
    final bytes = await E2EELocalBackupService.packBackupBytes(
      password: password,
      privateKey: privateKey,
      publicKey: publicKey,
      deviceId: deviceId,
      keyId: keyId,
      accountId: accountId,
    );
    final payload = base64.encode(bytes);
    // salt 位于二进制格式固定偏移（[头 32] 之后），提取供服务端存储/探测
    final salt = bytes.sublist(32, 32 + E2EECryptoService.saltLength);

    var result = await _putOnce(backupApi, payload, salt, cancelToken);
    if (!result.ok &&
        result.versionConflict &&
        !(cancelToken?.isCancelled ?? false)) {
      // 并发撞版本：刷新最新版本后重试一次
      result = await _putOnce(backupApi, payload, salt, cancelToken);
    }
    return result;
  }

  /// 从云端备份恢复密钥（换机场景）
  ///
  /// 返回 {device_id, key_id, private_key, public_key, created_at}。
  /// [expectedAccountId]：当前登录 uid，透传给解包层做跨账号恢复拒绝
  /// （云端密文包按登录账号存取，此为串号/拿错包时的纵深防御）。
  /// @throws StateError 无云端备份 / 账号不匹配（backup_account_mismatch）
  /// @throws ArgumentError 口令错误（GCM 认证失败）/ 密文包已损坏
  static Future<Map<String, dynamic>> restore({
    required String password,
    String? expectedAccountId,
    E2EEBackupApi? api,
  }) async {
    final backupApi = api ?? E2EEBackupApi();
    final row = await backupApi.getBackup();
    if (row == null) {
      throw StateError('无云端备份');
    }
    final payload = row['encrypted_payload'];
    final expectedHash = row['payload_hash'];
    if (payload is! String || payload.isEmpty) {
      throw ArgumentError('云端备份密文为空');
    }
    verifyPayloadHash(payload, expectedHash?.toString());
    final bytes = base64.decode(payload);
    return E2EELocalBackupService.unpackBackupBytes(
      bytes: Uint8List.fromList(bytes),
      password: password,
      expectedAccountId: expectedAccountId,
    );
  }

  /// 计算 payload（base64 文本）的 SHA-256 十六进制哈希
  static String payloadHash(String payload) {
    return E2EECryptoService.calculateChecksum(
      Uint8List.fromList(utf8.encode(payload)),
    );
  }

  /// 校验密文包完整性；不匹配即视为损坏/篡改
  ///
  /// @throws ArgumentError hash 不匹配
  static void verifyPayloadHash(String payload, String? expectedHash) {
    if (expectedHash == null || expectedHash.isEmpty) {
      throw ArgumentError('云端备份缺少完整性哈希');
    }
    final actual = payloadHash(payload);
    if (actual.toLowerCase() != expectedHash.toLowerCase()) {
      throw ArgumentError('云端备份已损坏（哈希不匹配）');
    }
  }

  static Future<E2EEBackupPutResult> _putOnce(
    E2EEBackupApi api,
    String payload,
    Uint8List salt,
    CancelToken? cancelToken,
  ) async {
    final info = await api.info(cancelToken: cancelToken);
    final nextVersion = info.hasBackup ? info.backupVersion + 1 : 1;
    return api.putBackup(
      backupVersion: nextVersion,
      kdfSalt: base64.encode(salt),
      // 实际派生迭代数（与密文包文件头一致：600k，OWASP 2023）
      kdfIterations: E2EELocalBackupService.kdfIterationsV2,
      encryptedPayload: payload,
      payloadHash: payloadHash(payload),
      cancelToken: cancelToken,
    );
  }
}
