part of 'talk_record_results_providers.dart';

enum TalkRecordExportPhase { idle, loading, ready, failed, noAccess }

/// 导出产物状态机：idle → creating → queued →（刷新）→ ready →（下载）
/// fetched / expired(410)；failed 任何阶段如实进入。
enum TalkRecordExportArtifactPhase {
  idle,
  creating,
  queued,
  ready,
  fetched,
  expired,
  failed,
}

enum TalkRecordExportDownloadPhase {
  idle,
  fetching,
  fetched,
  cancelled,
  expired,
  failed,
}

enum TalkRecordExportWritePhase { idle, conflict, failed }

class TalkRecordExportCenterState {
  final EntityId recordId;
  final TalkRecordExportPhase phase;
  final TalkRecordModel? record;
  final TalkRecordExportPolicy? policy;
  final TalkRecordExportFormat format;

  /// 「独立副本无法收回」主动确认（未确认不允许生成，UI-SPEC §2 导出行）。
  final bool independentCopyAcked;
  final TalkRecordExportArtifactPhase artifactPhase;
  final TalkRecordExportArtifact? artifact;
  final TalkRecordExportDownloadPhase downloadPhase;
  final String downloadUrl;
  final TalkRecordExportWritePhase writePhase;

  const TalkRecordExportCenterState({
    this.recordId = '',
    this.phase = TalkRecordExportPhase.idle,
    this.record,
    this.policy,
    this.format = TalkRecordExportFormat.txt,
    this.independentCopyAcked = false,
    this.artifactPhase = TalkRecordExportArtifactPhase.idle,
    this.artifact,
    this.downloadPhase = TalkRecordExportDownloadPhase.idle,
    this.downloadUrl = '',
    this.writePhase = TalkRecordExportWritePhase.idle,
  });

  /// 可导出判定（能力 ∩ 策略）：caps.export 是角色/授权投影（owner 策略
  /// 允许 / grant.allow_export），policy 是实例/企业策略（owner 不能绕过）。
  bool get canExport =>
      (record?.capabilitiesForActor.export ?? false) &&
      (policy?.exportAllowed ?? false);

  /// 禁用原因（canExport=false 时展示；能力优先于策略）。
  TalkRecordExportDisableReason get disableReason {
    if (record?.capabilitiesForActor.export ?? false) {
      return switch (policy?.blockReason) {
        TalkRecordExportBlockReason.organizationPolicy =>
          TalkRecordExportDisableReason.organizationPolicy,
        TalkRecordExportBlockReason.instancePolicy =>
          TalkRecordExportDisableReason.instancePolicy,
        _ => TalkRecordExportDisableReason.policyUnknown,
      };
    }
    return TalkRecordExportDisableReason.noGrant;
  }

  /// 生成按钮可按（可导出 + 已确认独立副本语义）。
  bool get canGenerate =>
      phase == TalkRecordExportPhase.ready &&
      canExport &&
      independentCopyAcked &&
      !creating &&
      !hasLiveArtifact;

  /// 生成中或已有产物（避免重复提交；重新生成需先到期/失败）。
  bool get creating => artifactPhase == TalkRecordExportArtifactPhase.creating;
  bool get hasLiveArtifact =>
      artifactPhase == TalkRecordExportArtifactPhase.queued ||
      artifactPhase == TalkRecordExportArtifactPhase.ready ||
      artifactPhase == TalkRecordExportArtifactPhase.fetched;

  TalkRecordExportCenterState copyWith({
    EntityId? recordId,
    TalkRecordExportPhase? phase,
    TalkRecordModel? record,
    TalkRecordExportPolicy? policy,
    TalkRecordExportFormat? format,
    bool? independentCopyAcked,
    TalkRecordExportArtifactPhase? artifactPhase,
    TalkRecordExportArtifact? artifact,
    bool clearArtifact = false,
    TalkRecordExportDownloadPhase? downloadPhase,
    String? downloadUrl,
    TalkRecordExportWritePhase? writePhase,
  }) {
    return TalkRecordExportCenterState(
      recordId: recordId ?? this.recordId,
      phase: phase ?? this.phase,
      record: record ?? this.record,
      policy: policy ?? this.policy,
      format: format ?? this.format,
      independentCopyAcked: independentCopyAcked ?? this.independentCopyAcked,
      artifactPhase: artifactPhase ?? this.artifactPhase,
      artifact: clearArtifact ? null : artifact ?? this.artifact,
      downloadPhase: downloadPhase ?? this.downloadPhase,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      writePhase: writePhase ?? this.writePhase,
    );
  }
}

/// 导出禁用原因（i18n 键由 UI 层映射）。
enum TalkRecordExportDisableReason {
  /// 当前角色没有被授予导出权限（非 owner 且 grant.allow_export=false）。
  noGrant,

  /// 企业/工作区策略禁止导出。
  organizationPolicy,

  /// 实例未开启导出能力。
  instancePolicy,

  /// 策略获取失败（保守禁用，不假装允许）。
  policyUnknown,
}

enum TalkRecordTransferPhase { idle, loading, ready, failed, noAccess }

/// 提交结果两分支：doneKeepAccess=成功页（保留查看）；
/// doneNoAccess=通用失效页（不保留，§9 原 owner 不再有权访问内容）。
enum TalkRecordTransferSubmitPhase {
  idle,
  submitting,
  doneKeepAccess,
  doneNoAccess,
  conflict,
  failed,
}

class TalkRecordTransferCenterState {
  final EntityId recordId;
  final TalkRecordTransferPhase phase;
  final TalkRecordModel? record;
  final List<TalkRecordShareCandidateModel> candidates;
  final EntityId selectedUserId;
  final String selectedUserName;

  /// 原 owner 是否保留查看（默认不保留，UI-SPEC §2 责任移交行冻结）。
  final bool keepViewer;
  final TalkRecordTransferSubmitPhase submitPhase;
  final TalkRecordTransferOutcome? outcome;

  const TalkRecordTransferCenterState({
    this.recordId = '',
    this.phase = TalkRecordTransferPhase.idle,
    this.record,
    this.candidates = const [],
    this.selectedUserId = '',
    this.selectedUserName = '',
    this.keepViewer = false,
    this.submitPhase = TalkRecordTransferSubmitPhase.idle,
    this.outcome,
  });

  /// 门控：企业记录 + 当前 owner（caps.transfer_owner 投影）。
  bool get canTransfer =>
      (record?.capabilitiesForActor.transferOwner ?? false) &&
      record?.scope == TalkRecordScope.organization;

  bool get isPersonal => record?.scope == TalkRecordScope.personal;

  bool get canSubmit => canTransfer && selectedUserId.isNotEmpty && !submitting;

  bool get submitting =>
      submitPhase == TalkRecordTransferSubmitPhase.submitting;

  TalkRecordTransferCenterState copyWith({
    EntityId? recordId,
    TalkRecordTransferPhase? phase,
    TalkRecordModel? record,
    List<TalkRecordShareCandidateModel>? candidates,
    EntityId? selectedUserId,
    String? selectedUserName,
    bool? keepViewer,
    TalkRecordTransferSubmitPhase? submitPhase,
    TalkRecordTransferOutcome? outcome,
  }) {
    return TalkRecordTransferCenterState(
      recordId: recordId ?? this.recordId,
      phase: phase ?? this.phase,
      record: record ?? this.record,
      candidates: candidates ?? this.candidates,
      selectedUserId: selectedUserId ?? this.selectedUserId,
      selectedUserName: selectedUserName ?? this.selectedUserName,
      keepViewer: keepViewer ?? this.keepViewer,
      submitPhase: submitPhase ?? this.submitPhase,
      outcome: outcome ?? this.outcome,
    );
  }
}

enum TalkRecordDeletePhase { idle, loading, ready, failed, noAccess }

enum TalkRecordDeleteSubmitPhase { idle, deleting, deleted, conflict, failed }

enum TalkRecordCleanupRetryPhase { idle, retrying, failed }

class TalkRecordDeleteCenterState {
  final EntityId recordId;
  final TalkRecordDeletePhase phase;
  final TalkRecordModel? record;
  final String recordEtag;

  /// 删除响应（§4：logical_deleted + cleanup_status 拆分）。
  final bool logicalDeleted;
  final TalkRecordCleanupStatus cleanupStatus;
  final TalkRecordDeleteSubmitPhase submitPhase;
  final TalkRecordCleanupRetryPhase retryPhase;

  const TalkRecordDeleteCenterState({
    this.recordId = '',
    this.phase = TalkRecordDeletePhase.idle,
    this.record,
    this.recordEtag = '',
    this.logicalDeleted = false,
    this.cleanupStatus = TalkRecordCleanupStatus.none,
    this.submitPhase = TalkRecordDeleteSubmitPhase.idle,
    this.retryPhase = TalkRecordCleanupRetryPhase.idle,
  });

  /// 门控：删除仅 owner（受治理限制，§3 角色表）。
  bool get canDelete => record?.capabilitiesForActor.delete ?? false;

  /// 已删除（进入状态视图：确认页不再展示）。
  ///
  /// P2-1 修复：正向集合判定——仅 deletedAt != null（模型 isDeleted）或
  /// 删除响应的显式 logicalDeleted 信号成立；cleanup_status 为
  /// none/unknown/缺失均**不**推断已删除（§10.4 拆分契约下活记录的
  /// GET /:id 响应可不携带该字段，parse 缺失回落 unknown，曾导致活记录
  /// 被误渲染为删除状态视图）。
  bool get isDeleted => logicalDeleted || (record?.isDeleted ?? false);

  TalkRecordDeleteCenterState copyWith({
    EntityId? recordId,
    TalkRecordDeletePhase? phase,
    TalkRecordModel? record,
    String? recordEtag,
    bool? logicalDeleted,
    TalkRecordCleanupStatus? cleanupStatus,
    TalkRecordDeleteSubmitPhase? submitPhase,
    TalkRecordCleanupRetryPhase? retryPhase,
  }) {
    return TalkRecordDeleteCenterState(
      recordId: recordId ?? this.recordId,
      phase: phase ?? this.phase,
      record: record ?? this.record,
      recordEtag: recordEtag ?? this.recordEtag,
      logicalDeleted: logicalDeleted ?? this.logicalDeleted,
      cleanupStatus: cleanupStatus ?? this.cleanupStatus,
      submitPhase: submitPhase ?? this.submitPhase,
      retryPhase: retryPhase ?? this.retryPhase,
    );
  }
}
