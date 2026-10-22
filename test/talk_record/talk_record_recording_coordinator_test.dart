import 'package:imboy/modules/talk_record/application/talk_record_upload_progress.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_pending_uploads.dart';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:imboy/modules/talk_record/application/talk_record_launch_failure.dart';

import 'package:imboy/store/model/talk_record/talk_record_participant_model.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/modules/talk_record/application/talk_record_recording_runtime.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/application/talk_record_recording_coordinator.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_services.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';
import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

import 'fake_talk_record_engine.dart';

class NotificationFailingEngine extends FakeTalkRecordEngine {
  NotificationFailingEngine(this.code);
  final String code;
  @override
  Future<void> open() async {
    throw PlatformException(code: code);
  }
}

class LeaseGateway implements TalkRecordCaptureGateway {
  LeaseGateway({this.known = false, this.ended = false});
  final bool known, ended;
  int calls = 0;
  @override
  Future<TalkRecordLocalBinding> bind(
    TalkRecordLocalBinding local,
    Future<void> Function(TalkRecordLocalBinding) checkpoint,
    void Function() checkAccount,
  ) async {
    checkAccount();
    calls++;
    return local.copyWith(
      recordId: '1',
      captureId: '2',
      leaseEpoch: known ? 0 : -1,
      captureStatus: ended ? 'ended' : 'recording',
      leaseUntil: known
          ? DateTime.now().add(Duration(minutes: ended ? -60 : 5))
          : null,
    );
  }
}

class TestUploader implements TalkRecordUploadGateway {
  int calls = 0;
  TalkRecordLocalBinding? lastBinding;
  @override
  Future<void> upload({
    required TalkRecordLocalBinding binding,
    required TalkRecordManifest manifest,
    required Directory directory,
    required TalkRecordKeyStore keys,
    required void Function() checkAccount,
  }) async {
    checkAccount();
    lastBinding = binding;
    calls++;
  }
}

class HeldUploader extends TestUploader {
  final entered = Completer<void>(), release = Completer<void>();
  @override
  Future<void> upload({
    required TalkRecordLocalBinding binding,
    required TalkRecordManifest manifest,
    required Directory directory,
    required TalkRecordKeyStore keys,
    required void Function() checkAccount,
  }) async {
    entered.complete();
    await release.future;
    await super.upload(
      binding: binding,
      manifest: manifest,
      directory: directory,
      keys: keys,
      checkAccount: checkAccount,
    );
  }
}

class ProgressHeldUploader extends HeldUploader
    implements TalkRecordUploadProgressSource {
  TalkRecordUploadSnapshot? progress;
  @override
  TalkRecordUploadSnapshot? get uploadSnapshot => progress;
  @override
  Stream<TalkRecordUploadSnapshot> get uploadUpdates => const Stream.empty();
  @override
  Future<void> upload({
    required TalkRecordLocalBinding binding,
    required TalkRecordManifest manifest,
    required Directory directory,
    required TalkRecordKeyStore keys,
    required void Function() checkAccount,
  }) async {
    progress = TalkRecordUploadSnapshot(
      account: binding.account,
      recordId: binding.recordId,
      sessionId: binding.sessionId,
      totalParts: manifest.segments.length,
      confirmedParts: 0,
      phase: TalkRecordUploadPhase.upload,
    );
    await super.upload(
      binding: binding,
      manifest: manifest,
      directory: directory,
      keys: keys,
      checkAccount: checkAccount,
    );
  }
}

void main() {
  late Directory root;
  late TalkRecordBindingStore store;
  late TalkRecordAccount account;
  late MemoryTalkRecordKeyStore keys;
  late List<FakeTalkRecordEngine> engines;
  late List<TalkRecordRecorderService> recorders;
  setUp(() {
    root = Directory.systemTemp.createTempSync('talk_coordinator_');
    store = TalkRecordBindingStore(root);
    account = const TalkRecordAccount('https://local.example', '100');
    keys = MemoryTalkRecordKeyStore();
    engines = [];
    recorders = [];
    TalkRecordCaptureLease.resetForTest();
  });
  tearDown(() async {
    for (final recorder in recorders) {
      await recorder.dispose();
    }
    TalkRecordCaptureLease.resetForTest();
    root.deleteSync(recursive: true);
  });
  TalkRecordRecordingCoordinator coordinator({
    LeaseGateway? gateway,
    TestUploader? uploader,
    FakeTalkRecordEngine? testEngine,
  }) => TalkRecordRecordingCoordinator(
    store: store,
    keys: keys,
    currentAccount: () => account,
    captureGateway: gateway,
    uploadGateway: uploader,
    recorderFactory: (directory) {
      final engine = testEngine ?? FakeTalkRecordEngine();
      engines.add(engine);
      final recorder = TalkRecordRecorderService(
        baseDirectory: directory,
        keyStore: keys,
        engine: engine,
        diskProbe: FakeDiskSpaceProbe(),
        config: const TalkRecordRecorderConfig(minFreeDiskBytesPerSegment: 1),
      );
      recorders.add(recorder);
      return recorder;
    },
  );
  const request = TalkRecordRecordingDraftRequest(
    title: 'Project sync',
    saveTo: TalkRecordEntryContext.personal(),
    policyVersion: 'v1',
  );
  Future<void> tick() async {
    engines.last.tick(500);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  test(
    'stale intent after runtime resolution cannot open a microphone',
    () async {
      var current = true;
      final pending = Completer<TalkRecordRecordingCoordinator>();
      final launcher = TalkRecordCoordinatorLauncher(() => pending.future);
      final result = launcher.launch(
        TalkRecordRecordingDraftRequest(
          saveTo: const TalkRecordEntryContext.personal(),
          isCurrentOperation: () => current,
        ),
      );
      current = false;
      final runtime = coordinator();
      pending.complete(runtime);
      expect((await result).started, isFalse);
      expect(engines, isEmpty);
    },
  );

  test(
    'production provider resolves real coordinator launcher, not placeholder',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(talkRecordRecordingLauncherProvider),
        isA<TalkRecordCoordinatorLauncher>(),
      );
    },
  );
  test(
    'launcher facade starts local audio without requiring server availability',
    () async {
      final gateway = LeaseGateway();
      final c = coordinator(gateway: gateway);
      final launcher = TalkRecordCoordinatorLauncher(() async => c);
      expect((await launcher.launch(request)).started, true);
      expect(gateway.calls, 0);
      expect(recorders.single.phase, TalkRecordRecorderPhase.recording);
      expect((await store.list(account)).single.recordId, isEmpty);
      await c.end();
    },
  );
  test('real local service starts and durable ownership mapping survives navigation', () async {
    final c = coordinator();
    expect((await c.launch(request)).started, true);
    await tick();
    final rows = await store.list(account);
    expect(rows.single.sessionId, c.snapshot.sessionId);
    expect(rows.single.context, request.saveTo);
    expect(rows.single.policyVersion, 'v1');
    expect(c.snapshot.effectiveDurationMs, 500);
    await c.pause();
    expect(c.snapshot.phase, TalkRecordRecorderPhase.paused);
    await c.resume();
    expect(c.snapshot.phase, TalkRecordRecorderPhase.recording);
    final result = await c.end();
    expect(result.savedCleanly, true);
    expect(result.segmentCount, 1);
    expect((await store.list(account)).single.completed, false);
  });
  test('second start cannot overwrite the active local capture', () async {
    final c = coordinator();
    await c.launch(request);
    final id = c.binding!.clientRecordingId;
    expect((await c.launch(request)).started, false);
    expect(c.binding!.clientRecordingId, id);
    expect((await store.list(account)).length, 1);
  });
  test(
    'foreign account and endpoint cannot discover or upload prior audio',
    () async {
      final c = coordinator();
      await c.launch(request);
      await tick();
      await c.end();
      final binding = c.binding!;
      account = const TalkRecordAccount('https://local.example', '200');
      expect(await store.list(account), isEmpty);
      await expectLater(c.uploadEnded(binding), throwsStateError);
      account = const TalkRecordAccount('https://other.example', '100');
      expect(await store.list(account), isEmpty);
      await expectLater(c.uploadEnded(binding), throwsStateError);
    },
  );
  test('auth transition interrupts mic; old control rejected', () async {
    final c = coordinator();
    await c.launch(request);
    account = const TalkRecordAccount('https://local.example', '200');
    await c.accountChanged();
    expect(recorders.single.phase, TalkRecordRecorderPhase.interrupted);
    await expectLater(c.resume(), throwsStateError);
    await expectLater(c.end(), throwsStateError);
  });
  test('anonymous recording refuses before opening engine', () async {
    account = const TalkRecordAccount('https://local.example', '');
    expect((await coordinator().launch(request)).started, false);
    expect(engines, isEmpty);
  });
  test('recovery discovery never opens mic and explicit resume requires stored key', () async {
    final c = coordinator();
    await c.launch(request);
    await tick();
    await c.pause();
    final original = await TalkRecordManifestStore(recorders.single.sessionDir!)
        .read();
    // Simulate a terminal old process: close its mic, retain pre-crash manifest.
    await c.end();
    await TalkRecordManifestStore(recorders.single.sessionDir!)
        .write(original!);
    final recovered = coordinator();
    await recovered.discover();
    expect(engines.length, 1);
    expect(recovered.snapshot.phase, TalkRecordRecorderPhase.interrupted);
    final key = keys.store.remove(recovered.binding!.sessionId)!;
    await expectLater(recovered.resume(), throwsStateError);
    expect(engines.length, 1);
    keys.store[recovered.binding!.sessionId] = key;
    await recovered.resume();
    expect(engines.length, 2);
    expect(recovered.snapshot.phase, TalkRecordRecorderPhase.recording);
    await recovered.end();
  });
  test('finish recovered recording retains sealed parts without opening microphone', () async {
    final c = coordinator();
    await c.launch(request);
    await tick();
    final result = await c.end();
    final manifest = result.manifest.copyWith(
      status: TalkRecordSessionStatus.interrupted,
    );
    await TalkRecordManifestStore(recorders.single.sessionDir!).write(manifest);
    final recovered = coordinator();
    await recovered.discover();
    final ended = await recovered.end();
    expect(engines.length, 1);
    expect(ended.segmentCount, 1);
    expect(ended.manifest.status, TalkRecordSessionStatus.ended);
  });
  test(
    'unknown lease preserves local audio and never calls uploader',
    () async {
      final gateway = LeaseGateway();
      final uploader = TestUploader();
      final c = coordinator(gateway: gateway, uploader: uploader);
      await c.launch(request);
      await tick();
      await c.end();
      await expectLater(c.uploadEnded(c.binding!), throwsStateError);
      expect(gateway.calls, 1);
      expect(uploader.calls, 0);
      expect((await store.list(account)).single.completed, false);
    },
  );
  test('absent production uploader never reports uploaded success', () async {
    final c = coordinator();
    await c.launch(request);
    await tick();
    await c.end();
    await expectLater(c.uploadEnded(c.binding!), throwsStateError);
    expect((await store.list(account)).single.completed, false);
  });
  test('completion checkpoint accepts real initial epoch zero and successful uploader', () async {
    final gateway = LeaseGateway(known: true);
    final uploader = TestUploader();
    final c = coordinator(gateway: gateway, uploader: uploader);
    await c.launch(request);
    await tick();
    await c.end();
    await c.uploadEnded(c.binding!);
    expect(uploader.calls, 1);
    expect((await store.list(account)).single.leaseEpoch, 0);
    expect((await store.list(account)).single.completed, true);
  });
  test(
    'local binding missing or invalid epoch is unknown, never initial zero',
    () async {
      final c = coordinator();
      await c.launch(request);
      await c.end();
      final json = c.binding!.toJson()..remove('lease_epoch');
      expect(TalkRecordLocalBinding.fromJson(json).leaseEpoch, -1);
      for (final malformed in [null, false, 0.5, '0.5', 'false', -2]) {
        json['lease_epoch'] = malformed;
        expect(TalkRecordLocalBinding.fromJson(json).leaseEpoch, -1);
      }
      json['lease_epoch'] = 0;
      expect(TalkRecordLocalBinding.fromJson(json).leaseEpoch, 0);
    },
  );
  test(
    'binding corruption fails closed without creating replacement session',
    () async {
      final c = coordinator();
      await c.launch(request);
      await tick();
      await c.end();
      final files = Directory('${root.path}/${account.storageKey}')
          .listSync()
          .whereType<File>();
      files.single.writeAsStringSync('{bad');
      expect((await coordinator().launch(request)).started, false);
      expect(engines.length, 1);
    },
  );
  test('binding persisted under wrong owner is rejected', () async {
    final c = coordinator();
    await c.launch(request);
    await tick();
    await c.end();
    final binding = c.binding!;
    account = const TalkRecordAccount('https://local.example', '200');
    final newDir = Directory('${root.path}/${account.storageKey}')
      ..createSync();
    final source = File(
      '${root.path}/${binding.account.storageKey}/${binding.clientRecordingId}.json',
    );
    source.copySync('${newDir.path}/${binding.clientRecordingId}.json');
    await expectLater(store.list(account), throwsStateError);
  });
  test('pending-ended projection is account-scoped and accepted uploads leave pending queue', () async {
    final c = coordinator(
      gateway: LeaseGateway(known: true),
      uploader: TestUploader(),
    );
    await c.launch(request);
    await tick();
    await c.end();
    final pending = await c.pendingEnded();
    expect(pending.length, 1);
    expect(pending.single.durationMs, 500);
    expect(pending.single.segmentCount, 1);
    await c.retryPending(pending.single.binding);
    expect(await c.pendingEnded(), isEmpty);
    account = const TalkRecordAccount('https://local.example', '200');
    expect(await c.pendingEnded(), isEmpty);
  });
  test('explicit pending correction preserves identity/audio and stale retry uses latest list', () async {
    final uploader = TestUploader();
    final c = coordinator(
      gateway: LeaseGateway(known: true),
      uploader: uploader,
    );
    await c.launch(request);
    await tick();
    await c.end();
    final stale = c.binding!;
    final originalManifest = await TalkRecordManifestStore(
      Directory('${store.audioDirectory(account).path}/${stale.sessionId}'),
    ).read();
    final latest = stale.copyWith(
      recordId: '1',
      captureId: '2',
      recordEtag: '"9"',
      participantsSynced: true,
    );
    await store.save(latest);
    const guest = TalkRecordParticipantInput(displayName: 'Corrected guest');
    final updated = await c.updatePendingParticipants(stale, [guest]);
    expect(updated.account, stale.account);
    expect(updated.context, stale.context);
    expect(updated.clientRecordingId, stale.clientRecordingId);
    expect(updated.sessionId, stale.sessionId);
    expect(updated.deviceSessionId, stale.deviceSessionId);
    expect(updated.recordId, '1');
    expect(updated.captureId, '2');
    expect(updated.recordEtag, '"9"');
    expect(updated.participantsRequested, true);
    expect(updated.participantsSynced, false);
    final after = await TalkRecordManifestStore(
      Directory('${store.audioDirectory(account).path}/${stale.sessionId}'),
    ).read();
    expect(after!.toJson(), originalManifest!.toJson());
    // The old UI snapshot is deliberately supplied after the correction.
    await c.retryPending(stale);
    expect(
      uploader.lastBinding!.participants.single.displayName,
      'Corrected guest',
    );
    expect((await store.list(account)).single.completed, true);
  });

  test(
    'pending correction rejects active/completed/foreign recordings',
    () async {
      final c = coordinator();
      await c.launch(request);
      await tick();
      final local = c.binding!;
      await expectLater(
        c.updatePendingParticipants(local, []),
        throwsStateError,
      );
      await c.end();
      await store.save(local.copyWith(completed: true));
      await expectLater(
        c.updatePendingParticipants(local, []),
        throwsStateError,
      );
      await store.save(local);
      account = const TalkRecordAccount('https://local.example', '200');
      await expectLater(
        c.updatePendingParticipants(local, []),
        throwsStateError,
      );
      expect((await store.list(local.account)).single.toJson(), local.toJson());
    },
  );

  test('first upload projects persisted binding while real pending mutex remains locked', () async {
    final uploader = ProgressHeldUploader();
    final c = coordinator(
      gateway: LeaseGateway(known: true),
      uploader: uploader,
    );
    await c.launch(request);
    await tick();
    await c.end();
    final original = (await c.pendingEnded()).single;
    expect(original.binding.recordId, isEmpty);
    final upload = c.retryPending(original.binding);
    await uploader.entered.future;
    await expectLater(c.pendingEnded(), throwsStateError);
    final snapshot = c.uploadSnapshot!;
    final projected = talkRecordPendingUploadProjection(original, snapshot);
    expect(projected.binding.recordId, '1');
    expect(snapshot.matches(projected.binding), isTrue);
    expect(
      projected.binding.toJson(),
      (await store.list(account)).single.toJson(),
    );
    expect(snapshot.matches(original.binding), isFalse);
    expect(
      talkRecordPendingUploadProjection(
        TalkRecordPendingEnded(
          original.binding.copyWith(recordId: 'different'),
          original.durationMs,
          original.segmentCount,
        ),
        snapshot,
      ).binding.recordId,
      'different',
    );
    account = const TalkRecordAccount('https://local.example', 'other-user');
    expect(c.uploadSnapshot, isNull);
    account = original.binding.account;
    uploader.release.complete();
    await upload;
  });

  test('pending correction shares exclusive lock with uploading', () async {
    final uploader = HeldUploader();
    final c = coordinator(
      gateway: LeaseGateway(known: true),
      uploader: uploader,
    );
    await c.launch(request);
    await tick();
    await c.end();
    final local = c.binding!;
    final upload = c.retryPending(local);
    await uploader.entered.future;
    await expectLater(c.updatePendingParticipants(local, []), throwsStateError);
    expect(
      (await store.list(account)).single.participantsRequested,
      local.participantsRequested,
    );
    expect((await store.list(account)).single.participants, local.participants);
    uploader.release.complete();
    await upload;
  });

  test(
    'pending correction fences an auth transition before persistence',
    () async {
      final c = coordinator();
      await c.launch(request);
      await tick();
      await c.end();
      final local = c.binding!;
      final before = (await store.list(account)).single.toJson();
      var checks = 0;
      await expectLater(
        c.updatePendingParticipants(
          local,
          [const TalkRecordParticipantInput(displayName: 'Not written')],
          checkCurrentOperation: () {
            if (++checks == 2) {
              throw StateError('same uid auth transition');
            }
          },
        ),
        throwsStateError,
      );
      expect(checks, 2);
      expect((await store.list(account)).single.toJson(), before);
    },
  );

  test(
    'pending correction rejects stale session and invalid whole selection',
    () async {
      final c = coordinator();
      await c.launch(request);
      await tick();
      await c.end();
      final local = c.binding!;
      await expectLater(
        c.updatePendingParticipants(local.copyWith(sessionId: 'wrong'), []),
        throwsStateError,
      );
      const guest = TalkRecordParticipantInput(displayName: 'Duplicate');
      await expectLater(
        c.updatePendingParticipants(local, [guest, guest]),
        throwsFormatException,
      );
      await expectLater(
        c.updatePendingParticipants(
          local,
          List.generate(
            101,
            (i) => TalkRecordParticipantInput(displayName: 'Guest $i'),
          ),
        ),
        throwsFormatException,
      );
      expect((await store.list(account)).single.toJson(), local.toJson());
    },
  );

  test('explicit empty pending selection persists a requested clear', () async {
    final c = coordinator();
    await c.launch(request);
    await tick();
    await c.end();
    final old = c.binding!;
    await store.save(
      old.copyWith(
        participants: [
          const TalkRecordParticipantInput(displayName: 'Old guest'),
        ],
        participantsSynced: true,
      ),
    );
    final cleared = await c.updatePendingParticipants(old, []);
    expect(cleared.participants, isEmpty);
    expect(cleared.participantsRequested, true);
    expect(cleared.participantsSynced, false);
  });

  test('coordinator permits normally ended late upload despite expired active lease', () async {
    final uploader = TestUploader();
    final c = coordinator(
      gateway: LeaseGateway(known: true, ended: true),
      uploader: uploader,
    );
    await c.launch(request);
    await tick();
    await c.end();
    await c.uploadEnded(c.binding!);
    expect(uploader.calls, 1);
    expect((await store.list(account)).single.completed, true);
  });
  test(
    'pending upload confirmation preserves original policy and immutable audio',
    () async {
      final c = coordinator();
      await c.launch(request);
      await tick();
      final active = c.binding!;
      await expectLater(
        c.confirmPendingUploadPolicy(
          active,
          'v2',
          checkCurrentOperation: () {},
        ),
        throwsStateError,
      );
      await c.end();
      final before = (await store.list(account)).single;
      final original = await TalkRecordManifestStore(
        Directory('${store.audioDirectory(account).path}/${before.sessionId}'),
      ).read();
      final updated = await c.confirmPendingUploadPolicy(
        before,
        'v2',
        checkCurrentOperation: () {},
      );
      expect(updated.policyVersion, before.policyVersion);
      expect(updated.uploadPolicyVersion, 'v2');
      expect(updated.uploadPolicyAcknowledgedAt, isNotNull);
      expect(updated.recordId, before.recordId);
      expect(updated.clientRecordingId, before.clientRecordingId);
      expect(updated.context, before.context);
      final after = await TalkRecordManifestStore(
        Directory('${store.audioDirectory(account).path}/${before.sessionId}'),
      ).read();
      expect(after!.toJson(), original!.toJson());
    },
  );

  test('processing re-confirmation is explicit, durable and preserves immutable capture facts', () async {
    final c = coordinator();
    await c.launch(request);
    await tick();
    await c.end();
    final old = (await store.list(account)).single;
    final local = TalkRecordLocalBinding.fromJson({
      ...old.toJson(),
      'processing_mode': 'transcribe',
    });
    await store.save(local);
    final updated = await c.confirmPendingProcessingConsent(
      local,
      'new-pv',
      'new-pcv',
      checkCurrentOperation: () {},
    );
    expect(updated.policyVersion, local.policyVersion);
    expect(updated.processingMode, 'transcribe');
    expect(updated.effectiveProcessingPolicy, 'new-pv');
    expect(updated.processingConsentGeneration, isNotEmpty);
    expect(updated.processingConsentAcknowledgedAt, isNotNull);
    expect(updated.clientRecordingId, local.clientRecordingId);
    expect(updated.deviceId, local.deviceId);
    expect(updated.recordId, local.recordId);
    expect(updated.context, local.context);
    final persisted = (await store.list(account)).single;
    expect(
      persisted.processingConsentGeneration,
      updated.processingConsentGeneration,
    );
    var checks = 0;
    await expectLater(
      c.confirmPendingProcessingConsent(
        local,
        'late-pv',
        'late-pcv',
        checkCurrentOperation: () {
          if (++checks == 2) throw StateError('reauth');
        },
      ),
      throwsStateError,
    );
    expect(
      (await store.list(account)).single.effectiveProcessingPolicy,
      'new-pv',
    );
    await store.save(updated.copyWith(completed: true));
    await expectLater(
      c.confirmPendingProcessingConsent(
        local,
        'late-pv',
        'late-pcv',
        checkCurrentOperation: () {},
      ),
      throwsStateError,
    );
  });

  test('pending confirmation rejects bound/foreign/completed and same uid auth race', () async {
    final c = coordinator();
    await c.launch(request);
    await tick();
    await c.end();
    final before = (await store.list(account)).single;
    var checks = 0;
    await expectLater(
      c.confirmPendingUploadPolicy(
        before,
        'v2',
        checkCurrentOperation: () {
          if (++checks == 2) throw StateError('reauth');
        },
      ),
      throwsStateError,
    );
    expect((await store.list(account)).single.uploadPolicyVersion, isEmpty);
    await store.save(before.copyWith(recordId: '1'));
    await expectLater(
      c.confirmPendingUploadPolicy(before, 'v2', checkCurrentOperation: () {}),
      throwsStateError,
    );
    await store.save(before.copyWith(completed: true));
    await expectLater(
      c.confirmPendingUploadPolicy(before, 'v2', checkCurrentOperation: () {}),
      throwsStateError,
    );
    await store.save(before);
    account = const TalkRecordAccount('https://local.example', 'another');
    await expectLater(
      c.confirmPendingUploadPolicy(before, 'v2', checkCurrentOperation: () {}),
      throwsStateError,
    );
  });
  for (final code in [
    'notification_permission_required',
    'notification_channel_blocked',
  ]) {
    test(
      'native $code preserves typed cause through real service and coordinator',
      () async {
        final c = coordinator(testEngine: NotificationFailingEngine(code));
        final result = await c.launch(request);
        expect(result.started, false);
        expect(result.notificationRequired, true);
        expect(c.snapshot.isActive, false);
        expect(TalkRecordCaptureLease.isBusy, false);
      },
    );
  }
  test(
    'nested notification causes classified, unrelated failures unchanged',
    () {
      expect(
        talkRecordLaunchFailure(
          TalkRecordStartException(
            'outer',
            cause: TalkRecordStartException(
              'inner',
              cause: PlatformException(code: 'notification_channel_blocked'),
            ),
          ),
        ).notificationRequired,
        true,
      );
      expect(
        talkRecordLaunchFailure(
          PlatformException(code: 'microphone_permission_required'),
        ).notificationRequired,
        false,
      );
      expect(
        talkRecordLaunchFailure(StateError('storage failure'))
            .notificationRequired,
        false,
      );
    },
  );
}
