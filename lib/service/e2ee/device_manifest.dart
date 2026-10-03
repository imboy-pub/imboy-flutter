/// E2EE-020 — Device Manifest Model and Codec.
///
/// Ref: 16-supersedes-03-04-06-device-trust.md §4
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:vodozemac/vodozemac.dart' as vod;
import 'package:imboy/service/e2ee/protected_frame_v3.dart';

/// Manifest 有效性异常（过期 / 链断裂 / 重放嫌疑）。
///
/// C02 合同：这是**显式兼容错误**——调用方必须把该设备排除出投递/协商，
/// 不得回退明文、不得静默继续。区别于验签失败（[vod] 抛出 / 返回 false），
/// 本异常覆盖「签名有效但内容不再可信」的时间维度攻击（旧 manifest 重放）。
class ManifestValidityException implements Exception {
  ManifestValidityException(this.message);

  final String message;

  @override
  String toString() => 'ManifestValidityException: $message';
}

/// Device Manifest bundling active cryptographic keys, capabilities, and generations.
@immutable
class DeviceManifest {
  const DeviceManifest({
    this.manifestVersion = 1,
    required this.uid,
    required this.deviceId,
    required this.deviceGeneration,
    required this.identityVersion,
    required this.ed25519,
    required this.curve25519,
    this.mlsCredential,
    required this.capabilities,
    required this.createdAtMs,
    required this.expiresAtMs,
    this.previousManifestHash,
    this.deviceSignature,
    this.accountSignature,
  });

  final int manifestVersion;
  final String uid;
  final String deviceId;
  final int deviceGeneration;
  final int identityVersion;
  final String ed25519;
  final String curve25519;
  final String? mlsCredential;
  final Set<String> capabilities;
  final int createdAtMs;
  final int expiresAtMs;
  final String? previousManifestHash;
  final String? deviceSignature;
  final String? accountSignature;

  /// Parses a DeviceManifest from an API / JSON Map.
  factory DeviceManifest.fromJson(Map<String, dynamic> json) {
    final caps = json['capabilities'];
    final Set<String> capabilitiesSet;
    if (caps is Iterable) {
      capabilitiesSet = caps.map((e) => e.toString()).toSet();
    } else {
      capabilitiesSet = <String>{};
    }

    return DeviceManifest(
      manifestVersion: json['manifest_version'] as int? ?? 1,
      uid: json['uid']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      deviceGeneration: json['device_generation'] as int? ?? 1,
      identityVersion: json['identity_version'] as int? ?? 1,
      ed25519: json['ed25519']?.toString() ?? '',
      curve25519: json['curve25519']?.toString() ?? '',
      mlsCredential: json['mls_credential']?.toString(),
      capabilities: capabilitiesSet,
      createdAtMs: json['created_at_ms'] as int? ?? 0,
      expiresAtMs: json['expires_at_ms'] as int? ?? 0,
      previousManifestHash: json['previous_manifest_hash']?.toString(),
      deviceSignature: json['device_signature']?.toString(),
      accountSignature: json['account_signature']?.toString(),
    );
  }

  /// Converts this DeviceManifest back into a JSON Map.
  Map<String, dynamic> toJson({bool includeSignatures = true}) {
    // Sort capabilities lexicographically for deterministic serialization
    final sortedCaps = capabilities.toList()..sort();

    return {
      'manifest_version': manifestVersion,
      'uid': uid,
      'device_id': deviceId,
      'device_generation': deviceGeneration,
      'identity_version': identityVersion,
      'ed25519': ed25519,
      'curve25519': curve25519,
      if (mlsCredential != null) 'mls_credential': mlsCredential,
      'capabilities': sortedCaps,
      'created_at_ms': createdAtMs,
      'expires_at_ms': expiresAtMs,
      if (previousManifestHash != null)
        'previous_manifest_hash': previousManifestHash,
      if (includeSignatures && deviceSignature != null)
        'device_signature': deviceSignature,
      if (includeSignatures && accountSignature != null)
        'account_signature': accountSignature,
    };
  }

  /// Generates the canonical bytes of this manifest for signing and verifying.
  ///
  /// This matches ADR 16 requirements by CBOR encoding all fields *excluding*
  /// the signatures themselves under deterministic ordering using [CanonicalCbor].
  Uint8List canonicalBytes() {
    final Map<String, dynamic> map = toJson(includeSignatures: false);
    return CanonicalCbor.encode(map);
  }

  /// Signs this manifest with a device signing key (or a generic mock Ed25519 signer).
  /// Returns a new instance with [deviceSignature] populated.
  DeviceManifest signDevice(String Function(String) signer) {
    final message = base64Url.encode(canonicalBytes());
    final sigBase64 = signer(message);
    return copyWith(deviceSignature: sigBase64);
  }

  /// Verifies that the [deviceSignature] is a valid signature of the canonical bytes
  /// using the manifest's own [ed25519] base64 public key.
  bool verifyDeviceSignature() {
    if (deviceSignature == null || deviceSignature!.isEmpty) return false;
    try {
      final message = base64Url.encode(canonicalBytes());
      final pubKey = vod.Ed25519PublicKey.fromBase64(ed25519);
      final sig = vod.Ed25519Signature.fromBase64(deviceSignature!);
      pubKey.verify(message: message, signature: sig);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Verifies that the [accountSignature] is a valid signature of the canonical bytes
  /// using the provided [accountPublicKey] base64 string.
  bool verifyAccountSignature(String accountPublicKey) {
    if (accountSignature == null || accountSignature!.isEmpty) return false;
    try {
      final message = base64Url.encode(canonicalBytes());
      final pubKey = vod.Ed25519PublicKey.fromBase64(accountPublicKey);
      final sig = vod.Ed25519Signature.fromBase64(accountSignature!);
      pubKey.verify(message: message, signature: sig);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// C02: 判定 manifest 在 [nowMs] 时刻是否已过期（含未设置 expiresAtMs=0）。
  ///
  /// `nowMs >= expiresAtMs` 即过期（到期时刻当刻视为过期，保守取边界）；
  /// `expiresAtMs == 0`（wire JSON 缺失字段时的 fromJson 默认值）恒为过期
  /// —— fail-closed：没有过期时间的 manifest 不被信任。
  bool isExpiredAt(int nowMs) => nowMs >= expiresAtMs;

  /// C02: 显式过期守卫。已过期（或未设置过期时间）→ 抛
  /// [ManifestValidityException]（显式兼容错误，调用方不得静默继续）。
  ///
  /// 背景：旧 manifest 重放攻击中签名依然有效（设备确实签过），
  /// 签名验证无法防御时间维度的重放，必须单独校验。
  void ensureNotExpired({required int nowMs}) {
    if (isExpiredAt(nowMs)) {
      throw ManifestValidityException(
        'manifest expired or expiresAtMs missing (replay suspect): '
        'device=$deviceId expiresAtMs=$expiresAtMs nowMs=$nowMs',
      );
    }
  }

  /// C02: 本 manifest 的规范哈希 —— SHA-256 over [canonicalBytes]，
  /// base64Url 编码。作为 [previousManifestHash] 链的节点值。
  ///
  /// 不含签名本身（canonical bytes 排除签名字段），因此对同一被签内容
  /// 稳定不变，可用于链式后继校验。
  String manifestHash() =>
      base64Url.encode(sha256.convert(canonicalBytes()).bytes);

  /// C02: 链式后继校验（防旧 manifest 重放）。
  ///
  /// 客户端已知当前 manifest 哈希 [currentManifestHash] 时，新到达的
  /// [incoming] 必须满足其一，否则视为断链或旧 manifest 重放并抛
  /// [ManifestValidityException]：
  /// 1. `incoming.manifestHash() == currentManifestHash`（同一 manifest
  ///    重投，幂等接受）；
  /// 2. `incoming.previousManifestHash == currentManifestHash`（合法后继）。
  ///
  /// 旧 manifest 重放（哈希既不等于当前值、又不链接到当前值）与
  /// genesis 冒充后继（`previousManifestHash == null`）均被拒绝。
  static void ensureChainLinked(
    DeviceManifest incoming,
    String currentManifestHash,
  ) {
    if (incoming.manifestHash() == currentManifestHash) {
      return; // 幂等重投
    }
    final prev = incoming.previousManifestHash;
    if (prev != null && prev == currentManifestHash) {
      return; // 合法后继
    }
    throw ManifestValidityException(
      'manifest chain break or replay: device=${incoming.deviceId} '
      'previousManifestHash=$prev expected=$currentManifestHash',
    );
  }

  /// Validates key structures strictly by decoding and checking exact sizes.
  /// Throws [FormatException] if any key is invalid.
  static void validateKeys(String ed25519Base64, String curve25519Base64) {
    try {
      final edBytes = _safeDecodeBase64(ed25519Base64);
      if (edBytes.length != 32) {
        throw const FormatException('ed25519 key must be 32 bytes');
      }
    } catch (_) {
      throw const FormatException('invalid ed25519 key');
    }

    try {
      final curveBytes = _safeDecodeBase64(curve25519Base64);
      if (curveBytes.length != 32) {
        throw const FormatException('curve25519 key must be 32 bytes');
      }
    } catch (_) {
      throw const FormatException('invalid curve25519 key');
    }
  }

  /// Securely decodes base64 keys, supporting both standard and url-safe formats.
  static Uint8List _safeDecodeBase64(String value) {
    final normalized = base64.normalize(
      value.replaceAll('-', '+').replaceAll('_', '/'),
    );
    return base64.decode(normalized);
  }

  /// Helper to copy with new fields.
  DeviceManifest copyWith({
    int? manifestVersion,
    String? uid,
    String? deviceId,
    int? deviceGeneration,
    int? identityVersion,
    String? ed25519,
    String? curve25519,
    String? mlsCredential,
    Set<String>? capabilities,
    int? createdAtMs,
    int? expiresAtMs,
    String? previousManifestHash,
    String? deviceSignature,
    String? accountSignature,
  }) {
    return DeviceManifest(
      manifestVersion: manifestVersion ?? this.manifestVersion,
      uid: uid ?? this.uid,
      deviceId: deviceId ?? this.deviceId,
      deviceGeneration: deviceGeneration ?? this.deviceGeneration,
      identityVersion: identityVersion ?? this.identityVersion,
      ed25519: ed25519 ?? this.ed25519,
      curve25519: curve25519 ?? this.curve25519,
      mlsCredential: mlsCredential ?? this.mlsCredential,
      capabilities: capabilities ?? this.capabilities,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      expiresAtMs: expiresAtMs ?? this.expiresAtMs,
      previousManifestHash: previousManifestHash ?? this.previousManifestHash,
      deviceSignature: deviceSignature ?? this.deviceSignature,
      accountSignature: accountSignature ?? this.accountSignature,
    );
  }
}
