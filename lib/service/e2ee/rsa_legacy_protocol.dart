/// RsaLegacyProtocol —— v1 RSA-OAEP + AES-GCM 套件的 [E2eeSessionProtocol] 实现
/// （ADR 02 §2.2 / §5.2 / B.2）。**仅 decrypt**：历史消息回看，不再用于新加密。
///
/// decrypt 逻辑迁移自 `e2ee_service.dart` 的 decryptE2EEMessage RSA 内联分支
/// （原 :347-414）：解析 `base64(nonce).base64(ct)` → 校验 nonce → 在 keys 里按
/// `did == 本机 deviceId` 找到自己的条目 → 用 kid 取本地私钥 PEM → RSA 解出 AES
/// 密钥 → AES-256-GCM 解出明文。
///
/// **aad 透传约定**：ADR 02 §2.1 冻结的 [decrypt] 接口无 aad 参数；业务层
/// （decryptE2EEMessage）将其 aad 注入 `metadata['aad']`（运行时瞬态键，非 wire
/// 格式），本实现按需读取。Olm/Megolm 不读该键。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/rsa.dart';
import 'package:imboy/service/storage_secure.dart';

class RsaLegacyProtocol implements E2eeSessionProtocol {
  RsaLegacyProtocol();

  @override
  ProtocolSuite get suite => ProtocolSuite.rsa;

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {
    // v1 设备公钥上报由既有 E2EEApi().reportDeviceKey 负责（登录流程），此处 no-op。
  }

  /// RSA 新加密已废弃（ADR 02 §5.2 防降级）。协商层不会选中 rsa-oaep 做新加密，
  /// 一旦被调用即防御性抛错。
  @override
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  }) => throw UnsupportedError(
    'RSA-OAEP legacy suite is decrypt-only; new encryption disabled '
    '(ADR 02 §5.2 anti-downgrade)',
  );

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async {
    // 1. 解析 ciphertext（格式：base64(nonce).base64(ciphertext)）
    final parts = ciphertext.split('.');
    if (parts.length != 2) {
      throw const E2eeDecryptException('invalid_ciphertext_format');
    }
    final nonceBase64 = parts[0];
    final ct = parts[1];

    // 2. 校验 nonce（与 e2ee 元数据比对）
    final e2eeNonce = metadata['nonce']?.toString();
    if (e2eeNonce != null && e2eeNonce.isNotEmpty && e2eeNonce != nonceBase64) {
      throw const E2eeDecryptException('nonce_mismatch');
    }

    // 3. 找到当前设备的密钥条目
    final keys = metadata['keys'] as List?;
    if (keys == null || keys.isEmpty) {
      throw const E2eeDecryptException('invalid_keys');
    }
    final myKey = keys
        .whereType<Map<dynamic, dynamic>>()
        .map((x) => x.cast<String, dynamic>())
        .cast<Map<String, dynamic>?>()
        .firstWhere((k) => k?['did'] == deviceId, orElse: () => null);
    if (myKey == null) {
      throw const E2eeDecryptException('no_device_key');
    }

    // 4. RSA 解出 AES 密钥
    final ekB64 = myKey['ek']?.toString() ?? '';
    if (ekB64.isEmpty) {
      throw const E2eeDecryptException('no_device_key');
    }
    final kid = myKey['kid']?.toString() ?? '';
    final privateKeyPem = await StorageSecureService.to.getPrivateKeyByKid(kid);
    if (privateKeyPem == null || privateKeyPem.isEmpty) {
      throw const E2eeDecryptException('no_device_key');
    }

    try {
      final encKeyBytes = base64.decode(base64.normalize(ekB64));
      final privateKeyObj = RSAService.parsePrivateKeyFromPem(privateKeyPem);
      final aesKey = RSAService.rsaDecrypt(
        privateKeyObj,
        Uint8List.fromList(encKeyBytes),
      );

      // 5. AES-256-GCM 解密（nonceBase64 作 IV，与加密时一致）
      final aad = metadata['aad']?.toString();
      final plainBytes = (aad != null && aad.isNotEmpty)
          ? EncrypterService.aesGcmDecryptBytes(
              nonceBase64,
              ct,
              aesKey,
              aad: Uint8List.fromList(utf8.encode(aad)),
            )
          : EncrypterService.aesGcmDecryptBytes(nonceBase64, ct, aesKey);
      return utf8.decode(plainBytes);
    } on E2eeDecryptException {
      rethrow;
    } catch (_) {
      throw const E2eeDecryptException('decrypt_error');
    }
  }

  @override
  Future<void> clearAll() async {
    // v1 私钥由 StorageSecureService 管理，退出登录走全量 wipe 兜底。
  }
}
