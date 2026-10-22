/// Application-lifetime local recording orchestration. Navigation owns no mic.
library;

import 'dart:async';
import 'dart:io';

import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_platform_adapters.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

import '../presentation/talk_record_services.dart';
import 'talk_record_local_binding.dart';
import 'talk_record_launch_failure.dart';
import 'talk_record_upload_progress.dart';

import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';

/// The gateway must use current server authorization and return a durable lease.
abstract interface class TalkRecordCaptureGateway {
  Future<TalkRecordLocalBinding> bind(
    TalkRecordLocalBinding local,
    Future<void> Function(TalkRecordLocalBinding) checkpoint,
    void Function() checkAccount,
  );
}

/// Reuses attachment sessions/confirm. Only an actual confirmed completion can
/// set completed=true. A missing implementation is an error, never a success.
abstract interface class TalkRecordUploadGateway {
  Future<void> upload({
    required TalkRecordLocalBinding binding,
    required TalkRecordManifest manifest,
    required Directory directory,
    required TalkRecordKeyStore keys,
    required void Function() checkAccount,
  });
}

typedef TalkRecordRecorderFactory = TalkRecordRecorderService Function(
  Directory,
);

class TalkRecordRecordingCoordinator implements TalkRecordRecordingLauncher {
  TalkRecordRecordingCoordinator({
    required this.store,
    required this.keys,
    required this.currentAccount,
    required this.recorderFactory,
    this.captureGateway,
    this.uploadGateway,
  });
  final TalkRecordBindingStore store;
  final TalkRecordKeyStore keys;
  final TalkRecordAccount Function() currentAccount;
  final TalkRecordRecorderFactory recorderFactory;
  final TalkRecordCaptureGateway? captureGateway;
  final TalkRecordUploadGateway? uploadGateway;
  TalkRecordUploadSnapshot? get uploadSnapshot {
    final source = uploadGateway;
    final snapshot = source is TalkRecordUploadProgressSource
        ? (source as TalkRecordUploadProgressSource).uploadSnapshot
        : null;
    return snapshot?.account == currentAccount()
        ? _withPendingBinding(snapshot!)
        : null;
  }

  Stream<TalkRecordUploadSnapshot> get uploadUpdates {
    final source = uploadGateway;
    return source is TalkRecordUploadProgressSource
        ? (source as TalkRecordUploadProgressSource).uploadUpdates
              .where((s) => s.account == currentAccount())
              .map(_withPendingBinding)
        : const Stream.empty();
  }

  TalkRecordLocalBinding? _pendingUploadBinding;
  TalkRecordUploadSnapshot _withPendingBinding(
    TalkRecordUploadSnapshot snapshot,
  ) {
    final bound = _pendingUploadBinding;
    if (bound == null ||
        bound.account != currentAccount() ||
        !snapshot.matches(bound)) {
      return snapshot;
    }
    return TalkRecordUploadSnapshot(
      account: snapshot.account,
      recordId: snapshot.recordId,
      sessionId: snapshot.sessionId,
      totalParts: snapshot.totalParts,
      confirmedParts: snapshot.confirmedParts,
      phase: snapshot.phase,
      pendingBinding: bound,
    );
  }

  final _updates = StreamController<TalkRecordRecorderSnapshot>.broadcast();
  Stream<TalkRecordRecorderSnapshot> get updates => _updates.stream;
  TalkRecordRecorderSnapshot get snapshot => _recorder?.snapshot ?? _snapshot;
  TalkRecordRecorderSnapshot _snapshot = const TalkRecordRecorderSnapshot();

  /// Safety-only interface; never exposes previous account metadata.
  bool get microphoneStopUnconfirmed =>
      _recorder?.snapshot.stopUnconfirmed ?? false;
  Future<void> retryMicrophoneStop() async {
    await _recorder?.retryMicrophoneStop();
  }

  TalkRecordLocalBinding? get binding => _binding;
  TalkRecordLocalBinding? _binding;
  TalkRecordRecorderService? _recorder;
  StreamSubscription<TalkRecordRecorderSnapshot>? _subscription;
  TalkRecordManifest? _recoverable;
  bool _busy = false;

  void _check(TalkRecordAccount expected) {
    if (!expected.valid || currentAccount() != expected) {
      throw StateError('Recording account changed');
    }
  }

  Future<T> _exclusive<T>(Future<T> Function() work) async {
    if (_busy) throw StateError('Recording operation in progress');
    _busy = true;
    try {
      return await work();
    } finally {
      _busy = false;
    }
  }

  /// Scan only this account. Recovery shows interrupted, without opening mic.
  Future<void> discover() => _exclusive(() async {
    final account = currentAccount();
    _check(account);
    if (_recorder?.snapshot.isActive ?? false) {
      _check(_binding!.account);
      _emit(_recorder!.snapshot);
      return;
    }
    if (_recorder != null) {
      await _subscription?.cancel();
      await _recorder!.dispose(); // only an already-ended service reaches here
      _recorder = null;
    }
    final bindings = await store.list(account);
    final sessions = await TalkRecordRecorderService.listSessions(
      store.audioDirectory(account),
    );
    _binding = null;
    _recoverable = null;
    _snapshot = const TalkRecordRecorderSnapshot();
    _check(account);
    for (var local in bindings.where((b) => !b.completed)) {
      final candidates = sessions.where(
        (m) => m.clientRecordingId == local.clientRecordingId,
      );
      if (candidates.isEmpty) continue;
      if (candidates.length != 1) throw StateError('Ambiguous local recording');
      final original = candidates.single;
      if (original.status == TalkRecordSessionStatus.ended) continue;
      local = local.withSession(original.sessionId);
      await store.save(local);
      final recovered = await TalkRecordRecorderService.recoverSession(
        Directory(
          '${store.audioDirectory(account).path}/${original.sessionId}',
        ),
      );
      _check(account);
      _binding = local;
      _recoverable = recovered.manifest;
      _emit(
        TalkRecordRecorderSnapshot(
          phase: TalkRecordRecorderPhase.interrupted,
          sessionId: local.sessionId,
          effectiveDurationMs: recovered.effectiveDurationMs,
          segmentCount: recovered.manifest!.segments.length,
          interruptReason: 'unknown_interrupt',
        ),
      );
      return;
    }
  });

  @override
  Future<TalkRecordRecordingLaunchResult> launch(
    TalkRecordRecordingDraftRequest request,
  ) async {
    try {
      request.checkCurrentOperation();
      await discover();
      request.checkCurrentOperation();
      return await _exclusive(() async {
        request.checkCurrentOperation();
        if (_snapshot.isActive || (_recorder?.snapshot.isActive ?? false)) {
          return const TalkRecordRecordingLaunchResult.unavailable();
        }
        final account = currentAccount();
        _check(account);
        if (request.saveTo.isOrganization &&
            request.saveTo.organizationId.isEmpty) {
          throw StateError('Organization required');
        }
        final clientId = TalkRecordIds.newUuidV4();
        var local = TalkRecordLocalBinding(
          account: account,
          clientRecordingId: clientId,
          context: request.saveTo,
          title: request.title,
          participantsRequested: true,
          participants: List.unmodifiable(
            request.participants.map(
              (item) => TalkRecordParticipantInput(
                userId: item.userId,
                displayName: item.displayName,
              ),
            ),
          ),
          processingMode: request.processingMode.wireName,
          policyVersion: request.policyVersion,
          processorConfigVersion: request.processorConfigVersion,
          language: request.language,
          deviceSessionId: TalkRecordIds.newUuidV4(),
        );
        // Persist owner before mic/manifest creation. A crash between start and
        // session mapping is reconciled by the immutable clientRecordingId.
        await store.save(local);
        _check(account);
        request.checkCurrentOperation();
        final recorder = recorderFactory(store.audioDirectory(account));
        _binding = local;
        _recorder = recorder;
        _listen(recorder);
        await recorder.start(
          recordLocalId: clientId,
          clientRecordingId: clientId,
          beforeOpen: () {
            _check(account);
            request.checkCurrentOperation();
          },
        );
        local = local.withSession(recorder.sessionId!);
        try {
          await store.save(local);
        } on Object {
          await recorder.markInterrupted('binding_write_failed');
          rethrow;
        }
        _binding = local;
        if (currentAccount() != account) {
          await recorder.markInterrupted('account_changed');
          throw StateError('Recording account changed');
        }
        return const TalkRecordRecordingLaunchResult.started();
      });
    } on Object catch (error) {
      // The page retains its draft. Existing audio is never discarded on a
      // server/network/key/ownership failure.
      return talkRecordLaunchFailure(error);
    }
  }

  void _listen(TalkRecordRecorderService recorder) {
    unawaited(_subscription?.cancel());
    _subscription = recorder.snapshots.listen(_emit);
  }

  void _emit(TalkRecordRecorderSnapshot value) {
    _snapshot = value;
    _updates.add(value);
  }

  Future<void> pause() => _exclusive(() async {
    _check(_binding!.account);
    await _recorder?.pause();
  });

  Future<void> resume() => _exclusive(() async {
    final local = _binding;
    if (local == null) throw StateError('No recording');
    _check(local.account);
    if (_recorder == null) {
      final manifest = _recoverable;
      if (manifest == null) throw StateError('Recovery required');
      final key = await keys.readRecordKey(local.sessionId);
      if (key == null || key.length != 32) {
        throw StateError('Recording key unavailable');
      }
      _check(local.account);
      final recorder = recorderFactory(store.audioDirectory(local.account));
      _recorder = recorder;
      _listen(recorder);
      try {
        await recorder.attachRecovered(manifest: manifest, recordKey: key);
      } on Object {
        _recorder = null;
        rethrow;
      }
      _recoverable = null;
    }
    _check(local.account);
    if (_recorder!.phase == TalkRecordRecorderPhase.interrupted) {
      await _recorder!.userResumeAfterInterruption();
    } else {
      await _recorder!.resume();
    }
    if (currentAccount() != local.account) {
      await _recorder!.markInterrupted('account_changed');
    }
  });

  Future<TalkRecordSessionResult> end() => _exclusive(() async {
    _check(_binding!.account);
    if (_recorder == null) {
      final recovered = _recoverable;
      if (recovered == null) throw StateError('Recovery unavailable');
      final ended = recovered.copyWith(
        status: TalkRecordSessionStatus.ended,
        endedReason: 'user',
        updatedAtIso: DateTime.now().toIso8601String(),
      );
      await TalkRecordManifestStore(
        Directory(
          '${store.audioDirectory(_binding!.account).path}/${_binding!.sessionId}',
        ),
      ).write(ended);
      _recoverable = null;
      _emit(
        TalkRecordRecorderSnapshot(
          phase: TalkRecordRecorderPhase.ended,
          sessionId: ended.sessionId,
          effectiveDurationMs: ended.effectiveDurationMs,
          segmentCount: ended.segments.length,
        ),
      );
      return TalkRecordSessionResult(
        sessionId: ended.sessionId,
        recordLocalId: ended.recordLocalId,
        clientRecordingId: ended.clientRecordingId,
        endReason: TalkRecordEndReason.user,
        savedCleanly: true,
        effectiveDurationMs: ended.effectiveDurationMs,
        segmentCount: ended.segments.length,
        totalCipherBytes: ended.totalCipherBytes,
        manifest: ended,
      );
    }
    final result = await _recorder!.end();
    if (result.stopUnconfirmed) {
      throw const TalkRecordStopUnconfirmedException();
    }
    return result;
  });

  /// Auth transitions interrupt microphone without granting the new account
  /// access to old content. Navigation/disposal must never call this method.
  Future<void> accountChanged() async {
    _pendingUploadBinding = null;
    if (_binding != null && currentAccount() != _binding!.account) {
      try {
        await _recorder?.markInterrupted('account_changed');
      } on Object {
        // If the platform refuses pause, close capture rather than continuing
        // to collect audio after an account change. Retain sealed content.
        if (_recorder?.snapshot.isActive ?? false) await _recorder!.end();
      } finally {
        if (microphoneStopUnconfirmed) {
          _updates.add(_recorder!.snapshot);
        } else {
          _updates.add(const TalkRecordRecorderSnapshot());
        }
      }
      if (microphoneStopUnconfirmed) {
        throw const TalkRecordStopUnconfirmedException();
      }
    }
  }

  /// Local ended recordings awaiting server acceptance, scoped to this login.
  /// A corrupt/mismatched entry fails closed instead of disappearing as success.
  Future<List<TalkRecordPendingEnded>> pendingEnded() => _exclusive(() async {
    final account = currentAccount();
    _check(account);
    final bindings = await store.list(account);
    final output = <TalkRecordPendingEnded>[];
    for (final local in bindings.where(
      (b) => !b.completed && b.sessionId.isNotEmpty,
    )) {
      final manifest = await TalkRecordManifestStore(
        Directory('${store.audioDirectory(account).path}/${local.sessionId}'),
      ).read();
      _check(account);
      if (manifest == null ||
          manifest.clientRecordingId != local.clientRecordingId) {
        throw StateError('Local recording mapping unavailable');
      }
      if (manifest.status == TalkRecordSessionStatus.ended) {
        output.add(
          TalkRecordPendingEnded(
            local,
            manifest.effectiveDurationMs,
            manifest.segments.length,
          ),
        );
      }
    }
    return List.unmodifiable(output);
  });

  /// Explicit local correction only. Audio, ownership, scope and capture remain
  /// unchanged; the normal upload pipeline will validate the new list remotely.
  Future<TalkRecordLocalBinding> updatePendingParticipants(
    TalkRecordLocalBinding requested,
    List<TalkRecordParticipantInput> participants, {
    void Function()? checkCurrentOperation,
  }) => _exclusive(() async {
    void check() {
      _check(requested.account);
      checkCurrentOperation?.call();
    }

    check();
    if (participants.length > 100 ||
        participants.map((p) => p.identityKey).toSet().length !=
            participants.length) {
      throw const FormatException('Invalid participant selection');
    }
    final selected = List<TalkRecordParticipantInput>.unmodifiable(
      participants,
    );
    for (final participant in selected) {
      participant.toJson();
    }
    final local = await _latestPending(requested);
    final manifest = await TalkRecordManifestStore(
      Directory(
        '${store.audioDirectory(local.account).path}/${local.sessionId}',
      ),
    ).read();
    check();
    if (manifest == null ||
        manifest.status != TalkRecordSessionStatus.ended ||
        manifest.sessionId != local.sessionId ||
        manifest.clientRecordingId != local.clientRecordingId) {
      throw StateError('Recording is not ended');
    }
    final updated = local.copyWith(
      participants: selected,
      participantsRequested: true,
      participantsSynced: false,
    );
    await store.save(updated);
    check();
    if (_binding?.clientRecordingId == updated.clientRecordingId &&
        _binding?.account == updated.account) {
      _binding = updated;
    }
    return updated;
  });

  /// Explicit current upload acknowledgement; preserves original capture policy.
  Future<TalkRecordLocalBinding> confirmPendingUploadPolicy(
    TalkRecordLocalBinding requested,
    String policyVersion, {
    required void Function() checkCurrentOperation,
  }) => _exclusive(() async {
    void check() {
      _check(requested.account);
      checkCurrentOperation();
    }

    check();
    if (policyVersion.trim().isEmpty) {
      throw const FormatException('Missing upload policy');
    }
    final local = await _latestPending(requested);
    final manifest = await TalkRecordManifestStore(
      Directory(
        '${store.audioDirectory(local.account).path}/${local.sessionId}',
      ),
    ).read();
    check();
    if (local.recordId.isNotEmpty ||
        manifest == null ||
        manifest.status != TalkRecordSessionStatus.ended ||
        manifest.clientRecordingId != local.clientRecordingId ||
        manifest.sessionId != local.sessionId) {
      throw StateError('Recording does not need a new upload confirmation');
    }
    final updated = local.copyWith(
      uploadPolicyVersion: policyVersion,
      uploadPolicyAcknowledgedAt: DateTime.now().toUtc(),
    );
    await store.save(updated);
    check();
    return updated;
  });

  /// New consent never changes historical capture facts or recording identity.
  Future<TalkRecordLocalBinding> confirmPendingProcessingConsent(
    TalkRecordLocalBinding requested,
    String policyVersion,
    String processorVersion, {
    required void Function() checkCurrentOperation,
  }) => _exclusive(() async {
    void check() {
      _check(requested.account);
      checkCurrentOperation();
    }

    check();
    if (policyVersion.trim().isEmpty || processorVersion.trim().isEmpty) {
      throw const FormatException('Missing processing consent version');
    }
    final local = await _latestPending(requested);
    final manifest = await TalkRecordManifestStore(
      Directory(
        '${store.audioDirectory(local.account).path}/${local.sessionId}',
      ),
    ).read();
    check();
    if (local.processingMode == 'record_only' ||
        manifest == null ||
        manifest.status != TalkRecordSessionStatus.ended ||
        manifest.clientRecordingId != local.clientRecordingId ||
        manifest.sessionId != local.sessionId) {
      throw StateError('Recording cannot accept processing consent');
    }
    final updated = local.copyWith(
      processingConsentPolicyVersion: policyVersion,
      processingConsentProcessorVersion: processorVersion,
      processingConsentGeneration: TalkRecordIds.newUuidV4(),
      processingConsentAcknowledgedAt: DateTime.now().toUtc(),
    );
    await store.save(updated);
    check();
    return updated;
  });

  Future<TalkRecordLocalBinding> _latestPending(
    TalkRecordLocalBinding requested,
  ) async {
    _check(requested.account);
    final matches = (await store.list(requested.account))
        .where((item) => item.clientRecordingId == requested.clientRecordingId)
        .toList();
    _check(requested.account);
    if (matches.length != 1) {
      throw StateError('Pending recording unavailable');
    }
    final local = matches.single;
    if (local.completed ||
        local.context != requested.context ||
        local.deviceSessionId != requested.deviceSessionId ||
        local.sessionId.isEmpty ||
        local.sessionId != requested.sessionId ||
        (requested.recordId.isNotEmpty &&
            local.recordId != requested.recordId) ||
        (requested.captureId.isNotEmpty &&
            local.captureId != requested.captureId)) {
      throw StateError('Pending recording identity changed');
    }
    return local;
  }

  Future<void> retryPending(
    TalkRecordLocalBinding local, {
    void Function()? checkCurrentOperation,
  }) => uploadEnded(local, checkCurrentOperation: checkCurrentOperation);

  /// An explicit retry rechecks owner + lease before every network boundary.
  /// No lease, unknown mapping or absent uploader => preserve local data.
  Future<void> uploadEnded(
    TalkRecordLocalBinding requested, {
    void Function()? checkCurrentOperation,
  }) => _exclusive(() async {
    checkCurrentOperation?.call();
    final local = await _latestPending(requested);
    checkCurrentOperation?.call();
    _check(local.account);
    if (microphoneStopUnconfirmed) {
      throw const TalkRecordStopUnconfirmedException();
    }
    final gateway = captureGateway;
    final uploader = uploadGateway;
    if (gateway == null || uploader == null) {
      throw StateError('Upload not integrated');
    }
    final directory = Directory(
      '${store.audioDirectory(local.account).path}/${local.sessionId}',
    );
    final manifest = await TalkRecordManifestStore(directory).read();
    if (manifest == null ||
        manifest.status != TalkRecordSessionStatus.ended ||
        manifest.clientRecordingId != local.clientRecordingId) {
      throw StateError('Recording is not ready for upload');
    }
    void check() {
      _check(local.account);
      checkCurrentOperation?.call();
    }

    final bound = await gateway.bind(local, store.save, check);
    check();
    if (bound.account != local.account ||
        bound.context != local.context ||
        bound.clientRecordingId != local.clientRecordingId ||
        bound.deviceSessionId != local.deviceSessionId ||
        bound.sessionId != local.sessionId ||
        bound.recordId.isEmpty ||
        bound.captureId.isEmpty ||
        bound.leaseEpoch != 0 ||
        !const [
          'draft',
          'recording',
          'paused',
          'interrupted',
          'ended',
        ].contains(bound.captureStatus) ||
        (bound.captureStatus == 'ended' && bound.leaseEpoch > 0) ||
        (bound.captureStatus != 'ended' &&
            (bound.leaseUntil == null ||
                !bound.leaseUntil!.isAfter(DateTime.now())))) {
      throw StateError('Capture lease unknown or expired');
    }
    await store.save(bound);
    check();
    _pendingUploadBinding = bound;
    await uploader.upload(
      binding: bound,
      manifest: manifest,
      directory: directory,
      keys: keys,
      checkAccount: check,
    );
    check();
    await store.save(bound.copyWith(completed: true));
  });
}

/// Presentation projection: no keys, plaintext bytes or capability tickets.
class TalkRecordPendingEnded {
  const TalkRecordPendingEnded(
    this.binding,
    this.durationMs,
    this.segmentCount,
  );
  final TalkRecordLocalBinding binding;
  final int durationMs, segmentCount;
}
