import 'dart:convert';

import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

// enum MsgType { custom, file, image, text, unsupported }

/// All possible statuses message can have.
// enum Status { delivered, error, seen, sending, sent }
class MessageStatus {
  // 发送中
  static const int sending = 10;
  //  已发送
  static const int send = 11;
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
  String? id;
  String? type; // C2C or GROUP
  String? fromId; // 等价于数据库的 from
  String? toId; // 等价于数据库的 to
  Map<String, dynamic>? payload;
  int? createdAt; // 消息创建时间 毫秒时间戳
  int? serverTs; // 服务器组装消息的时间戳
  //
  int? conversationId;
  // enum Status { delivered, error, seen, sending, sent }
  // types.Status status;
  // 10 发送中 sending;  11 已发送 send; 20 未读 delivered;  21 已读 seen; 41 错误（发送失败） error;
  int? status;

  MessageModel(
    this.id, {
    required this.type,
    required this.status,
    required this.fromId,
    required this.toId,
    required this.payload,
    this.createdAt,
    this.serverTs,
    //
    required this.conversationId,
  });

  MessageModel.fromJson(Map<String, dynamic> data) {
    if (data['payload'] == null || data['payload'] == "") {
      payload = <String, dynamic>{};
    } else if (data['payload'] is String) {
      payload = json.decode(data['payload']);
    } else if (data['payload'] is Map<String, dynamic>) {
      payload = data['payload'];
    }
    id = data[MessageRepo.id];
    type = data[MessageRepo.type];
    status = data[MessageRepo.status];
    fromId = data[MessageRepo.from] ?? '';
    toId = data[MessageRepo.to];
    createdAt = data[MessageRepo.createdAt];
    serverTs = data[MessageRepo.serverTs] ?? 0;
    //
    conversationId = data[MessageRepo.conversationId];
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['type'] = type;
    data['status'] = status;
    data['from'] = fromId;
    data['to'] = toId;
    data['payload'] = json.encode(payload);
    data['created_at'] = createdAt;
    data['server_ts'] = serverTs ?? 0;
    data['conversation_id'] = conversationId;

    debugPrint(">>>>> on MessageModel toMap $data");
    return data;
  }

  /// 10 发送中 sending;  11 已发送 send;
  /// 20 未读 delivered;  21 已读 seen;
  /// 41 错误（发送失败） error;
  types.Status get typesStatus {
    if (status == MessageStatus.sending) {
      return types.Status.sending;
    } else if (status == MessageStatus.send) {
      return types.Status.sent;
    } else if (status == MessageStatus.delivered) {
      return types.Status.delivered;
    } else if (status == MessageStatus.seen) {
      return types.Status.seen;
    } else if (status == MessageStatus.error) {
      return types.Status.error;
    }
    return types.Status.error;
  }

  types.MessageType get msgType {
    if (payload == null) {
      types.MessageType.unsupported;
    }
    if (payload!['msg_type'] == 'text') {
      return types.MessageType.text;
    } else if (payload!['msg_type'] == 'image') {
      return types.MessageType.image;
    } else if (payload!['msg_type'] == 'file') {
      return types.MessageType.file;
    } else if (payload!['msg_type'] == 'custom') {
      return types.MessageType.custom;
    } else if (payload!['msg_type'] == 'location') {
      return types.MessageType.custom;
    } else if (payload!['msg_type'] == 'revoked') {
      return types.MessageType.custom;
    }
    return types.MessageType.unsupported;
  }

  static String conversationMsgType(types.Message message) {
    if (message.type == types.MessageType.text) {
      return 'text';
    } else if (message.type == types.MessageType.image) {
      return 'image';
    } else if (message.type == types.MessageType.file) {
      return 'file';
    } else if (message.type == types.MessageType.custom) {
      return message.metadata?['custom_type'] ?? 'unsupported';
    }
    return 'unsupported';
  }

  int toStatus(types.Status status) {
    if (status == types.Status.sending) {
      return MessageStatus.sending;
    } else if (status == types.Status.sent) {
      return MessageStatus.send;
    } else if (status == types.Status.delivered) {
      return MessageStatus.delivered;
    } else if (status == types.Status.seen) {
      return MessageStatus.seen;
    } else if (status == types.Status.error) {
      return MessageStatus.error;
    }
    return MessageStatus.error;
  }

  Future<ContactModel?> get to async {
    return await ContactRepo().findByUid(toId!);
  }

  Future<ContactModel?> get from async {
    return await ContactRepo().findByUid(fromId!);
  }

  types.Message toTypeMessage() {
    types.Message? message;

    // enum MessageType { custom, file, image, text, unsupported }
    if (payload!['msg_type'] == 'text') {
      message = types.TextMessage(
        author: types.User(
          id: fromId!,
          // firstName: "",
          // imageUrl: "",
        ),
        createdAt: createdAt,
        id: id!,
        remoteId: toId,
        text: payload!['text'],
        status: typesStatus,
      );
    } else if (payload!['msg_type'] == 'image') {
      message = types.ImageMessage(
        author: types.User(
          id: fromId!,
          // firstName: "",
          // imageUrl: "",
        ),
        createdAt: createdAt,
        id: id!,
        remoteId: toId,
        name: payload!['name'],
        size: payload!['size'],
        uri: payload!['uri'],
        width: payload!['width'],
        height: payload!['height'],
        status: typesStatus,
      );
    } else if (payload!['msg_type'] == 'file') {
      message = types.FileMessage(
        author: types.User(
          id: fromId!,
          // firstName: "",
          // imageUrl: "",
        ),
        createdAt: createdAt,
        id: id!,
        remoteId: toId,
        name: payload!['name'],
        size: payload!['size'],
        uri: payload!['uri'],
        status: typesStatus,
      );
    } else if (payload!['custom_type'] == 'revoked') {
      message = types.CustomMessage(
        author: types.User(
          id: fromId!,
          // payload!['peer_name'] 目前只在收到撤回消息的时候才存在 peer_name
          firstName: payload!['peer_name'] ?? '',
          // imageUrl: "",
        ),
        id: id!,
        createdAt: createdAt,
        remoteId: toId,
        metadata: payload,
      );
    } else if (payload!['custom_type'] == 'quote') {
      message = types.CustomMessage(
        author: types.User(
          id: fromId!,
          firstName: payload!['quote_msg_author_name'] ?? '',
          // imageUrl: "",
        ),
        id: id!,
        createdAt: createdAt,
        remoteId: toId,
        metadata: payload,
      );
    } else if (payload!['custom_type'] == 'location') {
      message = types.CustomMessage(
        author: types.User(
          id: fromId!,
          // firstName: "",
          // imageUrl: "",
        ),
        id: id!,
        createdAt: createdAt,
        remoteId: toId,
        status: typesStatus,
        metadata: payload,
      );
    } else if (payload!['custom_type'] == 'video') {
      message = types.CustomMessage(
        author: types.User(
          id: fromId!,
          // firstName: "",
          // imageUrl: "",
        ),
        id: id!,
        createdAt: createdAt,
        remoteId: toId,
        status: typesStatus,
        metadata: payload,
      );
    } else if (payload!['custom_type'] == 'audio') {
      message = types.CustomMessage(
        author: types.User(
          id: fromId!,
          // firstName: "",
          // imageUrl: "",
        ),
        id: id!,
        createdAt: createdAt,
        remoteId: toId,
        status: typesStatus,
        metadata: payload,
      );
    }
    return message!;
  }
}
