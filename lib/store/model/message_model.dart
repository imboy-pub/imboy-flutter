import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/chat/enum.dart' show CustomMessageType;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/assets.dart' show AssetsService;
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

// enum MsgType { custom, file, image, text, unsupported }

/// All possible statuses message can have.
// enum Status { delivered, error, seen, sending, sent }
class IMBoyMessageStatus {
  // 发送中
  static const int sending = 10;

  //  已发送
  static const int sent = 11;

  // 未读 已投递
  static const int delivered = 20;

  // 已读
  static const int seen = 21;

  // 错误（发送失败）
  static const int error = 41;
}

class ReEditMessage {
  final String text;
  final String? messageId; // 添加消息ID字段，用于编辑消息

  ReEditMessage({required this.text, this.messageId});
}

class MessageModel {
  int autoId;
  String? id;
  String? type; // 等价于 msg type: C2C C2G S2C 等等，根据type显示item
  String? fromId; // 等价于数据库的 from
  String? toId; // 等价于数据库的 to

  // WebSocket API v2.0 新增字段
  // 根据 type 决定是否存在：
  // - C2C/C2G/C2S: msgType 有值，action 为 null
  // - S2C: action 有值，msgType 为 null
  String? msgType; // 仅 C2C/C2G/C2S 消息有值, S2C 可能有值
  String? action; // 仅 S2C 消息有值
  Map<String, dynamic>? e2ee; // 仅 C2C/C2G 加密时有值

  // payload 类型改为 dynamic，支持 Map 或 String（加密后的 JSON 字符串）
  dynamic payload;
  int createdAt; // 消息创建时间 毫秒时间戳
  // type_userId_peerId
  String conversationUk3;

  // from id is author bool true | false
  int isAuthor;
  int topicId;

  // enum Status { delivered, error, seen, sending, sent }
  // MessageStatus status;
  // 10 发送中 sending;  11 已发送 send; 20 (未读 已投递) delivered;  21 已读 seen; 41 错误（发送失败） error;
  int? status;

  MessageModel(
    this.id, {
    required this.autoId,
    required this.type,
    required this.status,
    required this.fromId,
    required this.toId,
    required this.payload,
    required this.isAuthor,
    required this.conversationUk3,
    this.topicId = 0,
    this.createdAt = 0,
    this.msgType,
    this.action,
    this.e2ee,
  });

  factory MessageModel.fromJson(Map<String, dynamic> data) {
    // 解析 type
    final type = data[MessageRepo.type] as String? ?? 'C2C';

    // WebSocket API v2.0: 从顶层读取 msg_type、action、e2ee
    // 根据 type 决定读取哪些字段
    final msgType = type == 'S2C' ? null : (data['msg_type'] as String?);
    final action = type == 'S2C' ? (data['action'] as String?) : null;

    // 解析 e2ee 字段（仅 C2C/C2G 有）
    Map<String, dynamic>? e2eeData;
    if (type != 'S2C' && data['e2ee'] != null) {
      if (data['e2ee'] is String) {
        try {
          e2eeData = jsonDecode(data['e2ee']) as Map<String, dynamic>?;
        } catch (e) {
          debugPrint('MessageModel: e2ee 解析失败: $e');
        }
      } else if (data['e2ee'] is Map<String, dynamic>) {
        e2eeData = data['e2ee'] as Map<String, dynamic>;
      }
    }

    // 解析 payload - 支持 Map 或 String
    dynamic p;
    if (data[MessageRepo.payload] == null || data[MessageRepo.payload] == "") {
      p = <String, dynamic>{};
    } else if (data[MessageRepo.payload] is String) {
      // 尝试解析为 JSON
      try {
        p = jsonDecode("${data[MessageRepo.payload]}");
      } catch (e) {
        // 如果解析失败，保持为 String（可能是加密数据）
        p = data[MessageRepo.payload];
      }
    } else if (data[MessageRepo.payload] is Map<String, dynamic>) {
      p = data[MessageRepo.payload];
    } else {
      p = data[MessageRepo.payload];
    }

    return MessageModel(
      data[MessageRepo.id] ?? '',
      autoId: data[MessageRepo.autoId] ?? 0,
      type: type,
      status: int.parse('${data[MessageRepo.status] ?? 0}'),
      fromId: data[MessageRepo.from] ?? '',
      toId: data[MessageRepo.to] ?? '',
      payload: p,
      createdAt: DateTimeHelper.parseTimestamp(
        data[MessageRepo.createdAt],
        defaultValue: 0,
      ),
      isAuthor: data[MessageRepo.isAuthor] ?? 0,
      topicId: data[MessageRepo.topicId] ?? 0,
      conversationUk3: data[MessageRepo.conversationUk3] ?? '',
      msgType: msgType,
      action: action,
      e2ee: e2eeData,
    );
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = <String, dynamic>{};
    data[MessageRepo.id] = id;
    data[MessageRepo.autoId] = autoId;
    data[MessageRepo.type] = type;
    data[MessageRepo.status] = status;
    data[MessageRepo.from] = fromId;
    data[MessageRepo.to] = toId;
    data[MessageRepo.createdAt] = createdAt;
    data[MessageRepo.isAuthor] = isAuthor;
    data[MessageRepo.topicId] = topicId;
    data[MessageRepo.conversationUk3] = conversationUk3;

    // WebSocket API v2.0: 根据 type 写入对应字段到顶层
    final currentType = type ?? 'C2C';

    // 仅 C2C/C2G/C2S 消息写入 msg_type 和 e2ee
    if (currentType != 'S2C') {
      if (msgType != null) {
        data['msg_type'] = msgType;
      }
      if (e2ee != null && e2ee!.isNotEmpty) {
        data['e2ee'] = json.encode(e2ee);
      }
    }

    // 仅 S2C 消息写入 action
    if (currentType == 'S2C' && action != null) {
      data['action'] = action;
    }

    // payload 序列化
    if (payload is Map) {
      data[MessageRepo.payload] = json.encode(payload);
    } else if (payload is String) {
      data[MessageRepo.payload] = payload;
    } else {
      data[MessageRepo.payload] = json.encode(payload);
    }

    // debugPrint("> on MessageModel toMap $data");
    return data;
  }

  /// 10 发送中 sending;  11 已发送 sent;
  /// 20 未读 delivered;  21 已读 seen;
  /// 41 错误（发送失败） error;
  ///  enum MessageStatus { delivered, error, seen, sending, sent }
  MessageStatus get typesStatus {
    if (status == IMBoyMessageStatus.sending) {
      return MessageStatus.sending;
    } else if (status == IMBoyMessageStatus.sent) {
      return MessageStatus.sent;
    } else if (status == IMBoyMessageStatus.delivered) {
      return MessageStatus.delivered;
    } else if (status == IMBoyMessageStatus.seen) {
      return MessageStatus.seen;
    } else if (status == IMBoyMessageStatus.error) {
      return MessageStatus.error;
    }
    return MessageStatus.error;
  }

  CustomMessageType get customMsgType {
    // WebSocket API v2.0: 优先使用顶层的 msgType 字段
    final typeValue = msgType ?? (payload is Map ? payload['msg_type'] : null);

    if (typeValue == 'text') {
      return CustomMessageType.text;
    } else if (typeValue == 'text_stream') {
      return CustomMessageType.textStream;
    } else if (typeValue == 'image') {
      return CustomMessageType.image;
    } else if (typeValue == 'file') {
      return CustomMessageType.file;
    } else if (typeValue == 'custom') {
      return CustomMessageType.custom;
    } else if (typeValue == 'location') {
      return CustomMessageType.custom;
    } else if (typeValue == 'visit_card') {
      return CustomMessageType.custom;
    } else if (typeValue == 'revoked') {
      return CustomMessageType.custom;
    }

    return CustomMessageType.unsupported;
  }

  static String conversationMsgType(Message message) {
    if (message is TextMessage) {
      return 'text';
    } else if (message is ImageMessage) {
      return 'image';
    } else if (message is FileMessage) {
      return 'file';
    } else if (message is CustomMessage) {
      String msgType = message.metadata?['custom_type'] ?? 'unsupported';
      if (msgType == 'revoked') {
        // 检查是否有revoke_user字段，如果有则根据revoke_user判断撤回方
        final String revokeUser = message.metadata?['revoke_user'] ?? '';
        if (revokeUser.isNotEmpty) {
          return revokeUser == UserRepoLocal.to.currentUid
              ? 'my_revoked'
              : 'peer_revoked';
        }
        // 如果没有revoke_user字段，则根据authorId判断
        return UserRepoLocal.to.currentUid == message.authorId
            ? 'my_revoked'
            : 'peer_revoked';
      }
      return msgType;
    }
    return 'unsupported';
  }

  static String conversationSubtitle(Message message) {
    String subtitle = '';
    String customType = '';
    if (message is CustomMessage) {
      customType = message.metadata?['custom_type'] ?? '';
    }
    if (message is TextMessage) {
      subtitle = message.text;
    } else if (customType == "quote") {
      subtitle = message.metadata?['quote_text'] ?? '';
    } else if (customType == 'visit_card') {
      subtitle = message.metadata?['title'] ?? '';
    } else if (customType == 'location') {
      subtitle = message.metadata?['title'] ?? '';
    }
    return subtitle;
  }

  int toStatus(MessageStatus status) {
    if (status == MessageStatus.sending) {
      return IMBoyMessageStatus.sending;
    } else if (status == MessageStatus.sent) {
      return IMBoyMessageStatus.sent;
    } else if (status == MessageStatus.delivered) {
      return IMBoyMessageStatus.delivered;
    } else if (status == MessageStatus.seen) {
      return IMBoyMessageStatus.seen;
    } else if (status == MessageStatus.error) {
      return IMBoyMessageStatus.error;
    }
    return IMBoyMessageStatus.error;
  }

  Future<ContactModel?> get to async {
    return await ContactRepo().findByUid(toId!);
  }

  Future<ContactModel?> get from async {
    return await ContactRepo().findByUid(fromId!);
  }

  Future<Message> toTypeMessage() async {
    // WebSocket API v2.0: 兼容新的 payload 结构（可能是 Map 或 String）
    Map<String, dynamic> payloadData;

    if (payload is String) {
      // payload 是加密的 JSON 字符串（E2EE 消息）
      if (e2ee != null && e2ee!.isNotEmpty) {
        // 尝试解密 E2EE 消息
        try {
          final ciphertext = payload;
          final decryptedJson = await E2EEService.decryptE2EEMessage(
            ciphertext: ciphertext,
            e2ee: e2ee!,
          );
          payloadData = jsonDecode(decryptedJson) as Map<String, dynamic>;
          iPrint('✅ toTypeMessage: E2EE 解密成功，id=$id');
        } catch (e) {
          iPrint('⚠️ toTypeMessage: E2EE 解密失败，id=$id, error=$e');
          return TextMessage(
            authorId: fromId!,
            createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
            id: id!,
            text: '[加密消息]',
            status: MessageStatus.error,
            metadata: {
              'conversation_uk3': conversationUk3,
              'peer_id': toId,
              'msg_type': msgType ?? 'custom',
              '_e2ee_failed': true,
              '_e2ee_reason': 'decrypt_failed',
              '_e2ee_error': e.toString(),
            },
          );
        }
      } else {
        // payload 是 String 但没有 e2ee 元数据，尝试 JSON 解析（可能是旧数据）
        try {
          payloadData = jsonDecode(payload) as Map<String, dynamic>;
        } catch (e) {
          iPrint('⚠️ toTypeMessage: payload 解析失败，id=$id, error=$e');
          return TextMessage(
            authorId: fromId!,
            createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
            id: id!,
            text: '[加密消息]',
            status: MessageStatus.error,
            metadata: {
              'conversation_uk3': conversationUk3,
              'peer_id': toId,
              'error': 'encrypted_payload',
            },
          );
        }
      }
    } else if (payload is Map<String, dynamic>) {
      payloadData = payload;
    } else {
      iPrint('⚠️ toTypeMessage: payload 无效或为空，id=$id, payload=$payload');
      return TextMessage(
        authorId: fromId!,
        createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
        id: id!,
        text: '[无效消息]',
        status: MessageStatus.error,
        metadata: {
          'conversation_uk3': conversationUk3,
          'peer_id': toId,
          'error': 'invalid_payload',
        },
      );
    }

    // WebSocket API v2.0: 优先使用顶层的 msgType 字段
    final currentMsgType = msgType ?? payloadData['msg_type'];

    // 验证 msg_type 有效性
    if (currentMsgType == null || payloadData.isEmpty) {
      iPrint('⚠️ toTypeMessage: msg_type 无效或为空，id=$id, payload=$payload');
      return TextMessage(
        authorId: fromId!,
        createdAt: DateTimeHelper.millisecondToDateTime(createdAt),
        id: id!,
        text: '[无效消息]',
        status: MessageStatus.error,
        metadata: {
          'conversation_uk3': conversationUk3,
          'peer_id': toId,
          'error': 'invalid_msg_type',
        },
      );
    }

    String sysPrompt = payloadData['sys_prompt'] ?? '';
    Message? message;
    // enum MessageType { custom, file, image, text, unsupported }
    // WebSocket API v2.0: 将 msgType 添加到 metadata，供 UI 层使用
    Map<String, dynamic> metadata = {
      'conversation_uk3': conversationUk3,
      'sys_prompt': sysPrompt,
      'peer_id': toId,
      'msg_type': currentMsgType, // 添加 msg_type 到 metadata
    };
    String nickname = '';
    String avatar = '';
    if (fromId == UserRepoLocal.to.currentUid) {
      nickname = UserRepoLocal.to.current.nickname;
      avatar = UserRepoLocal.to.current.avatar;
    } else {
      ContactModel? cm = await ContactRepo().findByUid(fromId!);
      nickname = cm?.nickname ?? '';
      avatar = cm?.avatar ?? '';
    }
    User author = User(
      id: fromId!,
      imageSource: avatar,
      // payload['peer_name'] 目前只在收到撤回消息的时候才存在 peer_name
      name: nickname.isEmpty
          ? (payloadData['peer_name'] ?? (payloadData['quote_msg_author_name'] ?? ''))
          : nickname,
    );
    DateTime createdDt = DateTimeHelper.millisecondToDateTime(createdAt);

    // Handle null payload case
    if (currentMsgType == 'text') {
      message = TextMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: id!,
        // peerId: toId,
        text: payloadData['text'],
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (currentMsgType == 'image') {
      message = ImageMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: id!,
        // peerId: toId,
        text: payloadData['name'] ?? '',
        size: payloadData['size'] ?? 0,
        source: AssetsService.viewUrl(payloadData['uri'] ?? '').toString(),
        width: (payloadData['width'] ?? 0) / 1.0,
        height: (payloadData['height'] ?? 0) / 1.0,
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (currentMsgType == 'file') {
      message = FileMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: id!,
        // peerId: toId,
        name: payloadData['name'] ?? '',
        size: payloadData['size'] ?? 0,
        source: AssetsService.viewUrl(payloadData['uri'] ?? '').toString(),
        status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else if (payloadData['custom_type'] == 'revoked' ||
        payloadData['custom_type'] == 'peer_revoked' ||
        payloadData['custom_type'] == 'my_revoked' ||
        payloadData['custom_type'] == 'c2c_revoke') {
      message = CustomMessage(
        authorId: author.id,
        id: id!,
        createdAt: createdDt,
        // peerId: toId,
        metadata: {...metadata, ...payloadData},
      );
    } else if (payloadData['custom_type'] == 'quote') {
      message = CustomMessage(
        authorId: author.id,
        id: id!,
        createdAt: createdDt,
        // peerId: toId,
        metadata: {...metadata, ...payloadData},
      );
    } else if (currentMsgType == 'custom') {
      message = CustomMessage(
        authorId: author.id,
        id: id!,
        createdAt: createdDt,
        // peerId: toId,
        // status: typesStatus,
        metadata: {...metadata, ...payloadData},
      );
    } else {
      // Fallback case for unknown message types
      message = CustomMessage(
        authorId: author.id,
        id: id!,
        createdAt: createdDt,
        metadata: {...metadata, ...payloadData},
      );
    }

    // debugPrint("> on toTypeMessage md ${toJson().toString()}");
    return message;
  }

  static MessageModel fromMessage(Message message) {
    final Map<String, dynamic> payload = {};

    // WebSocket API v2.0: 提取 msg_type 到顶层字段
    String? msgType;

    // 根据不同类型的消息提取特定字段
    if (message is TextMessage) {
      msgType = 'text';
      payload['msg_type'] = 'text';
      payload['text'] = message.text;
      payload.addAll(message.metadata ?? {});
    } else if (message is ImageMessage) {
      msgType = 'image';
      payload['msg_type'] = 'image';
      payload['name'] = message.text;
      payload['size'] = message.size;
      payload['uri'] = message.source;
      payload['width'] = message.width;
      payload['height'] = message.height;
      payload.addAll(message.metadata ?? {});
    } else if (message is FileMessage) {
      msgType = 'file';
      payload['msg_type'] = 'file';
      payload['name'] = message.name;
      payload['size'] = message.size;
      payload['uri'] = message.source;
      payload.addAll(message.metadata ?? {});
    } else if (message is CustomMessage) {
      msgType = 'custom';
      payload['msg_type'] = 'custom';
      if (message.metadata?['custom_type'] != null) {
        payload['custom_type'] = message.metadata!['custom_type'];
      }
      payload.addAll(message.metadata ?? {});
    }

    // 从metadata中提取可能存在的额外字段
    final metadata = message.metadata ?? {};
    // final sysPrompt = metadata['sys_prompt'] ?? '';
    final peerId = metadata['peer_id'] ?? '';
    final conversationUk3 = metadata['conversation_uk3'] ?? '';
    final type = payload['type'] ?? 'C2C';

    return MessageModel(
      message.id,
      autoId: 0,
      type: type,
      fromId: message.authorId,
      toId: peerId,
      payload: payload,
      createdAt: message.createdAt!.millisecondsSinceEpoch,
      isAuthor: message.authorId == UserRepoLocal.to.currentUid
          ? 1
          : 0,
      topicId: payload['topic_id'] ?? 0,
      conversationUk3: conversationUk3,
      status: 0,
      // WebSocket API v2.0: 设置顶层字段
      msgType: type == 'S2C' ? null : msgType,
      action: type == 'S2C' ? (metadata['action'] as String?) : null,
      e2ee: type == 'S2C' ? null : (metadata['e2ee'] as Map<String, dynamic>?),
    );
  }
}
