import 'dart:io';

import 'package:imboy/modules/talk_record/application/talk_record_processing_consent.dart';
import 'package:imboy/store/model/talk_record/talk_record_capabilities_model.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/talk_record_attachment_upload_gateway.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/application/talk_record_part_transport.dart';
import 'package:imboy/modules/talk_record/application/talk_record_upload_manifest.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/talk_record/talk_record_capture_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_enums.dart';
import 'package:imboy/store/model/talk_record/talk_record_mark_model.dart';
import 'package:imboy/store/model/talk_record/talk_record_model.dart';
import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_service.dart';

import 'fake_talk_record_engine.dart';

class UploadApi extends TalkRecordApi {
  String status = 'draft';
  String ownerId = '100', media = 'uploading';
  bool suppressProjection = false;
  int confirmedCount = 0;
  int lastSeq = -1, epoch = 0, verifyCount = 0, confirms = 0, completes = 0;
  bool revoked = false, loseEndResponse = false, loseCompleteResponse = false;
  bool missingSequence = false, expired = false, pendingTicket = false;
  TalkRecordAudioPartInput? part;
  final registrationKeys = <String>[],
      completeKeys = <String>[],
      markIds = <String>[];
  final eventIds = <String>[];
  String completedHash = '';
  bool missingCompletionHash = false, rejectCompletion = false;
  TalkRecordCapabilitiesModel cap = const TalkRecordCapabilitiesModel(
    recordingEnabled: true,
    processingAvailable: true,
    asrEnabled: true,
    summaryEnabled: true,
    policyVersion: 'v2',
    processorConfigVersion: 'pcv2',
  );
  @override
  Future<TalkRecordCapabilitiesModel> capabilities() async => cap;
  String? completedProcessorConfigVersion;
  TalkRecordCaptureModel get capture => TalkRecordCaptureModel.fromJson({
    'completion_manifest_hash': missingCompletionHash ? null : completedHash,
    'capture_id': 2,
    'record_id': 1,
    'device_session_id': 'device-session',
    'status': status,
    'parts': {
      'confirmed': confirmedCount,
      'pending': part != null && confirmedCount == 0 ? 1 : 0,
      'last_seq': part?.seq ?? -1,
      'effective_ms': confirmedCount > 0 ? (part!.endMs - part!.startMs) : 0,
    },
    'lease_epoch': epoch,
    if (!missingSequence) 'last_event_seq': lastSeq,
    'lease_until': DateTime.now()
        .add(Duration(minutes: expired ? -1 : 5))
        .toIso8601String(),
  });
  @override
  Future<List<TalkRecordCaptureModel>> captures(String id) async {
    if (revoked) throw StateError('revoked');
    return [capture];
  }

  @override
  Future<TalkRecordCaptureModel> postCaptureEvent(
    String id,
    String captureId,
    TalkRecordCaptureEventInput input,
  ) async {
    eventIds.add(input.clientEventId);
    lastSeq = input.seq;
    status = input.event == TalkRecordCaptureEventKind.end
        ? 'ended'
        : 'recording';
    if (loseEndResponse && status == 'ended') {
      loseEndResponse = false;
      throw StateError('lost response');
    }
    return capture;
  }

  @override
  Future<TalkRecordAudioUploadSession> createAudioPart(
    String id,
    String captureId,
    TalkRecordAudioPartInput input, {
    required String idempotencyKey,
  }) async {
    if (revoked) throw StateError('revoked');
    expect(
      input.codec,
      'aac',
      reason: 'Actual AAC-ADTS uses backend aac wire codec',
    );
    if (input.codec != 'aac') throw StateError('unsupported codec');
    part = input;
    registrationKeys.add(idempotencyKey);
    return TalkRecordAudioUploadSession.fromJson({
      'part_id': 3,
      'attachment_id': null,
      'upload_ref': {
        'gateway': true,
        'integration_pending': pendingTicket,
        'put_url': '/api/v1/attachment/gateway/client-part?capability=cap',
        'object_key': 'owner/record/audio.aac',
        'client_upload_id': 'client-part',
        'upload_capability': 'cap',
        'expires_at':
            DateTime.now()
                .add(const Duration(minutes: 5))
                .millisecondsSinceEpoch ~/
            1000,
      },
    });
  }

  @override
  Future<TalkRecordAudioPartConfirmResult> confirmAudioPart(
    String id,
    String captureId,
    String partId,
  ) async {
    if (revoked) throw StateError('revoked');
    confirms++;
    if (verifyCount-- > 0) {
      return const TalkRecordAudioPartConfirmResult(status: 'verifying');
    }
    confirmedCount = 1;
    return TalkRecordAudioPartConfirmResult.fromJson({
      'status': 'confirmed',
      'part_id': 3,
      'capture_id': 2,
      'seq': part!.seq,
      'attachment_id': 4,
      'sha256': part!.sha256,
      'byte_size': part!.byteSize,
    });
  }

  @override
  Future<TalkRecordMarkModel> createMark(
    String id, {
    required String clientMarkId,
    required int positionMs,
    String text = '',
    String captureId = '',
    int captureOffsetMs = 0,
  }) async {
    if (status != 'ended') throw StateError('capture duration not final');
    markIds.add(clientMarkId);
    return TalkRecordMarkModel(id: '5', clientMarkId: clientMarkId);
  }

  @override
  Future<TalkRecordFetched<TalkRecordModel>> detail(String id) async {
    if (revoked) throw StateError('revoked');
    return TalkRecordFetched(
      TalkRecordModel(
        id: '1',
        ownerUserId: ownerId,
        clientRecordingId: 'record-client',
        scope: TalkRecordScope.personal,
        captureStatus: TalkRecordCaptureStatus.parse(status),
        mediaStatus: TalkRecordMediaStatus.parse(media),
        durationMs: status == 'ended' ? (part?.endMs ?? 1000) : 0,
      ),
      etag: '"record-4"',
    );
  }

  String? completedPolicyVersion;
  @override
  Future<TalkRecordCompleteResult> complete(
    String id, {
    required List<TalkRecordCompleteCaptureInput> captures,
    required String policyVersion,
    String? processorConfigVersion,
    required String idempotencyKey,
    required String ifMatch,
  }) async {
    if (rejectCompletion) throw StateError('policy changed');
    completedPolicyVersion = policyVersion;
    completedProcessorConfigVersion = processorConfigVersion;
    completes++;
    completeKeys.add(idempotencyKey);
    completedHash = captures.single.manifestHash;
    if (!suppressProjection) media = 'assembling';
    if (loseCompleteResponse) {
      loseCompleteResponse = false;
      throw StateError('lost response');
    }
    return const TalkRecordCompleteResult(
      mediaStatus: 'assembling',
      jobId: '6',
    );
  }
}

class UploadTransport implements TalkRecordPartTransport {
  int puts = 0;
  bool fail = false;
  String plaintextHash = '';
  @override
  Future<void> put(
    TalkRecordUploadRef ticket,
    File plaintext,
    void Function() guard,
  ) async {
    guard();
    puts++;
    plaintextHash = (await sha256.bind(plaintext.openRead()).first).toString();
    if (fail) {
      fail = false;
      throw StateError('PUT response lost');
    }
  }
}

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
  Future<void> upload({int attempts = 6, TalkRecordManifest? source}) =>
      TalkRecordAttachmentUploadGateway(
        api: api,
        transport: transport,
        confirmAttempts: attempts,
        delay: (_) async {},
      ).upload(
        binding: binding,
        manifest: source ?? manifest,
        directory: recorder.sessionDir!,
        keys: keys,
        checkAccount: () {
          if (!accountValid) throw StateError('account changed');
        },
      );
  void expectNoPlaintext() => expect(
    Directory('${recorder.sessionDir!.path}/.upload_plain').existsSync(),
    false,
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
          'duration_ms': 1000,
        },
      ],
      'total_duration_ms': 1000,
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
}
