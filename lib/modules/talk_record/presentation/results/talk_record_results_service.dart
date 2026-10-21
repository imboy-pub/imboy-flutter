/// 面聊记录（talk_record）结果域服务抽象（T21：导出/责任移交/删除）。
///
/// 页面不直接持有 [TalkRecordApi]：导出、责任移交、删除及清理状态全部
/// 经此抽象网关注入（对齐 T10/T16/T18 服务纪律）：
/// 1. widget 测试零网络（fixture 注入，
///    见 talk_record_results_fixture_service.dart）；
/// 2. T19/T20 联调时替换为真实实现而无需改页面；
/// 3. 失败如实抛 [TalkRecordApiException]（403/404/410/412 语义驱动
///    门控、到期视图与冲突 UI），不吞错。
///
/// 契约源：BACKEND-API.md §4（POST /:id/exports、GET
/// /:id/exports/:export_id/download 到期 410、DELETE /:id 202
/// logical_deleted + cleanup_status）+ §9（POST /:id/ownership-transfers：
/// 当前 owner、If-Match+Idempotency-Key、原 owner 是否保留显式 grant 由
/// 请求明确决定、不修改 created_by/scope）+ §10.4（删除状态拆分
/// logical_deleted/cleanup_status 五态/physical_delete_state；排队≠字节
/// 已删除）+ §11.3（DELETE 后 owner 读取仅返回清理状态白名单，其余 404）。
///
/// Export polling and ownership transfer follow the implemented backend contract.
/// Cleanup retry uses the authenticated record-scoped capability and generation CAS.
library;

import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart'
    show TalkRecordApiException;
import 'package:imboy/store/api/talk_record_api.dart'
    show
        TalkRecordApi,
        TalkRecordDeleteResult,
        TalkRecordExportResult,
        TalkRecordFetched,
        TalkRecordResultOperations,
        TalkRecordTransferCandidatesApi;
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart'
    show TalkRecordShareCandidateModel;
import 'package:imboy/store/model/talk_record/talk_record_cursor_page.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/workspace_model.dart'
    show EntityId, entityIdOf;

import '../share/talk_record_share_service.dart'
    show TalkRecordExportBlockReason;

// 复用分享域导出阻止原因枚举（同一 §9 策略语义，防止两处漂移）。
export '../share/talk_record_share_service.dart'
    show TalkRecordExportBlockReason;

/// 导出策略投影（§8 导出行：企业记录还必须通过企业 export capability，
/// owner 不能绕过；策略禁用时 UI disabled + 原因展示）。
class TalkRecordExportPolicy {
  /// 实例/企业策略是否允许导出这条记录的文字内容。
  final bool exportAllowed;

  /// 被阻止时的原因（exportAllowed=true 时忽略）。
  final TalkRecordExportBlockReason blockReason;

  const TalkRecordExportPolicy({
    this.exportAllowed = false,
    this.blockReason = TalkRecordExportBlockReason.unknown,
  });

  const TalkRecordExportPolicy.allowed()
    : this(exportAllowed: true, blockReason: TalkRecordExportBlockReason.none);

  const TalkRecordExportPolicy.blocked(TalkRecordExportBlockReason reason)
    : this(exportAllowed: false, blockReason: reason);
}

/// 导出产物状态（§2 talk_record_export：state；到期 expires_at；
/// V1 不包含音频/未授权参与者信息）。
class TalkRecordExportArtifact {
  final EntityId exportId;
  final TalkRecordExportFormat format;

  /// queued | ready | failed（组件阶段投影；完整 job 状态归 jobs 端点）。
  final String state;
  final DateTime? expiresAt;
  final Map<String, dynamic> raw;

  const TalkRecordExportArtifact({
    this.exportId = '',
    this.format = TalkRecordExportFormat.txt,
    this.state = '',
    this.expiresAt,
    this.raw = const {},
  });

  bool get isReady => state == 'ready';
  bool get isQueued => state == 'queued';

  factory TalkRecordExportArtifact.fromExportResult(
    TalkRecordExportResult result,
    TalkRecordExportFormat format,
  ) {
    return TalkRecordExportArtifact(
      exportId: result.exportId,
      format: format,
      state: result.state,
      expiresAt: parseModelNullableDateTime(result.raw['expires_at']),
      raw: result.raw,
    );
  }
}

/// 责任移交结果（§9：服务器事务更新 owner、审计；原 owner 是否保留显式
/// grant 由请求明确决定；不修改 created_by/scope——归属不变）。
class TalkRecordTransferOutcome {
  final EntityId newOwnerUserId;
  final String newOwnerDisplayName;

  /// 原 owner 是否按请求保留了查看授权（显式 grant，默认不保留）。
  final bool originalOwnerKeptViewer;

  const TalkRecordTransferOutcome({
    this.newOwnerUserId = '',
    this.newOwnerDisplayName = '',
    this.originalOwnerKeptViewer = false,
  });
}

/// 结果域数据服务抽象（T21 UI 消费面）。
abstract class TalkRecordResultsService {
  /// GET /:id（门控真源：capabilities_for_actor.export/delete/
  /// transfer_owner；已删除记录 owner 读取仅返回清理状态白名单，
  /// 其余人 404，§11.3）。
  Future<TalkRecordFetched<TalkRecordModel>> record(EntityId id);

  /// 当前记录归属下的导出策略（§8/§9：策略禁止时禁用并说明原因）。
  Future<TalkRecordExportPolicy> exportPolicy(EntityId id);

  /// POST /:id/exports（format=txt/md；Idempotency-Key；202 export/job；
  /// 不包含音频/未授权参与者信息）。
  Future<TalkRecordExportArtifact> createExport(
    EntityId id, {
    required TalkRecordExportFormat format,
    required String idempotencyKey,
  });

  /// 导出产物状态（queued → ready；排队不伪造完成时刻，§3）。
  /// GET /:id/exports/:export_id；保留 expired 终态。
  Future<TalkRecordExportArtifact> exportState(EntityId id, EntityId exportId);

  /// GET /:id/exports/:export_id/download（每次下载重验 ACL + requester；
  /// 短时受控 URL；到期 410）。
  Future<String> exportDownloadUrl(EntityId id, EntityId exportId);

  /// 移交候选（§9：同企业且符合工作区授权的同事；服务端裁决，
  /// 候选≠授权凭证）。复用 share-candidates 目录形状。
  Future<TalkRecordCursorPage<TalkRecordShareCandidateModel>>
  transferCandidates(EntityId id, {String? q, String cursor = '', int? limit});

  /// POST /:id/ownership-transfers（当前 owner；If-Match + Idempotency-Key；
  /// keepViewerForOriginalOwner 由请求明确决定；不修改 created_by/scope）。
  Future<TalkRecordTransferOutcome> transferOwnership(
    EntityId id, {
    required EntityId targetUserId,
    required bool keepViewerForOriginalOwner,
    required String ifMatch,
    required String idempotencyKey,
  });

  /// DELETE /:id（owner + If-Match；202 logical_deleted=true、
  /// cleanup_status=pending；立即撤权，§4/§10.4）。
  Future<TalkRecordDeleteResult> deleteRecord(
    EntityId id, {
    required String ifMatch,
  });

  /// Cleanup recovery requires the server capability, revision and generation.
  /// A missing generation is rejected before HTTP for legacy callers.
  Future<void> retryCleanup(
    EntityId id, {
    required String ifMatch,
    required String idempotencyKey,
    int? generation,
    void Function()? requestGuard,
  });
}

/// Authenticated result-domain adapter for the implemented backend routes.
class ApiTalkRecordResultsService implements TalkRecordResultsService {
  ApiTalkRecordResultsService([TalkRecordApi? api])
    : _api = api ?? TalkRecordApi();

  final TalkRecordApi _api;

  @override
  Future<TalkRecordFetched<TalkRecordModel>> record(EntityId id) {
    return _api.detail(id);
  }

  @override
  Future<TalkRecordExportPolicy> exportPolicy(EntityId id) async {
    final record = await _api.detail(id);
    // Server projection already combines policy and actor/grant permission.
    return record.data.capabilitiesForActor.export
        ? const TalkRecordExportPolicy.allowed()
        : const TalkRecordExportPolicy.blocked(
            TalkRecordExportBlockReason.unknown,
          );
  }

  @override
  Future<TalkRecordExportArtifact> createExport(
    EntityId id, {
    required TalkRecordExportFormat format,
    required String idempotencyKey,
  }) async {
    final result = await _api.createExport(
      id,
      format: format,
      idempotencyKey: idempotencyKey,
    );
    return TalkRecordExportArtifact.fromExportResult(result, format);
  }

  @override
  Future<TalkRecordExportArtifact> exportState(
    EntityId id,
    EntityId exportId,
  ) async {
    final payload = await _api.exportStatePayload(id, exportId);
    final returnedId = entityIdOf(payload['export_id']);
    final state = payload['state'];
    final format = payload['format'];
    if (returnedId != exportId ||
        !const ['queued', 'ready', 'failed', 'expired'].contains(state) ||
        !const ['txt', 'md'].contains(format)) {
      throw const FormatException('Invalid export state response');
    }
    return TalkRecordExportArtifact(
      exportId: returnedId,
      state: state as String,
      format: format == 'md'
          ? TalkRecordExportFormat.md
          : TalkRecordExportFormat.txt,
      expiresAt: parseModelNullableDateTime(payload['expires_at']),
      raw: payload,
    );
  }

  @override
  Future<String> exportDownloadUrl(EntityId id, EntityId exportId) {
    return _api.exportDownloadUrl(id, exportId);
  }

  @override
  Future<TalkRecordCursorPage<TalkRecordShareCandidateModel>>
  transferCandidates(EntityId id, {String? q, String cursor = '', int? limit}) {
    // Existing grants do not exclude legitimate ownership-transfer candidates.
    return _api.transferCandidates(id, q: q, cursor: cursor, limit: limit);
  }

  @override
  Future<TalkRecordTransferOutcome> transferOwnership(
    EntityId id, {
    required EntityId targetUserId,
    required bool keepViewerForOriginalOwner,
    required String ifMatch,
    required String idempotencyKey,
  }) {
    return _api
        .transferOwnershipPayload(
          id,
          targetUserId: targetUserId,
          keepAccess: keepViewerForOriginalOwner,
          ifMatch: ifMatch,
          idempotencyKey: idempotencyKey,
        )
        .then((payload) {
          final owner = entityIdOf(payload['new_owner_user_id']);
          if (owner != targetUserId || payload['keep_access'] is! bool) {
            throw const FormatException('Invalid ownership transfer response');
          }
          return TalkRecordTransferOutcome(
            newOwnerUserId: owner,
            newOwnerDisplayName: parseModelString(
              payload['new_owner_display_name'],
            ),
            originalOwnerKeptViewer: payload['keep_access'] as bool,
          );
        });
  }

  @override
  Future<TalkRecordDeleteResult> deleteRecord(
    EntityId id, {
    required String ifMatch,
  }) {
    return _api.deleteRecord(id, ifMatch: ifMatch);
  }

  @override
  Future<void> retryCleanup(
    EntityId id, {
    required String ifMatch,
    required String idempotencyKey,
    int? generation,
    void Function()? requestGuard,
  }) {
    if (generation == null) {
      throw const TalkRecordApiException(422, 'Cleanup generation required');
    }
    return _api.retryPhysicalCleanup(
      id,
      etag: ifMatch,
      generation: generation,
      idempotencyKey: idempotencyKey,
      requestGuard: requestGuard,
    );
  }
}
