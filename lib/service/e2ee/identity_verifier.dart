/// P0-1: Olm identity key Ed25519 签名验证。
///
/// 签名语义：设备用自己的 Ed25519 私钥对 curve25519 公钥签名，
/// 证明两个密钥属于同一设备。对端在 X3DH 协商前验证此签名，
/// 防止服务端/MITM 替换公钥。
///
/// fail-closed：缺少任何必要字段 → 拒绝（不降级）。
library;

import 'package:vodozemac/vodozemac.dart' as vod;
import 'package:imboy/service/e2ee/device_manifest.dart';

/// identity 签名验证失败（MITM 检测 / 字段缺失 / 交叉绑定校验不通过）。
class IdentityVerificationException implements Exception {
  IdentityVerificationException(this.message);
  final String message;
  @override
  String toString() => 'IdentityVerificationException: $message';
}

/// 验证对端 identity map 中的 Ed25519 自签名。
///
/// [identity] 必须包含 `ed25519_key`、`curve25519_key`、`signature` 三个非空字段。
/// 验证 `signature` 是 `ed25519_key` 对 `curve25519_key` 的有效 Ed25519 签名。
///
/// 抛出 [IdentityVerificationException]：字段缺失或签名无效。
void verifyIdentitySignature(
  Map<String, dynamic> identity, {
  String context = '',
}) {
  final edPub = identity['ed25519_key']?.toString() ?? '';
  final c25519Pub = identity['curve25519_key']?.toString() ?? '';
  final sig = identity['signature']?.toString() ?? '';

  if (edPub.isEmpty || c25519Pub.isEmpty || sig.isEmpty) {
    throw IdentityVerificationException(
      'identity 签名缺失${context.isEmpty ? '' : '（$context）'}: '
      'ed25519=${edPub.isEmpty ? "missing" : "ok"} '
      'curve25519=${c25519Pub.isEmpty ? "missing" : "ok"} '
      'sig=${sig.isEmpty ? "missing" : "ok"}',
    );
  }

  try {
    vod.Ed25519PublicKey.fromBase64(edPub).verify(
      message: c25519Pub,
      signature: vod.Ed25519Signature.fromBase64(sig),
    );
  } catch (e) {
    throw IdentityVerificationException(
      'identity 签名验证失败${context.isEmpty ? '' : '（$context）'}: $e',
    );
  }
}

/// E2EE-022: 验证对端 [DeviceManifest] 的签名。
///
/// - 首先强制校验 Manifest 的设备自签名 (`device_signature`)。
/// - 如果提供了对端的 Master Signing Key [peerMasterKey]，则会一并验证
///   其 Account 主委派授权签名 (`account_signature`)，构建端到端的 Cross-signing 安全凭证验证。
///
/// 抛出 [IdentityVerificationException]：签名验证失败。
void verifyDeviceManifest(
  DeviceManifest manifest, {
  String? peerMasterKey,
  String context = '',
}) {
  // 1. 验证设备自签名
  if (!manifest.verifyDeviceSignature()) {
    throw IdentityVerificationException(
      'device_signature 验证失败${context.isEmpty ? '' : '（$context）'}',
    );
  }

  // 2. 若配置了 Master Key，强制校验 Account 主委派签名
  if (peerMasterKey != null && peerMasterKey.isNotEmpty) {
    if (!manifest.verifyAccountSignature(peerMasterKey)) {
      throw IdentityVerificationException(
        'account_signature 验证失败${context.isEmpty ? '' : '（$context）'}',
      );
    }
  }
}

/// E2EE-022: 强交叉约束绑定验证。
///
/// 强制比对对端的 [identity] 与 [manifest] 声明。
/// 确保服务端返回的用于 X3DH/Olm 密钥协商的 `curve25519_key` 与已签署 Manifest
/// 中的密码学身份字节一致，彻底杜绝自签名替换/篡改攻击。
///
/// 抛出 [IdentityVerificationException]：任何签名失败、字段或密钥不匹配。
void verifyIdentityWithManifest(
  Map<String, dynamic> identity,
  DeviceManifest manifest, {
  String? peerMasterKey,
  String context = '',
}) {
  // 1. 验证对端 identity 的自签名
  verifyIdentitySignature(identity, context: context);

  // 2. 验证对端 DeviceManifest 的签名
  verifyDeviceManifest(
    manifest,
    peerMasterKey: peerMasterKey,
    context: context,
  );

  // 3. 强交叉绑定 (Cross-Binding Guard) — 比对公钥是否一致
  final identityEd25519 = identity['ed25519_key']?.toString() ?? '';
  final identityCurve25519 = identity['curve25519_key']?.toString() ?? '';

  if (identityEd25519 != manifest.ed25519) {
    throw IdentityVerificationException(
      'ed25519 密钥交叉绑定不一致${context.isEmpty ? '' : '（$context）'}: '
      'identity=$identityEd25519 manifest=${manifest.ed25519}',
    );
  }

  if (identityCurve25519 != manifest.curve25519) {
    throw IdentityVerificationException(
      'curve25519 密钥交叉绑定不一致${context.isEmpty ? '' : '（$context）'}: '
      'identity=$identityCurve25519 manifest=${manifest.curve25519}',
    );
  }
}
