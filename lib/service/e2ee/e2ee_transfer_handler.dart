/// E2EE 设备间传输处理器
///
/// 封装设备间密钥传输的完整业务流程：
/// - 创建传输会话
/// - 接受传输并导入密钥
/// - 确认传输完成
/// - 二维码生成/解析
/// - 密钥包加密/解密
///
/// @author ImBoy Team
/// @since 2026-02-14
library;

import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/e2ee_transfer_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_api.dart';

/// 传输会话状态
enum TransferSessionStatus {
  /// 待接受
  pending,

  /// 已接受
  accepted,

  /// 已完成
  completed,

  /// 已过期
  expired,

  /// 已取消
  cancelled,

  /// 失败
  failed,
}

/// 传输会话模型
class TransferSession {
  /// 会话 ID
  final String sessionId;

  /// 发送方 UID
  final String? fromUid;

  /// 发送方设备 ID
  final String? fromDeviceId;

  /// 接收方 UID
  final String toUid;

  /// 状态
  final TransferSessionStatus status;

  /// 过期时间
  final DateTime? expiresAt;

  /// 创建时间
  final DateTime createdAt;

  /// 额外元数据
  final Map<String, dynamic>? metadata;

  const TransferSession({
    required this.sessionId,
    this.fromUid,
    this.fromDeviceId,
    required this.toUid,
    required this.status,
    this.expiresAt,
    required this.createdAt,
    this.metadata,
  });

  factory TransferSession.fromJson(Map<String, dynamic> json) {
    return TransferSession(
      sessionId: json['session_id'] as String,
      fromUid: json['from_uid']?.toString(),
      fromDeviceId: json['from_device_id']?.toString(),
      toUid: json['to_uid'] as String,
      status: _parseStatus(json['status'] as String?),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'from_uid': fromUid,
      'from_device_id': fromDeviceId,
      'to_uid': toUid,
      'status': status.name,
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  static TransferSessionStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return TransferSessionStatus.pending;
      case 'accepted':
        return TransferSessionStatus.accepted;
      case 'completed':
        return TransferSessionStatus.completed;
      case 'expired':
        return TransferSessionStatus.expired;
      case 'cancelled':
        return TransferSessionStatus.cancelled;
      case 'failed':
        return TransferSessionStatus.failed;
      default:
        return TransferSessionStatus.pending;
    }
  }

  /// 检查会话是否已过期
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// 检查会话是否可接受
  bool get canAccept => status == TransferSessionStatus.pending && !isExpired;
}

/// 传输结果
class TransferResult {
  /// 是否成功
  final bool success;

  /// 会话信息（成功时）
  final TransferSession? session;

  /// 错误消息（失败时）
  final String? errorMessage;

  /// 错误代码
  final String? errorCode;

  const TransferResult._({
    required this.success,
    this.session,
    this.errorMessage,
    this.errorCode,
  });

  /// 成功结果
  factory TransferResult.success(TransferSession session) {
    return TransferResult._(success: true, session: session);
  }

  /// 失败结果
  factory TransferResult.failure(String errorMessage, {String? errorCode}) {
    return TransferResult._(
      success: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
    );
  }
}

/// E2EE 设备间传输处理器
///
/// 单例模式，提供设备间密钥传输的完整业务逻辑
class E2EETransferHandler {
  /// 单例实例
  static final E2EETransferHandler _instance = E2EETransferHandler._internal();

  factory E2EETransferHandler() => _instance;

  E2EETransferHandler._internal();

  // ================================================================
  // 发送方操作
  // ================================================================

  /// 创建传输会话
  ///
  /// [toUid] 接收方用户 ID
  /// [extraMetadata] 额外元数据（可选）
  ///
  /// 返回传输会话信息，包含 session_id 用于生成二维码
  Future<TransferResult> createTransferSession(
    String toUid, {
    Map<String, dynamic>? extraMetadata,
  }) async {
    try {
      // 1. 检查本地是否有有效的 E2EE 密钥
      final hasKey = await E2EEKeyService.hasKey();
      if (!hasKey) {
        return TransferResult.failure(
          '当前设备没有 E2EE 密钥，无法传输',
          errorCode: 'no_key',
        );
      }

      // 2. 获取当前设备的密钥信息
      final storage = StorageSecureService.to;
      final privateKey = await storage.getPrivateKey();
      final publicKey = await storage.getPublicKey();
      final deviceId = await storage.getDeviceId();
      final keyId = await storage.getKeyId();

      if (privateKey == null || publicKey == null) {
        return TransferResult.failure('密钥信息不完整', errorCode: 'incomplete_key');
      }

      // 3. 构建密钥包
      final keyBundle = {
        'private_key': privateKey,
        'public_key': publicKey,
        'device_id': deviceId ?? '',
        'key_id': keyId ?? '',
        'exported_at': DateTime.now().toUtc().toIso8601String(),
      };

      // 4. 获取目标用户的公钥用于加密
      final recipientKeys = await E2EEApi().userKeys(uid: toUid);
      if (recipientKeys.isEmpty) {
        return TransferResult.failure(
          '无法获取目标用户的公钥，请确认对方已开启 E2EE',
          errorCode: 'no_recipient_key',
        );
      }
      final recipientPublicKeyPem =
          recipientKeys.first['public_key'] as String?;
      if (recipientPublicKeyPem == null || recipientPublicKeyPem.isEmpty) {
        return TransferResult.failure(
          '目标用户的公钥无效',
          errorCode: 'invalid_recipient_key',
        );
      }

      // 使用接收方公钥加密密钥包（RSA-OAEP）
      final encryptedBundle = await E2EETransferService.encryptKeyBundle(
        keyBundle,
        recipientPublicKeyPem,
      );

      // 5. 调用服务创建传输会话
      final response = await E2EETransferService.createTransfer(
        toUid: toUid,
        encryptedKeyBundle: encryptedBundle,
      );

      // 6. 构建会话对象
      final session = TransferSession(
        sessionId: response['session_id'] as String,
        toUid: toUid,
        status: TransferSessionStatus.pending,
        expiresAt: response['expires_at'] != null
            ? DateTime.parse(response['expires_at'] as String)
            : null,
        createdAt: DateTime.now(),
        metadata: {'from_device_id': deviceId, ...?extraMetadata},
      );

      return TransferResult.success(session);
    } catch (e) {
      return TransferResult.failure(
        '创建传输会话失败: ${_getErrorMessage(e)}',
        errorCode: 'create_failed',
      );
    }
  }

  /// 生成传输二维码数据
  ///
  /// [session] 传输会话
  /// [extraData] 额外数据（可选）
  ///
  /// 返回可用于生成二维码的字符串
  String generateQRCodeData(
    TransferSession session, {
    Map<String, dynamic>? extraData,
  }) {
    return E2EETransferService.generateQRCodeData(
      session.sessionId,
      extra: {
        'from_device': session.metadata?['from_device_id'],
        'created_at': session.createdAt.toIso8601String(),
        ...?extraData,
      },
    );
  }

  // ================================================================
  // 接收方操作
  // ================================================================

  /// 解析二维码数据
  ///
  /// [qrData] 二维码字符串
  ///
  /// 返回解析后的数据，如果格式无效则返回 null
  Map<String, dynamic>? parseQRCodeData(String qrData) {
    return E2EETransferService.parseQRCodeData(qrData);
  }

  /// 接受传输
  ///
  /// [sessionId] 会话 ID
  /// [deviceId] 当前设备 ID
  ///
  /// 接受传输并自动导入密钥到本地
  Future<TransferResult> acceptTransfer(
    String sessionId, {
    String? deviceId,
  }) async {
    try {
      // 1. 获取当前设备 ID
      final storage = StorageSecureService.to;
      final currentDeviceId = deviceId ?? await storage.getDeviceId() ?? '';

      // 2. 调用服务接受传输
      final response = await E2EETransferService.acceptTransfer(
        sessionId: sessionId,
        deviceId: currentDeviceId,
      );

      // 3. 构建会话对象
      final session = TransferSession(
        sessionId: response['session_id'] as String,
        fromUid: response['from_uid']?.toString(),
        fromDeviceId: response['from_device_id']?.toString(),
        toUid: currentDeviceId,
        status: TransferSessionStatus.accepted,
        expiresAt: response['expires_at'] != null
            ? DateTime.parse(response['expires_at'] as String)
            : null,
        createdAt: DateTime.now(),
      );

      return TransferResult.success(session);
    } catch (e) {
      return TransferResult.failure(
        '接受传输失败: ${_getErrorMessage(e)}',
        errorCode: 'accept_failed',
      );
    }
  }

  /// 确认传输完成
  ///
  /// [sessionId] 会话 ID
  ///
  /// 确认密钥已成功导入，标记传输完成
  Future<TransferResult> confirmTransfer(String sessionId) async {
    try {
      await E2EETransferService.confirmTransfer(sessionId: sessionId);

      final session = TransferSession(
        sessionId: sessionId,
        toUid: '',
        status: TransferSessionStatus.completed,
        createdAt: DateTime.now(),
      );

      return TransferResult.success(session);
    } catch (e) {
      return TransferResult.failure(
        '确认传输失败: ${_getErrorMessage(e)}',
        errorCode: 'confirm_failed',
      );
    }
  }

  // ================================================================
  // 查询操作
  // ================================================================

  /// 获取传输会话信息
  ///
  /// [sessionId] 会话 ID
  Future<TransferResult> getTransferInfo(String sessionId) async {
    try {
      final response = await E2EETransferService.getTransferInfo(
        sessionId: sessionId,
      );

      final session = TransferSession.fromJson(response);
      return TransferResult.success(session);
    } catch (e) {
      return TransferResult.failure(
        '获取会话信息失败: ${_getErrorMessage(e)}',
        errorCode: 'get_info_failed',
      );
    }
  }

  /// 获取待处理的传输列表
  ///
  /// 返回所有等待接受的传输会话
  Future<List<TransferSession>> getPendingTransfers() async {
    try {
      final response = await E2EETransferService.getPendingTransfers();
      return response
          .map((json) => TransferSession.fromJson(json))
          .where((session) => session.canAccept)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ================================================================
  // 辅助方法
  // ================================================================

  /// 检查本地是否有 E2EE 密钥
  Future<bool> hasLocalKey() async {
    return E2EEKeyService.hasKey();
  }

  /// 获取本地密钥信息
  Future<Map<String, dynamic>?> getLocalKeyInfo() async {
    return E2EEKeyService.getKeyInfo();
  }

  /// 删除本地密钥
  ///
  /// ⚠️ 危险操作：删除后将无法解密历史消息
  Future<void> deleteLocalKey() async {
    await E2EEKeyService.deleteKey();
  }

  /// 生成新的 E2EE 密钥对
  Future<Map<String, dynamic>> generateNewKeyPair() async {
    return E2EEKeyService.generateKeyPair();
  }

  /// 获取用户友好的错误消息
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('网络')) {
      return '网络错误，请检查网络连接';
    }

    if (errorStr.contains('timeout') || errorStr.contains('超时')) {
      return '操作超时，请重试';
    }

    if (errorStr.contains('expired') || errorStr.contains('过期')) {
      return '传输会话已过期';
    }

    if (errorStr.contains('not_found') || errorStr.contains('未找到')) {
      return '传输会话不存在';
    }

    if (errorStr.contains('invalid') || errorStr.contains('无效')) {
      return '无效的请求';
    }

    return error.toString();
  }
}
