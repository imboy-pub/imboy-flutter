/// E2EE 加密处理器
///
/// 负责消息的端到端加密、解密操作
/// 从 ChatNotifier 中提取，遵循单一职责原则（SRP）
library;

import 'dart:convert';

import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// E2EE 加密结果
class E2EEncryptResult {
  /// 加密成功
  final bool success;

  /// E2EE 元数据
  final Map<String, dynamic>? e2eeMetadata;

  /// 加密后的密文
  final String? ciphertext;

  /// 错误信息
  final String? errorMessage;

  const E2EEncryptResult._({
    required this.success,
    this.e2eeMetadata,
    this.ciphertext,
    this.errorMessage,
  });

  /// 成功结果
  factory E2EEncryptResult.success({
    required Map<String, dynamic> e2eeMetadata,
    required String ciphertext,
  }) {
    return E2EEncryptResult._(
      success: true,
      e2eeMetadata: e2eeMetadata,
      ciphertext: ciphertext,
    );
  }

  /// 失败结果
  factory E2EEncryptResult.failure(String errorMessage) {
    return E2EEncryptResult._(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

/// E2EE 解密结果
class E2EEDecryptResult {
  /// 解密成功
  final bool success;

  /// 解密后的明文
  final Map<String, dynamic>? plaintext;

  /// 错误信息
  final String? errorMessage;

  const E2EEDecryptResult._({
    required this.success,
    this.plaintext,
    this.errorMessage,
  });

  /// 成功结果
  factory E2EEDecryptResult.success(Map<String, dynamic> plaintext) {
    return E2EEDecryptResult._(
      success: true,
      plaintext: plaintext,
    );
  }

  /// 失败结果
  factory E2EEDecryptResult.failure(String errorMessage) {
    return E2EEDecryptResult._(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

/// E2EE 加密处理器
///
/// 封装所有端到端加密相关逻辑，包括：
/// - 消息加密
/// - 消息解密
/// - 密钥管理
class ChatE2EEHandler {
  /// 单例实例
  static final ChatE2EEHandler _instance = ChatE2EEHandler._internal();

  factory ChatE2EEHandler() => _instance;

  ChatE2EEHandler._internal();

  /// 检查是否需要加密
  ///
  /// [chatType] 聊天类型（C2C/C2G/C2S）
  /// [payload] 消息负载
  /// [action] 消息动作（action 消息不加密）
  bool shouldEncrypt(String chatType, Map<String, dynamic> payload, String action) {
    return action.isEmpty && E2EEService.shouldEncryptOutgoingPayload(chatType, payload);
  }

  /// 加密消息
  ///
  /// [chatType] 聊天类型
  /// [recipientId] 接收方 ID（用户 ID 或群 ID）
  /// [payload] 明文负载
  Future<E2EEncryptResult> encrypt(
    String chatType,
    String recipientId,
    Map<String, dynamic> payload,
  ) async {
    try {
      // 获取接收方设备公钥
      final deviceKeys = await _getDeviceKeys(chatType, recipientId);
      final didToPem = deviceKeys['didToPem'] ?? {};

      if (didToPem.isEmpty) {
        return E2EEncryptResult.failure('no_recipient_keys');
      }

      // 构造接收方设备列表
      final recipients = <RecipientDevice>[];
      for (final entry in didToPem.entries) {
        recipients.add(RecipientDevice(
          deviceId: entry.key,
          keyId: entry.key,
          publicKey: entry.value,
        ));
      }

      // 构造明文
      final plaintext = jsonEncode(payload);

      // 调用加密服务
      final result = await E2EEService.buildE2EEData(
        plaintext: plaintext,
        recipients: recipients,
      );

      return E2EEncryptResult.success(
        e2eeMetadata: result['e2ee'] as Map<String, dynamic>,
        ciphertext: result['ciphertext'] as String,
      );
    } catch (e) {
      return E2EEncryptResult.failure(_getErrorMessage(e));
    }
  }

  /// 解密消息
  ///
  /// [e2eeMetadata] E2EE 元数据
  /// [ciphertext] 密文
  /// [msgId] 消息 ID
  /// [msgType] 消息类型
  /// [fromUid] 发送方 UID
  /// [toUid] 接收方 UID
  /// [createdAt] 创建时间
  Future<E2EEDecryptResult> decrypt({
    required Map<String, dynamic> e2eeMetadata,
    required String ciphertext,
    required String msgId,
    required String msgType,
    required String fromUid,
    required String toUid,
    required int createdAt,
  }) async {
    try {
      // 构建完整的 payload 用于解密
      final fullPayload = {
        'e2ee': e2eeMetadata,
        'payload': ciphertext,
      };

      // 使用 decryptIncomingPayload 方法解密
      final plaintextMap = await E2EEService.decryptIncomingPayload(
        msgId: msgId,
        msgType: msgType,
        fromUid: fromUid,
        toUid: toUid,
        createdAt: createdAt,
        payload: fullPayload,
      );

      return E2EEDecryptResult.success(plaintextMap);
    } catch (e) {
      return E2EEDecryptResult.failure(_getErrorMessage(e));
    }
  }

  /// 获取设备公钥
  Future<Map<String, dynamic>> _getDeviceKeys(
    String chatType,
    String recipientId,
  ) async {
    return chatType == 'C2G'
        ? await E2EEService.getGroupDevicePublicKeys(recipientId)
        : await E2EEService.getUserDevicePublicKeys(recipientId);
  }

  /// 获取用户友好的错误消息
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('no_recipient_keys') ||
        errorStr.contains('设备密钥') ||
        errorStr.contains('device.*key')) {
      return '无法获取对方设备密钥';
    }

    if (errorStr.contains('timeout') || errorStr.contains('超时')) {
      return '加密超时，请检查网络连接';
    }

    if (errorStr.contains('network') || errorStr.contains('网络')) {
      return '网络错误，加密失败';
    }

    if (errorStr.contains('invalid') || errorStr.contains('格式')) {
      return '消息格式错误';
    }

    return '端到端加密失败';
  }

  /// 检查 E2EE 状态
  ///
  /// 返回当前用户的 E2EE 状态信息
  Future<Map<String, dynamic>> getE2EEStatus() async {
    try {
      // 检查是否有设备密钥
      // 通过尝试获取当前用户设备公钥来检查
      final currentUid = UserRepoLocal.to.currentUid;
      if (currentUid.isEmpty) {
        return {
          'enabled': false,
          'deviceId': null,
          'status': 'not_logged_in',
        };
      }

      // 尝试获取设备公钥来验证 E2EE 是否已初始化
      final deviceKeys = await E2EEService.getUserDevicePublicKeys(currentUid);
      final didToPem = deviceKeys['didToPem'] ?? {};
      final hasKey = didToPem.isNotEmpty;

      return {
        'enabled': hasKey,
        'deviceCount': didToPem.length,
        'status': hasKey ? 'ready' : 'not_setup',
      };
    } catch (e) {
      return {
        'enabled': false,
        'deviceId': null,
        'status': 'error',
        'error': e.toString(),
      };
    }
  }

  /// 初始化 E2EE（如果未设置）
  Future<bool> ensureE2EEInitialized() async {
    try {
      final status = await getE2EEStatus();
      if (status['enabled'] == true) {
        return true;
      }

      // E2EE 通常在用户登录时自动初始化
      // 这里返回 false 表示需要用户重新登录或手动初始化
      return false;
    } catch (e) {
      return false;
    }
  }
}

/// E2EE 消息类型扩展
extension E2EEMessageExtension on Map<String, dynamic> {
  /// 检查是否是 E2EE 加密消息
  bool get isE2EEMessage {
    return this['e2ee'] != null && this['e2ee'] is Map;
  }

  /// 获取 E2EE 元数据
  Map<String, dynamic>? get e2eeMetadata {
    final e2ee = this['e2ee'];
    if (e2ee is Map<String, dynamic>) {
      return e2ee;
    }
    return null;
  }

  /// 获取密文（如果是 E2EE 消息）
  String? get ciphertext {
    final payload = this['payload'];
    if (payload is String) {
      return payload;
    }
    return null;
  }
}
