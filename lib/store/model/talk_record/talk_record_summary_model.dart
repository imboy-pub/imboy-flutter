/// 面聊记录（talk_record）摘要模型（T08 数据层）。
///
/// 契约源：BACKEND-API.md §2 talk_record_summary（decision/action 带
/// segment_ids 引用并服务端校验同记录）+ §4 summary 端点（未生成返回
/// 状态对象，不伪装 404）+ §11.2（事实不确定保持未指定，不编造人员与
/// 截止时间）。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

import 'talk_record_enums.dart';

/// 单条 decision / action 结构项。
///
/// 服务端 schema 校验后仍可能新增键——未知键保留 [raw]；assignee/due
/// 未指定时为空（不编造）。
class TalkRecordSummaryItem {
  final String text;
  final List<EntityId> segmentIds;
  final String assignee;
  final DateTime? dueAt;
  final Map<String, dynamic> raw;

  const TalkRecordSummaryItem({
    this.text = '',
    this.segmentIds = const [],
    this.assignee = '',
    this.dueAt,
    this.raw = const {},
  });

  factory TalkRecordSummaryItem.fromJson(dynamic value) {
    final json = value is Map<String, dynamic>
        ? value
        : const <String, dynamic>{};
    final segs = json['segment_ids'] is List
        ? (json['segment_ids'] as List).map(entityIdOf).toList()
        : const <EntityId>[];
    return TalkRecordSummaryItem(
      text: parseModelString(json['text']),
      segmentIds: segs,
      assignee: parseModelNullableString(json['assignee']) ?? '',
      dueAt: parseModelNullableDateTime(json['due_at']),
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'segment_ids': segmentIds,
    if (assignee.isNotEmpty) 'assignee': assignee,
    if (dueAt != null) 'due_at': dueAt!.toIso8601String(),
  };
}

class TalkRecordSummaryModel {
  final EntityId id;
  final EntityId recordId;
  final int sourceTranscriptVersion;
  final int sourceContentRevision;
  final TalkRecordSummaryStatus status;
  final String overview;
  final List<TalkRecordSummaryItem> decisions;
  final List<TalkRecordSummaryItem> actions;
  final String modelVersion;
  final int revision;
  final EntityId confirmedBy;

  const TalkRecordSummaryModel({
    required this.id,
    this.recordId = '',
    this.sourceTranscriptVersion = 0,
    this.sourceContentRevision = 0,
    this.status = TalkRecordSummaryStatus.unknown,
    this.overview = '',
    this.decisions = const [],
    this.actions = const [],
    this.modelVersion = '',
    this.revision = 1,
    this.confirmedBy = '',
  });

  factory TalkRecordSummaryModel.fromJson(Map<String, dynamic> json) {
    return TalkRecordSummaryModel(
      id: entityIdOf(json['id']),
      recordId: entityIdOf(json['record_id']),
      sourceTranscriptVersion: parseModelInt(json['source_transcript_version']),
      sourceContentRevision: parseModelInt(json['source_content_revision']),
      status: TalkRecordSummaryStatus.parse(json['status']),
      overview: parseModelString(json['overview']),
      decisions: _parseItems(json['decisions']),
      actions: _parseItems(json['actions']),
      modelVersion: parseModelString(json['model_version']),
      revision: parseModelInt(json['revision'], defaultValue: 1),
      confirmedBy: entityIdOf(json['confirmed_by']),
    );
  }

  static List<TalkRecordSummaryItem> _parseItems(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map(TalkRecordSummaryItem.fromJson).toList(growable: false);
  }

  /// 状态对象（未生成/无正文时服务端仍返回 state，§4 不伪装 404）。
  bool get hasContent => overview.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'record_id': recordId,
    'source_transcript_version': sourceTranscriptVersion,
    'source_content_revision': sourceContentRevision,
    'status': status.wireName,
    'overview': overview,
    'decisions': decisions.map((e) => e.toJson()).toList(),
    'actions': actions.map((e) => e.toJson()).toList(),
    'model_version': modelVersion,
    'revision': revision,
    'confirmed_by': confirmedBy,
  };
}
