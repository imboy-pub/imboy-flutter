import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:imboy/service/compliance_key_service.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/olm_session_service.dart';
import 'package:imboy/service/storage_secure.dart';

/// E2EE 秘密清理失败（E2EE-015）。
///
/// 携带逐项失败/残留清单；调用方（logout / 换号）收到本异常
/// **必须阻止建立新账号会话**（fail-closed）。
class E2eeSecretPurgeException implements Exception {
  E2eeSecretPurgeException(this.failures);

  final List<String> failures;

  @override
  String toString() => 'E2eeSecretPurgeException: ${failures.join('; ')}';
}

/// E2EE 秘密清单与 logout 清理 orchestrator（E2EE-015）。
///
/// 单一入口枚举并清除全部秘密类别：
/// - RSA 身份/历史私钥/社交恢复分片（`e2ee_*`，含 backup/recovery 元数据与 DID/kid）；
/// - Olm account pickle / pickle key / session pickles（`olm_*`）；
/// - Megolm inbound session pickles（`megolm_inbound_*`）与群旗标（`group_e2ee_mode_*`）;
/// - SQLCipher DB key（`db_cipher_key_*`，删除后旧库无法打开）；
/// - MLS 预留（`mls_*`，尚无写入方）；
/// - 各服务内存缓存与本地备份临时文件。
///
/// 清理策略：逐项 continue-on-error 收集失败，最后 readAll 复核零残留；
/// 任一失败统一抛 [E2eeSecretPurgeException]，不静默吞错。
class E2eeSecretInventory {
  E2eeSecretInventory({
    required this.readAll,
    required this.deleteKey,
    this.clearMemoryCaches = const [],
    this.purgeArtifacts = const [],
  });

  /// 生产接线：真实 secure storage + 各 E2EE 服务内存缓存 + 临时备份文件。
  factory E2eeSecretInventory.production() => E2eeSecretInventory(
    readAll: StorageSecureService.to.readAll,
    deleteKey: (key) => StorageSecureService.to.delete(key: key),
    clearMemoryCaches: [
      E2EEService.clearCache,
      ComplianceKeyService.instance.clearCache,
      GroupSessionService.to.clearMemory,
    ],
    purgeArtifacts: [
      // 清 Olm 内存 Account/Session（其存储键由下方前缀清理兜底复核）
      OlmSessionService.to.clearAll,
      _purgeLocalBackupTempFiles,
    ],
  );

  final Future<Map<String, String>> Function() readAll;
  final Future<void> Function(String key) deleteKey;
  final List<void Function()> clearMemoryCaches;
  final List<Future<void> Function()> purgeArtifacts;

  /// 秘密键前缀清单（新增 E2EE 存储键必须落在这些前缀之下，
  /// 否则 logout 清理与本清单测试都覆盖不到）。
  ///
  /// 有意排除：`RSAService` 的 `public_key`/`private_key`（`Keys.publicKey/privateKey`）
  /// 是**设备级登录密码传输密钥**（仅对登录/改密时的明文密码做一次性 RSA 加密，
  /// 服务端持对应公钥），非账号级 E2EE 身份秘密；不随账号切换轮换，故不清理。
  /// `secure_token*`（JWT）由 SecureTokenStorageService 负责，亦不在此清单。
  static const List<String> secretKeyPrefixes = [
    'e2ee_', // RSA 身份/历史/分片/DID/kid + backup/recovery 元数据
    'olm_', // Olm account pickle / pickle key / session pickles
    'megolm_inbound_', // Megolm inbound session pickles
    'group_e2ee_mode_', // 群 E2EE 旗标（服务端权威，可重拉）
    'db_cipher_key_', // SQLCipher DB key（按 uid）
    'mls_', // MLS 预留
  ];

  static bool matchesSecretKey(String key) =>
      secretKeyPrefixes.any(key.startsWith);

  /// 清理全部秘密：内存缓存 → 附属产物 → 持久化键 → 复核零残留。
  Future<void> purgeAll() async {
    final failures = <String>[];

    for (final clear in clearMemoryCaches) {
      try {
        clear();
      } on Object catch (e) {
        failures.add('memory: $e');
      }
    }

    for (final purge in purgeArtifacts) {
      try {
        await purge();
      } on Object catch (e) {
        failures.add('artifact: $e');
      }
    }

    try {
      final keys = (await readAll()).keys.where(matchesSecretKey).toList();
      for (final key in keys) {
        try {
          await deleteKey(key);
        } on Object catch (e) {
          failures.add('delete $key: $e');
        }
      }
      // 复核：删除后逐项确认不存在，平台层假成功也拦下
      final residual = (await readAll()).keys.where(matchesSecretKey);
      failures.addAll(residual.map((key) => 'residual $key'));
    } on Object catch (e) {
      failures.add('storage: $e');
    }

    if (failures.isNotEmpty) {
      throw E2eeSecretPurgeException(List.unmodifiable(failures));
    }
  }

  /// 删除 E2EELocalBackupService 落在临时目录的加密备份文件。
  static Future<void> _purgeLocalBackupTempFiles() async {
    final tempDir = await getTemporaryDirectory();
    await for (final entry in tempDir.list()) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (name.startsWith('imboy_e2ee_backup_') && name.endsWith('.enc')) {
        await entry.delete();
      }
    }
  }
}
