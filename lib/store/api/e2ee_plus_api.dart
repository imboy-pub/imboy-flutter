import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

/// E2EE+ API 客户端
///
/// 完整的 E2EE+ 功能 API 集成
/// - 设备间传输 API
/// - 社交恢复 API
/// - 本地备份 API
///
/// @author Imboy Team
/// @since 2026-02-01
class E2EEPlusApi extends HttpClient {
  // ================================================================
  // 设备间传输 API
  // ================================================================

  /// 创建传输会话
  ///
  /// POST /api/v1/e2ee/transfer/create
  ///
  /// 从旧设备创建传输会话，将密钥传输到新设备
  ///
  /// 请求参数:
  /// - to_uid: 目标用户 ID
  /// - from_device_id: 发送方设备 ID（零信任契约必填）
  /// - encrypted_key_bundle: 使用目标用户公钥加密的密钥包
  ///
  /// 返回:
  /// - session_id: 会话 ID
  /// - expires_at: 过期时间（UTC）
  Future<Map<String, dynamic>> createTransferSession({
    required String toUid,
    required String fromDeviceId,
    required String encryptedKeyBundle,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.e2eeTransferCreate,
      data: {
        'to_uid': toUid,
        'from_device_id': fromDeviceId,
        'encrypted_key_bundle': encryptedKeyBundle,
      },
    );
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
    return resp.payload as Map<String, dynamic>;
  }

  /// 接受传输
  ///
  /// POST /api/v1/e2ee/transfer/accept
  ///
  /// 新设备接受传输会话
  ///
  /// 请求参数:
  /// - session_id: 会话 ID
  /// - device_id: 新设备 ID
  ///
  /// 返回:
  /// - session_id: 会话 ID
  /// - from_uid: 发送方用户 ID
  /// - from_device_id: 发送方设备 ID
  /// - encrypted_key_bundle: 加密的密钥包
  /// - status: 会话状态
  /// - expires_at: 过期时间
  Future<Map<String, dynamic>> acceptTransfer({
    required String sessionId,
    required String deviceId,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.e2eeTransferAccept,
      data: {'session_id': sessionId, 'device_id': deviceId},
    );
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
    return resp.payload as Map<String, dynamic>;
  }

  /// 确认传输完成
  ///
  /// POST /api/v1/e2ee/transfer/confirm
  ///
  /// 确认密钥传输完成
  ///
  /// 请求参数:
  /// - session_id: 会话 ID
  ///
  /// 返回:
  /// - message: 成功消息
  Future<void> confirmTransfer({required String sessionId}) async {
    IMBoyHttpResponse resp = await post(
      API.e2eeTransferConfirm,
      data: {'session_id': sessionId},
    );
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
  }

  /// 查询传输会话信息
  ///
  /// GET /api/v1/e2ee/transfer/info
  ///
  /// 请求参数:
  /// - session_id: 会话 ID
  ///
  /// 返回:
  /// - session_id: 会话 ID
  /// - from_uid: 发送方用户 ID
  /// - from_device_id: 发送方设备 ID
  /// - status: 会话状态
  /// - expires_at: 过期时间
  Future<Map<String, dynamic>> getTransferInfo({
    required String sessionId,
  }) async {
    IMBoyHttpResponse resp = await get(
      API.e2eeTransferInfo,
      queryParameters: {'session_id': sessionId},
    );
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
    return resp.payload as Map<String, dynamic>;
  }

  /// 获取待处理传输列表
  ///
  /// GET /api/v1/e2ee/transfer/pending
  ///
  /// 获取当前用户的待处理传输列表
  ///
  /// 返回:
  /// - transfers: 传输会话列表
  Future<List<Map<String, dynamic>>> getPendingTransfers() async {
    IMBoyHttpResponse resp = await get(API.e2eeTransferPending);
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
    final payload = resp.payload;
    final transfers = payload['transfers'];
    if (transfers is List) {
      return transfers.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  // ================================================================
  // 社交恢复 API
  // ================================================================

  /// 列出可信联系人
  ///
  /// GET /api/v1/e2ee/social/contacts
  ///
  /// 获取用户设置的可信联系人列表
  ///
  /// 返回:
  /// - contacts: 联系人列表
  Future<List<Map<String, dynamic>>> getTrustedContacts() async {
    IMBoyHttpResponse resp = await get(API.e2eeSocialContacts);
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
    final payload = resp.payload;
    final contacts = payload['contacts'];
    if (contacts is List) {
      return contacts.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  /// 添加可信联系人
  ///
  /// POST /api/v1/e2ee/social/contacts/add
  ///
  /// 请求参数:
  /// - contact_uid: 联系人用户 ID  /// - nickname: 昵称（可选）
  Future<void> addTrustedContact({
    required String contactUid,
    String? nickname,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.e2eeSocialContactsAdd,
      data: {
        'contact_uid': contactUid,
        // ignore: use_null_aware_elements
        if (nickname != null) 'nickname': nickname,
      },
    );
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
  }

  /// 移除可信联系人
  ///
  /// POST /api/v1/e2ee/social/contacts/remove
  ///
  /// 请求参数:
  /// - contact_uid: 联系人用户 ID
  Future<void> removeTrustedContact({required String contactUid}) async {
    IMBoyHttpResponse resp = await post(
      API.e2eeSocialContactsRemove,
      data: {'contact_uid': contactUid},
    );
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
  }

  /// 创建密钥分片
  ///
  /// POST /api/v1/e2ee/social/create_shards
  ///
  /// 使用 Shamir Secret Sharing 创建密钥分片
  ///
  /// 请求参数:
  /// - total_shards: 总分片数（2-5）
  /// - threshold: 恢复阈值（必须 ≤ total_shards）
  /// - proxies: 代理列表 [{proxy_uid, encrypted_public_key}]
  ///
  /// 返回:
  /// - key_version: 密钥版本
  /// - total_shards: 总分片数
  /// - threshold: 恢复阈值
  /// - shards: 分片列表
  Future<Map<String, dynamic>> createKeyShards({
    required int totalShards,
    required int threshold,
    required List<Map<String, dynamic>> proxies,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.e2eeSocialCreateShards,
      data: {
        'total_shards': totalShards,
        'threshold': threshold,
        'proxies': proxies,
      },
    );
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
    return resp.payload as Map<String, dynamic>;
  }

  /// 获取用户分片
  ///
  /// GET /api/v1/e2ee/social/shards
  ///
  /// 请求参数:
  /// - key_version: 密钥版本（默认 "latest"）
  ///
  /// 返回:
  /// - shards: 分片列表
  Future<List<Map<String, dynamic>>> getUserShards({
    String keyVersion = 'latest',
  }) async {
    IMBoyHttpResponse resp = await get(
      API.e2eeSocialShards,
      queryParameters: {'key_version': keyVersion},
    );
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
    final payload = resp.payload;
    final shards = payload['shards'];
    if (shards is List) {
      return shards.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  /// 恢复密钥
  ///
  /// POST /api/v1/e2ee/social/recover
  ///
  /// 零信任架构：客户端从代理获取解密后的分片，直接传给服务端重组
  ///
  /// 请求参数:
  /// - decrypted_shards: 已解密的分片列表（从代理获取）
  Future<void> recoverKey({required List<String> decryptedShards}) async {
    IMBoyHttpResponse resp = await post(
      API.e2eeSocialRecover,
      data: {'decrypted_shards': decryptedShards},
    );
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
  }

  /// 获取代理分片
  ///
  /// GET /api/v1/e2ee/social/proxy_shards
  ///
  /// 获取当前用户作为代理存储的分片
  ///
  /// 返回:
  /// - shards: 代理分片列表
  Future<List<Map<String, dynamic>>> getProxyShards() async {
    IMBoyHttpResponse resp = await get(API.e2eeSocialProxyShards);
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
    final payload = resp.payload;
    final shards = payload['shards'];
    if (shards is List) {
      return shards.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  /// 获取待解密的加密分片
  ///
  /// POST /api/v1/e2ee/social/decrypt_shard
  ///
  /// 零信任契约：服务端不再解密，仅按 shard_id 返回加密分片；
  /// 由代理客户端用本地私钥 RSA-OAEP 解密后回传明文分片。
  ///
  /// 请求参数:
  /// - shard_id: 分片 ID
  ///
  /// 返回:
  /// - encrypted_shard: 加密分片密文（需代理客户端本地解密）
  Future<Map<String, dynamic>> decryptShard({required String shardId}) async {
    IMBoyHttpResponse resp = await post(
      API.e2eeSocialDecryptShard,
      data: {'shard_id': shardId},
    );
    if (!resp.ok) {
      throw Exception(resp.msg);
    }
    return resp.payload as Map<String, dynamic>;
  }

  // ================================================================
  // 本地备份 API
  // ================================================================

  /// 获取当前用户的备份历史列表
  ///
  /// GET /api/v1/e2ee/backup/list
  ///
  /// 返回:
  /// - list: 备份记录列表，每条包含 id, device_id, backup_version, key_checksum, file_size, user_notes, created_at
  Future<List<Map<String, dynamic>>> listBackups() async {
    IMBoyHttpResponse resp = await get(API.e2eeBackupList);
    if (!resp.ok) return [];
    final payload = resp.payload;
    final list = payload['list'];
    if (list is List) {
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return [];
  }

  /// 删除备份记录
  ///
  /// POST /api/v1/e2ee/backup/delete
  ///
  /// 请求参数:
  /// - backup_id: 备份 ID
  ///
  /// 返回 true 表示删除成功
  Future<bool> deleteBackup(int backupId) async {
    IMBoyHttpResponse resp = await post(
      API.e2eeBackupDelete,
      data: {'backup_id': backupId},
    );
    return resp.ok;
  }
}
