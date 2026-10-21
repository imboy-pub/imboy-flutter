/// 面聊记录（talk_record）转写片段模型（T08 数据层）。
///
/// 契约源：BACKEND-API.md §2 talk_record_segment（UNIQUE(record_id,
/// transcript_version, seq)；speaker 与 segment 必须同 note 复合 FK）。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

import 'talk_record_enums.dart';

class TalkRecordSegmentModel {
  final EntityId id;
  final EntityId recordId;
  final int transcriptVersion;
  final int seq;
  final EntityId speakerId;
  final int startMs;
  final int endMs;
  final String text;

  /// 置信度 [0,1]；仅模型实际提供时才有值（§11.2 不显示虚假精确百分比）。
  final double? confidence;
  final bool isFinal;
  final TalkRecordSegmentOrigin origin;
  final int revision;
  final EntityId editedBy;

  const TalkRecordSegmentModel({
    required this.id,
    this.recordId = '',
    this.transcriptVersion = 0,
    this.seq = 0,
    this.speakerId = '',
    this.startMs = 0,
    this.endMs = 0,
    this.text = '',
    this.confidence,
    this.isFinal = true,
    this.origin = TalkRecordSegmentOrigin.unknown,
    this.revision = 1,
    this.editedBy = '',
  });

  factory TalkRecordSegmentModel.fromJson(Map<String, dynamic> json) {
    return TalkRecordSegmentModel(
      id: entityIdOf(json['id']),
      recordId: entityIdOf(json['record_id']),
      transcriptVersion: parseModelInt(json['transcript_version']),
      seq: parseModelInt(json['seq']),
      speakerId: entityIdOf(json['speaker_id']),
      startMs: parseModelInt(json['start_ms']),
      endMs: parseModelInt(json['end_ms']),
      text: parseModelString(json['text']),
      confidence: parseModelNullableDouble(json['confidence']),
      isFinal: parseModelBool(json['is_final'], defaultValue: true),
      origin: TalkRecordSegmentOrigin.parse(json['origin']),
      revision: parseModelInt(json['revision'], defaultValue: 1),
      editedBy: entityIdOf(json['edited_by']),
    );
  }

  bool get isHumanEdited => origin == TalkRecordSegmentOrigin.human;

  Map<String, dynamic> toJson() => {
    'id': id,
    'record_id': recordId,
    'transcript_version': transcriptVersion,
    'seq': seq,
    'speaker_id': speakerId,
    'start_ms': startMs,
    'end_ms': endMs,
    'text': text,
    'confidence': confidence,
    'is_final': isFinal,
    'origin': origin.wireName,
    'revision': revision,
    'edited_by': editedBy,
  };
}

/// parseModelDouble 的可空版（confidence 缺省 null 而非 0.0——
/// 0.0 会被误当作「模型给出的零置信度」）。
double? parseModelNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String && value.isNotEmpty) {
    return double.tryParse(value);
  }
  return null;
}
