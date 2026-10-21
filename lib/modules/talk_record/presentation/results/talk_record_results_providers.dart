/// 面聊记录（talk_record）结果域状态层（T21 UI）。
///
/// Provider 形态与 T10/T16/T18 一致：手写 Notifier/Provider（build.yaml
/// 白名单不含新文件）。服务注入点化——widget 测试零网络（fixture 注入）。
///
/// 职责划分：
/// - [TalkRecordExportCenterNotifier]：导出中心（record + policy + 格式
///   选择 + 生成/状态/下载状态机 + 独立副本确认）；
/// - [TalkRecordTransferCenterNotifier]：移交中心（候选 + 保留查看 +
///   提交结果两分支：保留查看=成功页 / 不保留=通用失效页）；
/// - [TalkRecordDeleteCenterNotifier]：删除中心（确认删除 → 已逻辑删除 +
///   清理状态独立展示 + 失败重试）。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:imboy/config/error_code.dart';
import 'package:imboy/service/talk_record/talk_record_platform_adapters.dart'
    show TalkRecordIds;
import 'package:imboy/modules/talk_record/talk_record_error.dart'
    show TalkRecordApiException, TalkRecordErrorCode;
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart'
    show TalkRecordShareCandidateModel;
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

import 'talk_record_results_service.dart';
import 'talk_record_export_delivery.dart';
import '../talk_record_auth.dart';
part 'talk_record_results_states.dart';

final talkRecordExportDeliveryProvider = Provider<TalkRecordExportDelivery>(
  (ref) => TalkRecordExportDelivery(),
);

// ---------------------------------------------------------------------------
// 注入点（测试 override；T19/T20 联调换真实实现）
// ---------------------------------------------------------------------------

final talkRecordResultsServiceProvider = Provider<TalkRecordResultsService>((
  ref,
) {
  return ApiTalkRecordResultsService();
});

/// record ETag 惯例：响应未带 ETag 头时以 revision 派生版本令牌
/// （删除/移交 If-Match 用；T19/T20 联调若改为逐资源 ETag 头仅替换此纯函数）。
String talkRecordRecordEtagOf(int revision) => 'record:$revision';

// ---------------------------------------------------------------------------
// 导出中心
// ---------------------------------------------------------------------------

class TalkRecordExportCenterNotifier
    extends Notifier<TalkRecordExportCenterState> {
  String? _exportIntentKey;
  int _intentEpoch = 0;

  @override
  TalkRecordExportCenterState build() {
    void changed() {
      _intentEpoch++;
      _exportIntentKey = null;
      state = const TalkRecordExportCenterState();
    }

    final remove = ref.read(talkRecordAuthSubscribeProvider)(changed);
    ref.onDispose(() {
      _intentEpoch++;
      remove();
    });
    return const TalkRecordExportCenterState();
  }

  Future<void> bind(EntityId recordId, {bool force = false}) async {
    if (!force &&
        state.recordId == recordId &&
        state.phase != TalkRecordExportPhase.idle) {
      return;
    }
    _exportIntentKey = null;
    _intentEpoch++;
    state = TalkRecordExportCenterState(recordId: recordId);
    await reload();
  }

  Future<void> reload() async {
    final id = state.recordId;
    if (id.isEmpty) return;
    final epoch = ++_intentEpoch;
    state = state.copyWith(phase: TalkRecordExportPhase.loading);
    try {
      final service = ref.read(talkRecordResultsServiceProvider);
      final record = await service.record(id);
      if (epoch != _intentEpoch) return;
      final policy = await service.exportPolicy(id);
      if (epoch != _intentEpoch) return;
      state = state.copyWith(
        phase: TalkRecordExportPhase.ready,
        record: record.data,
        policy: policy,
      );
    } on TalkRecordApiException catch (e) {
      if (epoch != _intentEpoch) return;
      state = state.copyWith(
        phase: e.isNoAccess
            ? TalkRecordExportPhase.noAccess
            : TalkRecordExportPhase.failed,
      );
    } on Object {
      if (epoch != _intentEpoch) return;
      state = state.copyWith(phase: TalkRecordExportPhase.failed);
    }
  }

  void setFormat(TalkRecordExportFormat format) {
    if (format == state.format || state.creating) return;
    _exportIntentKey = null;
    _intentEpoch++;
    state = state.copyWith(
      format: format,
      clearArtifact: true,
      artifactPhase: TalkRecordExportArtifactPhase.idle,
      downloadPhase: TalkRecordExportDownloadPhase.idle,
      downloadUrl: '',
    );
  }

  void setIndependentCopyAcked(bool value) {
    state = state.copyWith(independentCopyAcked: value);
  }

  /// 生成导出（POST exports；202 语义 queued/ready）。
  Future<void> createExport() async {
    if (!state.canGenerate) return;
    state = state.copyWith(
      artifactPhase: TalkRecordExportArtifactPhase.creating,
    );
    final service = ref.read(talkRecordResultsServiceProvider);
    final id = state.recordId;
    final epoch = _intentEpoch;
    final key = _exportIntentKey ??= TalkRecordIds.newUuidV4();
    try {
      final artifact = await service.createExport(
        id,
        format: state.format,
        idempotencyKey: key,
      );
      if (state.recordId != id || epoch != _intentEpoch) return;
      if (artifact.state == 'failed' || artifact.state == 'expired') {
        _exportIntentKey = null;
      }
      state = state.copyWith(
        artifact: artifact,
        artifactPhase: _artifactPhase(artifact.state),
        writePhase: TalkRecordExportWritePhase.idle,
      );
    } on TalkRecordApiException catch (e) {
      if (state.recordId != id || epoch != _intentEpoch) return;
      _exportError(e);
      state = state.copyWith(
        writePhase: e.isRevisionStale
            ? TalkRecordExportWritePhase.conflict
            : TalkRecordExportWritePhase.failed,
      );
    } on Object {
      if (state.recordId != id || epoch != _intentEpoch) return;
      state = state.copyWith(
        artifactPhase: TalkRecordExportArtifactPhase.failed,
        writePhase: TalkRecordExportWritePhase.failed,
      );
    }
  }

  /// Poll preserves every server terminal state; transport failures are visible.
  Future<void> refreshExportState() async {
    final artifact = state.artifact;
    if (artifact == null || !artifact.isQueued) return;
    final service = ref.read(talkRecordResultsServiceProvider);
    final epoch = _intentEpoch;
    try {
      final next = await service.exportState(state.recordId, artifact.exportId);
      if (epoch != _intentEpoch) return;
      if (next.state == 'failed' || next.state == 'expired') {
        _exportIntentKey = null;
      }
      state = state.copyWith(
        artifact: next,
        artifactPhase: _artifactPhase(next.state),
      );
    } on TalkRecordApiException catch (e) {
      if (epoch == _intentEpoch) _exportError(e);
    } on Object {
      if (epoch != _intentEpoch) return;
      state = state.copyWith(
        artifactPhase: TalkRecordExportArtifactPhase.failed,
      );
    }
  }

  TalkRecordExportArtifactPhase _artifactPhase(String value) => switch (value) {
    'queued' => TalkRecordExportArtifactPhase.queued,
    'ready' => TalkRecordExportArtifactPhase.ready,
    'expired' => TalkRecordExportArtifactPhase.expired,
    _ => TalkRecordExportArtifactPhase.failed,
  };

  void _exportError(TalkRecordApiException e) {
    if (e.code == ErrorCode.GONE ||
        e.code == TalkRecordErrorCode.exportExpired) {
      _exportIntentKey = null;
    }
    final denied =
        e.isNoAccess ||
        e.code == ErrorCode.FORBIDDEN ||
        e.code == ErrorCode.UNAUTHORIZED ||
        e.code == TalkRecordErrorCode.exportDisabledByPolicy;
    state = state.copyWith(
      phase: denied ? TalkRecordExportPhase.noAccess : state.phase,
      artifactPhase:
          (e.code == ErrorCode.GONE ||
              e.code == TalkRecordErrorCode.exportExpired)
          ? TalkRecordExportArtifactPhase.expired
          : TalkRecordExportArtifactPhase.failed,
      downloadUrl: '',
    );
  }

  /// 重新鉴权下载并由用户保存；只有保存返回成功才显示完成。
  Future<void> requestDownload() async {
    final artifact = state.artifact;
    if (artifact == null || !artifact.isReady) return;
    if (state.downloadPhase == TalkRecordExportDownloadPhase.fetching) return;
    state = state.copyWith(
      downloadPhase: TalkRecordExportDownloadPhase.fetching,
    );
    final service = ref.read(talkRecordResultsServiceProvider);
    final epoch = _intentEpoch;
    final delivery = ref.read(talkRecordExportDeliveryProvider);
    final recordId = state.recordId;
    try {
      final account = delivery.account;
      final url = await service.exportDownloadUrl(
        state.recordId,
        artifact.exportId,
      );
      if (epoch != _intentEpoch) return;
      final result = await delivery.deliver(
        url: url,
        recordId: recordId,
        exportId: artifact.exportId,
        extension: artifact.format.name,
        owner: account,
        isCurrent: () => epoch == _intentEpoch,
      );
      if (epoch != _intentEpoch) return;
      if (result == TalkRecordExportSaveResult.stale) {
        state = state.copyWith(
          phase: TalkRecordExportPhase.noAccess,
          downloadUrl: '',
          downloadPhase: TalkRecordExportDownloadPhase.idle,
        );
        return;
      }
      final saved = result == TalkRecordExportSaveResult.saved;
      state = state.copyWith(
        downloadUrl: '',
        downloadPhase: saved
            ? TalkRecordExportDownloadPhase.fetched
            : TalkRecordExportDownloadPhase.cancelled,
        artifactPhase: saved
            ? TalkRecordExportArtifactPhase.fetched
            : TalkRecordExportArtifactPhase.ready,
      );
    } on TalkRecordApiException catch (e) {
      if (epoch != _intentEpoch) return;
      if (e.code == ErrorCode.GONE ||
          e.code == TalkRecordErrorCode.exportExpired) {
        // §4：到期 410 → 到期视图 + 重新生成入口。
        _exportIntentKey = null;
        state = state.copyWith(
          downloadUrl: '',
          downloadPhase: TalkRecordExportDownloadPhase.expired,
          artifactPhase: TalkRecordExportArtifactPhase.expired,
        );
        return;
      }
      state = state.copyWith(
        phase: e.isNoAccess || e.code == 403 || e.code == 401
            ? TalkRecordExportPhase.noAccess
            : state.phase,
        downloadPhase: TalkRecordExportDownloadPhase.failed,
      );
    } on Object {
      if (epoch != _intentEpoch) return;
      state = state.copyWith(
        downloadPhase: TalkRecordExportDownloadPhase.failed,
      );
    }
  }

  /// 到期/失败后重新生成（清产物态回表单）。
  void prepareRegenerate() {
    _exportIntentKey = null;
    _intentEpoch++;
    state = state.copyWith(
      clearArtifact: true,
      artifactPhase: TalkRecordExportArtifactPhase.idle,
      downloadPhase: TalkRecordExportDownloadPhase.idle,
      downloadUrl: '',
    );
  }
}

final talkRecordExportCenterProvider =
    NotifierProvider<
      TalkRecordExportCenterNotifier,
      TalkRecordExportCenterState
    >(TalkRecordExportCenterNotifier.new);

// ---------------------------------------------------------------------------
// 移交中心（§9：仅企业记录 owner）
// ---------------------------------------------------------------------------

class TalkRecordTransferCenterNotifier
    extends Notifier<TalkRecordTransferCenterState> {
  int _epoch = 0;
  @override
  TalkRecordTransferCenterState build() {
    void changed() {
      _epoch++;
      state = const TalkRecordTransferCenterState();
    }

    final remove = ref.read(talkRecordAuthSubscribeProvider)(changed);
    ref.onDispose(() {
      _epoch++;
      remove();
    });
    return const TalkRecordTransferCenterState();
  }

  Future<void> bind(EntityId recordId, {bool force = false}) async {
    if (!force &&
        state.recordId == recordId &&
        state.phase != TalkRecordTransferPhase.idle) {
      return;
    }
    _epoch++;
    state = TalkRecordTransferCenterState(recordId: recordId);
    await reload();
  }

  Future<void> reload() async {
    final id = state.recordId;
    if (id.isEmpty) return;
    final epoch = ++_epoch;
    state = state.copyWith(phase: TalkRecordTransferPhase.loading);
    final service = ref.read(talkRecordResultsServiceProvider);
    try {
      final record = await service.record(id);
      if (epoch != _epoch) return;
      final candidates = await service.transferCandidates(id);
      if (epoch != _epoch) return;
      state = state.copyWith(
        phase: TalkRecordTransferPhase.ready,
        record: record.data,
        candidates: candidates.list,
      );
    } on TalkRecordApiException catch (e) {
      if (epoch != _epoch) return;
      state = state.copyWith(
        phase: e.isNoAccess
            ? TalkRecordTransferPhase.noAccess
            : TalkRecordTransferPhase.failed,
      );
    } on Object {
      if (epoch != _epoch) return;
      state = state.copyWith(phase: TalkRecordTransferPhase.failed);
    }
  }

  void selectTarget(TalkRecordShareCandidateModel candidate) {
    state = state.copyWith(
      selectedUserId: candidate.userId,
      selectedUserName: candidate.displayName,
    );
  }

  void setKeepViewer(bool value) {
    state = state.copyWith(keepViewer: value);
  }

  /// 提交移交（二次确认后调用；成功按 keepViewer 分支呈现）。
  Future<void> submit() async {
    if (!state.canSubmit) return;
    state = state.copyWith(
      submitPhase: TalkRecordTransferSubmitPhase.submitting,
    );
    final service = ref.read(talkRecordResultsServiceProvider);
    final epoch = _epoch;
    final keepViewer = state.keepViewer;
    try {
      final outcome = await service.transferOwnership(
        state.recordId,
        targetUserId: state.selectedUserId,
        keepViewerForOriginalOwner: state.keepViewer,
        ifMatch: _recordEtag(),
        idempotencyKey: 'transfer-${state.recordId}-${state.selectedUserId}',
      );
      if (epoch != _epoch) return;
      state = state.copyWith(
        outcome: outcome,
        submitPhase: keepViewer
            ? TalkRecordTransferSubmitPhase.doneKeepAccess
            : TalkRecordTransferSubmitPhase.doneNoAccess,
      );
    } on TalkRecordApiException catch (e) {
      if (epoch != _epoch) return;
      state = state.copyWith(
        submitPhase: e.isRevisionStale
            ? TalkRecordTransferSubmitPhase.conflict
            : TalkRecordTransferSubmitPhase.failed,
      );
    } on Object {
      if (epoch != _epoch) return;
      state = state.copyWith(submitPhase: TalkRecordTransferSubmitPhase.failed);
    }
  }

  String _recordEtag() {
    final record = state.record;
    if (record == null) return '';
    // 惯例派生（见 talkRecordRecordEtagOf 文档）；真实 ETag 头联调替换。
    return talkRecordRecordEtagOf(record.revision);
  }
}

final talkRecordTransferCenterProvider =
    NotifierProvider<
      TalkRecordTransferCenterNotifier,
      TalkRecordTransferCenterState
    >(TalkRecordTransferCenterNotifier.new);

// ---------------------------------------------------------------------------
// 删除中心（§4/§10.4/§11.3）
// ---------------------------------------------------------------------------

class TalkRecordDeleteCenterNotifier
    extends Notifier<TalkRecordDeleteCenterState> {
  int _epoch = 0;
  @override
  TalkRecordDeleteCenterState build() {
    void changed() {
      _epoch++;
      state = const TalkRecordDeleteCenterState();
    }

    final remove = ref.read(talkRecordAuthSubscribeProvider)(changed);
    ref.onDispose(() {
      _epoch++;
      remove();
    });
    return const TalkRecordDeleteCenterState();
  }

  Future<void> bind(EntityId recordId, {bool force = false}) async {
    if (!force &&
        state.recordId == recordId &&
        state.phase != TalkRecordDeletePhase.idle) {
      return;
    }
    _epoch++;
    state = TalkRecordDeleteCenterState(recordId: recordId);
    await reload();
  }

  Future<void> reload() async {
    final id = state.recordId;
    if (id.isEmpty) return;
    final epoch = ++_epoch;
    state = state.copyWith(phase: TalkRecordDeletePhase.loading);
    try {
      final record = await ref
          .read(talkRecordResultsServiceProvider)
          .record(id);
      if (epoch != _epoch) return;
      state = state.copyWith(
        phase: TalkRecordDeletePhase.ready,
        record: record.data,
        // 已删除记录（深链/回流）：直接进入清理状态视图（白名单数据）。
        cleanupStatus: record.data.cleanupStatus,
        logicalDeleted: record.data.isDeleted,
      );
    } on TalkRecordApiException catch (e) {
      if (epoch != _epoch) return;
      state = state.copyWith(
        phase: e.isNoAccess
            ? TalkRecordDeletePhase.noAccess
            : TalkRecordDeletePhase.failed,
      );
    } on Object {
      if (epoch != _epoch) return;
      state = state.copyWith(phase: TalkRecordDeletePhase.failed);
    }
  }

  /// 确认删除（二次确认后调用；DELETE → 202 logical_deleted + pending）。
  Future<void> confirmDelete() async {
    if (!state.canDelete ||
        state.submitPhase == TalkRecordDeleteSubmitPhase.deleting) {
      return;
    }
    state = state.copyWith(submitPhase: TalkRecordDeleteSubmitPhase.deleting);
    final record = state.record;
    final epoch = _epoch;
    try {
      final result = await ref
          .read(talkRecordResultsServiceProvider)
          .deleteRecord(
            state.recordId,
            ifMatch: talkRecordRecordEtagOf(record?.revision ?? 0),
          );
      if (epoch != _epoch) return;
      state = state.copyWith(
        submitPhase: TalkRecordDeleteSubmitPhase.deleted,
        logicalDeleted: result.logicalDeleted,
        cleanupStatus: result.cleanupStatus,
      );
    } on TalkRecordApiException catch (e) {
      if (epoch != _epoch) return;
      state = state.copyWith(
        submitPhase: e.isRevisionStale
            ? TalkRecordDeleteSubmitPhase.conflict
            : TalkRecordDeleteSubmitPhase.failed,
      );
    } on Object {
      if (epoch != _epoch) return;
      state = state.copyWith(submitPhase: TalkRecordDeleteSubmitPhase.failed);
    }
  }

  /// 刷新清理状态（owner 白名单读取，§11.3）。
  Future<void> refreshStatus() async {
    await reload();
  }

  /// 清理失败重试（failed → pending；重试≠清理完成）。
  Future<void> retryCleanup() async {
    if (state.retryPhase == TalkRecordCleanupRetryPhase.retrying) return;
    state = state.copyWith(retryPhase: TalkRecordCleanupRetryPhase.retrying);
    final record = state.record;
    final epoch = _epoch;
    try {
      await ref
          .read(talkRecordResultsServiceProvider)
          .retryCleanup(
            state.recordId,
            ifMatch: talkRecordRecordEtagOf(record?.revision ?? 0),
            idempotencyKey: 'cleanup-retry-${state.recordId}',
          );
      // 重试成功 → 重新读状态（fixture：pending）。
      if (epoch != _epoch) return;
      state = state.copyWith(retryPhase: TalkRecordCleanupRetryPhase.idle);
      await reload();
    } on TalkRecordApiException {
      if (epoch != _epoch) return;
      state = state.copyWith(retryPhase: TalkRecordCleanupRetryPhase.failed);
    } on Object {
      if (epoch != _epoch) return;
      state = state.copyWith(retryPhase: TalkRecordCleanupRetryPhase.failed);
    }
  }
}

final talkRecordDeleteCenterProvider =
    NotifierProvider<
      TalkRecordDeleteCenterNotifier,
      TalkRecordDeleteCenterState
    >(TalkRecordDeleteCenterNotifier.new);
