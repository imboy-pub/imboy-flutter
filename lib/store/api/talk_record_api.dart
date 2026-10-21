/// 面聊记录（talk_record）API 客户端（T08 数据层）。
///
/// 契约源：docs/design/2026-10-20-face-to-face-notes/BACKEND-API.md §4/§8/§11
/// + CONTRACT-FREEZE-T02 §3（复用 HttpClient/信封/EntityId；cursor 分页；
/// If-Match/428/412 为本域首次引入，客户端无既有先例）。
///
/// 约定：
/// - 全部端点 JWT 保护（HttpClient 统一注入 token）；
/// - 响应经 DefaultHttpTransformer 包络解析（{code,msg,payload}）；
/// - 失败统一抛 [TalkRecordApiException]（code/msg/payload + 分型），
///   不静默返回空值；
/// - 可变资源写操作（patch/complete/grants/delete 等）必须携带 If-Match
///   （缺头 428、版本过期 412，服务端语义）；
/// - create/captures/audio-parts/retry/processing/exports 携带
///   Idempotency-Key（scope=actor+method+resource+key，离线重放安全）；
/// - URL 常量集中在 [API]（const.dart）。
library;

import 'package:dio/dio.dart';

import 'package:imboy/store/model/talk_record/talk_record_audio_upload_session.dart';
export 'package:imboy/store/model/talk_record/talk_record_audio_upload_session.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_cursor_page.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_job_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_mark_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_segment_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_speaker_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_summary_model.dart';
import 'package:imboy/store/model/workspace_model.dart';

import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';

part 'talk_record_api_participants.dart';
part 'talk_record_api_recovery.dart';
part 'talk_record_api_results.dart';
part 'talk_record_api_result_operations.dart';

/// HTTP 头常量（talk_record 域新引入，集中定义防拼写漂移）。
class TalkRecordHttpHeaders {
  static const String idempotencyKey = 'Idempotency-Key';
  static const String ifMatch = 'If-Match';
  static const String etag = 'etag';
}

/// 带资源 ETag 的响应包装（§3/§11.2：每个可变资源 ETag/revision；
/// 客户端不得把 segment 的 ETag 用于 record 更新）。
class TalkRecordFetched<T> {
  final T data;

  /// 服务端响应 ETag；后续 If-Match 写操作原样回传。空表示响应未带。
  final String etag;

  const TalkRecordFetched(this.data, {this.etag = ''});

  bool get hasEtag => etag.isNotEmpty;
}

/// talk_record 域响应 ETag 捕获拦截器（独立组件，便于单测）。
///
/// 仅记录最近一次 talk-records 前缀响应的 ETag（[takeLast] 消费式读取，
/// 防跨请求串用）；同资源并发请求的时序竞态在 V1 由调用方串行化写操作
/// 规避（读取-修改-写入链路本身要求先 GET 再写）。
class TalkRecordEtagInterceptor extends Interceptor {
  String? _lastEtag;
  String _lastPath = '';

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final path = response.requestOptions.path;
    if (path.startsWith(API.talkRecords)) {
      _lastPath = path;
      _lastEtag = response.headers.value(TalkRecordHttpHeaders.etag);
    }
    handler.next(response);
  }

  /// 取走指定 uri 最近一次响应的 ETag（路径不匹配返回 null，不消费）。
  String? takeLast(String uri) {
    if (_lastPath != uri) return null;
    final value = _lastEtag;
    _lastEtag = null;
    _lastPath = '';
    return value;
  }
}

// ---------------------------------------------------------------------------
// 宽松响应小类（响应契约未冻结的端点：保留 raw 供后续字段对齐）
// ---------------------------------------------------------------------------

/// talk_record API 客户端（失败统一抛 [TalkRecordApiException]）。
class TalkRecordApi extends HttpClient {
  final TalkRecordEtagInterceptor _etagInterceptor =
      TalkRecordEtagInterceptor();

  TalkRecordApi() {
    dio.interceptors.add(_etagInterceptor);
  }

  // ==================== 能力与创建上下文 ====================

  /// GET /capabilities（§4/§11.4）。
  Future<TalkRecordCapabilitiesModel> capabilities() async {
    final resp = await get(API.talkRecordCapabilities);
    return _unwrap(resp, TalkRecordCapabilitiesModel.fromJson);
  }

  /// GET /creation-contexts（§8：可创建的个人/企业/工作区集合；cursor 分页）。
  Future<TalkRecordCursorPage<TalkRecordCreationContextModel>>
  creationContexts({String cursor = '', int? limit}) async {
    final resp = await get(
      API.talkRecordCreationContexts,
      queryParameters: _pageQuery(cursor: cursor, limit: limit),
    );
    return _unwrapPage(resp, TalkRecordCreationContextModel.fromJson);
  }

  // ==================== 记录生命周期 ====================

  /// GET /（§4：只返回有权记录；cursor 绑定筛选和调用者）。
  Future<TalkRecordCursorPage<TalkRecordModel>> list({
    TalkRecordScope? scope,
    EntityId? organizationId,
    EntityId? workspaceId,
    TalkRecordListFilter? filter,
    String? q,
    String cursor = '',
    int? limit,
  }) async {
    final resp = await get(
      API.talkRecords,
      queryParameters: {
        ..._pageQuery(cursor: cursor, limit: limit),
        if (scope != null && scope != TalkRecordScope.unknown)
          'scope': scope.wireName,
        if (organizationId != null && organizationId.isNotEmpty)
          'organization_id': organizationId,
        if (workspaceId != null && workspaceId.isNotEmpty)
          'workspace_id': workspaceId,
        if (filter != null && filter != TalkRecordListFilter.unknown)
          'filter': filter.wireName,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    return _unwrapPage(resp, TalkRecordModel.fromJson);
  }

  Future<TalkRecordFetched<TalkRecordModel>?> lookupRecording({
    required String clientRecordingId,
    required TalkRecordScope scope,
    EntityId? organizationId,
    EntityId? workspaceId,
  }) => _lookupRecording(
    this,
    clientRecordingId: clientRecordingId,
    scope: scope,
    organizationId: organizationId,
    workspaceId: workspaceId,
  );

  /// POST /（§4：Idempotency-Key 必带；201 note + revision；
  /// 缺告知确认 422；仅录音不要求转写同意）。
  Future<TalkRecordFetched<TalkRecordModel>> create({
    required String clientRecordingId,
    required TalkRecordScope scope,
    required String language,
    required TalkRecordProcessingMode processingMode,
    required String policyVersion,
    required String idempotencyKey,
    String title = '',
    EntityId? organizationId,
    EntityId? workspaceId,
    TalkRecordSourceType sourceType = TalkRecordSourceType.liveRecording,
    DateTime? reportedStartedAt,
  }) async {
    final uri = API.talkRecords;
    final resp = await post(
      uri,
      data: {
        'client_recording_id': clientRecordingId,
        if (title.isNotEmpty) 'title': title,
        'scope': scope.wireName,
        if (organizationId != null && organizationId.isNotEmpty)
          'organization_id': organizationId,
        if (workspaceId != null && workspaceId.isNotEmpty)
          'workspace_id': workspaceId,
        'source_type': sourceType.wireName,
        'language': language,
        'processing_mode': processingMode.wireName,
        'notice_ack': true,
        'policy_version': policyVersion,
        if (reportedStartedAt != null)
          'reported_started_at': reportedStartedAt.toIso8601String(),
      },
      options: _options(idempotencyKey: idempotencyKey),
    );
    return TalkRecordFetched(
      _unwrap(resp, TalkRecordModel.fromJson),
      etag: _takeEtag(uri),
    );
  }

  /// GET /:id（§4：元数据 + capabilities_for_actor + ETag；无权限或不存在
  /// 统一 404）。
  Future<TalkRecordFetched<TalkRecordModel>> detail(EntityId id) async {
    final uri = API.talkRecordDetail(id);
    final resp = await get(uri);
    return TalkRecordFetched(
      _unwrap(resp, TalkRecordModel.fromJson),
      etag: _takeEtag(uri),
    );
  }

  /// PATCH /:id（§4：title/language 仅未开始处理时；notes 共享补充笔记；
  /// 不接受 owner/scope 直接修改；If-Match 必带）。
  Future<TalkRecordFetched<TalkRecordModel>> patchRecord(
    EntityId id, {
    String? title,
    String? language,
    String? notes,
    required String ifMatch,
  }) async {
    final uri = API.talkRecordDetail(id);
    final resp = await patch(
      uri,
      data: {'title': ?title, 'language': ?language, 'notes': ?notes},
      options: _options(ifMatch: ifMatch),
    );
    return TalkRecordFetched(
      _unwrap(resp, TalkRecordModel.fromJson),
      etag: _takeEtag(uri),
    );
  }

  /// DELETE /:id（§4：owner + If-Match；202 逻辑删除 + cleanup pending）。
  Future<TalkRecordDeleteResult> deleteRecord(
    EntityId id, {
    required String ifMatch,
  }) async {
    final resp = await delete(
      API.talkRecordDetail(id),
      options: _options(ifMatch: ifMatch),
    );
    return TalkRecordDeleteResult.fromJson(_ensureOk(resp));
  }

  // ==================== 采集（§8 路径：captures 子资源） ====================

  /// 服务端恢复视图；不是 cursor/list 信封。租约过期不表示麦克风已停止。
  Future<List<TalkRecordCaptureModel>> captures(EntityId id) async {
    final resp = await get(API.talkRecordCaptures(id));
    final payload = _ensureOk(resp);
    final items = payload['captures'];
    if (items is! List || items.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('Invalid capture recovery response');
    }
    return items
        .cast<Map<String, dynamic>>()
        .map(TalkRecordCaptureModel.fromJson)
        .toList(growable: false);
  }

  /// 仅原 device_session_id 恢复，返回已确认分段；不隐式接管其他设备。
  Future<TalkRecordCaptureModel> recoverCapture(
    EntityId id,
    EntityId captureId, {
    required String deviceSessionId,
  }) async {
    final resp = await post(
      API.talkRecordCaptureRecover(id, captureId),
      data: {'device_session_id': deviceSessionId},
    );
    return _unwrap(resp, TalkRecordCaptureModel.fromJson);
  }

  /// 显式结束失联采集。If-Match 是 capture revision，服务端推进 lease_epoch；
  /// 这不会远程关闭离线设备麦克风，调用方必须先取得用户确认。
  Future<TalkRecordCaptureModel> abandonCapture(
    EntityId id,
    EntityId captureId, {
    required bool confirm,
    required String ifMatch,
  }) async {
    final resp = await post(
      API.talkRecordCaptureAbandon(id, captureId),
      data: {'confirm': confirm},
      options: _options(ifMatch: ifMatch),
    );
    return _unwrap(resp, TalkRecordCaptureModel.fromJson);
  }

  /// POST /:id/captures（§4/§8：Idempotency-Key + If-Match；同一记录或
  /// 同一设备已有活跃采集 409）。
  Future<TalkRecordCaptureModel> createCapture(
    EntityId id, {
    required String deviceSessionId,
    required String idempotencyKey,
    required String ifMatch,
    String deviceId = '',
  }) async {
    final resp = await post(
      API.talkRecordCaptures(id),
      data: {
        'device_session_id': deviceSessionId,
        if (deviceId.isNotEmpty) 'device_id': deviceId,
      },
      options: _options(idempotencyKey: idempotencyKey, ifMatch: ifMatch),
    );
    return _unwrap(resp, TalkRecordCaptureModel.fromJson);
  }

  /// POST /:id/captures/:capture_id/events（§4：幂等去重、顺序冲突 409；
  /// 返回 capture revision/状态投影）。
  Future<TalkRecordCaptureModel> postCaptureEvent(
    EntityId id,
    EntityId captureId,
    TalkRecordCaptureEventInput input,
  ) async {
    final resp = await post(
      API.talkRecordCaptureEvents(id, captureId),
      data: input.toJson(),
    );
    return _unwrap(resp, TalkRecordCaptureModel.fromJson);
  }

  /// POST /:id/captures/:capture_id/audio-parts（§4：Idempotency-Key；
  /// 签发受限上传会话）。
  Future<TalkRecordAudioUploadSession> createAudioPart(
    EntityId id,
    EntityId captureId,
    TalkRecordAudioPartInput input, {
    required String idempotencyKey,
  }) async {
    final resp = await post(
      API.talkRecordCaptureAudioParts(id, captureId),
      data: input.toJson(),
      options: _options(idempotencyKey: idempotencyKey),
    );
    return TalkRecordAudioUploadSession.fromJson(_ensureOk(resp));
  }

  /// POST .../audio-parts/:part_id/confirm（§4：202 verifying / 200 confirmed）。
  Future<TalkRecordAudioPartConfirmResult> confirmAudioPart(
    EntityId id,
    EntityId captureId,
    EntityId partId,
  ) async {
    final resp = await post(
      API.talkRecordCaptureAudioPartConfirm(id, captureId, partId),
      data: <String, dynamic>{},
    );
    return TalkRecordAudioPartConfirmResult.fromJson(_ensureOk(resp));
  }

  /// POST /:id/complete（§4：captures 清单 + processing_consent；
  /// 缺段 409 missing_sequences；202 assembling + job_id）。
  Future<TalkRecordCompleteResult> complete(
    EntityId id, {
    required List<TalkRecordCompleteCaptureInput> captures,
    required String policyVersion,
    String? processorConfigVersion,
    required String idempotencyKey,
    required String ifMatch,
  }) async {
    final resp = await post(
      API.talkRecordComplete(id),
      data: {
        'captures': captures.map((c) => c.toJson()).toList(),
        'processing_consent': {
          'policy_version': policyVersion,
          'processor_config_version': ?processorConfigVersion,
        },
      },
      options: _options(idempotencyKey: idempotencyKey, ifMatch: ifMatch),
    );
    return TalkRecordCompleteResult.fromJson(_ensureOk(resp));
  }

  // ==================== 处理任务 ====================

  /// GET /:id/jobs（§4：状态、可重试标记与归一化错误码）。
  Future<List<TalkRecordJobModel>> jobs(EntityId id) async {
    final resp = await get(API.talkRecordJobs(id));
    return _unwrapList(resp, TalkRecordJobModel.fromJson);
  }

  /// POST /:id/jobs/:job_id/retry（§4：仅可重试失败；202；If-Match +
  /// Idempotency-Key）。
  Future<void> retryJob(
    EntityId id,
    EntityId jobId, {
    required String idempotencyKey,
    required String ifMatch,
  }) async {
    final resp = await post(
      API.talkRecordJobRetry(id, jobId),
      data: <String, dynamic>{},
      options: _options(idempotencyKey: idempotencyKey, ifMatch: ifMatch),
    );
    _ensureOk(resp);
  }

  /// POST /:id/processing-requests（§4：会后把 record_only 升级转写/摘要；
  /// 202 或能力未配置 503；不借普通编辑隐式触发模型）。
  Future<void> requestProcessing(
    EntityId id, {
    required TalkRecordProcessingMode mode,
    required String policyVersion,
    String? processorConfigVersion,
    required String idempotencyKey,
    required String ifMatch,
  }) async {
    final resp = await post(
      API.talkRecordProcessingRequests(id),
      data: {
        'mode': mode.wireName,
        'processing_consent': {
          'policy_version': policyVersion,
          'processor_config_version': ?processorConfigVersion,
        },
      },
      options: _options(idempotencyKey: idempotencyKey, ifMatch: ifMatch),
    );
    _ensureOk(resp);
  }

  // ==================== 原文与说话人 ====================

  /// GET /:id/segments（§4：cursor/limit/speaker_id/q；start_ms 正序）。
  Future<TalkRecordCursorPage<TalkRecordSegmentModel>> segments(
    EntityId id, {
    EntityId? speakerId,
    String? q,
    String cursor = '',
    int? limit,
  }) async {
    final resp = await get(
      API.talkRecordSegments(id),
      queryParameters: {
        ..._pageQuery(cursor: cursor, limit: limit),
        if (speakerId != null && speakerId.isNotEmpty) 'speaker_id': speakerId,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    return _unwrapPage(resp, TalkRecordSegmentModel.fromJson);
  }

  /// PATCH /:id/segments/:segment_id（§4：text/speaker_id + If-Match；
  /// 更新 content_revision、标摘要 stale）。
  Future<TalkRecordFetched<TalkRecordSegmentModel>> patchSegment(
    EntityId id,
    EntityId segmentId, {
    String? text,
    EntityId? speakerId,
    required String ifMatch,
  }) async {
    final uri = API.talkRecordSegmentDetail(id, segmentId);
    final resp = await patch(
      uri,
      data: {
        'text': ?text,
        if (speakerId != null && speakerId.isNotEmpty) 'speaker_id': speakerId,
      },
      options: _options(ifMatch: ifMatch),
    );
    return TalkRecordFetched(
      _unwrap(resp, TalkRecordSegmentModel.fromJson),
      etag: _takeEtag(uri),
    );
  }

  /// GET /:id/speakers（§4：不暴露 voice embedding）。
  Future<List<TalkRecordSpeakerModel>> speakers(EntityId id) async {
    final resp = await get(API.talkRecordSpeakers(id));
    return _unwrapList(resp, TalkRecordSpeakerModel.fromJson);
  }

  /// PATCH /:id/speakers/:speaker_id（§4：display_name/matched_user_id；
  /// 服务端设 manual，客户端不能指定 self_claim）。
  Future<TalkRecordSpeakerModel> patchSpeaker(
    EntityId id,
    EntityId speakerId, {
    String? displayName,
    EntityId? matchedUserId,
    required String ifMatch,
  }) async {
    final resp = await patch(
      API.talkRecordSpeakerDetail(id, speakerId),
      data: {
        'display_name': ?displayName,
        if (matchedUserId != null && matchedUserId.isNotEmpty)
          'matched_user_id': matchedUserId,
      },
      options: _options(ifMatch: ifMatch),
    );
    return _unwrap(resp, TalkRecordSpeakerModel.fromJson);
  }

  /// POST /:id/speakers/:speaker_id/claim（§4：仅本人 user_id，服务端从
  /// JWT 取；已有他人认领 409）。sample_segment_ids 为确认用示例片段。
  Future<TalkRecordSpeakerModel> claimSpeaker(
    EntityId id,
    EntityId speakerId, {
    List<EntityId> sampleSegmentIds = const [],
  }) async {
    final resp = await post(
      API.talkRecordSpeakerClaim(id, speakerId),
      data: {
        if (sampleSegmentIds.isNotEmpty) 'sample_segment_ids': sampleSegmentIds,
      },
    );
    return _unwrap(resp, TalkRecordSpeakerModel.fromJson);
  }

  // ==================== 重点标记 ====================

  /// GET /:id/marks（§4：start_ms 正序；cursor 分页）。
  Future<TalkRecordCursorPage<TalkRecordMarkModel>> marks(
    EntityId id, {
    String cursor = '',
    int? limit,
  }) async {
    final resp = await get(
      API.talkRecordMarks(id),
      queryParameters: _pageQuery(cursor: cursor, limit: limit),
    );
    return _unwrapPage(resp, TalkRecordMarkModel.fromJson);
  }

  /// POST /:id/marks（§4：client_mark_id 离线幂等；有效录音范围校验）。
  Future<TalkRecordMarkModel> createMark(
    EntityId id, {
    required String clientMarkId,
    required int positionMs,
    String text = '',
    EntityId captureId = '',
    int captureOffsetMs = 0,
  }) async {
    final resp = await post(
      API.talkRecordMarks(id),
      data: {
        'client_mark_id': clientMarkId,
        'position_ms': positionMs,
        if (text.isNotEmpty) 'text': text,
        if (captureId.isNotEmpty) 'capture_id': captureId,
        if (captureId.isNotEmpty) 'capture_offset_ms': captureOffsetMs,
      },
    );
    return _unwrap(resp, TalkRecordMarkModel.fromJson);
  }

  /// PATCH /:id/marks/:mark_id（§4：手动编辑 + If-Match）。
  Future<TalkRecordMarkModel> patchMark(
    EntityId id,
    EntityId markId, {
    int? positionMs,
    String? text,
    required String ifMatch,
  }) async {
    final resp = await patch(
      API.talkRecordMarkDetail(id, markId),
      data: {'position_ms': ?positionMs, 'text': ?text},
      options: _options(ifMatch: ifMatch),
    );
    return _unwrap(resp, TalkRecordMarkModel.fromJson);
  }

  /// DELETE /:id/marks/:mark_id（§4：If-Match）。
  Future<void> deleteMark(
    EntityId id,
    EntityId markId, {
    required String ifMatch,
  }) async {
    final resp = await delete(
      API.talkRecordMarkDetail(id, markId),
      options: _options(ifMatch: ifMatch),
    );
    _ensureOk(resp);
  }

  // ==================== 摘要 ====================

  /// GET /:id/summary（§4：未生成返回状态对象，不伪装 404）。
  Future<TalkRecordFetched<TalkRecordSummaryModel>> summary(EntityId id) async {
    final uri = API.talkRecordSummary(id);
    final resp = await get(uri);
    return TalkRecordFetched(
      _unwrap(resp, TalkRecordSummaryModel.fromJson),
      etag: _takeEtag(uri),
    );
  }

  /// PATCH /:id/summary（§4：人工编辑与 confirm=true；source revision
  /// 不匹配 409；仅确认文本，不自动建任务/发通知）。
  Future<TalkRecordFetched<TalkRecordSummaryModel>> patchSummary(
    EntityId id, {
    String? overview,
    List<TalkRecordSummaryItem>? decisions,
    List<TalkRecordSummaryItem>? actions,
    bool confirm = false,
    required String ifMatch,
  }) async {
    final uri = API.talkRecordSummary(id);
    final resp = await patch(
      uri,
      data: {
        'overview': ?overview,
        if (decisions != null)
          'decisions': decisions.map((e) => e.toJson()).toList(),
        if (actions != null) 'actions': actions.map((e) => e.toJson()).toList(),
        if (confirm) 'confirm': true,
      },
      options: _options(ifMatch: ifMatch),
    );
    return TalkRecordFetched(
      _unwrap(resp, TalkRecordSummaryModel.fromJson),
      etag: _takeEtag(uri),
    );
  }

  // ==================== 授权与分享 ====================

  /// GET /:id/grants（§4：owner 查全量 ACL；其他人只看自己的权限；
  /// ETag 对应 acl_revision）。
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> grants(
    EntityId id,
  ) async {
    final uri = API.talkRecordGrants(id);
    final resp = await get(uri);
    _ensureOk(resp);
    return TalkRecordFetched(
      _unwrapList(resp, TalkRecordGrantModel.fromJson),
      etag: _takeEtag(uri),
    );
  }

  /// PUT /:id/grants（§4：owner 提交全量受权清单；If-Match；与并发删除
  /// 互斥；不得授权超归属范围人员）。
  Future<TalkRecordFetched<List<TalkRecordGrantModel>>> putGrants(
    EntityId id, {
    required List<TalkRecordGrantInput> grants,
    required String ifMatch,
  }) async {
    final uri = API.talkRecordGrants(id);
    final resp = await put(
      uri,
      data: {'grants': grants.map((g) => g.toJson()).toList()},
      options: _options(ifMatch: ifMatch),
    );
    _ensureOk(resp);
    return TalkRecordFetched(
      _unwrapList(resp, TalkRecordGrantModel.fromJson),
      etag: _takeEtag(uri),
    );
  }

  /// DELETE /:id/grants/:grant_id（§4：owner 撤销；If-Match；立即失效）。
  Future<void> deleteGrant(
    EntityId id,
    EntityId grantId, {
    required String ifMatch,
  }) async {
    final resp = await delete(
      API.talkRecordGrantDetail(id, grantId),
      options: _options(ifMatch: ifMatch),
    );
    _ensureOk(resp);
  }

  /// GET /:id/share-candidates（§8：existing record 场景，服务端从记录取
  /// 归属；仅返回主体有权可见目录；结果不是永久授权凭证）。
  Future<TalkRecordCursorPage<TalkRecordShareCandidateModel>> shareCandidates(
    EntityId id, {
    String? q,
    String cursor = '',
    int? limit,
  }) async {
    final resp = await get(
      API.talkRecordShareCandidates(id),
      queryParameters: {
        ..._pageQuery(cursor: cursor, limit: limit),
        if (q != null && q.isNotEmpty) 'q': q,
      },
    );
    return _unwrapPage(resp, TalkRecordShareCandidateModel.fromJson);
  }

  /// POST /:id/share-card（§4：受控定位数据；接收者打开仍需 ACL）。
  Future<TalkRecordShareCardData> shareCard(EntityId id) async {
    final resp = await post(
      API.talkRecordShareCard(id),
      data: <String, dynamic>{},
    );
    return TalkRecordShareCardData.fromJson(_ensureOk(resp));
  }

  // ==================== 回放与导出 ====================

  /// POST /:id/playback（§4：短时受控播放会话；position_ms 可选）。
  Future<TalkRecordPlaybackSession> playback(
    EntityId id, {
    int? positionMs,
  }) async {
    final resp = await post(
      API.talkRecordPlayback(id),
      data: {'position_ms': ?positionMs},
    );
    return TalkRecordPlaybackSession.fromJson(_ensureOk(resp));
  }

  /// POST /:id/exports（§4：format=txt/md；Idempotency-Key；202 export/job；
  /// 不包含音频/未授权参与者信息）。
  Future<TalkRecordExportResult> createExport(
    EntityId id, {
    required TalkRecordExportFormat format,
    required String idempotencyKey,
  }) async {
    final resp = await post(
      API.talkRecordExports(id),
      data: {'format': format.wireName},
      options: _options(idempotencyKey: idempotencyKey),
    );
    return TalkRecordExportResult.fromJson(_ensureOk(resp));
  }

  /// GET /:id/exports/:export_id/download（§4：再验 ACL + requester；
  /// 返回短时受控下载 URL；到期 410）。
  Future<String> exportDownloadUrl(EntityId id, EntityId exportId) async {
    final resp = await get(API.talkRecordExportDownload(id, exportId));
    final payload = _ensureOk(resp);
    return parseModelString(payload['url']);
  }

  // ==================== 内部：包络解包与头构造 ====================

  Map<String, dynamic> _ensureOk(IMBoyHttpResponse resp) {
    if (!resp.ok) {
      throw TalkRecordApiException.fromEnvelope(
        resp.code,
        resp.msg,
        resp.payload,
      );
    }
    return IMBoyHttpResponse.payloadAsMap(resp.payload);
  }

  T _unwrap<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return fromJson(_ensureOk(resp));
  }

  List<T> _unwrapList<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final payload = _ensureOk(resp);
    if (payload['list'] is List) {
      return (payload['list'] as List)
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList(growable: false);
    }
    // 兼容 payload 直接是数组的形态（fixture 契约未冻结处宽松处理）。
    final viaEnvelope = IMBoyHttpResponse.payloadList(resp.payload);
    return viaEnvelope.map(fromJson).toList(growable: false);
  }

  TalkRecordCursorPage<T> _unwrapPage<T>(
    IMBoyHttpResponse resp,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return TalkRecordCursorPage.fromJson(_ensureOk(resp), fromJson);
  }

  /// cursor/limit 公共查询参数（§4：limit 默认 20 最大 100 由服务端裁决，
  /// 客户端仅在显式传入时携带）。
  Map<String, dynamic> _pageQuery({String cursor = '', int? limit}) => {
    if (cursor.isNotEmpty) 'cursor': cursor,
    'limit': ?limit,
  };

  /// Idempotency-Key / If-Match 头构造（无则不建 Options，保留基础头）。
  Options? _options({String? idempotencyKey, String? ifMatch}) {
    if (idempotencyKey == null && ifMatch == null) return null;
    return Options(
      headers: {
        TalkRecordHttpHeaders.idempotencyKey: ?idempotencyKey,
        TalkRecordHttpHeaders.ifMatch: ?ifMatch,
      },
    );
  }

  /// 消费式读取 uri 最近响应的 ETag（无则空串）。
  String _takeEtag(String uri) => _etagInterceptor.takeLast(uri) ?? '';
}
