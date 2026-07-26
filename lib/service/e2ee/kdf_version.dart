/// S7: 版本化 KDF 调度层（ADR 08 T6 — KDF 可迁移）
///
/// 设计目标：让密钥派生函数（KDF）自描述、可升级、可审计。
///
/// - **自描述**：每个派生结果绑定一个整数 [version]，备份/存储记录该版本，
///   解密时按版本路由到对应 KDF 实现。
/// - **可升级**：新增 KDF（如未来的 Argon2id）只需注册新 version 并提升
///   [latest]，旧版本仍可读取（向后兼容），新写入自动用 [latest]。
/// - **可审计**：[needsMigration] 暴露"当前数据 KDF 是否落后"，供升级流程
///   与守护测试断言；降级被显式拒绝（[KdfDowngradeException]）。
///
/// 安全约束：
/// - 不自定义密码学——v1 直接委托既有 [E2EECryptoService.deriveKey]
///   （PBKDF2-HMAC-SHA256 / 310,000 迭代，OWASP 2021）。
/// - 未知版本 fail-closed（[UnsupportedKdfVersionException]），绝不静默回退。
/// - 降级 fail-closed（[KdfDowngradeException]）。
library;

import 'dart:typed_data';

import 'package:imboy/service/e2ee_crypto_service.dart';

/// 未知/不支持的 KDF 版本。fail-closed：不得静默回退到默认 KDF。
class UnsupportedKdfVersionException implements Exception {
  UnsupportedKdfVersionException(this.version);
  final int version;
  @override
  String toString() =>
      'UnsupportedKdfVersionException: KDF version $version is not supported';
}

/// KDF 降级尝试（目标版本低于当前版本）。fail-closed。
class KdfDowngradeException implements Exception {
  KdfDowngradeException({required this.fromVersion, required this.toVersion});
  final int fromVersion;
  final int toVersion;
  @override
  String toString() =>
      'KdfDowngradeException: refusing to downgrade KDF '
      'from v$fromVersion to v$toVersion';
}

/// KDF 迁移结果。
class KdfMigrationResult {
  KdfMigrationResult({
    required this.fromVersion,
    required this.toVersion,
    required this.key,
  });

  final int fromVersion;
  final int toVersion;

  /// 用目标版本 KDF 重新派生的密钥（32 bytes，AES-256）。
  final Uint8List key;
}

/// 版本化 KDF 调度器。
class KdfVersion {
  KdfVersion._();

  /// 当前最新 KDF 版本。新写入一律使用此版本。
  ///
  /// - v1: PBKDF2-HMAC-SHA256 / 310,000 迭代 / 16-byte salt / 32-byte key
  /// - v2（预留）: Argon2id —— 待引入经审计的 Argon2 依赖后注册
  static const int latest = 1;

  /// 该版本是否受支持。
  static bool isSupported(int version) => version == 1;

  /// 按版本派生密钥。未知版本抛 [UnsupportedKdfVersionException]。
  ///
  /// [password] 用户口令；[salt] 必须 16 bytes；可选 [iterations] 仅 v1 生效
  /// （默认沿用 OWASP 推荐值）。
  static Future<Uint8List> derive({
    required int version,
    required String password,
    required Uint8List salt,
    int? iterations,
  }) async {
    switch (version) {
      case 1:
        return E2EECryptoService.deriveKey(
          password,
          salt,
          iterations: iterations ?? E2EECryptoService.pbkdf2Iterations,
        );
      default:
        throw UnsupportedKdfVersionException(version);
    }
  }

  /// 数据是否需要迁移到 [latest]。
  static bool needsMigration(int currentVersion) => currentVersion < latest;

  /// 将口令派生从 [fromVersion] 迁移到 [toVersion]（默认 [latest]）。
  ///
  /// 迁移语义：用目标版本 KDF 对同一 (password, salt) 重新派生。
  /// - [toVersion] 不支持 → [UnsupportedKdfVersionException]
  /// - [toVersion] < [fromVersion] → [KdfDowngradeException]（拒绝降级）
  static Future<KdfMigrationResult> migrate({
    required int fromVersion,
    required String password,
    required Uint8List salt,
    int toVersion = latest,
  }) async {
    if (!isSupported(toVersion)) {
      throw UnsupportedKdfVersionException(toVersion);
    }
    if (toVersion < fromVersion) {
      throw KdfDowngradeException(
        fromVersion: fromVersion,
        toVersion: toVersion,
      );
    }

    final key = await derive(
      version: toVersion,
      password: password,
      salt: salt,
    );
    return KdfMigrationResult(
      fromVersion: fromVersion,
      toVersion: toVersion,
      key: key,
    );
  }
}
