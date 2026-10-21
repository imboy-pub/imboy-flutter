/// 面聊记录（talk_record）主表模型（T08 数据层）。
///
/// 契约源：BACKEND-API.md §2 talk_record 行 + §4 GET /:id / POST / 响应。
/// TSID 一律 [EntityId]（String，经 [entityIdOf] 宽松解析）；时长/位置为
/// int 毫秒；时间 `DateTime?`（宽松解析 parseModelNullableDateTime）。
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart';

import 'talk_record_enums.dart';
import 'talk_record_cleanup_retry_model.dart';

/// 当前主体对单条记录的能力投影（§4 GET /:id capabilities_for_actor、
/// §4 示例 `{edit, share, export}`、§9 企业详情 permissions
/// can_transfer_owner/can_export/can_share/can_delete）。
///
/// 未知键保留在 [raw]；bool 字段宽松解析，缺省 false（能力不默认开放）。
class TalkRecordCapabilitiesForActor {
  final bool edit;
  final bool share;
  final bool export;
  final bool delete;
  final bool transferOwner;
  final bool playback;
  final Map<String, dynamic> raw;

  const TalkRecordCapabilitiesForActor({
    this.edit = false,
    this.share = false,
    this.export = false,
    this.delete = false,
    this.transferOwner = false,
    this.playback = false,
    this.raw = const {},
  });

  factory TalkRecordCapabilitiesForActor.fromJson(dynamic raw) {
    final json = raw is Map<String, dynamic> ? raw : const <String, dynamic>{};
    return TalkRecordCapabilitiesForActor(
      edit: parseModelBool(json['edit']),
      share: parseModelBool(json['share']),
      export: parseModelBool(json['export']),
      delete: parseModelBool(
        json['can_delete'],
        defaultValue: parseModelBool(json['delete']),
      ),
      transferOwner: parseModelBool(json['can_transfer_owner']),
      playback: parseModelBool(json['playback'], defaultValue: true),
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);
}

/// talk_record 主表行模型（§2）。
class TalkRecordModel {
  static const cleanupReasons = <String>{
    'write_outcome_unknown',
    'processor_stop_unconfirmed',
    'processor_cleanup_pending',
  };
  bool get processorCleanupUnconfirmed => const <String>{
    'processor_stop_unconfirmed',
    'processor_cleanup_pending',
  }.contains(cleanupReason);

  final EntityId id;

  /// 当前管理责任人（§9：created_by 记录创建事实，两者 V1 相同）。
  final EntityId ownerUserId;
  final EntityId createdBy;
  final String clientRecordingId;
  final TalkRecordSourceType sourceType;
  final TalkRecordScope scope;
  final EntityId organizationId;
  final EntityId workspaceId;
  final String title;
  final String language;
  final EntityId activeCaptureId;
  final TalkRecordCaptureStatus captureStatus;
  final TalkRecordMediaStatus mediaStatus;
  final TalkRecordProcessingStatus transcriptStatus;
  final TalkRecordProcessingStatus summaryStatus;
  final TalkRecordProcessingMode processingMode;

  /// 有效音频累加时长（毫秒，排除暂停墙钟，§11.1）。
  final int durationMs;
  final EntityId currentTranscriptId;

  /// 内容修订（原文/署名变化推进，§11.2）。
  final int contentRevision;

  /// 跟随记录 ACL 的共享补充笔记（不是个人私密笔记，§2）。
  final String notes;

  /// 记录级修订（标题/归属内设置/删除/移交/ACL，§11.2）。
  final int revision;

  /// ACL 修订（授权/撤销/移交推进，§11.2）。
  final int aclRevision;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? endedAt;
  final DateTime? deletedAt;
  final DateTime? retentionUntil;
  final TalkRecordCleanupStatus cleanupStatus;

  /// Owner-only, allowlisted cleanup blocker; never contains storage identity.
  final String cleanupReason;
  final int? cleanupGeneration;
  final TalkRecordCleanupRetryCapability? cleanupRetry;

  /// 可见范围概述（§4 示例 `visibility: owner_only`；§11.3 仅自己/已共享）。
  final String visibility;
  final TalkRecordCapabilitiesForActor capabilitiesForActor;

  const TalkRecordModel({
    required this.id,
    this.ownerUserId = '',
    this.createdBy = '',
    this.clientRecordingId = '',
    this.sourceType = TalkRecordSourceType.unknown,
    this.scope = TalkRecordScope.unknown,
    this.organizationId = '',
    this.workspaceId = '',
    this.title = '',
    this.language = '',
    this.activeCaptureId = '',
    this.captureStatus = TalkRecordCaptureStatus.unknown,
    this.mediaStatus = TalkRecordMediaStatus.unknown,
    this.transcriptStatus = TalkRecordProcessingStatus.unknown,
    this.summaryStatus = TalkRecordProcessingStatus.unknown,
    this.processingMode = TalkRecordProcessingMode.unknown,
    this.durationMs = 0,
    this.currentTranscriptId = '',
    this.contentRevision = 1,
    this.notes = '',
    this.revision = 1,
    this.aclRevision = 1,
    this.createdAt,
    this.updatedAt,
    this.endedAt,
    this.deletedAt,
    this.retentionUntil,
    this.cleanupStatus = TalkRecordCleanupStatus.none,
    this.cleanupReason = '',
    this.cleanupGeneration,
    this.cleanupRetry,
    this.visibility = '',
    this.capabilitiesForActor = const TalkRecordCapabilitiesForActor(),
  });

  factory TalkRecordModel.fromJson(Map<String, dynamic> json) {
    final generation = TalkRecordCleanupRetryCapability.counter(
      json['cleanup_generation'],
    );
    final retry = TalkRecordCleanupRetryCapability.fromJson(
      json['cleanup_retry'],
    );
    return TalkRecordModel(
      id: entityIdOf(json['id']),
      ownerUserId: entityIdOf(json['owner_user_id']),
      createdBy: entityIdOf(json['created_by']),
      clientRecordingId: parseModelString(json['client_recording_id']),
      sourceType: TalkRecordSourceType.parse(json['source_type']),
      scope: TalkRecordScope.parse(json['scope']),
      organizationId: entityIdOf(json['organization_id']),
      workspaceId: entityIdOf(json['workspace_id']),
      title: parseModelString(json['title']),
      language: parseModelString(json['language']),
      activeCaptureId: entityIdOf(json['active_capture_id']),
      captureStatus: TalkRecordCaptureStatus.parse(json['capture_status']),
      mediaStatus: TalkRecordMediaStatus.parse(json['media_status']),
      transcriptStatus: TalkRecordProcessingStatus.parse(
        json['transcript_status'],
      ),
      summaryStatus: TalkRecordProcessingStatus.parse(json['summary_status']),
      processingMode: TalkRecordProcessingMode.parse(json['processing_mode']),
      durationMs: parseModelInt(json['duration_ms']),
      currentTranscriptId: entityIdOf(json['current_transcript_id']),
      contentRevision: parseModelInt(json['content_revision'], defaultValue: 1),
      notes: parseModelString(json['notes']),
      revision: parseModelInt(json['revision'], defaultValue: 1),
      aclRevision: parseModelInt(json['acl_revision'], defaultValue: 1),
      createdAt: parseModelNullableDateTime(json['created_at']),
      updatedAt: parseModelNullableDateTime(json['updated_at']),
      endedAt: parseModelNullableDateTime(json['ended_at']),
      deletedAt: parseModelNullableDateTime(json['deleted_at']),
      retentionUntil: parseModelNullableDateTime(json['retention_until']),
      cleanupStatus: TalkRecordCleanupStatus.parse(json['cleanup_status']),
      cleanupGeneration: generation,
      cleanupRetry: generation != null && retry.generation == generation
          ? retry
          : null,
      cleanupReason: cleanupReasons.contains(json['cleanup_reason'])
          ? json['cleanup_reason'] as String
          : '',
      visibility: parseModelString(json['visibility']),
      capabilitiesForActor: TalkRecordCapabilitiesForActor.fromJson(
        json['capabilities_for_actor'],
      ),
    );
  }

  bool get isOrganization => scope == TalkRecordScope.organization;
  bool get isDeleted => deletedAt != null;
  bool get canEdit => capabilitiesForActor.edit;

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_user_id': ownerUserId,
    'created_by': createdBy,
    'client_recording_id': clientRecordingId,
    'source_type': sourceType.wireName,
    'scope': scope.wireName,
    'organization_id': organizationId,
    'workspace_id': workspaceId,
    'title': title,
    'language': language,
    'active_capture_id': activeCaptureId,
    'capture_status': captureStatus.wireName,
    'media_status': mediaStatus.wireName,
    'transcript_status': transcriptStatus.wireName,
    'summary_status': summaryStatus.wireName,
    'processing_mode': processingMode.wireName,
    'duration_ms': durationMs,
    'current_transcript_id': currentTranscriptId,
    'content_revision': contentRevision,
    'notes': notes,
    'revision': revision,
    'acl_revision': aclRevision,
    'cleanup_status': cleanupStatus.wireName,
    if (cleanupGeneration != null) 'cleanup_generation': cleanupGeneration,
    if (cleanupReasons.contains(cleanupReason)) 'cleanup_reason': cleanupReason,
    'visibility': visibility,
  };
}
