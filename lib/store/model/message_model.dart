import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

// enum MsgType { custom, file, image, text, unsupported }

/// All possible statuses message can have.
// enum Status { delivered, error, seen, sending, sent }
class MessageStatus {
  // 发送中
  static final int sending = 10;
  //  已发送
  static final int send = 11;
  // 未读 已投递
  static final int delivered = 20;
  // 已读
  static final int seen = 21;
  // 错误（发送失败）
  static final int error = 41;
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
      payload = Map<String, dynamic>();
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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['type'] = this.type;
    data['status'] = this.status;
    data['from'] = this.fromId;
    data['to'] = this.toId;
    data['payload'] = json.encode(this.payload);
    data['created_at'] = this.createdAt;
    data['server_ts'] = this.serverTs != null ? this.serverTs : 0;
    data['conversation_id'] = this.conversationId;

    debugPrint(">>>>> on MessageModel toMap $data");
    return data;
  }

  /// 10 发送中 sending;  11 已发送 send;
  /// 20 未读 delivered;  21 已读 seen;
  /// 41 错误（发送失败） error;
  types.Status get typesStatus {
    if (this.status == MessageStatus.sending) {
      return types.Status.sending;
    } else if (this.status == MessageStatus.send) {
      return types.Status.sent;
    } else if (this.status == MessageStatus.delivered) {
      return types.Status.delivered;
    } else if (this.status == MessageStatus.seen) {
      return types.Status.seen;
    } else if (this.status == MessageStatus.error) {
      return types.Status.error;
    }
    return types.Status.error;
  }

  types.MessageType get msgType {
    if (this.payload == null) {
      types.MessageType.unsupported;
    }
    if (this.payload!['msg_type'] == 'text') {
      return types.MessageType.text;
    } else if (this.payload!['msg_type'] == 'image') {
      return types.MessageType.image;
    } else if (this.payload!['msg_type'] == 'file') {
      return types.MessageType.file;
    } else if (this.payload!['msg_type'] == 'custom') {
      return types.MessageType.custom;
    } else if (this.payload!['msg_type'] == 'location') {
      return types.MessageType.custom;
    } else if (this.payload!['msg_type'] == 'revoked') {
      return types.MessageType.custom;
    }
    return types.MessageType.unsupported;
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
    return await ContactRepo().find(this.toId!);
  }

  Future<ContactModel?> get from async {
    return await ContactRepo().find(this.fromId!);
  }

  types.Message toTypeMessage() {
    types.Message? message;

    // enum MessageType { custom, file, image, text, unsupported }
    if (this.payload!['msg_type'] == 'text') {
      message = types.TextMessage(
        author: types.User(
          id: this.fromId!,
          // firstName: "",
          // imageUrl: "",
        ),
        createdAt: this.createdAt,
        id: this.id!,
        remoteId: this.toId,
        text: this.payload!['text'],
        status: this.typesStatus,
      );
    } else if (this.payload!['custom_type'] == 'revoked') {
      message = types.CustomMessage(
        author: types.User(
          id: this.fromId!,
          // firstName: "",
          // imageUrl: "",
        ),
        id: this.id!,
        createdAt: this.createdAt,
        remoteId: this.toId,
        metadata: this.payload,
      );
    } else if (this.payload!['custom_type'] == 'location') {
      message = types.CustomMessage(
        author: types.User(
          id: this.fromId!,
          // firstName: "",
          // imageUrl: "",
        ),
        id: this.id!,
        createdAt: this.createdAt,
        remoteId: this.toId,
        status: this.typesStatus,
        metadata: this.payload,
      );
    }
    return message!;
  }
}
