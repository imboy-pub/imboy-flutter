/// T08 面聊记录（talk_record）契约测试：JSON→Model 序列化/反序列化、
/// cursor 分页参数构造、capabilities 解析。
///
/// fixture 取自 BACKEND-API.md §4 示例（2026-10-20 v3）；端点均未实现，
/// 本文件是 fixture 契约测试——只证明客户端组件行为，不是联调证据。
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_grant_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_job_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_mark_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_speaker_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_summary_model.dart';

/// 记录最近一次请求参数的假 API（fixture 契约测试用）。
class _RecordingApi extends TalkRecordApi {
  String lastMethod = '';
  String? lastUri;
  Map<String, dynamic>? lastQuery;
  dynamic lastData;
  IMBoyHttpResponse next = IMBoyHttpResponse.success(<String, dynamic>{});

  void _record(
    String method,
    String uri, [
    Map<String, dynamic>? q,
    dynamic d,
  ]) {
    lastMethod = method;
    lastUri = uri;
    lastQuery = q;
    lastData = d;
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    _record('GET', uri, queryParameters);
    return next;
  }

  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    _record('POST', uri, queryParameters, data);
    return next;
  }

  @override
  Future<IMBoyHttpResponse> patch(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    _record('PATCH', uri, queryParameters, data);
    return next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('信封（DefaultHttpTransformer）→ payload → TalkRecordModel', () {
    test('§4 POST / 响应示例（部分投影）解析', () {
      final resp = DefaultHttpTransformer.getInstance().parse(
        Response<dynamic>(
          requestOptions: RequestOptions(path: API.talkRecords),
          statusCode: 201,
          data: {
            'code': 0,
            'msg': 'success',
            'payload': {
              'id': 1001,
              'revision': 1,
              'capture_status': 'draft',
              'media_status': 'uploading',
              'transcript_status': 'not_requested',
              'summary_status': 'not_requested',
              'visibility': 'owner_only',
              'capabilities_for_actor': {
                'edit': true,
                'share': true,
                'export': true,
              },
            },
          },
        ),
        API.talkRecords,
      );
      expect(resp.ok, isTrue);
      final record = TalkRecordModel.fromJson(
        IMBoyHttpResponse.payloadAsMap(resp.payload),
      );
      expect(record.id, '1001');
      expect(record.revision, 1);
      expect(record.captureStatus, TalkRecordCaptureStatus.draft);
      expect(record.mediaStatus, TalkRecordMediaStatus.uploading);
      expect(record.transcriptStatus, TalkRecordProcessingStatus.notRequested);
      expect(record.summaryStatus, TalkRecordProcessingStatus.notRequested);
      expect(record.visibility, 'owner_only');
      expect(record.capabilitiesForActor.edit, isTrue);
      expect(record.capabilitiesForActor.share, isTrue);
      expect(record.capabilitiesForActor.export, isTrue);
      // 投影响应缺省字段走默认值，不抛异常。
      expect(record.scope, TalkRecordScope.unknown);
      expect(record.contentRevision, 1);
      expect(record.durationMs, 0);
    });

    test('完整行解析：毫秒时间戳 + ISO8601 + revisions', () {
      final record = TalkRecordModel.fromJson(const {
        'id': 2001,
        'owner_user_id': 3001,
        'created_by': 3001,
        'client_recording_id': '0b6cf76b-1e3f-4d3a-9d1a-3f8e2b7c9a10',
        'source_type': 'live_recording',
        'scope': 'organization',
        'organization_id': 42,
        'workspace_id': 64,
        'title': '项目例会',
        'language': 'zh-CN',
        'active_capture_id': 5001,
        'capture_status': 'ended',
        'media_status': 'available',
        'transcript_status': 'ready',
        'summary_status': 'draft',
        'processing_mode': 'summarize',
        'duration_ms': 754000,
        'current_transcript_id': 6001,
        'content_revision': 3,
        'notes': '补充笔记',
        'revision': 5,
        'acl_revision': 2,
        'created_at': 1760000000000,
        'updated_at': '2026-10-20T12:00:00+08:00',
        'ended_at': 1760000754000,
        'retention_until': 1791536000000,
        'cleanup_status': 'none',
        'visibility': 'shared',
      });
      expect(record.id, '2001');
      expect(record.ownerUserId, '3001');
      expect(record.scope, TalkRecordScope.organization);
      expect(record.organizationId, '42');
      expect(record.workspaceId, '64');
      expect(record.title, '项目例会');
      expect(record.processingMode, TalkRecordProcessingMode.summarize);
      expect(record.durationMs, 754000);
      expect(record.contentRevision, 3);
      expect(record.revision, 5);
      expect(record.aclRevision, 2);
      expect(record.createdAt, isNotNull);
      expect(record.updatedAt, DateTime.parse('2026-10-20T12:00:00+08:00'));
      expect(record.endedAt, isNotNull);
      expect(record.deletedAt, isNull);
      expect(record.retentionUntil, isNotNull);
      expect(record.isDeleted, isFalse);
      expect(record.isOrganization, isTrue);
    });

    test('缺字段 / null / 未知枚举容错：不抛异常、降级 unknown/默认值', () {
      final record = TalkRecordModel.fromJson(const {
        'id': null,
        'scope': 'team_x', // 未知枚举
        'media_status': null,
        'transcript_status': 'some_future_status',
        'duration_ms': null,
        'organization_id': null,
        'created_at': null,
      });
      expect(record.id, '');
      expect(record.scope, TalkRecordScope.unknown);
      expect(record.mediaStatus, TalkRecordMediaStatus.unknown);
      expect(record.transcriptStatus, TalkRecordProcessingStatus.unknown);
      expect(record.durationMs, 0);
      expect(record.organizationId, '');
      expect(record.createdAt, isNull);
    });

    test('toJson：TSID 以 string 落 JSON（往返不回转 int）', () {
      final record = TalkRecordModel.fromJson(const {
        'id': 2001,
        'owner_user_id': 3001,
        'organization_id': 42,
        'revision': 5,
      });
      final json = record.toJson();
      expect(json['id'], '2001');
      expect(json['id'], isA<String>());
      expect(json['owner_user_id'], '3001');
      expect(json['revision'], 5);
    });
  });

  group('capabilities 解析（§4 + §11.4 配额字段）', () {
    test('全字段解析', () {
      final caps = TalkRecordCapabilitiesModel.fromJson(const {
        'scopes': ['personal', 'organization'],
        'languages': ['zh-CN', 'en-US'],
        'max_duration_ms': 7200000,
        'max_recording_bytes': 2147483648,
        'max_part_bytes': 16777216,
        'storage_remaining_bytes': 1073741824,
        'processing_available': true,
        'queue_limit': 5,
        'retention_policy': 'enterprise-365d',
        'policy_version': 'notice-v1',
        'recording_enabled': true,
        'asr_enabled': true,
        'processor_config_version': 'approved-bundle-v1',
        'summary_enabled': true,
        'voice_id_enabled': false, // V1=false 且无入口
        'processor_location_category': 'in_region',
      });
      expect(caps.scopes, ['personal', 'organization']);
      expect(caps.languages, ['zh-CN', 'en-US']);
      expect(caps.maxDurationMs, 7200000);
      expect(caps.maxRecordingBytes, 2147483648);
      expect(caps.maxPartBytes, 16777216);
      expect(caps.storageRemainingBytes, 1073741824);
      expect(caps.processingAvailable, isTrue);
      expect(caps.queueLimit, 5);
      expect(caps.retentionPolicy, 'enterprise-365d');
      expect(caps.policyVersion, 'notice-v1');
      expect(caps.voiceIdEnabled, isFalse);
      expect(caps.canProcess, isTrue);
      expect(caps.processorLocationCategory, 'in_region');
    });

    test('空对象容错：缺省 0/false/空列表', () {
      final caps = TalkRecordCapabilitiesModel.fromJson(const {});
      expect(caps.scopes, isEmpty);
      expect(caps.maxDurationMs, 0);
      expect(caps.processingAvailable, isFalse);
      expect(caps.voiceIdEnabled, isFalse);
      expect(caps.canProcess, isFalse);
    });
  });

  group('creation-contexts 响应（§8）', () {
    test('个人/企业上下文解析 + cursor 分页形状', () async {
      final api = _RecordingApi();
      api.next = IMBoyHttpResponse.success({
        'list': [
          {
            'scope': 'personal',
            'display_name': '个人',
            'retention_policy': 'personal-default',
            'processing_notice_version': 'notice-v1',
            'capabilities': {'record': true, 'transcribe': true},
          },
          {
            'scope': 'organization',
            'organization_id': 42,
            'workspace_id': 64,
            'name': '示例企业 / 主工作区',
            'retention_policy': 'enterprise-365d',
            'processing_notice_version': 'notice-v2',
            'capabilities': {
              'record': true,
              'transcribe': false,
              'summarize': false,
              'export': true,
            },
          },
        ],
        'next_cursor': 'ctx-9',
        'has_more': true,
      });
      final page = await api.creationContexts(cursor: 'ctx-4', limit: 20);

      expect(api.lastUri, API.talkRecordCreationContexts);
      expect(api.lastQuery, {'cursor': 'ctx-4', 'limit': 20});
      expect(page.list.length, 2);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'ctx-9');

      expect(page.list.first.scope, TalkRecordScope.personal);
      expect(page.list.first.organizationId, isEmpty);
      expect(page.list.first.capabilities.transcribe, isTrue);

      final org = page.list.last;
      expect(org.scope, TalkRecordScope.organization);
      expect(org.organizationId, '42');
      expect(org.workspaceId, '64');
      expect(org.displayName, '示例企业 / 主工作区');
      expect(org.capabilities.transcribe, isFalse);
      expect(org.capabilities.exportAllowed, isTrue);
      expect(org.processingNoticeVersion, 'notice-v2');
    });

    test('has_more 缺省时按 next_cursor 推断', () async {
      final api = _RecordingApi();
      api.next = IMBoyHttpResponse.success({
        'list': <Map<String, dynamic>>[],
        'next_cursor': '',
      });
      final page = await api.creationContexts();
      expect(page.list, isEmpty);
      expect(page.hasMore, isFalse);
      // 未传 cursor/limit 时查询参数为空（API 不携带多余参数）。
      expect(api.lastQuery ?? const <String, dynamic>{}, isEmpty);
    });
  });

  group('cursor 分页参数构造（§4：cursor 绑定筛选与调用者）', () {
    test('list：scope/org/ws/filter/q + cursor/limit 透传', () async {
      final api = _RecordingApi();
      api.next = IMBoyHttpResponse.success({'list': <dynamic>[]});
      await api.list(
        scope: TalkRecordScope.organization,
        organizationId: '42',
        workspaceId: '64',
        filter: TalkRecordListFilter.shared,
        q: '例会',
        cursor: 'abc',
        limit: 50,
      );
      expect(api.lastUri, API.talkRecords);
      expect(api.lastQuery, {
        'cursor': 'abc',
        'limit': 50,
        'scope': 'organization',
        'organization_id': '42',
        'workspace_id': '64',
        'filter': 'shared',
        'q': '例会',
      });
    });

    test('segments：speaker_id/q + cursor/limit', () async {
      final api = _RecordingApi();
      api.next = IMBoyHttpResponse.success({
        'list': [
          {
            'id': 7001,
            'record_id': 2001,
            'transcript_version': 1,
            'seq': 0,
            'speaker_id': 7101,
            'start_ms': 0,
            'end_ms': 15200,
            'text': '大家好',
            'confidence': 0.92,
            'is_final': true,
            'origin': 'model',
            'revision': 1,
          },
        ],
        'next_cursor': '',
        'has_more': false,
      });
      final page = await api.segments(
        '2001',
        speakerId: '7101',
        q: '大家',
        cursor: 'seg-1',
        limit: 100,
      );
      expect(api.lastUri, API.talkRecordSegments('2001'));
      expect(api.lastQuery, {
        'cursor': 'seg-1',
        'limit': 100,
        'speaker_id': '7101',
        'q': '大家',
      });
      final seg = page.list.single;
      expect(seg.id, '7001');
      expect(seg.speakerId, '7101');
      expect(seg.confidence, 0.92);
      expect(seg.origin, TalkRecordSegmentOrigin.model);
      expect(seg.isHumanEdited, isFalse);
      expect(page.hasMore, isFalse);
    });

    test('marks：仅 cursor/limit；空过滤不携带', () async {
      final api = _RecordingApi();
      api.next = IMBoyHttpResponse.success({'list': <dynamic>[]});
      await api.marks('2001', cursor: 'm-3');
      expect(api.lastQuery, {'cursor': 'm-3'});
    });
  });

  group('子资源模型解析', () {
    test('summary：decision/action 携 segment_ids；未指定 assignee 为空', () {
      final summary = TalkRecordSummaryModel.fromJson(const {
        'id': 8001,
        'record_id': 2001,
        'source_transcript_version': 1,
        'source_content_revision': 3,
        'status': 'draft',
        'overview': '讨论了 A 方案',
        'decisions': [
          {
            'text': '采用 A 方案',
            'segment_ids': [7001, 7002],
          },
        ],
        'actions': [
          {
            'text': '同步设计稿',
            'segment_ids': [7003],
            'assignee': null,
          },
        ],
        'model_version': 'demo',
        'revision': 2,
      });
      expect(summary.status, TalkRecordSummaryStatus.draft);
      expect(summary.decisions.single.segmentIds, ['7001', '7002']);
      // §11.2：事实不确定保持未指定，不编造负责人。
      expect(summary.actions.single.assignee, isEmpty);
      expect(summary.hasContent, isTrue);
    });

    test('summary 状态对象：未生成时不伪装 404，正文为空', () {
      final summary = TalkRecordSummaryModel.fromJson(const {
        'status': 'not_requested',
      });
      expect(summary.status, TalkRecordSummaryStatus.unknown);
      expect(summary.hasContent, isFalse);
      expect(summary.decisions, isEmpty);
    });

    test('speaker：identity_source/置信度/认领判定', () {
      final speaker = TalkRecordSpeakerModel.fromJson(const {
        'id': 7101,
        'record_id': 2001,
        'local_label': '说话人 1',
        'display_name': '李雷',
        'matched_user_id': 3002,
        'identity_source': 'self_claim',
        'confirmed_by': 3002,
        'confidence': null,
        'revision': 4,
      });
      expect(speaker.identitySource, TalkRecordSpeakerIdentitySource.selfClaim);
      expect(speaker.matchedUserId, '3002');
      expect(speaker.confidence, isNull);
      expect(speaker.isClaimed, isTrue);
    });

    test('grant：role/allow_export/撤销判定', () {
      final grant = TalkRecordGrantModel.fromJson(const {
        'id': 9001,
        'record_id': 2001,
        'grantee_user_id': 3002,
        'role': 'viewer',
        'allow_export': false,
        'granted_by': 3001,
        'revoked_at': null,
      });
      expect(grant.role, TalkRecordGrantRole.viewer);
      expect(grant.allowExport, isFalse);
      expect(grant.isActive, isTrue);
    });

    test('job：state/kind/needsPolling/errorCode', () {
      final job = TalkRecordJobModel.fromJson(const {
        'id': 9101,
        'record_id': 2001,
        'kind': 'transcribe',
        'input_version': 'v1:3',
        'state': 'retry_wait',
        'attempt': 2,
        'error_code': 5501,
        'can_retry': true,
      });
      expect(job.kind, TalkRecordJobKind.transcribe);
      expect(job.state, TalkRecordJobState.retryWait);
      expect(job.needsPolling, isTrue);
      expect(job.errorCode, 5501);
      expect(job.canRetry, isTrue);
    });

    test('mark：capture_id + capture_offset_ms（§11.1）', () {
      final mark = TalkRecordMarkModel.fromJson(const {
        'id': 9201,
        'record_id': 2001,
        'author_id': 3001,
        'client_mark_id': 'm-uuid-1',
        'position_ms': 65_000,
        'text': '关键结论',
        'capture_id': 5001,
        'capture_offset_ms': 65_000,
      });
      expect(mark.positionMs, 65000);
      expect(mark.captureId, '5001');
      expect(mark.captureOffsetMs, 65000);
    });
  });
}
