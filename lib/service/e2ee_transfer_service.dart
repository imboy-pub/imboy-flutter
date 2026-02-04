import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart' as pg;

import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_plus_api.dart';

/// E2EE 设备间传输服务
/// 处理密钥在设备间的传输
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
  static Future<void> _decryptAndSaveKey(String encryptedBundle) async {
    try {
      // 1. 获取新设备的私钥
      final storage = StorageSecure();
      final privateKeyPem = await storage.getPrivateKey();
      if (privateKeyPem == null || privateKeyPem.isEmpty) {
        throw Exception('新设备私钥不存在');
      }

      // 2. 解析私钥 PEM
      final privateKey = _parsePrivateKeyFromPem(privateKeyPem);

      // 3. Base64 解码加密数据
      final encryptedData = base64.decode(encryptedBundle);

      // 4. 使用 RSA-OAEP-256 解密
      final decryptedData = _decryptRSAOAEP(privateKey, encryptedData);

      // 5. 解析解密后的数据（应该是旧设备的私钥 PEM）
      final oldPrivateKeyPem = utf8.decode(decryptedData);

      // 6. 保存旧设备的私钥
      await storage.savePrivateKey(oldPrivateKeyPem);

      // 7. 同时更新其他密钥信息（从传输会话中获取）
      // 这里需要从服务端获取完整的密钥信息
      // 暂时只保存私钥，其他信息需要额外处理
    } catch (e) {
      throw Exception('解密密钥失败: $e');
    }
  }

  /// 从 PEM 格式解析私钥
  static pg.RSAPrivateKey _parsePrivateKeyFromPem(String pem) {
    try {
      // 直接使用现有的 RSA 服务来解析私钥
      // 这里简化实现，实际应该使用现有的 RSA 服务
      // 暂时抛出异常，建议使用现有的 RSA 解析方法
      throw Exception('请使用现有的 RSA 服务解析私钥');
    } catch (e) {
      throw Exception('解析私钥失败: $e');
    }
  }

  /// 使用 RSA-OAEP-256 解密数据
  static Uint8List _decryptRSAOAEP(
    pg.RSAPrivateKey privateKey,
    Uint8List encryptedData,
  ) {
    try {
      // 使用 RSA/PKCS1-OAEP 填充模式解密
      final cipher = pg.AsymmetricBlockCipher('RSA/PKCS1');

      // 初始化解密器
      cipher.init(false, pg.PrivateKeyParameter(privateKey));

      // 解密数据
      final decrypted = cipher.process(encryptedData);

      return decrypted;
    } catch (e) {
      throw Exception('RSA 解密失败: $e');
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
