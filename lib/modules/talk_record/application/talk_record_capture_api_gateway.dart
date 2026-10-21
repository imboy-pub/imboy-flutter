/// Binds local drafts to server resources using persistent idempotency keys.
library;

import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/config/init.dart' as app;
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';

import 'talk_record_local_binding.dart';
import 'talk_record_participant_sync.dart';
import 'talk_record_recording_coordinator.dart';

class TalkRecordApiCaptureGateway implements TalkRecordCaptureGateway {
  TalkRecordApiCaptureGateway(this.api, {String Function()? deviceId})
    : currentDeviceId = deviceId ?? (() => app.deviceId);
  final TalkRecordApi api;
  final String Function() currentDeviceId;

  Future<TalkRecordLocalBinding> _bindRecord(
    TalkRecordLocalBinding local,
    Future<void> Function(TalkRecordLocalBinding) checkpoint,
    void Function() check,
  ) async {
    final found = await _lookup(local, check);
    if (found != null) {
      final bound = _map(local, found);
      await checkpoint(bound);
      check();
      return bound;
    }
    final cap = await api.capabilities();
    check();
    if ((local.uploadPolicyVersion.isNotEmpty &&
            local.uploadPolicyAcknowledgedAt == null) ||
        !cap.recordingEnabled ||
        local.effectiveUploadPolicy.isEmpty ||
        local.effectiveUploadPolicy != cap.policyVersion) {
      throw const TalkRecordUploadPolicyRequired();
    }
    // Checkpoint the exact policy before any possibly response-lost request.
    // Title/mode/language/context/client UUID are immutable in this binding.
    local = local.copyWith(submittedPolicyVersion: local.effectiveUploadPolicy);
    await checkpoint(local);
    check();
    return _createRecord(local, checkpoint, check);
  }

  Future<TalkRecordLocalBinding> _createRecord(
    TalkRecordLocalBinding local,
    Future<void> Function(TalkRecordLocalBinding) checkpoint,
    void Function() check,
  ) async {
    try {
      final result = await api.create(
        clientRecordingId: local.clientRecordingId,
        scope: local.context.scope,
        title: local.title,
        language: local.language,
        organizationId: local.context.organizationId.isEmpty
            ? null
            : local.context.organizationId,
        workspaceId: local.context.workspaceId.isEmpty
            ? null
            : local.context.workspaceId,
        processingMode: TalkRecordProcessingMode.parse(local.processingMode),
        policyVersion: local.submittedPolicyVersion,
        idempotencyKey: local.clientRecordingId,
      );
      check();
      final bound = _map(local.copyWith(uploadAttempted: true), result);
      await checkpoint(bound);
      check();
      return bound;
    } on Object {
      check();
      local = local.copyWith(uploadAttempted: true);
      await checkpoint(local);
      check();
      // none may race a late old create; keep the UUID/key and reconcile.
      final reconciled = await _lookup(local, check);
      if (reconciled == null) rethrow;
      final bound = _map(local, reconciled);
      await checkpoint(bound);
      check();
      return bound;
    }
  }

  Future<TalkRecordFetched<TalkRecordModel>?> _lookup(
    TalkRecordLocalBinding local,
    void Function() check,
  ) async {
    check();
    final value = await api.lookupRecording(
      clientRecordingId: local.clientRecordingId,
      scope: local.context.scope,
      organizationId: local.context.organizationId.isEmpty
          ? null
          : local.context.organizationId,
      workspaceId: local.context.workspaceId.isEmpty
          ? null
          : local.context.workspaceId,
    );
    check();
    return value;
  }

  TalkRecordLocalBinding _map(
    TalkRecordLocalBinding local,
    TalkRecordFetched<TalkRecordModel> fetched,
  ) {
    final value = fetched.data;
    if (value.id.isEmpty ||
        value.ownerUserId != local.account.userId ||
        value.clientRecordingId != local.clientRecordingId ||
        value.isDeleted ||
        value.scope != local.context.scope ||
        value.organizationId != local.context.organizationId ||
        value.workspaceId != local.context.workspaceId ||
        fetched.etag.isEmpty) {
      throw StateError('Current recording owner or scope changed');
    }
    return local.copyWith(recordId: value.id, recordEtag: fetched.etag);
  }

  @override
  Future<TalkRecordLocalBinding> bind(
    TalkRecordLocalBinding local,
    Future<void> Function(TalkRecordLocalBinding) checkpoint,
    void Function() checkAccount,
  ) async {
    checkAccount();
    if (local.recordId.isEmpty) {
      local = await _bindRecord(local, checkpoint, checkAccount);
    }
    checkAccount();
    local = await syncTalkRecordParticipants(
      api: api,
      local: local,
      checkpoint: checkpoint,
      checkAccount: checkAccount,
    );
    checkAccount();
    if (local.captureId.isEmpty) {
      // Reconcile a create-capture response lost before its checkpoint.
      final captures = await api.captures(local.recordId);
      checkAccount();
      final matching = captures.where(
        (c) => c.deviceSessionId == local.deviceSessionId,
      );
      if (matching.length > 1) throw StateError('Ambiguous capture mapping');
      if (matching.isNotEmpty) {
        local = local.copyWith(
          captureId: matching.single.id,
          deviceId: local.deviceId.isEmpty
              ? matching.single.deviceId
              : local.deviceId,
        );
        await checkpoint(local);
      }
    }
    if (local.captureId.isNotEmpty) {
      checkAccount();
      final listed = await api.captures(local.recordId);
      checkAccount();
      final matches = listed.where((c) => c.id == local.captureId);
      if (matches.length == 1 &&
          matches.single.status == TalkRecordCaptureStatus.ended) {
        final ended = matches.single;
        final owner = await api.detail(local.recordId);
        checkAccount();
        if (owner.data.id != local.recordId ||
            owner.data.clientRecordingId != local.clientRecordingId ||
            owner.data.ownerUserId != local.account.userId ||
            owner.data.isDeleted ||
            owner.data.scope != local.context.scope ||
            owner.data.organizationId != local.context.organizationId ||
            owner.data.workspaceId != local.context.workspaceId) {
          throw StateError('Current recording owner or scope changed');
        }
        _requireCapture(ended, local);
        return local.copyWith(
          deviceId: local.deviceId.isEmpty ? ended.deviceId : local.deviceId,
          captureEtag: ended.etag,
          captureStatus: ended.status.wireName,
          leaseEpoch: ended.leaseEpoch,
          leaseUntil: ended.leaseUntil,
        );
      }
      // Existing or response-lost captures must recover authoritatively; never
      // reset segment sequence or create a new capture when lease is unknown.
      final capture = await api.recoverCapture(
        local.recordId,
        local.captureId,
        deviceSessionId: local.deviceSessionId,
      );
      _requireCapture(capture, local);
      return local.copyWith(
        deviceId: local.deviceId.isEmpty ? capture.deviceId : local.deviceId,
        captureEtag: capture.etag,
        leaseEpoch: capture.leaseEpoch,
        captureStatus: capture.status.wireName,
        leaseUntil: capture.leaseUntil,
      );
    }
    if (local.recordEtag.isEmpty) {
      final fetched = await api.detail(local.recordId);
      local = local.copyWith(recordEtag: fetched.etag);
      await checkpoint(local);
    }
    checkAccount();
    if (local.recordEtag.isEmpty) {
      throw StateError('Record revision unavailable');
    }
    if (local.deviceId.isEmpty) {
      final identity = currentDeviceId();
      if (identity.trim().isEmpty) {
        throw StateError('Recording device identity unavailable');
      }
      local = local.copyWith(deviceId: identity);
      await checkpoint(local);
      checkAccount();
    }
    final capture = await api.createCapture(
      local.recordId,
      deviceId: local.deviceId,
      deviceSessionId: local.deviceSessionId,
      idempotencyKey: local.deviceSessionId,
      ifMatch: local.recordEtag,
    );
    _requireCapture(capture, local);
    local = local.copyWith(
      captureId: capture.id,
      captureEtag: capture.etag,
      leaseEpoch: capture.leaseEpoch,
      captureStatus: capture.status.wireName,
      leaseUntil: capture.leaseUntil,
    );
    await checkpoint(local);
    return local;
  }

  void _requireCapture(
    TalkRecordCaptureModel capture,
    TalkRecordLocalBinding local,
  ) {
    if ((local.deviceId.isNotEmpty &&
            capture.deviceId.isNotEmpty &&
            capture.deviceId != local.deviceId) ||
        capture.id.isEmpty ||
        (local.captureId.isNotEmpty && local.captureId != capture.id) ||
        capture.recordId != local.recordId ||
        capture.deviceSessionId != local.deviceSessionId ||
        capture.abandoned ||
        capture.status == TalkRecordCaptureStatus.unknown ||
        (capture.status == TalkRecordCaptureStatus.ended &&
            capture.leaseEpoch > 0) ||
        capture.leaseEpoch != 0 ||
        (capture.status != TalkRecordCaptureStatus.ended &&
            (capture.leaseUntil == null ||
                !capture.leaseUntil!.isAfter(DateTime.now())))) {
      throw StateError('Capture ownership, status or lease unavailable');
    }
  }
}

/// Requires an explicit current upload notice acknowledgement, never a policy rewrite.
class TalkRecordUploadPolicyRequired implements Exception {
  const TalkRecordUploadPolicyRequired();
}
