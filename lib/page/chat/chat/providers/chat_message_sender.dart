/// 消息发送处理器
///
/// 负责消息的发送、重试、状态更新等操作
/// 从 ChatNotifier 中提取，遵循单一职责原则（SRP）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 消息发送结果
enum MessageSendResult {
  /// 发送成功
  success,

  /// 发送失败
  failed,

  /// 需要重试
  retry,

  /// 已取消
  cancelled,
}

/// 消息发送处理器
///
/// 封装所有消息发送相关逻辑，包括：
/// - 消息格式转换
/// - E2EE 加密
/// - WebSocket 发送
/// - 重试机制
class ChatMessageSender {
  /// 发送消息
  ///
  /// [obj] 消息模型
  /// 返回发送结果
  Future<MessageSendResult> send(MessageModel obj) async {
    // 状态检查
    if (obj.status != IMBoyMessageStatus.sending) {
      return MessageSendResult.success;
    }

    // 构建发送数据
    final clientSendTs = DateTimeHelper.millisecond();
    Map<String, dynamic> payloadWithTs = Map<String, dynamic>.from(obj.payload);
    payloadWithTs['client_send_ts'] = clientSendTs;

    // 获取消息类型和动作
    String msgType = obj.msgType ?? '';
    String action = obj.action ?? '';
    Map<String, dynamic>? e2ee;
    dynamic finalPayload;

    // 检查是否需要加密
    final needEncrypt = action.isEmpty &&
        E2EEService.shouldEncryptOutgoingPayload(
          obj.type ?? 'C2C',
          payloadWithTs,
        );

    if (needEncrypt) {
      final encryptResult = await _encryptPayload(obj, payloadWithTs);
      if (encryptResult == null) {
        // 加密失败，返回需要重试
        return MessageSendResult.retry;
      }
      e2ee = encryptResult['e2ee'];
      finalPayload = encryptResult['ciphertext'];
    } else {
      finalPayload = payloadWithTs;
    }

    // 构建 WebSocket 消息
    final msg = _buildWebSocketMessage(
      obj: obj,
      msgType: msgType,
      action: action,
      e2ee: e2ee,
      payload: finalPayload,
    );

    // 发送消息
    return await _sendWithRetry(obj.id!, msg);
  }

  /// 直接发送消息（不经过数据库）
  ///
  /// [msg] 完整的消息对象
  Future<bool> sendMessageDirect(Map<String, dynamic> msg) async {
    final msgType = msg['type']?.toString() ?? '';
    final msgAction = msg['action']?.toString() ?? '';
    final originalPayload = msg['payload'];

    // 设置顶层字段
    if (!msg.containsKey('msg_type') && originalPayload is Map) {
      msg['msg_type'] = originalPayload['msg_type']?.toString() ?? '';
    }
    if (!msg.containsKey('action')) {
      msg['action'] = msgAction;
    }

    if (originalPayload is Map) {
      final payload = Map<String, dynamic>.from(originalPayload);

      // 检查是否需要加密
      final needEncrypt = msgAction.isEmpty &&
          E2EEService.shouldEncryptOutgoingPayload(msgType, payload);

      if (needEncrypt) {
        final toUid = msg['to']?.toString() ?? '';
        final encryptResult = await _encryptPayloadForDirect(
          msgType,
          toUid,
          payload,
        );

        if (encryptResult == null) {
          return false;
        }

        msg['e2ee'] = encryptResult['e2ee'];
        msg['payload'] = encryptResult['ciphertext'];
      } else {
        // 清理冗余字段
        final cleanPayload = Map<String, dynamic>.from(payload)
          ..remove('msg_type')
          ..remove('action')
          ..remove('e2ee');
        msg['payload'] = cleanPayload;
      }
    }

    // 发送消息
    AppEventBus.fire(
      WebSocketMessageSendRequestEvent(
        message: json.encode(msg),
        messageId: msg['id']?.toString(),
      ),
    );

    final msgId = msg['id']?.toString();
    if (msgId != null && msgId.isNotEmpty) {
      final type = msg['type']?.toString() ?? 'C2C';
      MessageRetry.to.addToRetryQueue(msgId, type);
    }

    return true;
  }

  /// 加密消息负载
  Future<Map<String, dynamic>?> _encryptPayload(
    MessageModel obj,
    Map<String, dynamic> payload,
  ) async {
    try {
      // 获取接收方设备公钥
      final deviceKeys = await (obj.type == 'C2G'
          ? E2EEService.getGroupDevicePublicKeys(obj.toId ?? '')
          : E2EEService.getUserDevicePublicKeys(obj.toId ?? ''));

      final didToPem = deviceKeys['didToPem'] ?? {};
      if (didToPem.isEmpty) {
        throw Exception('no_recipient_keys');
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
      final plaintextPayload = Map<String, dynamic>.from(obj.payload);
      final plaintext = jsonEncode(plaintextPayload);

      // 调用加密方法
      final result = await E2EEService.buildE2EEData(
        plaintext: plaintext,
        recipients: recipients,
      );

      return {
        'e2ee': result['e2ee'] as Map<String, dynamic>,
        'ciphertext': result['ciphertext'] as String,
      };
    } catch (e) {
      // 加密失败
      return null;
    }
  }

  /// 为直接发送的消息加密
  Future<Map<String, dynamic>?> _encryptPayloadForDirect(
    String msgType,
    String toUid,
    Map<String, dynamic> payload,
  ) async {
    try {
      final deviceKeys = await (msgType == 'C2G'
          ? E2EEService.getGroupDevicePublicKeys(toUid)
          : E2EEService.getUserDevicePublicKeys(toUid));

      final didToPem = deviceKeys['didToPem'] ?? {};
      if (didToPem.isEmpty) {
        throw Exception('no_recipient_keys');
      }

      final recipients = <RecipientDevice>[];
      for (final entry in didToPem.entries) {
        recipients.add(RecipientDevice(
          deviceId: entry.key,
          keyId: entry.key,
          publicKey: entry.value,
        ));
      }

      final plaintextPayload = Map<String, dynamic>.from(payload)
        ..remove('msg_type');
      final plaintext = jsonEncode(plaintextPayload);

      final result = await E2EEService.buildE2EEData(
        plaintext: plaintext,
        recipients: recipients,
      );

      return {
        'e2ee': result['e2ee'] as Map<String, dynamic>,
        'ciphertext': result['ciphertext'] as String,
      };
    } catch (e) {
      return null;
    }
  }

  /// 构建 WebSocket 消息
  Map<String, dynamic> _buildWebSocketMessage({
    required MessageModel obj,
    required String msgType,
    required String action,
    Map<String, dynamic>? e2ee,
    required dynamic payload,
  }) {
    return {
      'id': obj.id,
      'type': obj.type,
      'from': obj.fromId,
      'to': obj.toId,
      'msg_type': msgType,
      'action': action,
      'e2ee': e2ee,
      'payload': payload,
      'created_at': obj.createdAt,
    };
  }

  /// 带重试机制的发送
  Future<MessageSendResult> _sendWithRetry(
    String messageId,
    Map<String, dynamic> msg,
  ) async {
    try {
      // 通过事件总线发送
      AppEventBus.fire(
        WebSocketMessageSendRequestEvent(
          message: json.encode(msg),
          messageId: messageId,
        ),
      );

      // 添加到重试队列
      final type = msg['type']?.toString() ?? 'C2C';
      MessageRetry.to.addToRetryQueue(messageId, type);

      return MessageSendResult.success;
    } catch (e) {
      return MessageSendResult.failed;
    }
  }

  /// 从 UI 消息转换为数据模型
  ///
  /// WebSocket API v2.0: msg_type 字段提升到顶层
  MessageModel convertFromUIMessage(
    String type,
    String conversationUk3,
    Message message,
  ) {
    // 空值验证
    if (message.id.isEmpty) {
      throw ArgumentError('Message ID cannot be empty');
    }
    if (message.authorId.isEmpty) {
      throw ArgumentError('Message authorId cannot be empty');
    }
    if (message.createdAt == null) {
      throw ArgumentError('Message createdAt cannot be null');
    }

    Map<String, dynamic> payload = {};
    final metadata = message.metadata ?? <String, dynamic>{};
    String msgType = '';

    // 根据消息类型构建 payload
    if (message is TextMessage) {
      msgType = 'text';
      payload = {"text": message.text};
    } else if (message is ImageMessage) {
      msgType = 'image';
      payload = {
        "name": message.text,
        "text": message.text,
        "size": message.size,
        "uri": message.source,
        "width": message.width,
        "height": message.height,
        "thumbhash": message.thumbhash,
      };
    } else if (message is FileMessage) {
      msgType = 'file';
      payload = {
        "name": message.name,
        "text": message.name,
        "size": message.size,
        "uri": message.source,
        "mime_type": message.mimeType,
        "md5": message.metadata?['md5'],
      };
    } else if (message is VideoMessage) {
      msgType = 'video';
      payload = {
        "name": message.name ?? (message.text ?? ''),
        "size": message.size,
        "uri": message.source,
        "width": message.width,
        "height": message.height,
      };
      if (message.text != null) {
        payload['text'] = message.text;
      }
    } else if (message is AudioMessage) {
      msgType = 'voice';
      payload = {
        "uri": message.source,
        "duration_ms": message.duration.inMilliseconds,
        "size": message.size,
      };
      if (message.text != null) {
        payload['name'] = message.text;
      }
      if (message.waveform != null) {
        payload['waveform'] = message.waveform;
      }
    } else if (message is CustomMessage) {
      msgType = 'custom';
      final cleanMetadata = Map<String, dynamic>.from(message.metadata ?? {})
        ..remove('msg_type')
        ..remove('action')
        ..remove('e2ee');
      payload = cleanMetadata;
    } else {
      msgType = 'unsupported';
      payload = {
        'error': 'unknown_message_type',
        'runtime_type': message.runtimeType.toString(),
      };
    }

    // 添加 metadata
    _cleanAndAddMetadata(payload, metadata);

    return MessageModel(
      message.id,
      autoId: 0,
      type: type,
      fromId: message.authorId,
      toId: message.metadata?['peer_id'] ?? '',
      payload: payload,
      createdAt: message.createdAt!.millisecondsSinceEpoch,
      isAuthor: message.authorId == UserRepoLocal.to.currentUid ? 1 : 0,
      conversationUk3: conversationUk3,
      status: IMBoyMessageStatus.sending,
      msgType: msgType,
      action: '',
    );
  }

  /// 清理并添加 metadata
  void _cleanAndAddMetadata(
    Map<String, dynamic> payload,
    Map<String, dynamic> metadata,
  ) {
    final cleanMetadata = Map<String, dynamic>.from(metadata)
      ..remove('msg_type')
      ..remove('action')
      ..remove('e2ee');
    payload.addAll(cleanMetadata);
  }
}
