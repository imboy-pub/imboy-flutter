import 'dart:io';

import 'package:dio/dio.dart' show CancelToken;

import 'package:imboy/modules/talk_record/application/talk_record_upload_progress.dart';

import 'package:imboy/modules/talk_record/application/talk_record_processing_consent.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/talk_record_attachment_upload_gateway.dart';
import 'package:imboy/modules/talk_record/application/talk_record_upload_checkpoint.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/application/talk_record_part_transport.dart';
import 'package:imboy/modules/talk_record/application/talk_record_upload_manifest.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/store/api/attachment_direct_api.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_mark_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';

import 'fake_talk_record_engine.dart';

part 'talk_record_upload_fixtures.dart';

void main() {
  late Directory directory;
  late MemoryTalkRecordKeyStore keys;
  late TalkRecordRecorderService recorder;
  late TalkRecordManifest manifest;
  late TalkRecordLocalBinding binding;
  late UploadApi api;
  late UploadTransport transport;
  var accountValid = true;
  setUp(() async {
    directory = Directory.systemTemp.createTempSync('talk_upload_');
    keys = MemoryTalkRecordKeyStore();
    api = UploadApi();
    transport = UploadTransport();
    accountValid = true;
    TalkRecordCaptureLease.resetForTest();
    final engine = FakeTalkRecordEngine();
    recorder = TalkRecordRecorderService(
      baseDirectory: directory,
      engine: engine,
      keyStore: keys,
      diskProbe: FakeDiskSpaceProbe(),
      config: const TalkRecordRecorderConfig(minFreeDiskBytesPerSegment: 1),
    );
    await recorder.start(
      recordLocalId: 'record-client',
      clientRecordingId: 'record-client',
    );
    engine.tick(1000);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await recorder.addMark(note: 'Decision');
    manifest = (await recorder.end()).manifest;
    binding = TalkRecordLocalBinding(
      account: const TalkRecordAccount('https://local.example', '100'),
      clientRecordingId: 'record-client',
      deviceSessionId: 'device-session',
      context: const TalkRecordEntryContext.personal(),
      title: 'Sync',
      processingMode: 'record_only',
      policyVersion: 'v1',
      processorConfigVersion: 'approved-bundle-v1',
      sessionId: manifest.sessionId,
      recordId: '1',
      captureId: '2',
      leaseEpoch: 0,
      captureStatus: 'draft',
      leaseUntil: DateTime.now().add(const Duration(minutes: 5)),
    );
  });
  tearDown(() async {
    await recorder.dispose();
    TalkRecordCaptureLease.resetForTest();
    directory.deleteSync(recursive: true);
  });
  Future<void> upload({
    int attempts = 6,
    TalkRecordManifest? source,
    FinalDirectFake? finalDirect,
  }) {
    final fd = finalDirect ?? FinalDirectFake();
    return TalkRecordAttachmentUploadGateway(
      api: api,
      transport: transport,
      confirmAttempts: attempts,
      delay: (_) async {},
      directUpload: fd.upload,
      directStatus: fd.status,
      directRegister: fd.register,
    ).upload(
      binding: binding,
      manifest: source ?? manifest,
      directory: recorder.sessionDir!,
      keys: keys,
      checkAccount: () {
        if (!accountValid) throw StateError('account changed');
      },
    );
  }

  void expectNoPlaintext() => expect(
    Directory('${recorder.sessionDir!.path}/.upload_plain').existsSync(),
    false,
  );

  test(
    'progress follows server receipts and retry resumes confirmed count',
    () async {
      final fd = FinalDirectFake();
      final gateway = TalkRecordAttachmentUploadGateway(
        api: api,
        transport: transport,
        confirmAttempts: 1,
        delay: (_) async {},
        directUpload: fd.upload,
        directStatus: fd.status,
        directRegister: fd.register,
      );
      final snapshots = <TalkRecordUploadSnapshot>[];
      final subscription = gateway.uploadUpdates.listen(snapshots.add);
      Future<void> run() => gateway.upload(
        binding: binding,
        manifest: manifest,
        directory: recorder.sessionDir!,
        keys: keys,
        checkAccount: () {
          if (!accountValid) throw StateError('account changed');
        },
      );
      api.verifyCount = 20;
      await expectLater(run(), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.last.phase, TalkRecordUploadPhase.failed);
      expect(snapshots.last.confirmedParts, 0);
      expect(snapshots.every((s) => s.matches(binding)), isTrue);
      expect(
        snapshots.map((s) => s.phase),
        containsAllInOrder([
          TalkRecordUploadPhase.register,
          TalkRecordUploadPhase.upload,
          TalkRecordUploadPhase.confirm,
          TalkRecordUploadPhase.failed,
        ]),
      );
      final failedSnapshot = snapshots.last;
      expect(
        failedSnapshot.matches(binding.copyWith(recordId: 'other')),
        isFalse,
      );
      expect(
        TalkRecordUploadSnapshot(
          account: const TalkRecordAccount('other-endpoint', '100'),
          recordId: binding.recordId,
          sessionId: binding.sessionId,
          totalParts: 1,
          confirmedParts: 0,
          phase: TalkRecordUploadPhase.failed,
        ).matches(binding),
        isFalse,
      );
      api.verifyCount = 0;
      await run();
      await Future<void>.delayed(Duration.zero);
      expect(transport.puts, 1);
      expect(snapshots.last.phase, TalkRecordUploadPhase.completed);
      expect(snapshots.last.confirmedParts, manifest.segments.length);
      expect(failedSnapshot.confirmedParts, 0);
      expect(
        snapshots
            .where((s) => s.phase == TalkRecordUploadPhase.submitting)
            .every((s) => s.confirmedParts == s.totalParts),
        isTrue,
      );
      final previousLength = snapshots.length;
      accountValid = false;
      await expectLater(run(), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(snapshots.length, previousLength);
      await subscription.cancel();
    },
  );

  test('initial draft epoch zero uploads real decrypted bytes, confirms and submits canonical manifest', () async {
    api.verifyCount = 1;
    await upload();
    expect(transport.puts, 1);
    expect(api.confirms, 2);
    expect(api.completes, 1);
    expect(api.completedProcessorConfigVersion, isNull);
    expect(transport.plaintextHash, manifest.segments.single.plainSha256Hex);
    expect(api.markIds, [manifest.marks.single.localId]);
    final s = manifest.segments.single;
    final expected = {
      'v': 1,
      'capture_id': 2,
      'parts': [
        {
          'seq': 0,
          'part_id': 3,
          'attachment_id': 4,
          'sha256': s.plainSha256Hex,
          'byte_size': s.plainSize,
          'offset_ms': 0,
          'duration_ms': 1024, // 16 帧@16kHz 真实样本（tick 1000 → ceil→16 帧）
        },
      ],
      'total_duration_ms': 1024,
      'total_bytes': s.plainSize,
    };
    expect(api.completedHash, talkRecordManifestHash(expected));
    expect(api.status, 'ended');
    expectNoPlaintext();
    expect(keys.store[manifest.sessionId]!.any((b) => b != 0), true);
  });
  test('verifying timeout preserves PUT checkpoint and retry never reuploads confirmed bytes', () async {
    api.verifyCount = 20;
    await expectLater(upload(attempts: 2), throwsStateError);
    expect(api.completes, 0);
    expect(transport.puts, 1);
    expectNoPlaintext();
    api.verifyCount = 0;
    await upload();
    expect(transport.puts, 1);
    expect(api.registrationKeys.length, 1);
    expect(api.completes, 1);
  });
  test(
    'PUT response loss retries same part session key and cleans plaintext',
    () async {
      transport.fail = true;
      await expectLater(upload(), throwsStateError);
      expectNoPlaintext();
      await upload();
      expect(transport.puts, 2);
      expect(api.registrationKeys.toSet().length, 1);
      expect(api.completes, 1);
      expectNoPlaintext();
    },
  );
  test('end response loss reconciles ended server sequence, no new capture or repeated event', () async {
    api.loseEndResponse = true;
    await expectLater(upload(), throwsStateError);
    final sent = api.eventIds.length;
    await upload();
    expect(api.eventIds.length, sent);
    expect(api.completes, 1);
    expect(transport.puts, 1);
  });
  test(
    'complete response loss reuses frozen idempotency key, manifest and ETag',
    () async {
      api.loseCompleteResponse = true;
      await upload();
      await upload();
      expect(api.completeKeys.length, 1);
      expect(api.completeKeys.toSet().length, 1);
      expect(transport.puts, 1);
      expect(api.markIds.length, 1);
    },
  );
  test('missing server sequence rejects instead of assuming zero', () async {
    api.missingSequence = true;
    await expectLater(upload(), throwsStateError);
    expect(transport.puts, 0);
    expect(api.eventIds, isEmpty);
    expect(api.completes, 0);
  });
  test(
    'expired lease and revoked authorization preserve local encrypted source',
    () async {
      api.expired = true;
      await expectLater(upload(), throwsStateError);
      api.expired = false;
      api.revoked = true;
      await expectLater(upload(), throwsStateError);
      expect(transport.puts, 0);
      expect(recorder.sessionDir!.existsSync(), true);
    },
  );
  test('pending ticket never PUTs or completes', () async {
    api.pendingTicket = true;
    await expectLater(upload(), throwsStateError);
    expect(transport.puts, 0);
    expect(api.completes, 0);
    expectNoPlaintext();
  });
  test('account change refuses before server requests or plaintext materialization', () async {
    accountValid = false;
    await expectLater(upload(), throwsStateError);
    expect(api.eventIds, isEmpty);
    expect(transport.puts, 0);
    expectNoPlaintext();
  });
  test('missing decryption key and corrupt encrypted file do not upload or complete', () async {
    final key = keys.store.remove(manifest.sessionId)!;
    await expectLater(upload(), throwsStateError);
    expectNoPlaintext();
    keys.store[manifest.sessionId] = key;
    final file = File(
      '${recorder.sessionDir!.path}/${manifest.segments.single.cipherFileName}',
    );
    await file.writeAsBytes([1, 2, 3]);
    await expectLater(upload(), throwsA(isA<Object>()));
    expectNoPlaintext();
    expect(transport.puts, 0);
    expect(api.completes, 0);
  });
  test(
    'gap in local part sequence rejects before any server request',
    () async {
      final segment = manifest.segments.single.toJson()..['seq'] = 1;
      final malformed = TalkRecordManifest.fromJson(
        manifest.toJson()..['segments'] = [segment],
      );
      await expectLater(upload(source: malformed), throwsStateError);
      expect(api.eventIds, isEmpty);
      expect(transport.puts, 0);
    },
  );
  test(
    'checkpoint source drift refuses resume rather than resetting to part zero',
    () async {
      api.verifyCount = 20;
      await expectLater(upload(attempts: 1), throwsStateError);
      final changed = manifest.copyWith(updatedAtIso: 'different');
      await expectLater(upload(source: changed), throwsStateError);
      expect(api.registrationKeys.length, 1);
    },
  );
  test(
    'canonical JSON matches sorted integer TSID manifest, floats forbidden',
    () {
      expect(
        canonicalTalkRecordJson({'z': 0, 'a': 9223372036854775807}),
        '{"a":9223372036854775807,"z":0}',
      );
      expect(() => canonicalTalkRecordJson({'v': 1.5}), throwsFormatException);
    },
  );
  test('stale plaintext from process interruption is removed before revoked network retry', () async {
    final plain = Directory('${recorder.sessionDir!.path}/.upload_plain')
      ..createSync();
    File('${plain.path}/interrupted.aac').writeAsBytesSync([1, 2, 3]);
    api.revoked = true;
    await expectLater(upload(), throwsStateError);
    expectNoPlaintext();
  });
  test(
    'two-part backend build_manifest vector has independently frozen digest',
    () {
      TalkRecordSegmentEntry part(int seq, int start, int end, int size) =>
          TalkRecordSegmentEntry.fromJson({
            'seq': seq,
            'start_ms': start,
            'end_ms': end,
            'plain_size': size,
            'plain_sha256': '0' * 64,
          });
      final canonical = talkRecordCanonicalManifest(
        '77',
        [part(0, 0, 30000, 1024), part(1, 30000, 75000, 2048)],
        {
          '0': {'part_id': '101', 'attachment_id': '11'},
          '1': {'part_id': '102', 'attachment_id': '12'},
        },
      );
      // Backend T12 shape; digest independently reproduced with sorted stdlib JSON.
      expect(
        talkRecordManifestHash(canonical),
        '7e821fd8290df5465a3ef2395698c7d5cfb6eb56ec85ce61485ac0e4ad76b8d4',
      );
    },
  );
  test('normal ended capture completes after active lease expires without recovering mic', () async {
    api.loseEndResponse = true;
    await expectLater(upload(), throwsStateError);
    expect(api.status, 'ended');
    api.expired = true;
    await upload();
    expect(api.completes, 1);
    expect(transport.puts, 1);
  });
  test('submitted checkpoint crash window replays complete and verifies current server projection after expiry', () async {
    await upload();
    // Simulates the upload checkpoint committed before binding.completed write.
    api.expired = true;
    await upload();
    expect(api.completeKeys.length, 1);
    expect(api.completeKeys.toSet().length, 1);
    expect(transport.puts, 1);
  });
  test(
    'submitted local flag cannot replace current server completed projection',
    () async {
      await upload();
      api.media = 'uploading';
      api.suppressProjection = true;
      api.expired = true;
      await expectLater(upload(), throwsStateError);
      expect(api.completes, 2);
    },
  );
  test(
    'expired ended capture still rejects transferred owner and fencing',
    () async {
      await upload();
      api.expired = true;
      api.ownerId = '200';
      await expectLater(upload(), throwsStateError);
      expect(api.completes, 1);
      api.ownerId = '100';
      api.epoch = 1;
      await expectLater(upload(), throwsStateError);
      expect(api.completes, 1);
    },
  );
  test('current processing consent required before upload; historical facts unchanged', () async {
    binding = TalkRecordLocalBinding.fromJson({
      ...binding.toJson(),
      'processing_mode': 'transcribe',
    });
    await expectLater(
      upload(),
      throwsA(isA<TalkRecordProcessingConsentRequired>()),
    );
    expect(transport.puts, 0);
    expect(api.completes, 0);
    binding = binding.copyWith(
      processingConsentPolicyVersion: 'v2',
      processingConsentProcessorVersion: 'pcv2',
      processingConsentGeneration: 'explicit-1',
      processingConsentAcknowledgedAt: DateTime.utc(2026),
    );
    await upload();
    expect(api.completedPolicyVersion, 'v2');
    expect(api.completedProcessorConfigVersion, 'pcv2');
    expect(binding.policyVersion, 'v1');
    expect(binding.processorConfigVersion, 'approved-bundle-v1');
  });
  test(
    'completed authoritative hash reconciles before changed processor notice',
    () async {
      await upload();
      binding = TalkRecordLocalBinding.fromJson({
        ...binding.toJson(),
        'processing_mode': 'transcribe',
      });
      await upload();
      expect(api.completes, 1);
    },
  );
  test(
    'missing completion hash cannot certify a submitted local flag',
    () async {
      await upload();
      api.missingCompletionHash = true;
      await expectLater(upload(), throwsStateError);
    },
  );
  test('new explicit processing generation uses a fresh complete key after failure', () async {
    binding = TalkRecordLocalBinding.fromJson({
      ...binding.toJson(),
      'processing_mode': 'transcribe',
      'policy_version': 'v2',
      'processor_config_version': 'pcv2',
    });
    api.suppressProjection = true;
    await expectLater(upload(), throwsStateError);
    final originalKey = api.completeKeys.single;
    binding = binding.copyWith(
      processingConsentPolicyVersion: 'v2',
      processingConsentProcessorVersion: 'pcv2',
      processingConsentGeneration: 'explicit-2',
      processingConsentAcknowledgedAt: DateTime.utc(2026),
    );
    api.suppressProjection = false;
    await upload();
    expect(api.completeKeys.last, isNot(originalKey));
    expect(transport.puts, 1);
  });
  test('offline original policy stays unknown while explicitly confirmed upload completes', () async {
    binding = TalkRecordLocalBinding.fromJson({
      ...binding.toJson(),
      'policy_version': '',
      'upload_policy_version': 'v2',
      'upload_policy_acknowledged_at': DateTime.utc(2026).toIso8601String(),
    });
    await upload();
    expect(api.completes, 1);
    expect(api.completedPolicyVersion, 'v2');
    expect(binding.policyVersion, isEmpty);
    expectNoPlaintext();
  });
  group('final audio direct upload (no-backend-ffmpeg V1 T2)', () {
    test('composes ordered plaintext, direct-confirms with talk_record scope before complete, freezes identity', () async {
      final fd = FinalDirectFake();
      await upload(finalDirect: fd);
      expect(fd.registers, 1);
      expect(fd.statuses, 1, reason: 'register must re-check server status');
      expect(fd.uploads, 1);
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(fd.clientUploadIds.single),
        isTrue,
        reason: 'client_upload_id must be uuid36 (server register contract)',
      );
      expect(fd.scopeRefs.single, binding.recordId);
      final decl = api.completedFinalAudio!;
      expect(decl.objectKey, fd.objectKeyOf(fd.clientUploadIds.single));
      expect(decl.clientUploadId, fd.clientUploadIds.single);
      expect(decl.channels, 1);
      expect(decl.sampleRate, 16000);
      // 成品字节 = 段明文逐字节（单段：size/hash 相等）。
      expect(decl.byteSize, manifest.segments.single.plainSize);
      // fake 引擎 tick 1000ms → 16 帧 × 1024 样本 → 统一舍入 1024ms。
      expect(decl.sampleCount, 16 * 1024);
      expect(decl.durationMs, 1024);
      // checkpoint 冻结 confirmed 身份；明文临时目录已清。
      final cp = await TalkRecordUploadCheckpointStore(recorder.sessionDir!)
          .load(binding, talkRecordManifestHash(manifest.toJson()));
      expect(cp.finalAudio['confirmed'], true);
      expect(cp.finalAudio['client_upload_id'], fd.clientUploadIds.single);
      expectNoPlaintext();
    });
    test(
      'confirmed identity short-circuits recomposition and re-upload',
      () async {
        final fd = FinalDirectFake();
        await upload(finalDirect: fd);
        expect(fd.uploads, 1);
        await upload(finalDirect: fd);
        expect(
          fd.uploads,
          1,
          reason: 'checkpoint confirmed must not re-upload',
        );
        expect(
          fd.statuses,
          1,
          reason: 'only the first-run register re-check queries status',
        );
        expect(api.completes, 1);
      },
    );
    test('FINALIZING never reaches complete and leaves no plaintext', () async {
      final fd = FinalDirectFake()..finalizeState = 'FINALIZING';
      await expectLater(upload(finalDirect: fd), throwsStateError);
      expect(api.completes, 0);
      expectNoPlaintext();
    });
    test('lost direct put recovers along the same frozen identity', () async {
      final fd = FinalDirectFake()..failFirstPut = true;
      await expectLater(upload(finalDirect: fd), throwsStateError);
      expect(api.completes, 0);
      await upload(finalDirect: fd);
      expect(api.completes, 1);
      expect(
        fd.clientUploadIds.toSet().length,
        1,
        reason: 'retry must reuse the frozen client_upload_id',
      );
      expect(
        api.completedFinalAudio!.clientUploadId,
        fd.clientUploadIds.toSet().single,
      );
    });
    test('finalize receipt loss recovers via server status CONFIRMED without re-upload', () async {
      // 第一次：direct PUT 丢失 → 身份已落盘（无 confirmed）、未到 complete。
      final fd = FinalDirectFake()..failFirstPut = true;
      await expectLater(upload(finalDirect: fd), throwsStateError);
      expect(api.completes, 0);
      // 真实场景：服务端 finalize 其实已成功，仅 confirmed 落盘前崩溃。
      fd
        ..failFirstPut = false
        ..sessionState = 'CONFIRMED';
      await upload(finalDirect: fd);
      expect(fd.statuses, 2, reason: 'recovery must consult server status');
      expect(fd.registers, 1, reason: 'same session must not re-register');
      expect(
        fd.uploads,
        1,
        reason: 'status CONFIRMED must short-circuit re-upload',
      );
      expect(api.completes, 1);
      expect(
        api.completedFinalAudio!.clientUploadId,
        fd.clientUploadIds.toSet().single,
      );
    });
    test(
      'status non-confirmed states idempotently re-arm via same identity',
      () async {
        // 第一次：direct PUT 丢失 → 身份已落盘、服务端会话停在早期状态。
        final fd = FinalDirectFake()..failFirstPut = true;
        await expectLater(upload(finalDirect: fd), throwsStateError);
        fd.failFirstPut = false;
        fd.sessionState = 'GRANTED';
        // 重入：status GRANTED → 沿原身份幂等补齐（同 client_upload_id）。
        await upload(finalDirect: fd);
        expect(fd.statuses, 2);
        expect(fd.registers, 1, reason: 'same session must not re-register');
        expect(fd.clientUploadIds.toSet().length, 1);
        expect(fd.uploads, 2);
        expect(api.completes, 1);
        expect(
          api.completedFinalAudio!.clientUploadId,
          fd.clientUploadIds.toSet().single,
        );
      },
    );
  });
}
