/// 面聊记录（talk_record）结果域 fixture 服务（T21，component 阶段）。
///
/// **声明：fixture 只证明组件行为，不冒充真实导出/移交/删除生效。**
/// 内存实现模拟 BACKEND-API.md §4/§9/§10.4/§11.3 端点形状的关键语义：
/// - 导出：caps.export ∩ policy 才可创建（403 语义）；排队→就绪可编程；
///   下载返回短时示例 URL；到期/过期抛 410 GONE（不伪造续期）；
/// - 移交：仅 caps.transfer_owner（当前 owner）；If-Match 错配 412；
///   成功换 owner、推进 revision/acl_revision，**不修改 created_by/scope**
///   （归属不变）；keepViewer 由请求显式决定；
/// - 删除：caps.delete 才可删；202 语义 = logical_deleted=true +
///   cleanup_status=pending；删除后 record() 对 owner 仅返回清理状态
///   白名单（正文清空），非 owner 统一 404（§11.3）；
/// - 清理：五态可编程推进；failed 可重试回 pending（重试≠立即成功）。
/// 真实联调（T19/T20）后由 API 实现替换。
library;

import 'package:imboy/config/error_code.dart';
import 'package:imboy/modules/talk_record/talk_record_error.dart'
    show TalkRecordApiException;
import 'package:imboy/store/api/talk_record_api.dart'
    show TalkRecordDeleteResult, TalkRecordFetched;
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart'
    show TalkRecordShareCandidateModel;
import 'package:imboy/store/model/talk_record/talk_record_cursor_page.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

import 'talk_record_results_service.dart';

/// 内存 fixture 结果域条目（单记录粒度；测试按需播种多记录）。
///
/// 所有候选/责任人为虚构用户，不对应真实账号。
class TalkRecordResultsFixtureEntry {
  TalkRecordModel record;

  /// record ETag（If-Match 校验；对应 record.revision，删除/移交用）。
  String recordEtag;
  TalkRecordExportPolicy exportPolicy;
  List<TalkRecordShareCandidateModel> transferCandidates;

  /// 当前主体 user_id（非 owner 门控 fixture 等价物）。
  EntityId currentUserId;

  /// exportState 轮询多少次后进入 ready（0=创建即 ready）。
  int exportPollsToReady;

  /// 已过期（下载 410）的 exportId 集合。
  final Set<EntityId> expiredExports = {};

  /// 下一个 exportId（fixture 递增）。
  EntityId nextExportId;

  /// createExport 是否应失败（组件失败态演示）。
  bool exportShouldFail;

  /// transferOwnership 是否应 412（冲突演示）。
  bool transferShouldConflict;

  /// deleteRecord 是否应 412（冲突演示）。
  bool deleteShouldConflict;

  /// retryCleanup 是否应失败（重试失败态演示）。
  bool cleanupRetryShouldFail;

  /// 已创建的导出产物（exportId → artifact）。
  final Map<EntityId, TalkRecordExportArtifact> exports = {};

  /// 最近一次移交结果（测试断言用）。
  TalkRecordTransferOutcome? lastTransfer;

  /// retryCleanup 调用计数（测试断言用）。
  int cleanupRetryCount = 0;

  TalkRecordResultsFixtureEntry({
    required this.record,
    required this.recordEtag,
    this.exportPolicy = const TalkRecordExportPolicy.allowed(),
    this.transferCandidates = const [],
    this.currentUserId = '9001',
    this.exportPollsToReady = 0,
    EntityId? nextExportId,
    this.exportShouldFail = false,
    this.transferShouldConflict = false,
    this.deleteShouldConflict = false,
    this.cleanupRetryShouldFail = false,
    this.denyAccess = false,
  }) : nextExportId = nextExportId ?? '8001';

  /// 当前主体是否 owner（§9 owner_user_id 为当前管理责任人）。
  bool get isOwner => record.ownerUserId == currentUserId;

  /// 显式无访问标记（record() 统一 404，§11.3 防探测演示）。
  bool denyAccess;
}

/// fixture 结果域服务。
class FixtureTalkRecordResultsService implements TalkRecordResultsService {
  FixtureTalkRecordResultsService(this.entries);

  final List<TalkRecordResultsFixtureEntry> entries;

  /// 测试钩子：直接推进清理状态（模拟五态治理裁决，§10.4）。
  void setCleanupStatus(EntityId recordId, TalkRecordCleanupStatus status) {
    final e = _entry(recordId);
    e.record = _copyWith(
      e.record,
      deletedAt: e.record.deletedAt ?? DateTime.now(),
      cleanupStatus: status,
    );
  }

  /// 测试钩子：直接把某导出标记过期（下载 410 演示）。
  void expireExport(EntityId recordId, EntityId exportId) {
    _entry(recordId).expiredExports.add(exportId);
  }

  TalkRecordResultsFixtureEntry _entry(EntityId id) {
    return entries.firstWhere(
      (e) => e.record.id == id,
      orElse: () => throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'record not found (fixture)',
      ),
    );
  }

  void _checkIfMatch(TalkRecordResultsFixtureEntry e, String ifMatch) {
    if (ifMatch != e.recordEtag) {
      throw const TalkRecordApiException(
        ErrorCode.PRECONDITION_FAILED,
        'record revision stale (fixture 412)',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 读取（门控 + 删除后白名单）
  // ---------------------------------------------------------------------------

  @override
  Future<TalkRecordFetched<TalkRecordModel>> record(EntityId id) async {
    final e = _entry(id);
    if (e.record.isDeleted) {
      // §11.3：DELETE 后 owner 读取仅返回清理状态白名单（不回正文/
      // 标题/人员）；其余人统一 404。
      if (!e.isOwner) {
        throw const TalkRecordApiException(
          ErrorCode.NOT_FOUND,
          'no access (fixture)',
        );
      }
      final whitelist = _copyWith(
        e.record,
        title: '',
        notes: '',
        // 白名单投影：只保留 id/归属/删除与清理状态语义。
        transcriptStatus: TalkRecordProcessingStatus.unknown,
        summaryStatus: TalkRecordProcessingStatus.unknown,
        capabilitiesForActor: const TalkRecordCapabilitiesForActor(),
      );
      return TalkRecordFetched(whitelist, etag: 'record:${whitelist.revision}');
    }
    if (e.denyAccess) {
      // 非 owner 且无任何授权 → 统一 404（§11.3 不区分防探测）。
      throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'no access (fixture)',
      );
    }
    return TalkRecordFetched(e.record, etag: e.recordEtag);
  }

  @override
  Future<TalkRecordExportPolicy> exportPolicy(EntityId id) async {
    return _entry(id).exportPolicy;
  }

  // ---------------------------------------------------------------------------
  // 导出
  // ---------------------------------------------------------------------------

  @override
  Future<TalkRecordExportArtifact> createExport(
    EntityId id, {
    required TalkRecordExportFormat format,
    required String idempotencyKey,
  }) async {
    final e = _entry(id);
    if (!e.record.capabilitiesForActor.export ||
        !e.exportPolicy.exportAllowed) {
      // §4/§9：导出须有导出权限且策略允许；客户端判定不构成授权。
      throw const TalkRecordApiException(
        ErrorCode.FORBIDDEN,
        'export not allowed (fixture 403)',
      );
    }
    if (e.exportShouldFail) {
      throw const TalkRecordApiException(
        ErrorCode.SERVICE_UNAVAILABLE,
        'export job failed (fixture)',
      );
    }
    final exportId = e.nextExportId;
    e.nextExportId = '${(int.tryParse(e.nextExportId) ?? 8000) + 1}';
    final state = e.exportPollsToReady > 0 ? 'queued' : 'ready';
    final artifact = TalkRecordExportArtifact(
      exportId: exportId,
      format: format,
      state: state,
      // §2：导出对象短期自动清理；fixture TTL 15 分钟。
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      raw: const {'fixture': true},
    );
    e.exports[exportId] = artifact;
    return artifact;
  }

  @override
  Future<TalkRecordExportArtifact> exportState(
    EntityId id,
    EntityId exportId,
  ) async {
    final e = _entry(id);
    final artifact = e.exports[exportId];
    if (artifact == null) {
      throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'export not found (fixture)',
      );
    }
    if (artifact.isQueued && e.exportPollsToReady > 0) {
      e.exportPollsToReady--;
      if (e.exportPollsToReady == 0) {
        final ready = TalkRecordExportArtifact(
          exportId: artifact.exportId,
          format: artifact.format,
          state: 'ready',
          expiresAt: artifact.expiresAt,
          raw: artifact.raw,
        );
        e.exports[exportId] = ready;
        return ready;
      }
    }
    return artifact;
  }

  @override
  Future<String> exportDownloadUrl(EntityId id, EntityId exportId) async {
    final e = _entry(id);
    final artifact = e.exports[exportId];
    if (artifact == null) {
      throw const TalkRecordApiException(
        ErrorCode.NOT_FOUND,
        'export not found (fixture)',
      );
    }
    final expired =
        e.expiredExports.contains(exportId) ||
        (artifact.expiresAt != null &&
            DateTime.now().isAfter(artifact.expiresAt!));
    if (expired) {
      // §4：到期 410；不可向公共 bucket 开永久 URL。
      throw const TalkRecordApiException(
        ErrorCode.GONE,
        'export expired (fixture 410)',
      );
    }
    // 短时受控下载 URL（fixture 示例；不产生真实文件）。
    return '/api/v1/talk-records/$id/exports/'
        '$exportId/download?ticket=synthetic-ticket';
  }

  // ---------------------------------------------------------------------------
  // 责任移交（§9）
  // ---------------------------------------------------------------------------

  @override
  Future<TalkRecordCursorPage<TalkRecordShareCandidateModel>>
  transferCandidates(
    EntityId id, {
    String? q,
    String cursor = '',
    int? limit,
  }) async {
    final e = _entry(id);
    var rows = e.transferCandidates
        .where((c) => c.userId != e.record.ownerUserId)
        .toList();
    if (q != null && q.isNotEmpty) {
      final kw = q.toLowerCase();
      rows = rows
          .where(
            (c) =>
                c.displayName.toLowerCase().contains(kw) ||
                c.account.toLowerCase().contains(kw),
          )
          .toList();
    }
    return TalkRecordCursorPage(list: rows, nextCursor: '', hasMore: false);
  }

  @override
  Future<TalkRecordTransferOutcome> transferOwnership(
    EntityId id, {
    required EntityId targetUserId,
    required bool keepViewerForOriginalOwner,
    required String ifMatch,
    required String idempotencyKey,
  }) async {
    final e = _entry(id);
    if (!e.record.capabilitiesForActor.transferOwner || !e.isOwner) {
      // §9：当前 owner 在仍有权时才可移交；客户端门控只是展示层。
      throw const TalkRecordApiException(
        ErrorCode.FORBIDDEN,
        'only current owner can transfer (fixture 403)',
      );
    }
    _checkIfMatch(e, ifMatch);
    if (e.transferShouldConflict) {
      throw const TalkRecordApiException(
        ErrorCode.PRECONDITION_FAILED,
        'record revision stale (fixture 412)',
      );
    }
    TalkRecordShareCandidateModel? target;
    for (final c in e.transferCandidates) {
      if (c.userId == targetUserId) {
        target = c;
        break;
      }
    }
    if (target == null) {
      // 目标仍须合法（同企业 + 工作区授权；§3 移交行「目标仍须合法」）。
      throw const TalkRecordApiException(
        ErrorCode.FORBIDDEN,
        'transfer target not eligible (fixture 403)',
      );
    }
    final originalOwner = e.record.ownerUserId;
    // §9：更新 owner，推进 revision/acl_revision；不改 created_by/scope。
    e.record = _copyWith(
      e.record,
      ownerUserId: targetUserId,
      revision: e.record.revision + 1,
      aclRevision: e.record.aclRevision + 1,
    );
    e.recordEtag = 'record:${e.record.revision}';
    e.lastTransfer = TalkRecordTransferOutcome(
      newOwnerUserId: targetUserId,
      newOwnerDisplayName: target.displayName,
      originalOwnerKeptViewer: keepViewerForOriginalOwner,
    );
    if (!keepViewerForOriginalOwner) {
      // 不保留 → 原 owner 立即失去访问（§9：原 owner 不再有权访问内容）；
      // 页面据此呈现通用失效页（不泄露具体原因，§11.3）。
      e.currentUserId = originalOwner;
      e.denyAccess = true;
    }
    return e.lastTransfer!;
  }

  // ---------------------------------------------------------------------------
  // 删除与清理（§4/§10.4）
  // ---------------------------------------------------------------------------

  @override
  Future<TalkRecordDeleteResult> deleteRecord(
    EntityId id, {
    required String ifMatch,
  }) async {
    final e = _entry(id);
    if (!e.record.capabilitiesForActor.delete) {
      // §3 角色表：删除仅 owner（受治理限制）。
      throw const TalkRecordApiException(
        ErrorCode.FORBIDDEN,
        'only owner can delete (fixture 403)',
      );
    }
    _checkIfMatch(e, ifMatch);
    if (e.deleteShouldConflict) {
      throw const TalkRecordApiException(
        ErrorCode.PRECONDITION_FAILED,
        'record revision stale (fixture 412)',
      );
    }
    e.record = _copyWith(
      e.record,
      deletedAt: DateTime.now(),
      cleanupStatus: TalkRecordCleanupStatus.pending,
      revision: e.record.revision + 1,
      aclRevision: e.record.aclRevision + 1,
    );
    e.recordEtag = 'record:${e.record.revision}';
    // §4：202 语义 = logical_deleted=true + cleanup_status=pending；
    // 排队成功 ≠ 字节已删除。
    return TalkRecordDeleteResult(
      logicalDeleted: true,
      cleanupStatus: TalkRecordCleanupStatus.pending,
      raw: const {'fixture': true},
    );
  }

  @override
  Future<void> retryCleanup(
    EntityId id, {
    required String ifMatch,
    required String idempotencyKey,
  }) async {
    final e = _entry(id);
    if (!e.isOwner) {
      throw const TalkRecordApiException(
        ErrorCode.FORBIDDEN,
        'only owner can retry cleanup (fixture 403)',
      );
    }
    e.cleanupRetryCount++;
    if (e.cleanupRetryShouldFail) {
      throw const TalkRecordApiException(
        ErrorCode.SERVICE_UNAVAILABLE,
        'cleanup retry failed (fixture)',
      );
    }
    if (e.record.cleanupStatus != TalkRecordCleanupStatus.failed) {
      // 仅清理失败态可重试（对齐 §4 retry「只允许可重试失败」纪律）。
      throw const TalkRecordApiException(
        ErrorCode.CONFLICT,
        'cleanup not in retryable state (fixture 409)',
      );
    }
    // 重试成功 → 回到 pending（再次排队；仍非字节已删除）。
    e.record = _copyWith(
      e.record,
      cleanupStatus: TalkRecordCleanupStatus.pending,
    );
  }

  // ---------------------------------------------------------------------------
  // 复制辅助（不可变模型推进）
  // ---------------------------------------------------------------------------

  static TalkRecordModel _copyWith(
    TalkRecordModel r, {
    EntityId? ownerUserId,
    String? title,
    String? notes,
    DateTime? deletedAt,
    TalkRecordCleanupStatus? cleanupStatus,
    TalkRecordProcessingStatus? transcriptStatus,
    TalkRecordProcessingStatus? summaryStatus,
    int? revision,
    int? aclRevision,
    TalkRecordCapabilitiesForActor? capabilitiesForActor,
  }) {
    return TalkRecordModel(
      id: r.id,
      ownerUserId: ownerUserId ?? r.ownerUserId,
      createdBy: r.createdBy,
      clientRecordingId: r.clientRecordingId,
      sourceType: r.sourceType,
      scope: r.scope,
      organizationId: r.organizationId,
      workspaceId: r.workspaceId,
      title: title ?? r.title,
      language: r.language,
      activeCaptureId: r.activeCaptureId,
      captureStatus: r.captureStatus,
      mediaStatus: r.mediaStatus,
      transcriptStatus: transcriptStatus ?? r.transcriptStatus,
      summaryStatus: summaryStatus ?? r.summaryStatus,
      processingMode: r.processingMode,
      durationMs: r.durationMs,
      currentTranscriptId: r.currentTranscriptId,
      contentRevision: r.contentRevision,
      notes: notes ?? r.notes,
      revision: revision ?? r.revision,
      aclRevision: aclRevision ?? r.aclRevision,
      createdAt: r.createdAt,
      updatedAt: DateTime.now(),
      endedAt: r.endedAt,
      deletedAt: deletedAt ?? r.deletedAt,
      retentionUntil: r.retentionUntil,
      cleanupStatus: cleanupStatus ?? r.cleanupStatus,
      cleanupReason: r.cleanupReason,
      visibility: r.visibility,
      capabilitiesForActor: capabilitiesForActor ?? r.capabilitiesForActor,
    );
  }
}

// ---------------------------------------------------------------------------
// 场景构造器（fixture 数据——仅证明组件行为，人名均为虚构）
// ---------------------------------------------------------------------------

/// 按场景播种 fixture 服务。所有候选/责任人为虚构用户。
class TalkRecordResultsFixtureScenarios {
  static const _ownerOrgCaps = {
    'edit': true,
    'share': true,
    'export': true,
    'can_delete': true,
    'can_transfer_owner': true,
    'playback': true,
  };
  static const _editorExportCaps = {
    'edit': true,
    'share': false,
    'export': true, // grant.allow_export=true 投影（§3：非 owner 须单独授予）
    'can_delete': false,
    'playback': true,
  };
  static const _viewerCaps = {
    'edit': false,
    'share': false,
    'export': false,
    'can_delete': false,
    'playback': true,
  };

  /// 基础条目构造。
  static TalkRecordResultsFixtureEntry entry({
    required String recordId,
    String title = '项目例会',
    String scope = 'organization',
    Map<String, dynamic> caps = _ownerOrgCaps,
    String currentUserId = '9001',
    String ownerUserId = '9001',
    TalkRecordExportPolicy exportPolicy =
        const TalkRecordExportPolicy.allowed(),
    // 默认空（默认参数须为 const）；场景按需传 defaultTransferCandidates()。
    List<TalkRecordShareCandidateModel> transferCandidates = const [],
    int exportPollsToReady = 0,
    bool exportShouldFail = false,
    bool transferShouldConflict = false,
    bool deleteShouldConflict = false,
    bool cleanupRetryShouldFail = false,
    bool denyAccess = false,
    bool deleted = false,
    TalkRecordCleanupStatus cleanupStatus = TalkRecordCleanupStatus.none,
  }) {
    final record = TalkRecordModel.fromJson({
      'id': recordId,
      'owner_user_id': ownerUserId,
      'created_by': '9001',
      'title': title,
      'scope': scope,
      'capture_status': 'ended',
      'media_status': 'available',
      'transcript_status': 'ready',
      'summary_status': 'draft',
      'processing_mode': 'summarize',
      'duration_ms': 655_000,
      'revision': 2,
      'acl_revision': 1,
      'visibility': 'owner_only',
      'capabilities_for_actor': caps,
      if (deleted) 'deleted_at': '2026-10-20T10:00:00Z',
      'cleanup_status': cleanupStatus.wireName,
    });
    return TalkRecordResultsFixtureEntry(
      record: record,
      recordEtag: 'record:2',
      exportPolicy: exportPolicy,
      transferCandidates: transferCandidates,
      currentUserId: currentUserId,
      exportPollsToReady: exportPollsToReady,
      exportShouldFail: exportShouldFail,
      transferShouldConflict: transferShouldConflict,
      deleteShouldConflict: deleteShouldConflict,
      cleanupRetryShouldFail: cleanupRetryShouldFail,
      denyAccess: denyAccess,
    );
  }

  /// 默认虚构移交候选（同企业同事形状；均已排除当前 owner）。
  static List<TalkRecordShareCandidateModel> defaultTransferCandidates() => [
    for (var i = 0; i < 3; i++)
      TalkRecordShareCandidateModel.fromJson({
        'user_id': '${9201 + i}',
        'display_name': _candidateName(i),
        'account': 'peer${i + 1}@fixture.example',
      }),
  ];

  static String _candidateName(int i) => const ['沈例', '韩设', '唐样'][i % 3];

  /// owner + 策略允许（导出可用基线）。
  static FixtureTalkRecordResultsService ownerExportAllowed({
    String recordId = '1001',
    int exportPollsToReady = 0,
  }) {
    return FixtureTalkRecordResultsService([
      entry(
        recordId: recordId,
        transferCandidates: defaultTransferCandidates(),
        exportPollsToReady: exportPollsToReady,
      ),
    ]);
  }

  /// owner + 企业策略禁导出。
  static FixtureTalkRecordResultsService ownerExportBlockedByOrg({
    String recordId = '1001',
  }) {
    return FixtureTalkRecordResultsService([
      entry(
        recordId: recordId,
        exportPolicy: const TalkRecordExportPolicy.blocked(
          TalkRecordExportBlockReason.organizationPolicy,
        ),
      ),
    ]);
  }

  /// owner + 策略未知（保守禁用）。
  static FixtureTalkRecordResultsService ownerExportPolicyUnknown({
    String recordId = '1001',
  }) {
    return FixtureTalkRecordResultsService([
      entry(
        recordId: recordId,
        exportPolicy: const TalkRecordExportPolicy.blocked(
          TalkRecordExportBlockReason.unknown,
        ),
      ),
    ]);
  }

  /// editor + grant.allow_export（caps.export=true）→ 可导出非 owner 形态。
  static FixtureTalkRecordResultsService editorWithExportGrant({
    String recordId = '1001',
  }) {
    return FixtureTalkRecordResultsService([
      entry(
        recordId: recordId,
        caps: _editorExportCaps,
        currentUserId: '9201',
        ownerUserId: '9001',
        transferCandidates: defaultTransferCandidates(),
      ),
    ]);
  }

  /// viewer（caps.export=false）→ 无导出/删除/移交能力。
  static FixtureTalkRecordResultsService viewerNoExport({
    String recordId = '1001',
  }) {
    return FixtureTalkRecordResultsService([
      entry(
        recordId: recordId,
        caps: _viewerCaps,
        currentUserId: '9203',
        ownerUserId: '9001',
      ),
    ]);
  }

  /// 已删除记录 + 指定清理状态（owner 读取白名单演示，§11.3）。
  static FixtureTalkRecordResultsService deletedOwnerWithStatus(
    TalkRecordCleanupStatus status, {
    String recordId = '1001',
    bool cleanupRetryShouldFail = false,
  }) {
    return FixtureTalkRecordResultsService([
      entry(
        recordId: recordId,
        deleted: true,
        cleanupStatus: status,
        cleanupRetryShouldFail: cleanupRetryShouldFail,
      ),
    ]);
  }

  /// P2-1 回归：活记录且响应**完全缺失** cleanup_status / deleted_at 字段
  /// （宽松解析回落 unknown）→ 不得推断为已删除（正向集合判定）。
  static FixtureTalkRecordResultsService liveRecordWithoutCleanupField({
    String recordId = '1001',
  }) {
    final record = TalkRecordModel.fromJson({
      'id': recordId,
      'owner_user_id': '9001',
      'created_by': '9001',
      'title': '项目例会',
      'scope': 'organization',
      'transcript_status': 'ready',
      'revision': 2,
      'acl_revision': 1,
      'capabilities_for_actor': _ownerOrgCaps,
      // 故意不写 deleted_at / cleanup_status：模拟字段表不含该字段的
      // 真实 GET /:id 活记录响应。
    });
    return FixtureTalkRecordResultsService([
      TalkRecordResultsFixtureEntry(
        record: record,
        recordEtag: 'record:2',
        currentUserId: '9001',
      ),
    ]);
  }
}
