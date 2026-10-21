/// 面聊记录（talk_record）重点标记模型（T08 数据层）。
///
/// 契约源：BACKEND-API.md §2 talk_record_mark + §4 marks 端点 + §11.1
/// （mark 绑定 capture_id + capture_offset_ms；UNIQUE(record_id,author_id,
/// client_mark_id) 离线去重）。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

class TalkRecordMarkModel {
  final EntityId id;
  final EntityId recordId;
  final EntityId authorId;
  final String clientMarkId;
  final int positionMs;
  final String text;
  final DateTime? createdAt;
  final EntityId captureId;
  final int captureOffsetMs;

  const TalkRecordMarkModel({
    required this.id,
    this.recordId = '',
    this.authorId = '',
    this.clientMarkId = '',
    this.positionMs = 0,
    this.text = '',
    this.createdAt,
    this.captureId = '',
    this.captureOffsetMs = 0,
  });

  factory TalkRecordMarkModel.fromJson(Map<String, dynamic> json) {
    return TalkRecordMarkModel(
      id: entityIdOf(json['id']),
      recordId: entityIdOf(json['record_id']),
      authorId: entityIdOf(json['author_id']),
      clientMarkId: parseModelString(json['client_mark_id']),
      positionMs: parseModelInt(json['position_ms']),
      text: parseModelString(json['text']),
      createdAt: parseModelNullableDateTime(json['created_at']),
      captureId: entityIdOf(json['capture_id']),
      captureOffsetMs: parseModelInt(json['capture_offset_ms']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'record_id': recordId,
    'author_id': authorId,
    'client_mark_id': clientMarkId,
    'position_ms': positionMs,
    'text': text,
    'capture_id': captureId,
    'capture_offset_ms': captureOffsetMs,
  };
}
