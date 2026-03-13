/// E2EE 社交恢复处理器
///
/// 封装基于 Shamir Secret Sharing 的社交恢复业务流程：
/// - 生成密钥分片
/// - 分发分片给代理
/// - 收集分片恢复密钥
/// - 验证分片完整性
///
/// @author ImBoy Team
/// @since 2026-02-14
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/service/shamir_secret_sharing.dart';
import 'package:imboy/service/storage_secure.dart';

/// 代理状态
enum TrusteeStatus {
  /// 待确认
  pending,

  /// 已接受
  accepted,

  /// 已拒绝
  rejected,

  /// 已失效
  expired,
}

/// 代理信息
class TrusteeInfo {
  /// 代理用户 ID
  final String uid;

  /// 代理设备 ID
  final String? deviceId;

  /// 状态
  final TrusteeStatus status;

  /// 分片索引
  final int shareIndex;

  /// 邀请时间
  final DateTime invitedAt;

  /// 接受时间
  final DateTime? acceptedAt;

  const TrusteeInfo({
    required this.uid,
    this.deviceId,
    required this.status,
    required this.shareIndex,
    required this.invitedAt,
    this.acceptedAt,
  });

  factory TrusteeInfo.fromJson(Map<String, dynamic> json) {
    return TrusteeInfo(
      uid: json['uid'] as String,
      deviceId: json['device_id']?.toString(),
      status: _parseStatus(json['status'] as String?),
      shareIndex: json['share_index'] as int? ?? 0,
      invitedAt: json['invited_at'] != null
          ? DateTime.parse(json['invited_at'] as String)
          : DateTime.now(),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'device_id': deviceId,
      'status': status.name,
      'share_index': shareIndex,
      'invited_at': invitedAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
    };
  }

  static TrusteeStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return TrusteeStatus.pending;
      case 'accepted':
        return TrusteeStatus.accepted;
      case 'rejected':
        return TrusteeStatus.rejected;
      case 'expired':
        return TrusteeStatus.expired;
      default:
        return TrusteeStatus.pending;
    }
  }
}

/// 社交恢复配置
class SocialRecoveryConfig {
  /// 代理总数
  final int trusteeCount;

  /// 恢复阈值（至少需要的代理数）
  final int threshold;

  /// 分片有效期（天）
  final int expiryDays;

  const SocialRecoveryConfig({
    this.trusteeCount = 5,
    this.threshold = 3,
    this.expiryDays = 365,
  });

  /// 默认配置：5 个代理，3 个恢复
  static const SocialRecoveryConfig defaultConfig = SocialRecoveryConfig();

  /// 高安全配置：7 个代理，5 个恢复
  static const SocialRecoveryConfig highSecurity = SocialRecoveryConfig(
    trusteeCount: 7,
    threshold: 5,
  );

  /// 快速恢复配置：3 个代理，2 个恢复
  static const SocialRecoveryConfig quickRecovery = SocialRecoveryConfig(
    trusteeCount: 3,
    threshold: 2,
  );
}

/// 分片数据（加密后）
class EncryptedShare {
  /// 分片索引
  final int index;

  /// 代理 UID
  final String trusteeUid;

  /// 加密后的分片数据
  final String encryptedData;

  /// 创建时间
  final DateTime createdAt;

  const EncryptedShare({
    required this.index,
    required this.trusteeUid,
    required this.encryptedData,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'trustee_uid': trusteeUid,
      'encrypted_data': encryptedData,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// 社交恢复结果
class SocialRecoveryResult {
  /// 是否成功
  final bool success;

  /// 恢复的密钥信息（成功时）
  final Map<String, dynamic>? keyInfo;

  /// 错误消息（失败时）
  final String? errorMessage;

  /// 错误代码
  final String? errorCode;

  const SocialRecoveryResult._({
    required this.success,
    this.keyInfo,
    this.errorMessage,
    this.errorCode,
  });

  /// 成功结果
  factory SocialRecoveryResult.success(Map<String, dynamic> keyInfo) {
    return SocialRecoveryResult._(success: true, keyInfo: keyInfo);
  }

  /// 失败结果
  factory SocialRecoveryResult.failure(
    String errorMessage, {
    String? errorCode,
  }) {
    return SocialRecoveryResult._(
      success: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
    );
  }
}

/// E2EE 社交恢复处理器
///
/// 单例模式，提供基于 Shamir Secret Sharing 的社交恢复业务逻辑
class E2EESocialHandler {
  /// 单例实例
  static final E2EESocialHandler _instance = E2EESocialHandler._internal();

  factory E2EESocialHandler() => _instance;

  E2EESocialHandler._internal();

  // ================================================================
  // 分片生成与分发
  // ================================================================

  /// 生成密钥分片
  ///
  /// [config] 恢复配置
  ///
  /// 返回分片列表，每个分片需要加密后发送给对应的代理
  Future<List<Map<String, dynamic>>> generateShares({
    SocialRecoveryConfig config = SocialRecoveryConfig.defaultConfig,
  }) async {
    try {
      // 1. 检查本地是否有有效的 E2EE 私钥
      final storage = StorageSecureService.to;
      final privateKey = await storage.getPrivateKey();

      if (privateKey == null || privateKey.isEmpty) {
        throw Exception('没有可用的私钥');
      }

      // 2. 将私钥转换为字节数组
      final secretBytes = Uint8List.fromList(utf8.encode(privateKey));

      // 3. 使用 Shamir Secret Sharing 分片
      final shares = ShamirSecretSharing.splitSecret(
        secretBytes,
        config.trusteeCount,
        config.threshold,
      );

      // 4. 转换为可序列化的格式
      final result = <Map<String, dynamic>>[];
      for (int i = 0; i < shares.length; i++) {
        final share = shares[i];
        result.add({
          'index': i,
          'x': share['x'].toString(),
          'y': share['y'].toString(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'threshold': config.threshold,
          'total': config.trusteeCount,
        });
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// 加密分片给指定代理
  ///
  /// [share] 原始分片数据
  /// [trusteePublicKey] 代理的公钥 PEM
  ///
  /// 返回加密后的分片数据
  Future<EncryptedShare> encryptShareForTrustee(
    Map<String, dynamic> share,
    String trusteeUid,
    String trusteePublicKey,
  ) async {
    try {
      // 1. 序列化分片
      final shareJson = json.encode(share);
      final shareBytes = utf8.encode(shareJson);

      // 2. 使用代理公钥加密
      final pubKey = RSAService.parsePublicKeyFromPem(trusteePublicKey);
      final encryptedBytes = RSAService.rsaEncrypt(
        pubKey,
        Uint8List.fromList(shareBytes),
      );

      // 3. Base64 编码
      final encryptedData = base64.encode(encryptedBytes);

      return EncryptedShare(
        index: share['index'] as int,
        trusteeUid: trusteeUid,
        encryptedData: encryptedData,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// 解密收到的分片
  ///
  /// [encryptedShare] 加密的分片数据
  ///
  /// 返回原始分片数据
  Future<Map<String, dynamic>> decryptShare(String encryptedShare) async {
    try {
      // 1. Base64 解码
      final encryptedBytes = base64.decode(encryptedShare);

      // 2. 获取私钥对象
      final privateKey = await RSAService.privateKeyObject();

      // 3. RSA 解密
      final decryptedBytes = RSAService.rsaDecrypt(privateKey, encryptedBytes);

      // 4. 解析 JSON
      final shareJson = utf8.decode(decryptedBytes);
      return json.decode(shareJson) as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // ================================================================
  // 密钥恢复
  // ================================================================

  /// 从收集的分片恢复密钥
  ///
  /// [shares] 收集到的分片列表（至少需要 threshold 个）
  ///
  /// 恢复私钥并导入到本地安全存储
  Future<SocialRecoveryResult> recoverFromShares(
    List<Map<String, dynamic>> shares,
  ) async {
    try {
      // 1. 验证分片数量
      if (shares.isEmpty) {
        return SocialRecoveryResult.failure('没有提供分片', errorCode: 'no_shares');
      }

      // 2. 获取阈值信息
      final threshold = shares.first['threshold'] as int? ?? shares.length;
      if (shares.length < threshold) {
        return SocialRecoveryResult.failure(
          '分片数量不足，需要至少 $threshold 个分片',
          errorCode: 'insufficient_shares',
        );
      }

      // 3. 验证分片索引唯一性
      final indices = shares.map((s) => s['index'] as int).toSet();
      if (indices.length < shares.length) {
        return SocialRecoveryResult.failure(
          '存在重复的分片索引',
          errorCode: 'duplicate_shares',
        );
      }

      // 4. 转换分片格式
      final shamirShares = shares.map((share) {
        return {
          'x': BigInt.parse(share['x'] as String),
          'y': BigInt.parse(share['y'] as String),
        };
      }).toList();

      // 5. 使用 Shamir 恢复秘密
      final recoveredBytes = ShamirSecretSharing.combineShares(shamirShares);

      // 6. 转换为私钥字符串
      final recoveredKey = utf8.decode(recoveredBytes);

      // 7. 验证私钥格式
      if (!recoveredKey.contains('-----BEGIN PRIVATE KEY-----')) {
        return SocialRecoveryResult.failure(
          '恢复的密钥格式无效',
          errorCode: 'invalid_key_format',
        );
      }

      // 8. 保存到本地安全存储
      final storage = StorageSecureService.to;
      await storage.savePrivateKey(recoveredKey);

      // 9. 返回成功结果
      return SocialRecoveryResult.success({
        'recovered_at': DateTime.now().toUtc().toIso8601String(),
        'share_count': shares.length,
        'threshold': threshold,
      });
    } catch (e) {
      return SocialRecoveryResult.failure(
        '恢复密钥失败: ${_getErrorMessage(e)}',
        errorCode: 'recovery_failed',
      );
    }
  }

  /// 验证分片有效性
  ///
  /// [share] 分片数据
  ///
  /// 返回分片是否有效
  bool validateShare(Map<String, dynamic> share) {
    try {
      // 检查必需字段
      if (!share.containsKey('x') || !share.containsKey('y')) {
        return false;
      }

      // 检查 x 和 y 是否为有效的 BigInt 字符串
      BigInt.parse(share['x'] as String);
      BigInt.parse(share['y'] as String);

      // 检查索引
      final index = share['index'] as int?;
      if (index == null || index < 0) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // ================================================================
  // 辅助方法
  // ================================================================

  /// 检查本地是否有 E2EE 密钥
  Future<bool> hasLocalKey() async {
    return E2EEKeyService.hasKey();
  }

  /// 获取当前配置建议
  ///
  /// 根据用户的好友数量推荐配置
  SocialRecoveryConfig getRecommendedConfig(int friendCount) {
    if (friendCount >= 7) {
      return SocialRecoveryConfig.highSecurity;
    } else if (friendCount >= 5) {
      return SocialRecoveryConfig.defaultConfig;
    } else if (friendCount >= 3) {
      return SocialRecoveryConfig.quickRecovery;
    } else {
      // 好友数量不足，返回最小配置
      return SocialRecoveryConfig(
        trusteeCount: friendCount,
        threshold: (friendCount * 0.6).ceil(), // 60% 阈值
      );
    }
  }

  /// 获取用户友好的错误消息
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('insufficient') || errorStr.contains('不足')) {
      return '分片数量不足';
    }

    if (errorStr.contains('duplicate') || errorStr.contains('重复')) {
      return '存在重复的分片';
    }

    if (errorStr.contains('invalid') || errorStr.contains('无效')) {
      return '分片数据无效';
    }

    if (errorStr.contains('format') || errorStr.contains('格式')) {
      return '数据格式错误';
    }

    return error.toString();
  }
}
