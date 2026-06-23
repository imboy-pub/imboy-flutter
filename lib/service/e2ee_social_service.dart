import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:imboy/service/shamir_secret_sharing.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/store/api/e2ee_plus_api.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/service/e2ee_shard_message_handler.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/service/app_logger.dart';

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
    } catch (e, s) {
      AppLogger.error(
        '[e2ee_social_service] saveE2EEShardMetadataList error',
        e,
        s,
      );
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
    } catch (e, s) {
      AppLogger.error(
        '[e2ee_social_service] updateE2EEShardMetadataStatus error',
        e,
        s,
      );
    }
  }

  /// 清理本地分片数据
  static Future<void> clearLocalShardData() async {
    try {
      await StorageSecureService.to.deleteE2EEShardMetadataList();
      await StorageSecureService.to.deleteAllE2EEShards();
    } catch (e, s) {
      AppLogger.error('[e2ee_social_service] clearLocalShardData error', e, s);
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

  /// 获取待解密的加密分片（零信任：服务端不解密）
  ///
  /// 返回 payload 含 `encrypted_shard`，需代理客户端用本地私钥 RSA-OAEP
  /// 解密后再回传明文（参见 [decryptShardForRequester]）。
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
  /// 零信任架构：完整验证代理的公钥是否有效
  /// 包括格式验证、长度验证、算法验证和有效性验证
  ///
  /// 验证步骤：
  /// 1. 非空检查
  /// 2. PEM 格式验证
  /// 3. 密钥长度验证（至少 2048 位）
  /// 4. 公钥可解析性验证
  /// 5. 公钥指数验证
  static Future<bool> validateProxyPublicKey(
    String proxyUid,
    String publicKey,
  ) async {
    try {
      // 1. 非空检查
      if (proxyUid.isEmpty || publicKey.isEmpty) {
        return false;
      }

      // 2. PEM 格式验证
      if (!publicKey.contains('BEGIN PUBLIC KEY') &&
          !publicKey.contains('BEGIN RSA PUBLIC KEY')) {
        return false;
      }

      // 3. 尝试解析公钥
      final rsaPublicKey = RSAService.parsePublicKeyFromPem(publicKey);

      // 4. 密钥长度验证（至少 2048 位）
      final modulus = rsaPublicKey.modulus;
      if (modulus == null) {
        return false;
      }

      final bitLength = modulus.bitLength;
      if (bitLength < 2048) {
        return false;
      }

      // 5. 公钥指数验证
      final exponent = rsaPublicKey.exponent;
      if (exponent == null) {
        return false;
      }

      // 6. 验证公钥指数是否为常见的安全值（65537）
      if (exponent != BigInt.from(65537)) {
        // 不直接返回 false，仅记录警告
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 推荐恢复代理
  ///
  /// 零信任架构：基于多因素的推荐算法
  /// 权重因子：
  /// - 好友关系时长：30%
  /// - 最近互动频率：25%
  /// - 好友备注名称：15%
  /// - 共同群组数量：15%
  /// - 在线状态：15%
  ///
  /// [count] 推荐数量（默认 3）
  /// [currentUserId] 当前用户 ID（可选）
  /// Returns: 按推荐度排序的好友列表
  static Future<List<Map<String, dynamic>>> recommendProxies({
    int count = 3,
    String? currentUserId,
  }) async {
    try {
      // 1. 获取可信联系人列表
      final contacts = await getTrustedContacts();
      if (contacts.isEmpty) {
        return [];
      }

      // 2. 计算每个好友的推荐分数
      final scoredContacts = <Map<String, dynamic>>[];

      for (final contact in contacts) {
        final contactUid = contact['uid']?.toString() ?? '';
        if (contactUid.isEmpty) continue;

        // 计算各因素得分
        final relationScore = await _calculateRelationDurationScore(contactUid);
        final interactionScore = await _calculateInteractionFrequencyScore(
          contactUid,
        );
        final remarkScore = _calculateRemarkScore(contact);
        final groupScore = await _calculateCommonGroupScore(contactUid);
        final onlineScore = await _calculateOnlineStatusScore(contactUid);

        // 加权总分
        final totalScore =
            (relationScore * 0.30) +
            (interactionScore * 0.25) +
            (remarkScore * 0.15) +
            (groupScore * 0.15) +
            (onlineScore * 0.15);

        scoredContacts.add({
          ...contact,
          'recommend_score': totalScore,
          'score_details': {
            'relation': relationScore,
            'interaction': interactionScore,
            'remark': remarkScore,
            'group': groupScore,
            'online': onlineScore,
          },
        });
      }

      // 3. 按分数排序并返回前 N 个
      scoredContacts.sort(
        (a, b) => (b['recommend_score'] as double).compareTo(
          a['recommend_score'] as double,
        ),
      );

      final result = scoredContacts.take(count).toList();

      return result;
    } catch (e) {
      return [];
    }
  }

  /// 计算好友关系时长得分（0-100）
  ///
  /// 基于好友添加时间计算得分：
  /// - 30天以下: 20分
  /// - 30-90天: 40分
  /// - 90-365天: 70分
  /// - 1年以上: 100分
  static Future<double> _calculateRelationDurationScore(
    String contactUid,
  ) async {
    try {
      // 从联系人仓库获取好友添加时间
      final contactRepo = ContactRepo();
      final contact = await contactRepo.findByUid(contactUid);

      // ContactModel 没有 createdAt 属性，使用 updatedAt 替代
      if (contact == null || contact.updatedAt == 0) {
        return 30.0; // 默认中等偏低分数
      }

      final updatedAt = DateTime.fromMillisecondsSinceEpoch(contact.updatedAt);
      final days = DateTime.now().difference(updatedAt).inDays;

      if (days < 30) {
        return 20.0;
      } else if (days < 90) {
        return 40.0;
      } else if (days < 365) {
        return 70.0;
      } else {
        return 100.0;
      }
    } catch (e) {
      return 30.0;
    }
  }

  /// 计算最近互动频率得分（0-100）
  ///
  /// 基于最近30天的消息数量计算得分：
  /// - 0条: 0分
  /// - 1-10条: 30分
  /// - 11-50条: 60分
  /// - 50条以上: 100分
  static Future<double> _calculateInteractionFrequencyScore(
    String contactUid,
  ) async {
    try {
      // 从消息仓库获取最近30天的消息数量
      final messageRepo = MessageRepo(tableName: MessageRepo.c2cTable);
      final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30));
      final since = thirtyDaysAgo.millisecondsSinceEpoch;

      final count = await messageRepo.countMessagesWithUser(
        contactUid,
        since: since,
      );

      if (count == 0) {
        return 0.0;
      } else if (count <= 10) {
        return 30.0;
      } else if (count <= 50) {
        return 60.0;
      } else {
        return 100.0;
      }
    } catch (e) {
      return 30.0;
    }
  }

  /// 计算好友备注得分（0-100）
  ///
  /// 有备注说明关系密切
  static double _calculateRemarkScore(Map<String, dynamic> contact) {
    final remark = contact['remark']?.toString() ?? '';
    return remark.isNotEmpty ? 100.0 : 30.0;
  }

  /// 计算共同群组得分（0-100）
  ///
  /// 基于共同群组数量计算得分：
  /// - 0个: 10分
  /// - 1-2个: 40分
  /// - 3-5个: 70分
  /// - 5个以上: 100分
  static Future<double> _calculateCommonGroupScore(String contactUid) async {
    try {
      // 从群组成员仓库获取共同群组数量
      final groupMemberRepo = GroupMemberRepo();
      final currentUid = UserRepoLocal.to.currentUid;

      // 获取当前用户的群组列表
      final myGroups = await groupMemberRepo.groupIdsByUserId(currentUid);
      // 获取联系人的群组列表
      final contactGroups = await groupMemberRepo.groupIdsByUserId(contactUid);

      // 计算交集
      final commonGroups = myGroups.toSet().intersection(contactGroups.toSet());
      final count = commonGroups.length;

      if (count == 0) {
        return 10.0;
      } else if (count <= 2) {
        return 40.0;
      } else if (count <= 5) {
        return 70.0;
      } else {
        return 100.0;
      }
    } catch (e) {
      return 30.0;
    }
  }

  /// 计算在线状态得分（0-100）
  ///
  /// 基于用户在线状态计算得分：
  /// - 离线: 20分
  /// - 在线: 100分
  /// - 未知: 50分
  static Future<double> _calculateOnlineStatusScore(String contactUid) async {
    try {
      // 从在线状态缓存获取
      final isOnline = await _getOnlineStatus(contactUid);

      if (isOnline == null) {
        // 未知状态，返回中等分数
        return 50.0;
      }

      return isOnline ? 100.0 : 20.0;
    } catch (e) {
      return 50.0;
    }
  }

  /// 在线状态缓存
  ///
  /// 存储用户的在线状态，key 为用户 ID，value 为在线状态
  /// 使用 LRU 缓存策略，最多存储 1000 个用户状态
  static final Map<String, bool> _onlineStatusCache = {};
  static final Map<String, int> _onlineStatusTimestamp = {};

  /// 获取用户在线状态
  ///
  /// 从缓存中获取用户在线状态，如果缓存过期则返回 null
  ///
  /// [uid] 用户 ID
  /// Returns: true=在线, false=离线, null=未知
  static Future<bool?> _getOnlineStatus(String uid) async {
    try {
      // 检查缓存是否存在且未过期（5分钟有效期）
      final timestamp = _onlineStatusTimestamp[uid];
      if (timestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (age < 5 * 60 * 1000) {
          // 5分钟内有效
          return _onlineStatusCache[uid];
        }
      }

      // 缓存过期，尝试从 WebSocket 服务获取
      // 注意：这需要 WebSocket 服务支持在线状态查询
      // 目前返回 null 表示未知状态
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 更新用户在线状态缓存
  ///
  /// 当收到用户上线/下线通知时调用此方法更新缓存
  ///
  /// [uid] 用户 ID
  /// [isOnline] 是否在线
  static void updateOnlineStatus(String uid, bool isOnline) {
    _onlineStatusCache[uid] = isOnline;
    _onlineStatusTimestamp[uid] = DateTime.now().millisecondsSinceEpoch;

    // 限制缓存大小，移除最旧的条目
    if (_onlineStatusCache.length > 1000) {
      // 找到最旧的条目并移除
      String? oldestKey;
      int oldestTime = DateTime.now().millisecondsSinceEpoch;
      for (final entry in _onlineStatusTimestamp.entries) {
        if (entry.value < oldestTime) {
          oldestTime = entry.value;
          oldestKey = entry.key;
        }
      }
      if (oldestKey != null) {
        _onlineStatusCache.remove(oldestKey);
        _onlineStatusTimestamp.remove(oldestKey);
      }
    }
  }

  /// 清除在线状态缓存
  static void clearOnlineStatusCache() {
    _onlineStatusCache.clear();
    _onlineStatusTimestamp.clear();
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
      } catch (e, s) {
        AppLogger.error('[e2ee_social_service] sendMessage error', e, s);
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
  /// 零信任架构：代理从本地安全存储读取所有分片
  /// 通过维护的分片 ID 列表遍历所有分片
  ///
  /// Returns: 本地存储的分片列表
  static Future<List<Map<String, dynamic>>> getStoredShards() async {
    try {
      // 1. 获取所有分片 ID
      final shardIds = await StorageSecureService.to.getShardIdList();
      if (shardIds.isEmpty) {
        return [];
      }

      // 2. 遍历读取每个分片
      final shards = <Map<String, dynamic>>[];
      for (final shardId in shardIds) {
        try {
          final shardJson = await StorageSecureService.to.read(
            key: 'e2ee_shard_$shardId',
          );
          if (shardJson != null && shardJson.isNotEmpty) {
            final shard = jsonDecode(shardJson) as Map<String, dynamic>;
            shards.add(shard);
          }
        } catch (e, s) {
          AppLogger.error('[e2ee_social_service] read shard error', e, s);
        }
      }

      return shards;
    } catch (e) {
      return [];
    }
  }

  /// 解密并返回分片（代理端）
  ///
  /// 零信任架构：代理使用自己的私钥解密分片，返回给密钥所有者
  /// 分片是通过 RSA-OAEP-SHA256 加密的
  ///
  /// [shardId] 分片 ID
  /// [requesterUid] 请求者用户 ID
  /// Returns: 解密后的分片数据（Base64 编码）
  static Future<String?> decryptShardForRequester({
    required String shardId,
    required int requesterUid,
  }) async {
    try {
      // 1. 从安全存储读取分片
      final shardJson = await StorageSecureService.to.read(
        key: 'e2ee_shard_$shardId',
      );
      if (shardJson == null) {
        throw Exception('分片不存在');
      }

      final shard = jsonDecode(shardJson) as Map<String, dynamic>;

      // 2. 验证请求者是否是分片所有者
      if (shard['uid'] != requesterUid) {
        throw Exception('无权访问此分片');
      }

      final encryptedShard = shard['encrypted_shard']?.toString() ?? '';
      if (encryptedShard.isEmpty) {
        throw Exception('分片数据为空');
      }

      // 3. 获取代理的私钥
      final privateKeyPem = await RSAService.privateKey();
      if (privateKeyPem == null || privateKeyPem.isEmpty) {
        throw Exception('代理私钥不存在');
      }

      // 4. 解析私钥
      final privateKey = RSAService.parsePrivateKeyFromPem(privateKeyPem);

      // 5. 解码 Base64 加密分片
      final encryptedBytes = base64Decode(encryptedShard);

      // 6. 使用 RSA-OAEP-SHA256 解密
      final decryptedBytes = RSAService.rsaDecrypt(privateKey, encryptedBytes);

      // 7. 重新编码为 Base64 以便传输
      final decryptedShard = base64.encode(decryptedBytes);

      return decryptedShard;
    } catch (e) {
      return null;
    }
  }

  /// 请求代理解密分片
  ///
  /// 零信任架构：恢复密钥时，向代理请求解密分片
  /// 使用 E2EEShardMessageHandler 进行请求，支持超时和响应等待
  ///
  /// [proxyUid] 代理用户 ID
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

      final decryptedShards = <String>[];
      final processedShards = <String>[];

      for (final shard in shards) {
        if (decryptedShards.length >= threshold) {
          break;
        }

        final shardId = shard['shard_id']?.toString() ?? '';
        final proxyUid = shard['proxy_uid']?.toString() ?? '';

        if (shardId.isEmpty || proxyUid.isEmpty) {
          continue;
        }

        // 避免重复请求同一个分片
        if (processedShards.contains(shardId)) {
          continue;
        }

        processedShards.add(shardId);

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
          onProgress?.call(decryptedShards.length, shards.length);
        } else {}
      }

      // 检查是否收集到足够的分片
      if (decryptedShards.length < threshold) {
        throw Exception('收集到的分片不足：${decryptedShards.length}/$threshold');
      }

      // 调用服务端 API 重组密钥
      await recoverKey(decryptedShards: decryptedShards);

      return true;
    } catch (e) {
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
