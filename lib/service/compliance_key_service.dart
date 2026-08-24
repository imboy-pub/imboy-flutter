/// 合规密钥缓存服务（单例）
///
/// 从服务端获取并缓存活跃的合规公钥。
/// 用于 compliance_e2ee 模式下的双密钥加密。
///
/// ## TOFU 锚定（审计 P1-1，2026-08-24）
///
/// compliance 公钥由服务端下发、客户端**未锚定**时，恶意服务端可把自己的
/// 公钥当"合规公钥"下发 → 消息双包裹一份给攻击者 → 静默全量解密。
///
/// 本服务对首次拉取的公钥做 TOFU 固定（pin 存 SecureStorage）：
/// - key_id 或公钥指纹与 pin 不符 → 抛 [ComplianceKeyChangedException]，
///   发送路径 fail-closed 拒发（绝不带新钥继续加密）；
/// - 用户经 UI 确认"管理员确实轮换了合规密钥"后调用 [confirmRotation]
///   以最新拉取值 re-pin（拒绝则保持旧 pin，继续 fail-closed）。
///
/// 局限（明示）：TOFU 只能防"已固定后的服务端偷换"；**首次**接触的
/// 恶意服务端仍可注入首钥（与 X3DH 首触同理，根治需 Key Transparency，
/// 见台账 IMB-2026-007）。
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_api.dart';
import 'package:crypto/crypto.dart';

/// 合规密钥信息
class ComplianceKeyInfo {
  final String keyId;
  final String publicKey;
  final String? algorithm;
  final DateTime? createdAt;
  final DateTime fetchedAt;

  ComplianceKeyInfo({
    required this.keyId,
    required this.publicKey,
    this.algorithm,
    this.createdAt,
    required this.fetchedAt,
  });

  /// 缓存是否过期（55 分钟）
  /// 使用 55 分钟而非 60 分钟作为安全裕量，避免系统时钟微调导致缓存恰好过期
  bool get isExpired => DateTime.now().difference(fetchedAt).inMinutes > 55;

  /// 公钥的规范化 SHA-256 指纹（PEM 去空白/换行差异后计算）。
  ///
  /// 只对 PEM 的 base64 主体哈希：`-----BEGIN/END` 行与换行是表示层，
  /// 服务端格式化差异不得造成误报；公钥内容变化必然改变指纹。
  String get fingerprint => ComplianceKeyService.fingerprintOf(publicKey);
}

/// 合规密钥变更（疑似偷换或被管理员轮换）——发送路径必须 fail-closed。
///
/// [pinned] 为本地已固定的旧值，[observed] 为服务端刚下发的新值。
class ComplianceKeyChangedException implements Exception {
  final String? pinnedKeyId;
  final String? pinnedFingerprint;
  final String observedKeyId;
  final String observedFingerprint;

  const ComplianceKeyChangedException({
    this.pinnedKeyId,
    this.pinnedFingerprint,
    required this.observedKeyId,
    required this.observedFingerprint,
  });

  @override
  String toString() =>
      'ComplianceKeyChangedException: key_id $pinnedKeyId -> $observedKeyId';
}

/// 合规密钥缓存服务（单例）
class ComplianceKeyService {
  ComplianceKeyService._();
  static final ComplianceKeyService _instance = ComplianceKeyService._();
  static ComplianceKeyService get instance => _instance;

  // 存储键名，非密钥材料（gitleaks 误报 generic-api-key，标注放行）
  static const String _pinStorageKey =
      'compliance_key_pin_v1'; // gitleaks:allow

  final E2EEApi _api = E2EEApi();
  ComplianceKeyInfo? _cached;

  /// 最近一次服务端下发但未被确认的值（UI 确认轮换时的比对源）。
  ComplianceKeyInfo? _pendingObserved;

  /// 测试注入点：返回服务端下发字段 map；抛异常表示拉取失败。
  /// 不注入时走真实 [E2EEApi.getComplianceKey]。
  @visibleForTesting
  static Future<Map<String, dynamic>?> Function()? debugFetcher;

  Future<Map<String, dynamic>?> _fetch() async {
    final override = debugFetcher;
    if (override != null) return override();
    return _api.getComplianceKey();
  }

  /// 规范化 PEM 的 base64 主体（去空白/换行/头尾标记），再算 SHA-256 十六进制。
  static String fingerprintOf(String publicKeyPem) {
    final cleaned = publicKeyPem
        .replaceAll(RegExp(r'-----BEGIN [A-Z ]+-----'), '')
        .replaceAll(RegExp(r'-----END [A-Z ]+-----'), '')
        .replaceAll(RegExp(r'\s'), '');
    return sha256.convert(utf8.encode(cleaned)).toString();
  }

  /// 获取合规公钥（优先使用缓存；TOFU pin 校验见类文档）。
  ///
  /// - 与 pin 匹配 → 正常返回；
  /// - 无 pin（首次）→ 固定并返回；
  /// - 与 pin 不匹配 → 抛 [ComplianceKeyChangedException]（fail-closed）。
  Future<ComplianceKeyInfo?> getComplianceKey({
    bool forceRefresh = false,
  }) async {
    // 使用缓存（缓存内必已通过 pin 校验）
    if (!forceRefresh && _cached != null && !_cached!.isExpired) {
      return _cached;
    }

    try {
      final data = await _fetch();
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

      final observed = ComplianceKeyInfo(
        keyId: keyId,
        publicKey: publicKey,
        algorithm: data['algorithm'] as String?,
        createdAt: data['created_at'] is String
            ? DateTime.tryParse(data['created_at'] as String)
            : null,
        fetchedAt: DateTime.now(),
      );

      final pin = await _loadPin();
      if (pin == null) {
        // TOFU：首次固定。已固定后，服务端换钥必须经用户确认。
        await _savePin(
          keyId: keyId,
          fingerprint: observed.fingerprint,
          pinnedAt: DateTime.now(),
        );
        iPrint('[ComplianceKey] TOFU 首次固定: keyId=$keyId');
        _pendingObserved = null;
        _cached = observed;
        return _cached;
      }

      final fingerprint = observed.fingerprint;
      if (pin['key_id'] == keyId && pin['fingerprint'] == fingerprint) {
        _pendingObserved = null;
        _cached = observed;
        return _cached;
      }

      // 不匹配：疑似偷换或管理员轮换。保留旧 pin，fail-closed。
      _pendingObserved = observed;
      iPrint(
        '[ComplianceKey] ⚠️ 合规密钥与本地固定不一致: '
        'pin=${pin['key_id']}/${pin['fingerprint']} '
        'got=$keyId/$fingerprint',
      );
      throw ComplianceKeyChangedException(
        pinnedKeyId: pin['key_id'] as String?,
        pinnedFingerprint: pin['fingerprint'] as String?,
        observedKeyId: keyId,
        observedFingerprint: fingerprint,
      );
    } on ComplianceKeyChangedException {
      rethrow;
    } catch (e) {
      iPrint('[ComplianceKey] 获取失败: $e');
      // fail-closed（CB-10）：绝不返回 stale/过期缓存降级。
      // 仅在缓存仍在有效期内时复用；否则返回 null，由 PolicyGate 拒发。
      if (_cached != null && !_cached!.isExpired) {
        return _cached;
      }
      return null;
    }
  }

  /// 用户确认合规密钥轮换后调用：以最近一次服务端下发值重新固定。
  ///
  /// [accept] 为 true 时 re-pin（返回 true）；为 false 时保持旧 pin
  /// （返回 false，后续发送继续 fail-closed）。
  Future<bool> confirmRotation({required bool accept}) async {
    final observed = _pendingObserved;
    if (observed == null) return false;
    if (!accept) {
      _pendingObserved = null;
      return false;
    }
    await _savePin(
      keyId: observed.keyId,
      fingerprint: observed.fingerprint,
      pinnedAt: DateTime.now(),
    );
    _pendingObserved = null;
    _cached = observed;
    iPrint('[ComplianceKey] 已确认轮换并 re-pin: keyId=${observed.keyId}');
    return true;
  }

  /// 最近一次未确认的服务端下发值（UI 展示"将要固定"的内容）。
  ComplianceKeyInfo? get pendingObserved => _pendingObserved;

  /// 当前已固定的 pin（供设置页信息展示）。
  Future<Map<String, dynamic>?> pinned() => _loadPin();

  Future<Map<String, dynamic>?> _loadPin() async {
    final raw = await StorageSecureService.to.read(key: _pinStorageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePin({
    required String keyId,
    required String fingerprint,
    required DateTime pinnedAt,
  }) => StorageSecureService.to.write(
    key: _pinStorageKey,
    value: jsonEncode({
      'key_id': keyId,
      'fingerprint': fingerprint,
      'pinned_at': pinnedAt.toIso8601String(),
    }),
  );

  /// 清除缓存
  void clearCache() {
    _cached = null;
    _pendingObserved = null;
  }
}
