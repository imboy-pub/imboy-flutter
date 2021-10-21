import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

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
  int? status; // 10 未发送  11 已发送  20 未读  21 已读

  MessageModel(
    this.id, {
    required this.type,
    required this.fromId,
    required this.toId,
    required this.payload,
    this.createdAt,
    this.serverTs,
    //
    required this.conversationId,
    required this.status,
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
    fromId = data[MessageRepo.from] ?? '';
    toId = data[MessageRepo.to];
    createdAt = data[MessageRepo.createdAt];
    serverTs = data[MessageRepo.serverTs] ?? 0;
    //
    conversationId = data[MessageRepo.conversationId];
    status = data[MessageRepo.status];
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = this.id;
    data['type'] = this.type;
    data['from'] = this.fromId;
    data['to'] = this.toId;
    data['payload'] = json.encode(this.payload);
    data['created_at'] = this.createdAt;
    data['server_ts'] = this.serverTs != null ? this.serverTs : 0;
    data['status'] = this.status;
    data['conversation_id'] = this.conversationId;

    debugPrint(">>>>> on MessageModel toMap $data");
    return data;
  }

  Future<ContactModel?> get to async {
    return await ContactRepo().find(this.toId!);
  }

  Future<ContactModel?> get from async {
    return await ContactRepo().find(this.fromId!);
  }
}
