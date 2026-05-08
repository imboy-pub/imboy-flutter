/// 合规密钥缓存服务
///
/// 从服务端获取并缓存活跃的合规公钥。
/// 用于 compliance_e2ee 模式下的双密钥加密。
library;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/api/e2ee_api.dart';

/// 合规密钥信息
class ComplianceKeyInfo {
  final String keyId;
  final String publicKey;
  final DateTime fetchedAt;

  ComplianceKeyInfo({
    required this.keyId,
    required this.publicKey,
    required this.fetchedAt,
  });

  /// 缓存是否过期（55 分钟）
  /// 使用 55 分钟而非 60 分钟作为安全裕量，避免系统时钟微调导致缓存恰好过期
  bool get isExpired => DateTime.now().difference(fetchedAt).inMinutes > 55;
}

/// 合规密钥缓存服务（单例）
class ComplianceKeyService {
  ComplianceKeyService._();
  static final ComplianceKeyService _instance = ComplianceKeyService._();
  static ComplianceKeyService get instance => _instance;

  final E2EEApi _api = E2EEApi();
  ComplianceKeyInfo? _cached;

  /// 获取合规公钥（优先使用缓存）
  ///
  /// 返回 ComplianceKeyInfo 或 null（如果服务端未配置合规密钥）
  Future<ComplianceKeyInfo?> getComplianceKey({
    bool forceRefresh = false,
  }) async {
    // 使用缓存
    if (!forceRefresh && _cached != null && !_cached!.isExpired) {
      return _cached;
    }

    try {
      final data = await _api.getComplianceKey();
      if (data == null) {
        iPrint('[ComplianceKey] 服务端无活跃合规密钥');
        return null;
      }

      final keyId = data['key_id'] as String?;
      final publicKey = data['public_key'] as String?;

      if (keyId == null || publicKey == null) {
        iPrint('[ComplianceKey] 返回数据不完整');
        return null;
      }

      _cached = ComplianceKeyInfo(
        keyId: keyId,
        publicKey: publicKey,
        fetchedAt: DateTime.now(),
      );

      iPrint('[ComplianceKey] 获取成功: keyId=$keyId');
      return _cached;
    } catch (e) {
      iPrint('[ComplianceKey] 获取失败: $e');
      // 如果有缓存（即使过期），降级返回
      return _cached;
    }
  }

  /// 清除缓存
  void clearCache() {
    _cached = null;
  }
}
