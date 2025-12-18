import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/chat/enum.dart' show CustomMessageType;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/assets.dart' show AssetsService;
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
  String text;

  ReEditMessage({required this.text});
}

class MessageModel {
  int autoId;
  String? id;
  String? type; // 等价于 msg type: C2C C2G S2C 等等，根据type显示item
  String? fromId; // 等价于数据库的 from
  String? toId; // 等价于数据库的 to
  Map<String, dynamic> payload;
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
  });

  factory MessageModel.fromJson(Map<String, dynamic> data) {
    Map<String, dynamic> p = <String, dynamic>{};
    if (data['payload'] == null || data['payload'] == "") {
      p = <String, dynamic>{};
    } else if (data['payload'] is String) {
      p = jsonDecode("${data['payload']}");
    } else if (data['payload'] is Map<String, dynamic>) {
      p = data['payload'];
    }

    return MessageModel(
      data[MessageRepo.id],
      autoId: data[MessageRepo.autoId] ?? 0,
      type: data[MessageRepo.type],
      status: int.parse('${data[MessageRepo.status] ?? 0}'),
      fromId: data[MessageRepo.from] ?? '',
      toId: data[MessageRepo.to],
      payload: p,
      createdAt: int.parse('${data[MessageRepo.createdAt] ?? 0}'),
      isAuthor: data[MessageRepo.isAuthor] ?? 0,
      topicId: data[MessageRepo.topicId] ?? 0,
      conversationUk3: data[MessageRepo.conversationUk3] ?? '',
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
    data[MessageRepo.payload] = json.encode(payload);
    data[MessageRepo.createdAt] = createdAt;
    data[MessageRepo.isAuthor] = isAuthor;
    data[MessageRepo.topicId] = topicId;
    data[MessageRepo.conversationUk3] = conversationUk3;

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

  CustomMessageType get msgType {
    if (payload['msg_type'] == 'text') {
      return CustomMessageType.text;
    } else if (payload['msg_type'] == 'text_stream') {
      return CustomMessageType.textStream;
    } else if (payload['msg_type'] == 'image') {
      return CustomMessageType.image;
    } else if (payload['msg_type'] == 'file') {
      return CustomMessageType.file;
    } else if (payload['msg_type'] == 'custom') {
      return CustomMessageType.custom;
    } else if (payload['msg_type'] == 'location') {
      return CustomMessageType.custom;
    } else if (payload['msg_type'] == 'visit_card') {
      return CustomMessageType.custom;
    } else if (payload['msg_type'] == 'revoked') {
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
          return revokeUser == UserRepoLocal.to.currentUid ? 'my_revoked' : 'peer_revoked';
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
    String sysPrompt = payload['sys_prompt'] ?? '';
    Message? message;
    // enum MessageType { custom, file, image, text, unsupported }
    Map<String, dynamic> metadata = {
      'conversation_uk3': conversationUk3,
      'sys_prompt': sysPrompt,
      'peer_id': toId,
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
          ? (payload['peer_name'] ?? (payload['quote_msg_author_name'] ?? ''))
          : nickname,
    );
    DateTime createdDt = DateTimeHelper.millisecondToDateTime(createdAt);

    // Handle null payload case
    final payloadData = payload;
    if (payloadData['msg_type'] == 'text') {
      message = TextMessage(
        authorId: author.id,
        createdAt: createdDt,
        id: id!,
        // peerId: toId,
        text: payload['text'],
        status: typesStatus,
        metadata: {...metadata, ...payload},
      );
    } else if (payloadData['msg_type'] == 'image') {
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
    } else if (payloadData['msg_type'] == 'file') {
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
    } else if (payloadData['msg_type'] == 'custom') {
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

    // 根据不同类型的消息提取特定字段
    if (message is TextMessage) {
      payload['msg_type'] = 'text';
      payload['text'] = message.text;
      payload.addAll(message.metadata ?? {});
    }
    else if (message is ImageMessage) {
      payload['msg_type'] = 'image';
      payload['name'] = message.text;
      payload['size'] = message.size;
      payload['uri'] = message.source;
      payload['width'] = message.width;
      payload['height'] = message.height;
      payload.addAll(message.metadata ?? {});
    }
    else if (message is FileMessage) {
      payload['msg_type'] = 'file';
      payload['name'] = message.name;
      payload['size'] = message.size;
      payload['uri'] = message.source;
      payload.addAll(message.metadata ?? {});
    }
    else if (message is CustomMessage) {
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

    return MessageModel(
      message.id,
      autoId: 0,
      type: payload['type'], // 需要根据实际情况设置，可能是从metadata获取
      fromId: message.authorId,
      toId: peerId,
      payload: payload,
      createdAt: message.createdAt!.millisecondsSinceEpoch,
      isAuthor: message.authorId == UserRepoLocal.to.currentUid ? 1 : 0, // 需要根据实际情况设置
      topicId: payload['topic_id'] ?? 0, // 需要根据实际情况设置
      conversationUk3: conversationUk3,
      status: 0, // 默认状态
      // sysPrompt: sysPrompt,
    );
  }
}
