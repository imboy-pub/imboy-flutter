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

/// 单类秘密/信任态的清单条目（C05 secret/data inventory）。
///
/// 每个条目回答四个边界问题：存哪、怎么来、OS 备份里会不会出现、
/// logout / 换号清不清。新增 E2EE 存储类别时必须同步在此登记，
/// 否则 [E2eeSecretInventory.report] 的对账测试（canary）会失败。
class SecretCategory {
  const SecretCategory({
    required this.id,
    required this.keyPrefix,
    required this.storageLocation,
    required this.derivation,
    required this.inOsBackup,
    required this.clearedOnLogout,
    required this.clearedOnAccountSwitch,
    required this.note,
  });

  /// 类别标识（报告行 ID）。
  final String id;

  /// 对应的 secure storage 键前缀（须与 [E2eeSecretInventory.secretKeyPrefixes]
  /// 中某一项前缀一致，报告一致性测试据此对账）。
  final String keyPrefix;

  /// 存储位置描述。
  final String storageLocation;

  /// 派生方式描述（随机生成 / 服务端下发 / 协议计算）。
  final String derivation;

  /// 是否会进入 OS 级备份（iOS iCloud/iTunes 备份、Android auto backup）。
  ///
  /// flutter_secure_storage 条目在 iOS 侧统一使用
  /// `kSecAttrAccessibleAfterFirstUnlockThisDevice`（ThisDeviceOnly，
  /// 见 StorageSecureService）：**不随 iCloud 备份迁移到新设备**；Android 侧
  /// `allowBackup=false` + `fullBackupContent=false` + dataExtractionRules
  /// 显式排除（见 android/app/src/main/AndroidManifest.xml）→ 不进备份。
  final bool inOsBackup;

  /// logout（quitLogin）是否清理。
  final bool clearedOnLogout;

  /// 换号（logout → loginAfter 闸门）是否清理。
  final bool clearedOnAccountSwitch;

  /// 补充说明。
  final String note;
}

/// E2EE 秘密清单与 logout 清理 orchestrator（E2EE-015 + C05 inventory）。
///
/// 单一入口枚举并清除全部秘密类别：
/// - RSA 身份/历史私钥/社交恢复分片（`e2ee_*`，含 backup/recovery 元数据与 DID/kid）；
/// - Olm account pickle / pickle key / session pickles（`olm_*`）；
/// - Megolm inbound session、历史授权与恢复标记（`megolm_*`）以及群旗标
///   （`group_e2ee_mode_*`）;
/// - SQLCipher DB key（`db_cipher_key_*`，删除后旧库无法打开）；
/// - safety number 验证标记（`safety_number_verified_*`，C05：信任态残留，
///   换号不清会让新账号错误继承旧账号对同一 peer 的「已验证」结论）；
/// - safety number 设备集合（`safety_number_devset_*`，C07/AC-15：批准集合
///   与漂移基线，同为对 peer 的信任态/观察态）；
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
      _purgeUploadCacheFiles,
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
    'megolm_history_grant_', // 当前账号从后端取得的群历史授权
    'megolm_restored_history_grant_', // 备份恢复会话的范围门 marker
    'group_e2ee_mode_', // 群 E2EE 旗标（服务端权威，可重拉）
    'safety_number_verified_', // safety number 信任态（C05：防换号残留）
    // safety number 设备集合（C07/AC-15）：用户批准集合 + 漂移检测基线
    //（前缀同时覆盖 safety_number_devset_baseline_* 子族）
    'safety_number_devset_',
    'db_cipher_key_', // SQLCipher DB key（按 uid）
    'utk_', // 附件上传 content key / nonce / descriptor（兼容清除旧全局键）
    'mls_', // MLS 预留
  ];

  /// 有意**不**纳入 purge 清单的 secure storage 键（及其理由）。
  ///
  /// 新增豁免必须给出理由，注册表对账测试据此放行；无理由的豁免
  /// 视为清单缺口。
  static const Map<String, String> declaredExemptions = {
    // 登录密码一次性传输密钥：设备级、服务端持公钥，不随账号轮换（见类注释）
    'public_key': 'RSAService 设备级登录密码传输公钥，非账号 E2EE 身份',
    'private_key': 'RSAService 设备级登录密码传输私钥，不随账号切换轮换',
    // JWT：由 SecureTokenStorageService 在 quitLogin 单独 clear
    'secure_token': 'JWT，SecureTokenStorageService.logout 专责清理',
    'secure_refresh_token': 'JWT refresh，SecureTokenStorageService.logout 专责清理',
    // 服务端合规公钥 pin：设备级信任锚（pin 的是服务端密钥，不随账号变）
    'compliance_key_pin_v1': '服务端合规密钥 TOFU pin，设备级信任锚，跨账号复用',
    // 上传凭据：per-login 下发，loginAfter → initConfig 每次登录覆盖写；
    // 残留窗口内是旧账号凭据（低危），非 E2EE 会话秘密（C05 矩阵邻接项）
    'upload_key': '附件上传授权凭据，每次登录由 initConfig 重新下发覆盖',
  };

  /// C05 secret/data inventory：每类秘密的完整边界矩阵。
  ///
  /// 一致性契约：
  /// - 每个条目的 [SecretCategory.keyPrefix] 必须是 [secretKeyPrefixes] 之一
  ///   （canary 测试据此生成标记值验证 purge 覆盖）；
  /// - 每个 [secretKeyPrefixes] 前缀必须恰好有一个条目（防清单/purge 漂移）。
  static const List<SecretCategory> categories = [
    SecretCategory(
      id: 'rsa-identity',
      keyPrefix: 'e2ee_',
      storageLocation:
          'secure storage（iOS Keychain ThisDeviceOnly / Android '
          'Keystore-AES SharedPreferences）',
      derivation:
          '客户端 Random.secure 生成 RSA-2048 身份对；backup 口令为'
          '用户口令 KDF；shard 由所有者端分片下发',
      inOsBackup: false,
      clearedOnLogout: true,
      clearedOnAccountSwitch: true,
      note: '含 e2ee_backup_passphrase（备份口令明文，随 e2ee_ 前缀清理）',
    ),
    SecretCategory(
      id: 'olm-sessions',
      keyPrefix: 'olm_',
      storageLocation: 'secure storage + OlmSessionService 内存 Account/Session',
      derivation: 'Olm（X3DH/双棘轮）协议计算，pickle 以 olm_pickle_key 加密',
      inOsBackup: false,
      clearedOnLogout: true,
      clearedOnAccountSwitch: true,
      note: '内存态由 OlmSessionService.clearAll（purgeArtifacts）清除',
    ),
    SecretCategory(
      id: 'megolm-inbound',
      keyPrefix: 'megolm_inbound_',
      storageLocation: 'secure storage',
      derivation: '对端 Megolm 房间密钥经 Olm 通道分发',
      inOsBackup: false,
      clearedOnLogout: true,
      clearedOnAccountSwitch: true,
      note: '群会话解密能力，泄漏即历史明文可解',
    ),
    SecretCategory(
      id: 'megolm-history-grant',
      keyPrefix: 'megolm_history_grant_',
      storageLocation: 'secure storage',
      derivation: '服务端下发的历史消息授权凭证',
      inOsBackup: false,
      clearedOnLogout: true,
      clearedOnAccountSwitch: true,
      note: '当前账号在线取得的历史授权',
    ),
    SecretCategory(
      id: 'megolm-restored-grant-marker',
      keyPrefix: 'megolm_restored_history_grant_',
      storageLocation: 'secure storage',
      derivation: '备份恢复流程写入的范围门 marker',
      inOsBackup: false,
      clearedOnLogout: true,
      clearedOnAccountSwitch: true,
      note: '标记某会话历史来自备份恢复（服务端权威范围门）',
    ),
    SecretCategory(
      id: 'group-e2ee-flag',
      keyPrefix: 'group_e2ee_mode_',
      storageLocation: 'secure storage',
      derivation: '服务端权威旗标的本地缓存',
      inOsBackup: false,
      clearedOnLogout: true,
      clearedOnAccountSwitch: true,
      note: '可从服务端重拉，清理无数据损失',
    ),
    SecretCategory(
      id: 'safety-number-trust',
      keyPrefix: 'safety_number_verified_',
      storageLocation: 'secure storage',
      derivation: '用户在 safety number 页人工确认的 TOFU 信任决定',
      inOsBackup: false,
      clearedOnLogout: true,
      clearedOnAccountSwitch: true,
      note: 'C05 新增：防换号后新账号错误继承旧账号验证结论',
    ),
    SecretCategory(
      id: 'safety-number-device-set',
      // 同前缀覆盖 safety_number_devset_<uid>（用户批准集合）与
      // safety_number_devset_baseline_<uid>（漂移检测观察基线）两族键。
      keyPrefix: 'safety_number_devset_',
      storageLocation: 'secure storage',
      derivation:
          '用户验证安全码时记录的对端设备批准集合（排序 JSON）；'
          '观察基线为服务端下发设备集合的本地快照',
      inOsBackup: false,
      clearedOnLogout: true,
      clearedOnAccountSwitch: true,
      note:
          'C07/AC-15 新增：设备集合是对 peer 的信任态/观察态，换号不清会让'
          '新账号继承旧账号的设备批准结论（与 safety_number_verified_ 同理）',
    ),
    SecretCategory(
      id: 'sqlcipher-db-key',
      keyPrefix: 'db_cipher_key_',
      storageLocation: 'secure storage（按 uid 隔离）',
      derivation: 'Random.secure 32 字节 hex（256-bit）',
      inOsBackup: false,
      clearedOnLogout: true,
      clearedOnAccountSwitch: true,
      note:
          'quitLogin 同步删除 DB 文件（deleteDatabaseForUid），密钥+文件'
          '双清除；明文库在 iOS 备份中的残留见 C05 矩阵（密文，无密钥不可解）',
    ),
    SecretCategory(
      id: 'attachment-upload-material',
      keyPrefix: 'utk_',
      storageLocation: 'secure storage，按 env/uid/task 命名',
      derivation: 'Random.secure content key / nonce 与原 descriptor',
      inOsBackup: false,
      clearedOnLogout: true,
      clearedOnAccountSwitch: true,
      note: '与认证队列串行写入；logout purge 覆盖旧全局及新隔离键',
    ),
    SecretCategory(
      id: 'mls-reserved',
      keyPrefix: 'mls_',
      storageLocation: 'secure storage（预留，尚无写入方）',
      derivation: 'N/A',
      inOsBackup: false,
      clearedOnLogout: true,
      clearedOnAccountSwitch: true,
      note: '前缀预留：未来 MLS 落地时自动纳入清理',
    ),
  ];

  /// 生成 inventory 文本报告（C05 证据产物；测试断言报告与前缀清单一致）。
  static String report() {
    final buf = StringBuffer('E2EE Secret Inventory (C05)\n');
    for (final c in categories) {
      buf
        ..write(
          '- [${c.id}] prefix=${c.keyPrefix} storage=${c.storageLocation}'
          ' derivation=${c.derivation} osBackup=${c.inOsBackup ? 'YES' : 'no'}'
          ' logout=${c.clearedOnLogout ? 'purge' : 'keep'}'
          ' switch=${c.clearedOnAccountSwitch ? 'purge' : 'keep'}',
        )
        ..write(' | ${c.note}\n');
    }
    buf.write('exemptions:\n');
    declaredExemptions.forEach((k, v) => buf.write('- $k: $v\n'));
    return buf.toString();
  }

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

  static Future<void> _purgeUploadCacheFiles() async {
    final root = await getApplicationCacheDirectory();
    final directory = Directory('${root.path}/attachment_uploads');
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
