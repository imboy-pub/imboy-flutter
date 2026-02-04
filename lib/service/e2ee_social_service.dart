import 'dart:convert';
import 'dart:typed_data';
import 'package:imboy/service/shamir_secret_sharing.dart';
import 'package:imboy/store/api/e2ee_plus_api.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/service/e2ee_shard_message_handler.dart';

/// E2EE 社交恢复服务
/// 使用 Shamir Secret Sharing 将密钥分割成多个分片
/// 零信任架构：分片存储在代理设备，服务端不存储
class E2EESocialService {
  static final E2EEPlusApi _api = E2EEPlusApi();

  /// 创建恢复分片
  ///
  /// [totalShards] 总分片数（3-5）
  /// [threshold] 恢复阈值（2-3）
  /// [proxies] 代理列表 [{proxyUid, encryptedPublicKey}]
  /// Returns: { "key_version": "xxx", "shards": [...] }
  static Future<Map<String, dynamic>> createShards({
    required int totalShards,
    required int threshold,
    required List<Map<String, dynamic>> proxies,
  }) async {
    try {
      // 验证参数
      if (totalShards < threshold) {
        throw Exception('总分片数必须大于阈值');
      }
      if (threshold < 2) {
        throw Exception('阈值至少为 2');
      }
      if (proxies.length < totalShards) {
        throw Exception('代理数量不足');
      }

      final result = await _api.createKeyShards(
        totalShards: totalShards,
        threshold: threshold,
        proxies: proxies,
      );

      // 零信任架构：创建分片后，保存元数据到本地安全存储
      // 用于后续恢复时知道有哪些分片可用
      final keyVersion = result['key_version']?.toString() ?? '';
      final shards = result['shards'] as List? ?? [];

      // 保存分片元数据
      await _saveShardMetadataLocally(keyVersion, shards);

      return result;
    } catch (e) {
      throw Exception('创建恢复分片失败: $e');
    }
  }

  /// 保存分片元数据到本地安全存储
  static Future<void> _saveShardMetadataLocally(
    String keyVersion,
    List<dynamic> shards,
  ) async {
    try {
      // 构造元数据列表（只保存必要信息）
      final metadataList = <Map<String, dynamic>>[];

      for (final shard in shards) {
        if (shard is Map<String, dynamic>) {
          metadataList.add({
            'shard_id': shard['shard_id']?.toString() ?? '',
            'shard_index': shard['shard_index'] ?? 0,
            'proxy_uid': shard['proxy_uid']?.toString() ?? '',
            'total_shards': shard['total_shards'] ?? 3,
            'threshold': shard['threshold'] ?? 2,
            'key_version': keyVersion,
            'status': 'pending', // pending, active, used
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // 先清理旧版本的元数据（如果有）
      await StorageSecureService.to.cleanE2EEShardMetadataByKeyVersion(
        keyVersion,
      );

      // 保存新元数据
      await StorageSecureService.to.saveE2EEShardMetadataList(metadataList);

      print('✅ [E2EE] 已保存 ${metadataList.length} 个分片元数据到本地存储');
    } catch (e) {
      print('⚠️ [E2EE] 保存分片元数据失败: $e');
    }
  }

  /// 获取本地存储的分片元数据
  ///
  /// [keyVersion] 密钥版本号，默认获取最新版本
  static Future<List<Map<String, dynamic>>> getLocalShardMetadata([
    String keyVersion = 'latest',
  ]) async {
    try {
      if (keyVersion == 'latest') {
        return await StorageSecureService.to.getLatestE2EEShardMetadata();
      } else {
        return await StorageSecureService.to.getE2EEShardMetadataByKeyVersion(
          keyVersion,
        );
      }
    } catch (e) {
      print('⚠️ [E2EE] 获取本地分片元数据失败: $e');
      return [];
    }
  }

  /// 更新分片状态
  static Future<void> updateShardStatus(String shardId, String status) async {
    try {
      await StorageSecureService.to.updateE2EEShardMetadataStatus(
        shardId,
        status,
      );
      print('✅ [E2EE] 已更新分片状态: $shardId -> $status');
    } catch (e) {
      print('⚠️ [EEE] 更新分片状态失败: $e');
    }
  }

  /// 清理本地分片数据
  static Future<void> clearLocalShardData() async {
    try {
      await StorageSecureService.to.deleteE2EEShardMetadataList();
      await StorageSecureService.to.deleteAllE2EEShards();
      print('✅ [E2EE] 已清理本地分片数据');
    } catch (e) {
      print('⚠️ [E2EE] 清理本地分片数据失败: $e');
    }
  }

  /// 获取用户的恢复分片
  ///
  /// [keyVersion] 密钥版本号（默认 "latest"）
  static Future<List<Map<String, dynamic>>> getShards([
    String keyVersion = 'latest',
  ]) async {
    try {
      return await _api.getUserShards(keyVersion: keyVersion);
    } catch (e) {
      throw Exception('获取分片失败: $e');
    }
  }

  /// 恢复密钥
  ///
  /// 零信任架构：客户端从代理获取解密后的分片，直接传给服务端重组
  ///
  /// [decryptedShards] 从代理获取的已解密分片列表
  static Future<void> recoverKey({
    required List<String> decryptedShards,
  }) async {
    try {
      if (decryptedShards.length < 2) {
        throw Exception('至少需要 2 个分片才能恢复密钥');
      }

      await _api.recoverKey(decryptedShards: decryptedShards);
    } catch (e) {
      throw Exception('恢复密钥失败: $e');
    }
  }

  /// 获取代理的分片列表
  static Future<List<Map<String, dynamic>>> getProxyShards() async {
    try {
      return await _api.getProxyShards();
    } catch (e) {
      throw Exception('获取代理分片失败: $e');
    }
  }

  /// 解密分片（代理调用）
  ///
  /// [shardId] 分片 ID
  static Future<Map<String, dynamic>> decryptShard({
    required String shardId,
  }) async {
    try {
      return await _api.decryptShard(shardId: shardId);
    } catch (e) {
      throw Exception('解密分片失败: $e');
    }
  }

  /// 检查是否可以恢复
  ///
  /// [keyVersion] 密钥版本号
  static Future<bool> canRecover([String keyVersion = 'latest']) async {
    try {
      final shards = await getShards(keyVersion);
      final threshold = shards.isNotEmpty ? shards[0]['threshold'] as int : 2;
      return shards.length >= threshold;
    } catch (e) {
      return false;
    }
  }

  /// 列出可信联系人
  static Future<List<Map<String, dynamic>>> getTrustedContacts() async {
    try {
      return await _api.getTrustedContacts();
    } catch (e) {
      throw Exception('获取联系人列表失败: $e');
    }
  }

  /// 添加可信联系人
  static Future<void> addTrustedContact({
    required String contactUid,
    String? nickname,
  }) async {
    try {
      await _api.addTrustedContact(contactUid: contactUid, nickname: nickname);
    } catch (e) {
      throw Exception('添加可信联系人失败: $e');
    }
  }

  /// 移除可信联系人
  static Future<void> removeTrustedContact({required String contactUid}) async {
    try {
      await _api.removeTrustedContact(contactUid: contactUid);
    } catch (e) {
      throw Exception('移除可信联系人失败: $e');
    }
  }

  /// 生成分片数据（用于 Shamir Secret Sharing）
  ///
  /// 使用真正的 Shamir Secret Sharing 算法
  static List<String> splitSecret(String secret, int n, int k) {
    try {
      final bytes = utf8.encode(secret);
      final shares = ShamirSecretSharing.splitSecret(
        Uint8List.fromList(bytes),
        n,
        k,
      );

      // 将分片编码为 JSON 字符串
      return shares.map((share) {
        return base64.encode(utf8.encode(jsonEncode(share)));
      }).toList();
    } catch (e) {
      throw Exception('生成分片失败: $e');
    }
  }

  /// 重组密钥
  ///
  /// [shards] 分片列表（Base64 编码的 JSON）
  static String combineShards(List<String> shards) {
    try {
      // 解码分片
      final decodedShards = shards.map((shard) {
        final bytes = base64.decode(shard);
        final jsonStr = utf8.decode(bytes);
        return jsonDecode(jsonStr) as Map<String, dynamic>;
      }).toList();

      // 重组秘密
      final secretBytes = ShamirSecretSharing.combineShares(decodedShards);
      return utf8.decode(secretBytes);
    } catch (e) {
      throw Exception('重组密钥失败: $e');
    }
  }

  /// 验证代理公钥
  ///
  /// 验证代理的公钥是否有效
  static Future<bool> validateProxyPublicKey(
    String proxyUid,
    String publicKey,
  ) async {
    try {
      if (proxyUid.isEmpty || publicKey.isEmpty) {
        return false;
      }

      // 验证公钥格式是否为有效的 PEM 格式
      if (!publicKey.contains('BEGIN PUBLIC KEY') &&
          !publicKey.contains('BEGIN RSA PUBLIC KEY')) {
        return false;
      }

      // 尝试解析公钥以验证其有效性
      // TODO: 添加更完整的公钥验证逻辑
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 推荐恢复代理
  ///
  /// 基于好友关系和活跃度推荐代理
  /// 返回推荐的好友列表，按推荐度排序
  static Future<List<Map<String, dynamic>>> recommendProxies({
    int count = 3,
    String? currentUserId,
  }) async {
    try {
      // TODO: 实现基于以下因素的推荐算法
      // 1. 好友关系时长（认识时间越长越推荐）
      // 2. 最近互动频率（最近消息多的更推荐）
      // 3. 好友备注名称（有备注的说明关系密切）
      // 4. 共同群组数量（共同群多说明关系密切）
      // 5. 在线状态（在线的更推荐）

      // 目前返回空列表，待实现
      return [];
    } catch (e) {
      return [];
    }
  }

  // ================================================================
  // 零信任架构方法
  // Zero Trust Architecture Methods
  // ================================================================

  /// 生成消息 ID
  ///
  /// 使用时间戳和随机数生成唯一消息 ID
  static String generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'msg_$timestamp$random';
  }

  /// 发送分片给代理
  ///
  /// 零信任架构：创建分片后，通过 WebSocket 将加密后的分片发送给代理
  ///
  /// [shards] 服务端返回的加密分片列表
  /// Returns: 发送成功的分片数量
  static Future<int> sendShardsToProxies(
    List<Map<String, dynamic>> shards,
  ) async {
    int sentCount = 0;
    final ws = WebSocketService.to;

    for (final shard in shards) {
      try {
        final proxyUid = shard['proxy_uid']?.toString() ?? '';
        if (proxyUid.isEmpty) continue;

        // 构造 WebSocket S2C 消息
        final message = {
          'type': 'S2C',
          'to': proxyUid,
          'payload': {
            'msg_type': 'e2ee_social_shard',
            'action': 'store_shard',
            'shard_id': shard['shard_id']?.toString() ?? '',
            'shard_index': shard['shard_index'] ?? 0,
            'encrypted_shard': shard['encrypted_shard']?.toString() ?? '',
            'uid': shard['uid'] ?? 0,
            'key_version': shard['key_version']?.toString() ?? '',
            'total_shards': shard['total_shards'] ?? 3,
            'threshold': shard['threshold'] ?? 2,
          },
        };

        final messageId = generateMessageId();
        final success = await ws.sendMessage(jsonEncode(message), messageId);

        if (success) {
          sentCount++;
        }
      } catch (e) {
        print('发送分片失败: $e');
      }
    }

    return sentCount;
  }

  /// 存储接收到的分片（代理端）
  ///
  /// 零信任架构：代理将接收到的分片存储在本地安全存储中
  ///
  /// [shardData] 分片数据
  static Future<void> storeReceivedShard(Map<String, dynamic> shardData) async {
    try {
      final shardId = shardData['shard_id']?.toString() ?? '';
      if (shardId.isEmpty) {
        throw Exception('分片 ID 为空');
      }

      // 构造存储数据
      final storedShard = {
        'shard_id': shardId,
        'uid': shardData['uid'] ?? 0,
        'key_version': shardData['key_version']?.toString() ?? '',
        'shard_index': shardData['shard_index'] ?? 0,
        'encrypted_shard': shardData['encrypted_shard']?.toString() ?? '',
        'total_shards': shardData['total_shards'] ?? 3,
        'threshold': shardData['threshold'] ?? 2,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'active',
      };

      // 存储到安全存储
      await StorageSecureService.to.write(
        key: 'e2ee_shard_$shardId',
        value: jsonEncode(storedShard),
      );
    } catch (e) {
      throw Exception('存储分片失败: $e');
    }
  }

  /// 获取本地存储的分片（代理端）
  ///
  /// 零信任架构：代理从本地安全存储读取分片
  ///
  /// Returns: 本地存储的分片列表
  static Future<List<Map<String, dynamic>>> getStoredShards() async {
    try {
      // TODO: 实现遍历安全存储中所有 e2ee_shard_ 开头的键
      // 由于 flutter_secure_storage 没有直接列出所有键的方法
      // 需要维护一个分片 ID 列表
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 解密并返回分片（代理端）
  ///
  /// 零信任架构：代理使用自己的私钥解密分片，返回给密钥所有者
  ///
  /// [shardId] 分片 ID
  /// [requesterUid] 请求者用户 ID
  /// Returns: 解密后的分片数据
  static Future<String?> decryptShardForRequester({
    required String shardId,
    required int requesterUid,
  }) async {
    try {
      // 从安全存储读取分片
      final shardJson = await StorageSecureService.to.read(
        key: 'e2ee_shard_$shardId',
      );
      if (shardJson == null) {
        throw Exception('分片不存在');
      }

      final shard = jsonDecode(shardJson) as Map<String, dynamic>;

      // 验证请求者是否是分片所有者
      if (shard['uid'] != requesterUid) {
        throw Exception('无权访问此分片');
      }

      final encryptedShard = shard['encrypted_shard']?.toString() ?? '';

      // TODO: 使用代理的私钥解密分片
      // 这里需要调用加密库进行 RSA-OAEP 解密
      // 目前返回加密的分片，待实现解密逻辑

      return encryptedShard;
    } catch (e) {
      print('解密分片失败: $e');
      return null;
    }
  }

  /// 请求代理解密分片
  ///
  /// 零信任架构：恢复密钥时，向代理请求解密分片
  /// 使用 E2EEShardMessageHandler 进行请求，支持超时和响应等待
  ///
  /// [proxyUid] 代理用户 ID（HashID 编码）
  /// [shardId] 分片 ID
  /// [timeout] 超时时间（秒），默认 30 秒
  /// Returns: 解密后的分片，超时或失败返回 null
  static Future<String?> requestDecryptedShard({
    required String proxyUid,
    required String shardId,
    int timeout = 30,
  }) async {
    return E2EEShardMessageHandler.to.requestDecryptedShard(
      proxyUid: proxyUid,
      shardId: shardId,
      timeout: timeout,
    );
  }

  /// 完整的恢复密钥流程
  ///
  /// 零信任架构：自动联系代理请求解密分片，收集足够的分片后恢复密钥
  ///
  /// [shards] 分片信息列表（包含 proxy_uid 和 shard_id）
  /// [threshold] 恢复阈值
  /// [onProgress] 进度回调，返回当前收集的分片数量
  /// Returns: 恢复成功返回 true，失败返回 false
  static Future<bool> recoverKeyWithProxies({
    required List<Map<String, dynamic>> shards,
    required int threshold,
    void Function(int collected, int total)? onProgress,
  }) async {
    try {
      if (shards.isEmpty) {
        throw Exception('没有可用的分片');
      }

      if (threshold < 2) {
        throw Exception('阈值至少为 2');
      }

      print('🔐 [E2EE] 开始恢复密钥流程: 分片数=${shards.length}, 阈值=$threshold');

      final decryptedShards = <String>[];
      final processedShards = <String>[];

      for (final shard in shards) {
        if (decryptedShards.length >= threshold) {
          print('✅ [E2EE] 已收集足够的分片: ${decryptedShards.length}/$threshold');
          break;
        }

        final shardId = shard['shard_id']?.toString() ?? '';
        final proxyUid = shard['proxy_uid']?.toString() ?? '';

        if (shardId.isEmpty || proxyUid.isEmpty) {
          print('⚠️ [E2EE] 跳过无效分片: shardId=$shardId, proxyUid=$proxyUid');
          continue;
        }

        // 避免重复请求同一个分片
        if (processedShards.contains(shardId)) {
          print('⚠️ [E2EE] 跳过已处理的分片: $shardId');
          continue;
        }

        processedShards.add(shardId);

        print('🔓 [E2EE] 请求解密分片: shardId=$shardId, proxyUid=$proxyUid');

        // 通知进度
        onProgress?.call(decryptedShards.length, shards.length);

        // 请求代理解密分片
        final decryptedShard = await requestDecryptedShard(
          proxyUid: proxyUid,
          shardId: shardId,
          timeout: 30,
        );

        if (decryptedShard != null && decryptedShard.isNotEmpty) {
          decryptedShards.add(decryptedShard);
          print('✅ [E2EE] 成功获取解密分片: shardId=$shardId');
          onProgress?.call(decryptedShards.length, shards.length);
        } else {
          print('❌ [E2EE] 获取解密分片失败: shardId=$shardId');
        }
      }

      // 检查是否收集到足够的分片
      if (decryptedShards.length < threshold) {
        throw Exception('收集到的分片不足：${decryptedShards.length}/$threshold');
      }

      print('🔐 [E2EE] 开始重组密钥: 分片数=${decryptedShards.length}');

      // 调用服务端 API 重组密钥
      await recoverKey(decryptedShards: decryptedShards);

      print('✅ [E2EE] 密钥恢复成功');
      return true;
    } catch (e) {
      print('❌ [E2EE] 恢复密钥失败: $e');
      return false;
    }
  }

  /// 删除本地存储的分片（代理端）
  ///
  /// [shardId] 分片 ID
  static Future<void> deleteStoredShard(String shardId) async {
    try {
      await StorageSecureService.to.delete(key: 'e2ee_shard_$shardId');
    } catch (e) {
      throw Exception('删除分片失败: $e');
    }
  }
}
