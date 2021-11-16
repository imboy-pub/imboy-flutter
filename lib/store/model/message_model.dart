import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

// enum MsgType { custom, file, image, text, unsupported }

class MessageModel {
  String? id;
  String? type;
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

  MessageModel.fromMap(Map<String, dynamic> data) {
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

  Map<String, dynamic> toMap() {
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
  types.Status get eStatus {
    if (this.status == 10) {
      return types.Status.sending;
    } else if (this.status == 11) {
      return types.Status.sent;
    } else if (this.status == 20) {
      return types.Status.delivered;
    } else if (this.status == 21) {
      return types.Status.seen;
    } else if (this.status == 41) {
      return types.Status.error;
    }
    return types.Status.error;
  }

  int toStatus(types.Status status) {
    if (status == types.Status.sending) {
      return 10;
    } else if (status == types.Status.sent) {
      return 11;
    } else if (status == types.Status.delivered) {
      return 20;
    } else if (status == types.Status.seen) {
      return 21;
    } else if (status == types.Status.error) {
      return 41;
    }
    return 41;
  }

  Future<ContactModel?> get to async {
    return await ContactRepo().find(this.toId!);
  }

  Future<ContactModel?> get from async {
    return await ContactRepo().find(this.fromId!);
  }
}
