/// P0-1: Olm identity key Ed25519 签名验证。
///
/// 签名语义：设备用自己的 Ed25519 私钥对 curve25519 公钥签名，
/// 证明两个密钥属于同一设备。对端在 X3DH 协商前验证此签名，
/// 防止服务端/MITM 替换公钥。
///
/// fail-closed：缺少任何必要字段 → 拒绝（不降级）。
library;

import 'package:vodozemac/vodozemac.dart' as vod;

/// identity 签名验证失败（MITM 检测 / 字段缺失）。
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
