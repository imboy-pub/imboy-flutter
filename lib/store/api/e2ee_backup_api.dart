import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';

/// 上传备份的结构化结果。
///
/// [versionConflict] = 服务端返回 409（backup_version 必须 = 当前最新 + 1），
/// 调用方应重新 info() 取最新版本后重试。
@immutable
class E2EEBackupPutResult {
  const E2EEBackupPutResult({
    required this.ok,
    this.versionConflict = false,
    this.backupVersion = 0,
  });

  final bool ok;
  final bool versionConflict;
  final int backupVersion;
}

/// 云端备份探测结果（不含密文与盐值，服务端 info 端点契约）。
@immutable
class E2EEBackupInfo {
  const E2EEBackupInfo({
    required this.hasBackup,
    this.backupVersion = 0,
    this.createdAt,
  });

  final bool hasBackup;
  final int backupVersion;
  final String? createdAt;
}

/// E2EE 服务端加密密钥备份 API（4S 模式，P0-B B3）
///
/// 服务端只存客户端加密后的密文包与 KDF 参数；
/// 加解密全部在客户端（E2EEServerBackupService）。
///
/// [cancelToken]：备份上传是用户在向导页盯着等的前台操作，页面侧一旦
/// 判定超时/用户跳过，必须能真正掐断在途请求——否则默认 60 秒超时叠加
/// 3 次自动重试（见 HttpRetryInterceptor）会让单次上传在后台空转数分钟。
class E2EEBackupApi extends HttpClient {
  /// POST /api/v1/e2ee/backup/put — 上传新版本加密备份
  Future<E2EEBackupPutResult> putBackup({
    required int backupVersion,
    required String kdfSalt,
    required int kdfIterations,
    required String encryptedPayload,
    required String payloadHash,
    String algo = 'pbkdf2-sha256/aes-256-gcm',
    CancelToken? cancelToken,
  }) async {
    final IMBoyHttpResponse resp = await post(
      API.e2eeBackupPut,
      cancelToken: cancelToken,
      data: {
        'backup_version': backupVersion,
        'algo': algo,
        'kdf_salt': kdfSalt,
        'kdf_iterations': kdfIterations,
        'encrypted_payload': encryptedPayload,
        'payload_hash': payloadHash,
      },
    );
    if (resp.ok) {
      int version = backupVersion;
      final payload = resp.payload;
      if (payload is Map && payload['backup_version'] is int) {
        version = payload['backup_version'] as int;
      }
      return E2EEBackupPutResult(ok: true, backupVersion: version);
    }
    // 主动取消（页面超时兜底 / 用户点「稍后再说」）：静默返回，调用方按
    // 取消语义收尾——此处弹「云端备份失败」会把用户主动跳过误导成故障。
    if (cancelToken?.isCancelled ?? false) {
      return const E2EEBackupPutResult(ok: false);
    }
    // 透出服务端中文错误消息；409 版本冲突除外——调用方（E2EEServerBackupService）
    // 会自动刷新版本号重试一次，此处弹错误 toast 会造成"失败闪一下又成功"的假象。
    // 重试耗尽的 409 由页面层按 versionConflict 兜底提示。
    if (resp.code != 409 && resp.msg.isNotEmpty) {
      AppLoading.showBackendError(resp.msg);
    }
    return E2EEBackupPutResult(ok: false, versionConflict: resp.code == 409);
  }

  /// GET /api/v1/e2ee/backup/get — 拉取最新版本备份（含密文与 KDF 参数）
  ///
  /// 返回 {backup_version, algo, kdf_salt, kdf_iterations,
  /// encrypted_payload, payload_hash, created_at} 或 null（无备份/失败）。
  Future<Map<String, dynamic>?> getBackup({CancelToken? cancelToken}) async {
    final IMBoyHttpResponse resp = await get(
      API.e2eeBackupGet,
      cancelToken: cancelToken,
    );
    // 失败必须上抛：恢复链把 null 当「无云端备份」展示——网络故障会被
    // 误读成备份丢失。null 只许表达「确认无备份」（成功响应但无 payload）。
    resp.throwIfFailed();
    final p = resp.payload;
    return p is Map ? p.cast<String, dynamic>() : null;
  }

  /// GET /api/v1/e2ee/backup/info — 备份存在性探测（恢复横幅用）
  Future<E2EEBackupInfo> info({CancelToken? cancelToken}) async {
    final IMBoyHttpResponse resp = await get(
      API.e2eeBackupInfo,
      cancelToken: cancelToken,
    );
    // 失败必须上抛：上传链用它算 nextVersion（假「无备份」会退化成
    // version=1 连撞 409），恢复横幅会把网络故障误报成「无备份可恢复」。
    resp.throwIfFailed();
    final p = resp.payload;
    if (p is! Map) return const E2EEBackupInfo(hasBackup: false);
    final version = p['backup_version'];
    return E2EEBackupInfo(
      hasBackup: p['has_backup'] == true,
      backupVersion: version is int ? version : 0,
      createdAt: p['created_at']?.toString(),
    );
  }

  /// POST /api/v1/e2ee/backup/delete — 删除全部云端备份版本
  Future<bool> deleteBackup() async {
    final IMBoyHttpResponse resp = await post(API.e2eeBackupDelete);
    // 失败必须上抛：false 会被设置页吞成「已删除」或原因不明的失败提示。
    resp.throwIfFailed();
    return true;
  }
}
