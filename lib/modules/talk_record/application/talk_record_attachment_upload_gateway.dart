/// Real capture-part adapter: registration -> scoped PUT -> confirm -> complete.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_platform_adapters.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/store/model/workspace_model.dart';

import 'talk_record_local_binding.dart';
import 'talk_record_processing_consent.dart';
import 'talk_record_part_transport.dart';
import 'talk_record_recording_coordinator.dart';
import 'talk_record_upload_checkpoint.dart';
import 'talk_record_upload_manifest.dart';
import 'talk_record_upload_progress.dart';
part 'talk_record_upload_parts.dart';

class TalkRecordAttachmentUploadGateway
    implements TalkRecordUploadGateway, TalkRecordUploadProgressSource {
  final _uploadUpdates = StreamController<TalkRecordUploadSnapshot>.broadcast();
  @override
  Stream<TalkRecordUploadSnapshot> get uploadUpdates => _uploadUpdates.stream;
  @override
  TalkRecordUploadSnapshot? get uploadSnapshot => _uploadSnapshot;
  TalkRecordUploadSnapshot? _uploadSnapshot;
  TalkRecordAttachmentUploadGateway({
    required this.api,
    TalkRecordPartTransport? transport,
    this.confirmAttempts = 6,
    Future<void> Function(Duration)? delay,
  }) : transport = transport ?? TalkRecordGatewayPartTransport(),
       delay = delay ?? Future<void>.delayed;
  final TalkRecordApi api;
  final TalkRecordPartTransport transport;
  final int confirmAttempts;
  final Future<void> Function(Duration) delay;

  @override
  Future<void> upload({
    required TalkRecordLocalBinding binding,
    required TalkRecordManifest manifest,
    required Directory directory,
    required TalkRecordKeyStore keys,
    required void Function() checkAccount,
  }) async {
    void report(TalkRecordUploadPhase phase, int confirmed) {
      checkAccount();
      final snapshot = TalkRecordUploadSnapshot(
        account: binding.account,
        recordId: binding.recordId,
        sessionId: binding.sessionId,
        totalParts: manifest.segments.length,
        confirmedParts: confirmed,
        phase: phase,
      );
      _uploadSnapshot = snapshot;
      _uploadUpdates.add(snapshot);
    }

    var confirmed = 0;
    void update(TalkRecordUploadPhase phase, int count) {
      confirmed = count;
      report(phase, count);
    }

    try {
      await _upload(binding, manifest, directory, keys, checkAccount, update);
      report(TalkRecordUploadPhase.completed, manifest.segments.length);
    } on Object {
      // A revoked account must never publish its late progress to a new user.
      try {
        report(TalkRecordUploadPhase.failed, confirmed);
      } on Object {
        /* fenced */
      }
      rethrow;
    }
  }

  Future<void> _upload(
    TalkRecordLocalBinding binding,
    TalkRecordManifest manifest,
    Directory directory,
    TalkRecordKeyStore keys,
    void Function() checkAccount,
    void Function(TalkRecordUploadPhase, int) report,
  ) async {
    _validateLocal(binding, manifest);
    checkAccount();
    await _clearPlaintext(Directory('${directory.path}/.upload_plain'));
    final checkpoints = TalkRecordUploadCheckpointStore(directory);
    final source = talkRecordManifestHash(manifest.toJson());
    final checkpoint = await checkpoints.load(binding, source);
    int confirmed() => checkpoint.parts.values
        .where((part) => part is Map && part['confirmed'] == true)
        .length;
    report(TalkRecordUploadPhase.register, confirmed());
    TalkRecordCaptureModel? capture;
    void guard() {
      checkAccount();
      final c = capture;
      if (c != null &&
          (c.leaseEpoch != 0 ||
              (c.status != TalkRecordCaptureStatus.ended &&
                  (c.leaseUntil == null ||
                      !c.leaseUntil!.isAfter(DateTime.now()))))) {
        throw StateError('Capture lease unavailable; recover before retry');
      }
    }

    checkAccount();
    await _ownedRecord(binding, checkAccount);
    capture = await _loadCapture(binding, checkAccount);
    guard();
    // Retry of an already-submitted completion still verifies current owner via
    // GET detail. A local flag alone is never an authorization receipt.
    if (await _reconcileSubmitted(
      binding,
      manifest,
      checkpoint,
      checkpoints,
      guard,
    )) {
      return;
    }
    if (binding.processingMode != 'record_only') {
      guard();
      final cap = await api.capabilities();
      guard();
      validateTalkRecordProcessingConsent(binding, cap);
    }
    await _start(binding, capture, checkpoint, checkpoints, guard);
    await _uploadBody(
      binding,
      manifest,
      directory,
      keys,
      capture,
      checkpoint,
      checkpoints,
      guard,
      (phase) => report(phase, confirmed()),
    );
  }

  Future<TalkRecordCaptureModel> _loadCapture(
    TalkRecordLocalBinding binding,
    void Function() checkAccount,
  ) async {
    checkAccount();
    final captures = await api.captures(binding.recordId);
    checkAccount();
    final matches = captures.where((c) => c.id == binding.captureId);
    if (matches.length != 1) throw StateError('Capture mapping unavailable');
    final capture = matches.single;
    _validateCapture(capture, binding);
    return capture;
  }

  Future<TalkRecordModel> _ownedRecord(
    TalkRecordLocalBinding binding,
    void Function() guard,
  ) async {
    guard();
    final fetched = await api.detail(binding.recordId);
    guard();
    final record = fetched.data;
    if (record.id != binding.recordId ||
        record.isDeleted ||
        record.ownerUserId != binding.account.userId ||
        record.clientRecordingId != binding.clientRecordingId ||
        record.scope != binding.context.scope ||
        record.organizationId != binding.context.organizationId ||
        record.workspaceId != binding.context.workspaceId) {
      throw StateError('Current recording owner or scope changed');
    }
    return record;
  }

  Future<void> _assertSubmitted(
    TalkRecordLocalBinding binding,
    TalkRecordManifest manifest,
    TalkRecordUploadCheckpoint checkpoint,
    void Function() guard,
  ) async {
    final record = await _ownedRecord(binding, guard);
    final capture = await _loadCapture(binding, guard);
    if (capture.status != TalkRecordCaptureStatus.ended ||
        record.captureStatus != TalkRecordCaptureStatus.ended ||
        !const [
          TalkRecordMediaStatus.assembling,
          TalkRecordMediaStatus.available,
          TalkRecordMediaStatus.retryableFailed,
        ].contains(record.mediaStatus) ||
        record.durationMs != manifest.effectiveDurationMs ||
        capture.parts['confirmed'] != manifest.segments.length ||
        capture.parts['pending'] != 0 ||
        capture.parts['last_seq'] != manifest.lastSeq ||
        capture.parts['effective_ms'] != manifest.effectiveDurationMs ||
        checkpoint.completeHash.isEmpty ||
        capture.completionManifestHash != checkpoint.completeHash ||
        talkRecordManifestHash(
              talkRecordCanonicalManifest(
                binding.captureId,
                manifest.segments,
                checkpoint.parts,
              ),
            ) !=
            checkpoint.completeHash) {
      throw StateError('Server completion projection is not confirmed');
    }
  }

  Future<bool> _reconcileSubmitted(
    TalkRecordLocalBinding binding,
    TalkRecordManifest manifest,
    TalkRecordUploadCheckpoint checkpoint,
    TalkRecordUploadCheckpointStore checkpoints,
    void Function() guard,
  ) async {
    if (checkpoint.completeHash.isEmpty) return false;
    try {
      await _assertSubmitted(binding, manifest, checkpoint, guard);
    } on Object {
      guard();
      return false;
    }
    guard();
    checkpoint.submitted = true;
    await checkpoints.save(checkpoint);
    guard();
    return true;
  }

  Future<void> _uploadBody(
    TalkRecordLocalBinding binding,
    TalkRecordManifest manifest,
    Directory directory,
    TalkRecordKeyStore keys,
    TalkRecordCaptureModel capture,
    TalkRecordUploadCheckpoint checkpoint,
    TalkRecordUploadCheckpointStore checkpoints,
    void Function() guard,
    void Function(TalkRecordUploadPhase) report,
  ) async {
    final plaintextDir = Directory('${directory.path}/.upload_plain');
    await _clearPlaintext(plaintextDir);
    try {
      for (final segment in manifest.segments) {
        guard();
        await _part(
          binding,
          segment,
          directory,
          plaintextDir,
          keys,
          checkpoint,
          checkpoints,
          guard,
          report,
        );
      }
      report(TalkRecordUploadPhase.submitting);
      // Server mark bounds use capture.duration_ms, advanced by the end event.
      await _end(binding, manifest, capture, checkpoint, checkpoints, guard);
      await _marks(binding, manifest, checkpoint, checkpoints, guard);
      await _complete(binding, manifest, checkpoint, checkpoints, guard);
    } finally {
      await _clearPlaintext(plaintextDir);
    }
  }

  Future<void> _marks(
    TalkRecordLocalBinding binding,
    TalkRecordManifest manifest,
    TalkRecordUploadCheckpoint checkpoint,
    TalkRecordUploadCheckpointStore checkpoints,
    void Function() guard,
  ) async {
    for (final mark in manifest.marks) {
      if (checkpoint.marks.contains(mark.localId)) continue;
      guard();
      final created = await api.createMark(
        binding.recordId,
        clientMarkId: mark.localId,
        positionMs: mark.positionMs,
        text: mark.note,
        captureId: binding.captureId,
        captureOffsetMs: mark.positionMs,
      );
      guard();
      if (created.id.isEmpty || created.clientMarkId != mark.localId) {
        throw StateError('Recording mark receipt mismatch');
      }
      checkpoint.marks.add(mark.localId);
      await checkpoints.save(checkpoint);
    }
  }

  Future<void> _complete(
    TalkRecordLocalBinding binding,
    TalkRecordManifest manifest,
    TalkRecordUploadCheckpoint checkpoint,
    TalkRecordUploadCheckpointStore checkpoints,
    void Function() guard,
  ) async {
    final hash = await _prepareComplete(
      binding,
      manifest,
      checkpoint,
      checkpoints,
      guard,
    );
    guard();
    try {
      final result = await api.complete(
        binding.recordId,
        captures: [
          TalkRecordCompleteCaptureInput(
            captureId: binding.captureId,
            lastSeq: manifest.lastSeq,
            manifestHash: hash,
          ),
        ],
        policyVersion: binding.processingMode == 'record_only'
            ? binding.effectiveUploadPolicy
            : binding.effectiveProcessingPolicy,
        processorConfigVersion: binding.processingMode == 'record_only'
            ? null
            : binding.effectiveProcessingProcessor,
        idempotencyKey: checkpoint.completeKey,
        ifMatch: checkpoint.completeEtag,
      );
      guard();
      if (!const [
        'assembling',
        'ready',
        'available',
      ].contains(result.mediaStatus)) {
        throw StateError('Completion has not been accepted');
      }
      await _assertSubmitted(binding, manifest, checkpoint, guard);
      checkpoint.submitted = true;
      await checkpoints.save(checkpoint);
    } on Object {
      guard();
      if (await _reconcileSubmitted(
        binding,
        manifest,
        checkpoint,
        checkpoints,
        guard,
      )) {
        return;
      }
      rethrow;
    }
  }

  Future<String> _prepareComplete(
    TalkRecordLocalBinding binding,
    TalkRecordManifest manifest,
    TalkRecordUploadCheckpoint checkpoint,
    TalkRecordUploadCheckpointStore checkpoints,
    void Function() guard,
  ) async {
    final canonical = talkRecordCanonicalManifest(
      binding.captureId,
      manifest.segments,
      checkpoint.parts,
    );
    final hash = talkRecordManifestHash(canonical);
    if (checkpoint.completeHash.isNotEmpty && checkpoint.completeHash != hash) {
      throw StateError('Completion manifest changed');
    }
    final fingerprint = talkRecordConsentFingerprint(binding);
    final changed =
        checkpoint.completeKey.isNotEmpty &&
        ((checkpoint.completeConsentFingerprint.isEmpty &&
                binding.processingConsentGeneration.isNotEmpty) ||
            (checkpoint.completeConsentFingerprint.isNotEmpty &&
                checkpoint.completeConsentFingerprint != fingerprint));
    if (changed && binding.processingConsentGeneration.isEmpty) {
      throw StateError('Completion consent changed without confirmation');
    }
    if (checkpoint.completeKey.isEmpty || changed) {
      guard();
      final current = await api.detail(binding.recordId);
      guard();
      if (current.etag.isEmpty) {
        throw StateError('Record revision unavailable');
      }
      checkpoint.completeKey = TalkRecordIds.newUuidV4();
      checkpoint.completeEtag = current.etag;
      checkpoint.completeHash = hash;
      checkpoint.completeConsentFingerprint = fingerprint;
      await checkpoints.save(checkpoint);
    } else if (checkpoint.completeConsentFingerprint.isEmpty) {
      checkpoint.completeConsentFingerprint = fingerprint;
      await checkpoints.save(checkpoint);
    }
    return hash;
  }

  void _validateLocal(TalkRecordLocalBinding b, TalkRecordManifest m) {
    if (b.recordId.isEmpty ||
        b.captureId.isEmpty ||
        !const [
          'record_only',
          'transcribe',
          'summarize',
        ].contains(b.processingMode) ||
        m.clientRecordingId != b.clientRecordingId ||
        m.sessionId != b.sessionId ||
        m.status != TalkRecordSessionStatus.ended ||
        m.segments.isEmpty) {
      throw StateError('Local recording not ready');
    }
    var seq = 0, position = 0;
    for (final s in m.segments) {
      if (s.seq != seq++ ||
          s.startMs != position ||
          s.endMs <= s.startMs ||
          s.plainSize <= 0 ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(s.plainSha256Hex) ||
          !RegExp(r'^seg_[0-9]+[.]aes$').hasMatch(s.cipherFileName)) {
        throw StateError('Missing or invalid local audio part');
      }
      position = s.endMs;
    }
  }

  void _validateCapture(TalkRecordCaptureModel c, TalkRecordLocalBinding b) {
    if (c.id != b.captureId ||
        c.recordId != b.recordId ||
        c.deviceSessionId != b.deviceSessionId ||
        c.leaseEpoch != b.leaseEpoch ||
        c.leaseEpoch != 0 ||
        c.lastEventSeq < -1 ||
        c.lastEventSeq > 1 ||
        c.status == TalkRecordCaptureStatus.unknown ||
        c.abandoned ||
        (c.status == TalkRecordCaptureStatus.ended && c.leaseEpoch > 0)) {
      throw StateError('Capture identity, sequence or status mismatch');
    }
  }

  Future<void> _start(
    TalkRecordLocalBinding b,
    TalkRecordCaptureModel capture,
    TalkRecordUploadCheckpoint cp,
    TalkRecordUploadCheckpointStore store,
    void Function() guard,
  ) async {
    final existing = cp.events['start'];
    if (existing == null) {
      if (capture.lastEventSeq != -1 ||
          capture.status != TalkRecordCaptureStatus.draft) {
        throw StateError('Event history checkpoint missing');
      }
      cp.events['start'] = {
        'id': TalkRecordIds.newUuidV4(),
        'seq': 0,
        'acked': false,
      };
      await store.save(cp);
    }
    final start = Map<String, dynamic>.from(cp.events['start'] as Map);
    if (start['acked'] == true) return;
    if (capture.lastEventSeq > (start['seq'] as int)) {
      throw StateError('Unexpected server event sequence');
    }
    guard();
    final result = await api.postCaptureEvent(
      b.recordId,
      b.captureId,
      TalkRecordCaptureEventInput(
        clientEventId: start['id'] as String,
        deviceSessionId: b.deviceSessionId,
        seq: start['seq'] as int,
        event: TalkRecordCaptureEventKind.start,
      ),
    );
    guard();
    if (result.status != TalkRecordCaptureStatus.recording) {
      throw StateError('Capture start not acknowledged');
    }
    start['acked'] = true;
    cp.events['start'] = start;
    await store.save(cp);
  }

  Future<void> _end(
    TalkRecordLocalBinding b,
    TalkRecordManifest manifest,
    TalkRecordCaptureModel capture,
    TalkRecordUploadCheckpoint cp,
    TalkRecordUploadCheckpointStore store,
    void Function() guard,
  ) async {
    if (cp.events['end'] == null) {
      cp.events['end'] = {
        'id': TalkRecordIds.newUuidV4(),
        'seq': 1,
        'acked': false,
      };
      await store.save(cp);
    }
    final end = Map<String, dynamic>.from(cp.events['end'] as Map);
    if (end['acked'] == true) return;
    if (capture.status == TalkRecordCaptureStatus.ended) {
      if (capture.lastEventSeq != end['seq']) {
        throw StateError('Unexpected ended capture');
      }
    } else {
      guard();
      final result = await api.postCaptureEvent(
        b.recordId,
        b.captureId,
        TalkRecordCaptureEventInput(
          clientEventId: end['id'] as String,
          deviceSessionId: b.deviceSessionId,
          seq: end['seq'] as int,
          event: TalkRecordCaptureEventKind.end,
          positionMs: manifest.effectiveDurationMs,
        ),
      );
      guard();
      if (result.status != TalkRecordCaptureStatus.ended) {
        throw StateError('Capture end not acknowledged');
      }
    }
    end['acked'] = true;
    cp.events['end'] = end;
    await store.save(cp);
  }

  Future<void> _clearPlaintext(Directory directory) async {
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      await Link(directory.path).delete();
    } else if (type == FileSystemEntityType.directory) {
      await directory.delete(recursive: true);
    }
  }
}
