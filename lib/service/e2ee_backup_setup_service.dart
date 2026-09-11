import 'dart:convert';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/e2ee_server_backup_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 首启备份向导完成标记（设备级，SharedPreferences 域；非敏感布尔）
const String kE2eeBackupSetupDoneKey = 'e2ee_backup_setup_done';

/// 缓存口令的安全存储键（flutter_secure_storage 域）。
/// 值为 JSON {uid, passphrase}：uid 绑定防换号——下一账号登录后密钥
/// 变化触发自动重传时，若缓存口令属于上一账号则弃用并清除，
/// 避免新账号的备份被旧账号口令加密成「谁也解不开」的废包。
const String kE2eeBackupPassphraseSecureKey = 'e2ee_backup_passphrase';

/// E2EE 云端备份默认化编排（发生率压降路径3·方案A，2026-09-11 拍板）。
///
/// 口令取舍：**独立恢复口令/随机恢复密钥**——口令只在本地参与 PBKDF2，
/// 服务器永远见不到；明确不做「登录密码派生」（登录时服务端见明文密码，
/// 理论上可解备份，零信任卖点倒退）。
///
/// 职责：
/// - 首启判定 [shouldPromptNow]：本地有密钥 + 未完成备份设置 + 服务端无
///   云端备份 → 会话页推强制向导；网络失败不 nag，下次启动重查；
/// - 完成回执 [completeSetup]：口令缓存进安全存储（与密钥本体同级）+
///   设备落完成标记；
/// - 密钥变化自动重传 [uploadWithCachedPassphrase]：generateKeyPair 成功
///   后调用，用缓存口令把新密钥重新打包上传，用户无感。
class E2EEBackupSetupService {
  E2EEBackupSetupService._internal();

  static final E2EEBackupSetupService _instance =
      E2EEBackupSetupService._internal();

  static E2EEBackupSetupService get to => _instance;

  /// 本次会话是否已推过向导（会话页 init 可能因路由重建多次触发）
  bool _promptedThisSession = false;

  /// 测试用：复位会话级防重入
  void resetPromptGuardForTest() => _promptedThisSession = false;

  /// 本地判定：未完成备份设置且本机已有 E2EE 密钥
  Future<bool> needsSetup() async {
    if (StorageService.to.getBool(kE2eeBackupSetupDoneKey) ?? false) {
      return false;
    }
    // 直接查安全存储而非 E2EEKeyService.hasKey()：避免 service 间环依赖
    return StorageSecureService.to.hasE2EEKeys();
  }

  /// 首启完整判定（会话页触发向导的唯一入口）。
  /// - 服务端已有备份（老用户在导出页手动传过）→ 静默补完成标记，不 nag；
  /// - info() 网络失败上抛 → 本次不 nag，下次启动重查。
  Future<bool> shouldPromptNow({E2EEBackupApi? api}) async {
    if (_promptedThisSession) return false;
    if (!await needsSetup()) return false;
    try {
      final info = await (api ?? E2EEBackupApi()).info();
      if (info.hasBackup) {
        await StorageService.to.setBool(kE2eeBackupSetupDoneKey, true);
        return false;
      }
      return true;
    } on Object {
      return false;
    }
  }

  /// 标记本次会话已推过（推页面前调用，防重复推）
  void markPrompted() => _promptedThisSession = true;

  /// 向导/导出页云端上传成功后的统一回执
  Future<void> completeSetup({required String passphrase, String? uid}) async {
    final uidKey = uid ?? UserRepoLocal.to.currentUid;
    await StorageSecureService.to.write(
      key: kE2eeBackupPassphraseSecureKey,
      value: jsonEncode({'uid': uidKey, 'passphrase': passphrase}),
    );
    await StorageService.to.setBool(kE2eeBackupSetupDoneKey, true);
  }

  /// 读取属于当前账号的缓存口令；无缓存 / 属于其他账号（并清除）→ null。
  ///
  /// 保险：currentUid 为空（登出态/尚未落库的瞬态）视为「会话未知」——
  /// 只返回 null，**不触发清除**。缓存的口令是用户唯一的恢复凭据副本，
  /// 不能因 uid 读取时序的意外把它误删（合法换号清除要求 uid 非空且不等）。
  Future<String?> cachedPassphrase() async {
    final raw = await StorageSecureService.to.read(
      key: kE2eeBackupPassphraseSecureKey,
    );
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is! Map<String, dynamic>) return null;
      final uidKey = UserRepoLocal.to.currentUid;
      if (uidKey.isEmpty) return null;
      if ((m['uid'] ?? '').toString() != uidKey) {
        await StorageSecureService.to.delete(
          key: kE2eeBackupPassphraseSecureKey,
        );
        return null;
      }
      final passphrase = (m['passphrase'] ?? '').toString();
      return passphrase.isEmpty ? null : passphrase;
    } on Object {
      return null;
    }
  }

  /// 密钥变化后自动重传：无缓存口令/密钥缺失/换号残留 → 静默跳过；
  /// 上传失败仅记日志（fail-open，绝不阻塞密钥生成主链路），下次密钥
  /// 变化再试。
  Future<E2EEBackupPutResult> uploadWithCachedPassphrase({
    E2EEBackupApi? api,
  }) async {
    try {
      final passphrase = await cachedPassphrase();
      final privateKey = await StorageSecureService.to.getPrivateKey();
      final publicKey = await StorageSecureService.to.getPublicKey();
      if (passphrase == null ||
          passphrase.isEmpty ||
          privateKey == null ||
          publicKey == null) {
        return const E2EEBackupPutResult(ok: false);
      }
      final result = await E2EEServerBackupService.upload(
        password: passphrase,
        privateKey: privateKey,
        publicKey: publicKey,
        deviceId: await StorageSecureService.to.getDeviceId() ?? 'unknown',
        keyId: await StorageSecureService.to.getKeyId() ?? 'unknown',
        api: api,
      );
      iPrint(
        '[E2EE_BACKUP_SETUP] 密钥变化自动重传: ok=${result.ok} '
        'version=${result.backupVersion}',
      );
      return result;
    } on Object catch (e) {
      iPrint('[E2EE_BACKUP_SETUP] 自动重传失败(下次密钥变化再试): ${e.runtimeType}');
      return const E2EEBackupPutResult(ok: false);
    }
  }
}
