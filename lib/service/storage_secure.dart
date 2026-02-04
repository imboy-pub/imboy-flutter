import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全存储服务 - 基于 FlutterSecureStorage
/// Secure storage service based on FlutterSecureStorage
///
/// 职责：
/// - 提供安全的键值对存储（数据加密存储）
/// - 适用于存储敏感信息（如 Token、密钥等）
/// - 支持多平台（iOS Keychain、Android Keystore）
///
/// 使用方式：
/// ```dart
/// // 写入
/// await StorageSecureService.to.write(
///   key: 'token',
///   value: 'secret_token',
/// );
///
/// // 读取
/// String? token = await StorageSecureService.to.read(key: 'token');
///
/// // 删除
/// await StorageSecureService.to.delete(key: 'token');
/// ```
///
/// 迁移说明：
/// - 使用标准 Dart 单例模式
/// - 提供 `.to` 静态访问方式（与项目其他服务保持一致）
/// - 保留 factory 构造函数以向后兼容
class StorageSecureService {
  // 单例实例
  static final StorageSecureService _instance =
      StorageSecureService._internal();

  // FlutterSecureStorage 实例
  final FlutterSecureStorage _self = const FlutterSecureStorage();

  /// 获取单例实例（推荐使用）
  /// Get singleton instance (recommended)
  static StorageSecureService get to => _instance;

  /// Factory 构造函数（向后兼容）
  /// Factory constructor (for backward compatibility)
  factory StorageSecureService() {
    return _instance;
  }

  /// 私有构造函数
  /// Private constructor
  StorageSecureService._internal();

  /// Encrypts and saves the [key] with the given [value].
  ///
  /// If the key was already in the storage, its associated value is changed.
  /// If the value is null, deletes associated value for the given [key].
  /// [key] shouldn't be null.
  /// [value] required value
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _self.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }

  /// Decrypts and returns the value for the given [key] or null if [key] is not in the storage.
  ///
  /// [key] shouldn't be null.
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _self.read(
    key: key,
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions,
    wOptions: wOptions,
  );

  /// Deletes associated value for the given [key].
  ///
  /// If the given [key] does not exist, nothing will happen.
  ///
  /// [key] shouldn't be null.
  /// [iOptions] optional iOS options
  /// [aOptions] optional Android options
  /// [lOptions] optional Linux options
  /// [webOptions] optional web options
  /// [mOptions] optional MacOs options
  /// [wOptions] optional Windows options
  /// Can throw a [PlatformException].
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _self.delete(
    key: key,
    iOptions: iOptions,
    aOptions: aOptions,
    lOptions: lOptions,
    webOptions: webOptions,
    mOptions: mOptions,
    wOptions: wOptions,
  );

  // ==========================================
  // E2EE 密钥相关便捷方法
  // E2EE Key Related Convenience Methods
  // ==========================================

  /// 存储私钥（E2EE）
  /// Store private key for E2EE
  Future<void> savePrivateKey(String privateKey) async {
    await write(key: 'e2ee_private_key', value: privateKey);
  }

  /// 获取私钥（E2EE）
  /// Get private key for E2EE
  Future<String?> getPrivateKey() async {
    return await read(key: 'e2ee_private_key');
  }

  /// 存储公钥（E2EE）
  /// Store public key for E2EE
  Future<void> savePublicKey(String publicKey) async {
    await write(key: 'e2ee_public_key', value: publicKey);
  }

  /// 获取公钥（E2EE）
  /// Get public key for E2EE
  Future<String?> getPublicKey() async {
    return await read(key: 'e2ee_public_key');
  }

  /// 设置设备 ID（E2EE）
  /// Set device ID for E2EE
  Future<void> setDeviceId(String deviceId) async {
    await write(key: 'e2ee_device_id', value: deviceId);
  }

  /// 获取设备 ID（E2EE）
  /// Get device ID for E2EE
  Future<String?> getDeviceId() async {
    return await read(key: 'e2ee_device_id');
  }

  /// 设置密钥 ID（E2EE）
  /// Set key ID for E2EE
  Future<void> setKeyId(String keyId) async {
    await write(key: 'e2ee_key_id', value: keyId);
  }

  /// 获取密钥 ID（E2EE）
  /// Get key ID for E2EE
  Future<String?> getKeyId() async {
    return await read(key: 'e2ee_key_id');
  }

  /// 设置密钥创建时间（E2EE）
  /// Set key creation time for E2EE
  Future<void> setKeyCreatedAt(String createdAt) async {
    await write(key: 'e2ee_key_created_at', value: createdAt);
  }

  /// 获取密钥创建时间（E2EE）
  /// Get key creation time for E2EE
  Future<String?> getKeyCreatedAt() async {
    return await read(key: 'e2ee_key_created_at');
  }

  /// 删除所有 E2EE 密钥数据
  /// Delete all E2EE key data
  Future<void> deleteAllE2EEKeys() async {
    await delete(key: 'e2ee_private_key');
    await delete(key: 'e2ee_public_key');
    await delete(key: 'e2ee_device_id');
    await delete(key: 'e2ee_key_id');
    await delete(key: 'e2ee_key_created_at');
  }

  /// 检查是否存在 E2EE 密钥
  /// Check if E2EE keys exist
  Future<bool> hasE2EEKeys() async {
    final privateKey = await getPrivateKey();
    final publicKey = await getPublicKey();
    return privateKey != null && publicKey != null;
  }

  // ==========================================
  // E2EE 社交恢复分片相关方法
  // E2EE Social Recovery Shard Methods
  // ==========================================

  /// 存储接收的分片（代理端）
  /// Store received shard (proxy side)
  Future<void> saveE2EEShard(String shardId, String shardData) async {
    await write(key: 'e2ee_shard_$shardId', value: shardData);
  }

  /// 获取存储的分片（代理端）
  /// Get stored shard (proxy side)
  Future<String?> getE2EEShard(String shardId) async {
    return await read(key: 'e2ee_shard_$shardId');
  }

  /// 删除存储的分片（代理端）
  /// Delete stored shard (proxy side)
  Future<void> deleteE2EEShard(String shardId) async {
    await delete(key: 'e2ee_shard_$shardId');
  }

  /// 存储分片 ID 列表
  /// Store shard ID list (for tracking all shards)
  Future<void> saveShardIdList(List<String> shardIds) async {
    await write(key: 'e2ee_shard_id_list', value: jsonEncode(shardIds));
  }

  /// 获取分片 ID 列表
  /// Get shard ID list
  Future<List<String>> getShardIdList() async {
    final data = await read(key: 'e2ee_shard_id_list');
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List;
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  /// 添加分片 ID 到列表
  /// Add shard ID to list
  Future<void> addShardId(String shardId) async {
    final list = await getShardIdList();
    if (!list.contains(shardId)) {
      list.add(shardId);
      await saveShardIdList(list);
    }
  }

  /// 从列表中移除分片 ID
  /// Remove shard ID from list
  Future<void> removeShardId(String shardId) async {
    final list = await getShardIdList();
    final newList = list.where((id) => id != shardId).toList();
    await saveShardIdList(newList);
  }

  /// 删除所有分片
  /// Delete all shards
  Future<void> deleteAllE2EEShards() async {
    final list = await getShardIdList();
    for (final shardId in list) {
      await deleteE2EEShard(shardId);
    }
    await delete(key: 'e2ee_shard_id_list');
  }

  // ==========================================
  // E2EE 分片元数据管理（零信任架构）
  // Shard Metadata Management for Zero Trust
  // ==========================================

  /// 保存分片元数据列表（密钥所有者端）
  /// 用于恢复密钥时知道有哪些分片可用
  Future<void> saveE2EEShardMetadataList(
    List<Map<String, dynamic>> shards,
  ) async {
    await write(key: 'e2ee_shard_metadata_list', value: jsonEncode(shards));
  }

  /// 获取分片元数据列表（密钥所有者端）
  Future<List<Map<String, dynamic>>> getE2EEShardMetadataList() async {
    final data = await read(key: 'e2ee_shard_metadata_list');
    if (data == null) return [];
    try {
      final list = jsonDecode(data) as List;
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e) {
      return [];
    }
  }

  /// 添加分片元数据
  Future<void> addE2EEShardMetadata(Map<String, dynamic> shard) async {
    final list = await getE2EEShardMetadataList();
    list.add(shard);
    await saveE2EEShardMetadataList(list);
  }

  /// 根据分片 ID 更新元数据状态
  Future<void> updateE2EEShardMetadataStatus(
    String shardId,
    String status,
  ) async {
    final list = await getE2EEShardMetadataList();
    final updatedList = list.map((shard) {
      if (shard['shard_id']?.toString() == shardId) {
        return {...shard, 'status': status};
      }
      return shard;
    }).toList();
    await saveE2EEShardMetadataList(updatedList);
  }

  /// 删除所有分片元数据
  Future<void> deleteE2EEShardMetadataList() async {
    await delete(key: 'e2ee_shard_metadata_list');
  }

  /// 根据密钥版本获取分片元数据
  Future<List<Map<String, dynamic>>> getE2EEShardMetadataByKeyVersion(
    String keyVersion,
  ) async {
    final list = await getE2EEShardMetadataList();
    return list
        .where((shard) => shard['key_version']?.toString() == keyVersion)
        .toList();
  }

  /// 获取最新的分片元数据列表
  Future<List<Map<String, dynamic>>> getLatestE2EEShardMetadata() async {
    final list = await getE2EEShardMetadataList();
    if (list.isEmpty) return [];

    // 按密钥版本排序，返回最新的
    final sorted = list.toList()
      ..sort((a, b) {
        final verA = a['key_version']?.toString() ?? '0';
        final verB = b['key_version']?.toString() ?? '0';
        return verB.compareTo(verA);
      });

    // 按密钥版本分组
    final latestVersion = sorted.first['key_version']?.toString() ?? '';
    return list
        .where((shard) => shard['key_version']?.toString() == latestVersion)
        .toList();
  }

  /// 清理指定密钥版本的分片元数据
  Future<void> cleanE2EEShardMetadataByKeyVersion(String keyVersion) async {
    final list = await getE2EEShardMetadataList();
    final filtered = list
        .where((shard) => shard['key_version']?.toString() != keyVersion)
        .toList();
    await saveE2EEShardMetadataList(filtered);
  }
}

/// 类型别名，用于向后兼容
/// Type alias for backward compatibility
typedef StorageSecure = StorageSecureService;
