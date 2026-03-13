import 'dart:convert';

import 'package:imboy/service/rsa.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_plus_api.dart';

/// E2EE 设备间传输服务
///
/// 处理密钥在设备间的安全传输：
/// - 创建传输会话
/// - 接受传输并导入密钥
/// - 确认传输完成
/// - 生成/解析二维码数据
///
/// @author Imboy Team
/// @since 2026-02-14
class E2EETransferService {
  static final E2EEPlusApi _api = E2EEPlusApi();

  /// 创建传输会话
  ///
  /// [toUid] 接收方用户 ID（HashID 编码）
  /// [encryptedKeyBundle] 使用目标用户公钥加密的密钥包
  /// Returns: { "session_id": "uuid", "expires_at": "2026-01-31T10:00:00Z" }
  static Future<Map<String, dynamic>> createTransfer({
    required String toUid,
    required String encryptedKeyBundle,
  }) async {
    try {
      return await _api.createTransferSession(
        toUid: toUid,
        encryptedKeyBundle: encryptedKeyBundle,
      );
    } catch (e) {
      throw Exception('创建传输会话失败: $e');
    }
  }

  /// 接受传输
  ///
  /// [sessionId] 会话 ID
  /// [deviceId] 新设备 ID
  /// Returns: { "session_id": "uuid", "from_uid": 123, "from_device_id": "xxx",
  ///            "encrypted_key_bundle": "base64...", "status": "accepted", "expires_at": "..." }
  static Future<Map<String, dynamic>> acceptTransfer({
    required String sessionId,
    required String deviceId,
  }) async {
    try {
      final data = await _api.acceptTransfer(
        sessionId: sessionId,
        deviceId: deviceId,
      );

      // 解密并保存私钥
      final encryptedBundle = data['encrypted_key_bundle'] as String;
      await _decryptAndSaveKey(encryptedBundle);

      return data;
    } catch (e) {
      throw Exception('接受传输失败: $e');
    }
  }

  /// 确认传输完成
  ///
  /// [sessionId] 会话 ID
  static Future<void> confirmTransfer({required String sessionId}) async {
    try {
      await _api.confirmTransfer(sessionId: sessionId);
    } catch (e) {
      throw Exception('确认传输失败: $e');
    }
  }

  /// 获取传输会话信息
  ///
  /// [sessionId] 会话 ID
  static Future<Map<String, dynamic>> getTransferInfo({
    required String sessionId,
  }) async {
    try {
      return await _api.getTransferInfo(sessionId: sessionId);
    } catch (e) {
      throw Exception('获取会话信息失败: $e');
    }
  }

  /// 获取待处理的传输列表
  ///
  /// Returns: 传输会话列表
  static Future<List<Map<String, dynamic>>> getPendingTransfers() async {
    try {
      return await _api.getPendingTransfers();
    } catch (e) {
      throw Exception('获取传输列表失败: $e');
    }
  }

  /// 解密并保存密钥
  ///
  /// [encryptedBundle] 加密的密钥包（Base64 编码）
  ///
  /// 使用当前设备的私钥解密传输的密钥包，并保存到安全存储
  static Future<void> _decryptAndSaveKey(String encryptedBundle) async {
    try {
      // 1. 获取当前设备的私钥对象
      final privateKey = await RSAService.privateKeyObject();

      // 2. Base64 解码加密数据
      final encryptedData = base64.decode(encryptedBundle);

      // 3. 使用 RSA-OAEP 解密
      final decryptedData = RSAService.rsaDecrypt(privateKey, encryptedData);

      // 4. 解析解密后的数据（应该是密钥包 JSON）
      final keyBundle =
          json.decode(utf8.decode(decryptedData)) as Map<String, dynamic>;

      // 5. 保存密钥信息
      final privateKeyStr = keyBundle['private_key'] as String?;
      final publicKeyStr = keyBundle['public_key'] as String?;
      final deviceId = keyBundle['device_id'] as String?;
      final keyId = keyBundle['key_id'] as String?;

      if (privateKeyStr == null || publicKeyStr == null) {
        throw Exception('密钥包格式无效：缺少密钥数据');
      }

      // 6. 保存到安全存储
      final storage = StorageSecureService.to;
      await storage.savePrivateKey(privateKeyStr);
      await storage.savePublicKey(publicKeyStr);
      if (deviceId != null) {
        await storage.setDeviceId(deviceId);
      }
      if (keyId != null) {
        await storage.setKeyId(keyId);
      }
    } catch (e) {
      throw Exception('解密密钥失败: $e');
    }
  }

  /// 加密密钥包
  ///
  /// [keyBundle] 密钥数据 Map
  /// [publicKeyPem] 目标设备的公钥 PEM
  /// Returns: Base64 编码的加密数据
  static Future<String> encryptKeyBundle(
    Map<String, dynamic> keyBundle,
    String publicKeyPem,
  ) async {
    try {
      // 1. 序列化为 JSON
      final jsonString = json.encode(keyBundle);
      final plaintext = base64.encode(utf8.encode(jsonString));

      // 2. 使用 RSA 服务加密
      final encrypted = await RSAService.rsaEncryptWithPointyCastleAsync(
        plaintext,
        publicKeyPem,
      );

      return encrypted;
    } catch (e) {
      throw Exception('加密密钥包失败: $e');
    }
  }

  /// 生成二维码数据
  ///
  /// 将会话 ID 和其他信息编码为二维码
  static String generateQRCodeData(
    String sessionId, {
    Map<String, dynamic>? extra,
  }) {
    final data = {
      'type': 'e2ee_transfer',
      'session_id': sessionId,
      if (extra != null) ...extra,
    };
    return jsonEncode(data);
  }

  /// 解析二维码数据
  ///
  /// [qrData] 二维码字符串
  static Map<String, dynamic>? parseQRCodeData(String qrData) {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      if (data['type'] == 'e2ee_transfer') {
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
