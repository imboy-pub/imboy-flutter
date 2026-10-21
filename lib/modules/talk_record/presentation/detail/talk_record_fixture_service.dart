/// 面聊记录（talk_record）详情域 fixture 服务（T16，component 阶段）。
///
/// **声明：fixture 只证明组件行为，不冒充真实转写/摘要数据质量。**
/// 内存实现模拟 BACKEND-API.md §4 端点形状的关键语义：
/// - ETag/If-Match：错配抛 412（[TalkRecordApiException] code=
///   ErrorCode.PRECONDITION_FAILED），驱动片段校对冲突 UI；
/// - PATCH segments 成功 → segment.revision++、origin=human、
///   record.content_revision++、summary.status=stale（§11.2）；
/// - claim：已有他人认领返回 409（§4）；
/// - patchSpeaker 带 matched_user_id 时服务端置 identity_source=manual
///   （客户端不能指定 self_claim，§4）。
/// 真实联调（T13/T15）后由 API 实现替换，fixture 仅存于测试与组件预览。
library;

import 'package:imboy/config/error_code.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart'
    show TalkRecordApiException;
import 'package:imboy/store/api/talk_record_api.dart' show TalkRecordFetched;
import 'package:imboy/store/model/talk_record/talk_record_cursor_page.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_mark_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_speaker_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_summary_model.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

import 'talk_record_detail_service.dart';

/// 内存 fixture 记录仓（单记录粒度；测试按需播种多记录）。
class TalkRecordFixtureEntry {
  TalkRecordModel record;

  /// record ETag 对应 record.revision（If-Match 校验用）。
  String recordEtag;
  List<TalkRecordSegmentModel> segments;
  List<String> segmentEtags;
  List<TalkRecordSpeakerModel> speakers;
  List<String> speakerEtags;
  TalkRecordSummaryModel summary;
  List<TalkRecordMarkModel> marks;

  /// 模型原稿快照（PATCH 后保留原 text 供「原稿对照」；真实历史在
  /// 服务端受控历史中，§4——fixture 以本地快照近似该行为）。
  Map<EntityId, String> originalTexts;

  /// 当前主体 user_id（claim 时服务端从 JWT 取的 fixture 等价物）。
  EntityId currentUserId;

  TalkRecordFixtureEntry({
    required this.record,
    required this.recordEtag,
    this.segments = const [],
    this.segmentEtags = const [],
    this.speakers = const [],
    this.speakerEtags = const [],
    required this.summary,
    this.marks = const [],
    this.originalTexts = const {},
    this.currentUserId = '9001',
  });
}

/// fixture 详情服务。
class FixtureTalkRecordDetailService implements TalkRecordDetailService {
  FixtureTalkRecordDetailService(this.entries);

  final List<TalkRecordFixtureEntry> entries;

  /// retryTranscribe 受理后置 true（证明 UI 流，不代表真实转写）。
  bool lastRetryAccepted = false;
  int retryCount = 0;

  TalkRecordFixtureEntry _entry(EntityId id) {
    return entries.firstWhere(
      (e) => e.record.id == id,
      orElse: () => throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'record not found (fixture)',
      ),
    );
  }

  int _segmentIndex(TalkRecordFixtureEntry entry, EntityId segmentId) {
    final i = entry.segments.indexWhere((s) => s.id == segmentId);
    if (i < 0) {
      throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'segment not found (fixture)',
      );
    }
    return i;
  }

  @override
  Future<TalkRecordFetched<TalkRecordModel>> record(EntityId id) async {
    final e = _entry(id);
    return TalkRecordFetched(e.record, etag: e.recordEtag);
  }

  @override
  Future<TalkRecordFetched<TalkRecordModel>> patchNotes(
    EntityId id,
    String notes, {
    required String ifMatch,
  }) async {
    final e = _entry(id);
    _checkIfMatch(ifMatch, e.recordEtag);
    final updated = _bumpRecord(e, notes: notes);
    return TalkRecordFetched(updated, etag: e.recordEtag);
  }

  @override
  Future<TalkRecordCursorPage<TalkRecordSegmentModel>> segments(
    EntityId id, {
    EntityId? speakerId,
    String? q,
    String cursor = '',
    int? limit,
  }) async {
    final e = _entry(id);
    var rows = List<TalkRecordSegmentModel>.from(e.segments)
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    if (speakerId != null && speakerId.isNotEmpty) {
      rows = rows.where((s) => s.speakerId == speakerId).toList();
    }
    if (q != null && q.isNotEmpty) {
      final kw = q.toLowerCase();
      rows = rows.where((s) => s.text.toLowerCase().contains(kw)).toList();
    }
    return TalkRecordCursorPage(list: rows, nextCursor: '', hasMore: false);
  }

  @override
  Future<TalkRecordFetched<TalkRecordSegmentModel>> patchSegment(
    EntityId id,
    EntityId segmentId, {
    String? text,
    EntityId? speakerId,
    required String ifMatch,
  }) async {
    final e = _entry(id);
    final i = _segmentIndex(e, segmentId);
    _checkIfMatch(ifMatch, e.segmentEtags[i]);
    final old = e.segments[i];
    final updated = TalkRecordSegmentModel(
      id: old.id,
      recordId: old.recordId,
      transcriptVersion: old.transcriptVersion,
      seq: old.seq,
      speakerId: speakerId ?? old.speakerId,
      startMs: old.startMs,
      endMs: old.endMs,
      text: text ?? old.text,
      confidence: old.confidence,
      isFinal: old.isFinal,
      origin: TalkRecordSegmentOrigin.human,
      revision: old.revision + 1,
      editedBy: e.currentUserId,
    );
    e.segments[i] = updated;
    e.segmentEtags[i] = _segmentEtag(updated);
    e.originalTexts[old.id] ??= old.text;
    // §11.2：原文修订推进 content_revision，摘要标 stale。
    e.record = _copyRecord(
      e.record,
      contentRevision: e.record.contentRevision + 1,
    );
    e.recordEtag = _recordEtag(e.record);
    if (e.summary.status != TalkRecordSummaryStatus.unknown) {
      e.summary = _copySummary(
        e.summary,
        status: TalkRecordSummaryStatus.stale,
      );
    }
    return TalkRecordFetched(updated, etag: e.segmentEtags[i]);
  }

  @override
  Future<List<TalkRecordSpeakerModel>> speakers(EntityId id) async {
    return List<TalkRecordSpeakerModel>.from(_entry(id).speakers);
  }

  @override
  Future<TalkRecordSpeakerModel> patchSpeaker(
    EntityId id,
    EntityId speakerId, {
    String? displayName,
    EntityId? matchedUserId,
    required String ifMatch,
  }) async {
    final e = _entry(id);
    final i = e.speakers.indexWhere((s) => s.id == speakerId);
    if (i < 0) {
      throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'speaker not found (fixture)',
      );
    }
    _checkIfMatch(ifMatch, e.speakerEtags[i]);
    final old = e.speakers[i];
    // §4：带 matched_user_id 时服务端设 manual；客户端不能指定 self_claim。
    final nextSource = (matchedUserId != null && matchedUserId.isNotEmpty)
        ? TalkRecordSpeakerIdentitySource.manual
        : old.identitySource;
    final updated = TalkRecordSpeakerModel(
      id: old.id,
      recordId: old.recordId,
      localLabel: old.localLabel,
      displayName: displayName ?? old.displayName,
      matchedUserId: matchedUserId ?? old.matchedUserId,
      identitySource: nextSource,
      confirmedBy: nextSource == TalkRecordSpeakerIdentitySource.manual
          ? e.currentUserId
          : old.confirmedBy,
      confidence: old.confidence,
      revision: old.revision + 1,
    );
    e.speakers[i] = updated;
    e.speakerEtags[i] = _speakerEtag(updated);
    return updated;
  }

  @override
  Future<TalkRecordSpeakerModel> claimSpeaker(
    EntityId id,
    EntityId speakerId,
  ) async {
    final e = _entry(id);
    final i = e.speakers.indexWhere((s) => s.id == speakerId);
    if (i < 0) {
      throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'speaker not found (fixture)',
      );
    }
    final old = e.speakers[i];
    if (old.isClaimed && old.matchedUserId != e.currentUserId) {
      // §4：已有他人认领 409，走 owner 人工纠正并审计。
      throw const TalkRecordApiException(
        ErrorCode.CONFLICT,
        'speaker already claimed by another user (fixture)',
      );
    }
    final updated = TalkRecordSpeakerModel(
      id: old.id,
      recordId: old.recordId,
      localLabel: old.localLabel,
      displayName: old.displayName.isNotEmpty
          ? old.displayName
          : old.localLabel,
      matchedUserId: e.currentUserId,
      identitySource: TalkRecordSpeakerIdentitySource.selfClaim,
      confirmedBy: e.currentUserId,
      revision: old.revision + 1,
    );
    e.speakers[i] = updated;
    e.speakerEtags[i] = _speakerEtag(updated);
    return updated;
  }

  @override
  Future<TalkRecordFetched<TalkRecordSummaryModel>> summary(EntityId id) async {
    final e = _entry(id);
    return TalkRecordFetched(e.summary, etag: 'summary:${e.summary.revision}');
  }

  @override
  Future<TalkRecordCursorPage<TalkRecordMarkModel>> marks(
    EntityId id, {
    String cursor = '',
    int? limit,
  }) async {
    final e = _entry(id);
    final rows = List<TalkRecordMarkModel>.from(e.marks)
      ..sort((a, b) => a.positionMs.compareTo(b.positionMs));
    return TalkRecordCursorPage(list: rows, nextCursor: '', hasMore: false);
  }

  @override
  Future<bool> retryTranscribe(EntityId id) async {
    final e = _entry(id);
    retryCount++;
    if (e.record.transcriptStatus != TalkRecordProcessingStatus.failed) {
      // §4：只允许可重试失败。
      throw const TalkRecordApiException(
        ErrorCode.CONFLICT,
        'no retryable transcribe job (fixture)',
      );
    }
    lastRetryAccepted = true;
    e.record = _copyRecord(
      e.record,
      transcriptStatus: TalkRecordProcessingStatus.queued,
    );
    e.recordEtag = _recordEtag(e.record);
    return true;
  }

  // ---- 内部：ETag 与拷贝 ----

  void _checkIfMatch(String ifMatch, String etag) {
    if (ifMatch != etag) {
      throw const TalkRecordApiException(
        ErrorCode.PRECONDITION_FAILED,
        'revision stale (fixture 412)',
      );
    }
  }

  static String _recordEtag(TalkRecordModel r) => 'record:${r.revision}';

  static String _segmentEtag(TalkRecordSegmentModel s) =>
      'segment:${s.id}:${s.revision}';

  static String _speakerEtag(TalkRecordSpeakerModel s) =>
      'speaker:${s.id}:${s.revision}';

  TalkRecordModel _bumpRecord(TalkRecordFixtureEntry e, {String? notes}) {
    e.record = _copyRecord(
      e.record,
      notes: notes ?? e.record.notes,
      revision: e.record.revision + 1,
    );
    e.recordEtag = _recordEtag(e.record);
    return e.record;
  }

  static TalkRecordModel _copyRecord(
    TalkRecordModel r, {
    String? notes,
    int? revision,
    int? contentRevision,
    TalkRecordProcessingStatus? transcriptStatus,
  }) {
    return TalkRecordModel(
      id: r.id,
      ownerUserId: r.ownerUserId,
      createdBy: r.createdBy,
      clientRecordingId: r.clientRecordingId,
      sourceType: r.sourceType,
      scope: r.scope,
      organizationId: r.organizationId,
      workspaceId: r.workspaceId,
      title: r.title,
      language: r.language,
      activeCaptureId: r.activeCaptureId,
      captureStatus: r.captureStatus,
      mediaStatus: r.mediaStatus,
      transcriptStatus: transcriptStatus ?? r.transcriptStatus,
      summaryStatus: r.summaryStatus,
      processingMode: r.processingMode,
      durationMs: r.durationMs,
      currentTranscriptId: r.currentTranscriptId,
      contentRevision: contentRevision ?? r.contentRevision,
      notes: notes ?? r.notes,
      revision: revision ?? r.revision,
      aclRevision: r.aclRevision,
      createdAt: r.createdAt,
      updatedAt: DateTime.now(),
      endedAt: r.endedAt,
      deletedAt: r.deletedAt,
      retentionUntil: r.retentionUntil,
      cleanupStatus: r.cleanupStatus,
      visibility: r.visibility,
      capabilitiesForActor: r.capabilitiesForActor,
    );
  }

  static TalkRecordSummaryModel _copySummary(
    TalkRecordSummaryModel s, {
    TalkRecordSummaryStatus? status,
  }) {
    return TalkRecordSummaryModel(
      id: s.id,
      recordId: s.recordId,
      sourceTranscriptVersion: s.sourceTranscriptVersion,
      sourceContentRevision: s.sourceContentRevision,
      status: status ?? s.status,
      overview: s.overview,
      decisions: s.decisions,
      actions: s.actions,
      modelVersion: s.modelVersion,
      revision: s.revision,
      confirmedBy: s.confirmedBy,
    );
  }
}

// ---------------------------------------------------------------------------
// 场景构造器（fixture 数据——仅证明组件行为，非真实转写质量）
// ---------------------------------------------------------------------------

/// 按场景播种 fixture 服务。所有正文为合成短句，明确不用于质量评估。
class TalkRecordFixtureScenarios {
  /// 完整场景：转写 ready + 摘要 draft（decisions/actions 引用片段）。
  static FixtureTalkRecordDetailService transcribedWithSummary({
    Map<String, dynamic> caps = const {
      'edit': true,
      'share': true,
      'export': true,
      'playback': true,
    },
    String summaryStatus = 'draft',
  }) {
    return _seed(
      transcriptStatus: 'ready',
      summaryStatus: summaryStatus,
      caps: caps,
      withSegments: true,
      withSummaryContent: true,
    );
  }

  /// 仅录音（record_only / not_requested）：无原文无摘要。
  static FixtureTalkRecordDetailService recordOnly({
    Map<String, dynamic> caps = const {'playback': true},
  }) {
    return _seed(
      transcriptStatus: 'not_requested',
      summaryStatus: 'not_requested',
      caps: caps,
      processingMode: 'record_only',
      withSegments: false,
      withSummaryContent: false,
    );
  }

  /// 无语音（no_speech）：录音保留，不显示「转写失败」（UI-SPEC §4）。
  static FixtureTalkRecordDetailService noSpeech({
    Map<String, dynamic> caps = const {'playback': true},
  }) {
    return _seed(
      transcriptStatus: 'no_speech',
      summaryStatus: 'not_requested',
      caps: caps,
      withSegments: false,
      withSummaryContent: false,
    );
  }

  /// 转写失败：录音仍可回听；editor/owner 可重试。
  static FixtureTalkRecordDetailService transcribeFailed({
    Map<String, dynamic> caps = const {'edit': true, 'playback': true},
  }) {
    return _seed(
      transcriptStatus: 'failed',
      summaryStatus: 'not_requested',
      caps: caps,
      withSegments: false,
      withSummaryContent: false,
    );
  }

  /// 摘要过时（正文校对后 stale）。
  static FixtureTalkRecordDetailService staleSummary({
    Map<String, dynamic> caps = const {'edit': true, 'playback': true},
  }) {
    return _seed(
      transcriptStatus: 'ready',
      summaryStatus: 'stale',
      caps: caps,
      withSegments: true,
      withSummaryContent: true,
    );
  }

  static FixtureTalkRecordDetailService _seed({
    required String transcriptStatus,
    required String summaryStatus,
    required Map<String, dynamic> caps,
    String processingMode = 'summarize',
    required bool withSegments,
    required bool withSummaryContent,
  }) {
    const recordId = '1001';
    final record = TalkRecordModel.fromJson({
      'id': recordId,
      'title': '项目例会',
      'capture_status': 'ended',
      'media_status': 'available',
      'transcript_status': transcriptStatus,
      'summary_status': summaryStatus,
      'processing_mode': processingMode,
      'duration_ms': 655_000,
      'content_revision': 3,
      'revision': 2,
      'notes': '',
      'visibility': 'shared_with_grants',
      'capabilities_for_actor': caps,
    });

    final speakers = [
      TalkRecordSpeakerModel.fromJson({
        'id': '201',
        'record_id': recordId,
        'local_label': '说话人 1',
        'identity_source': 'anonymous',
        'revision': 1,
      }),
      TalkRecordSpeakerModel.fromJson({
        'id': '202',
        'record_id': recordId,
        'local_label': '说话人 2',
        'identity_source': 'anonymous',
        'revision': 1,
      }),
    ];

    final segments = withSegments
        ? <TalkRecordSegmentModel>[
            for (var i = 0; i < 6; i++)
              TalkRecordSegmentModel.fromJson({
                'id': '${300 + i}',
                'record_id': recordId,
                'transcript_version': 1,
                'seq': i,
                'speaker_id': '${201 + (i % 2)}',
                'start_ms': i * 60_000,
                'end_ms': i * 60_000 + 55_000,
                'text': _fixtureSegmentText(i),
                'origin': 'model',
                'revision': 1,
              }),
          ]
        : const <TalkRecordSegmentModel>[];

    final summary = TalkRecordSummaryModel.fromJson({
      'id': '401',
      'record_id': recordId,
      'source_transcript_version': 1,
      'source_content_revision': 3,
      'status': summaryStatus,
      'overview': withSummaryContent ? '（fixture 摘要）围绕发布节奏与分工讨论。' : '',
      'decisions': withSegments && withSummaryContent
          ? <Map<String, dynamic>>[
              {
                'text': '（fixture 决策）下周一发布候选版本',
                'segment_ids': ['301'],
              },
            ]
          : const <Map<String, dynamic>>[],
      'actions': withSegments && withSummaryContent
          ? <Map<String, dynamic>>[
              {
                'text': '（fixture 待办）整理发布清单',
                'segment_ids': ['302'],
                'assignee': '',
              },
            ]
          : const <Map<String, dynamic>>[],
      'model_version': 'fixture-model-0',
      'revision': 1,
    });

    final marks = withSegments
        ? [
            TalkRecordMarkModel.fromJson({
              'id': '501',
              'record_id': recordId,
              'position_ms': 65_000,
              'text': '预算口径',
              'client_mark_id': 'm-1',
            }),
          ]
        : const <TalkRecordMarkModel>[];

    return FixtureTalkRecordDetailService([
      TalkRecordFixtureEntry(
        record: record,
        recordEtag: 'record:${record.revision}',
        segments: segments,
        segmentEtags: [
          for (final s in segments) 'segment:${s.id}:${s.revision}',
        ],
        speakers: speakers,
        speakerEtags: [
          for (final s in speakers) 'speaker:${s.id}:${s.revision}',
        ],
        summary: summary,
        marks: marks,
        originalTexts: {},
        currentUserId: '9001',
      ),
    ]);
  }

  /// 合成片段文本（含可搜索关键词，供高亮/跳转断言）。
  static String _fixtureSegmentText(int i) {
    const texts = [
      '（fixture）先过一下上周的发布进展。预算',
      '（fixture）服务端拼装已经完成联调。',
      '（fixture）客户端灰度计划下周启动。',
      '（fixture）预算口径需要财务再确认一次。',
      '（fixture）文档同步更新到知识库。',
      '（fixture）下次会议周四下午继续。',
    ];
    return texts[i % texts.length];
  }
}
