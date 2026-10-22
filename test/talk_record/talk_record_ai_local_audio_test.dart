import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_local_audio.dart';
import 'package:imboy/modules/talk_record/application/talk_record_local_binding.dart';
import 'package:imboy/modules/talk_record/application/talk_record_recording_coordinator.dart';
import 'package:imboy/modules/talk_record/application/talk_record_upload_checkpoint.dart';
import 'package:imboy/modules/talk_record/application/talk_record_upload_manifest.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_entry_context.dart';
import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';

import 'fake_talk_record_engine.dart';

void main() {
  late Directory root, directory;
  late TalkRecordAiLocalAudio audio;
  late Map<String, dynamic> chunk;
  late TalkRecordUploadCheckpoint checkpoint;
  final bytes = Uint8List.fromList([0xff, 0xf1, 0x60, 0x40, 1, 0x1f, 0xfc, 0]);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('talk-ai-audio-');
    const account = TalkRecordAccount('https://synthetic.invalid', '2');
    const binding = TalkRecordLocalBinding(
      account: account,
      clientRecordingId: 'synthetic-recording',
      sessionId: 'synthetic-session',
      recordId: '1',
      captureId: '3',
      context: TalkRecordEntryContext.personal(),
      title: 'Synthetic',
      processingMode: 'transcribe',
      deviceSessionId: 'synthetic-device',
      completed: true,
    );
    final store = TalkRecordBindingStore(root);
    final keys = MemoryTalkRecordKeyStore();
    await store.save(binding);
    directory = Directory(
      '${store.audioDirectory(account).path}/${binding.sessionId}',
    );
    await directory.create(recursive: true);
    final source = File('${root.path}/synthetic.aac');
    await source.writeAsBytes(bytes);
    final key = TalkRecordSegmentCrypto.generateRecordKey();
    await keys.writeRecordKey(binding.sessionId, key);
    final cipher = File('${directory.path}/segment.enc');
    final info = await TalkRecordSegmentCrypto.sealSegment(
      plainFile: source,
      cipherFile: cipher,
      recordKey: key,
      sessionId: binding.sessionId,
      seq: 0,
      mime: 'audio/aac',
    );
    await source.delete();
    final manifest = TalkRecordManifest(
      sessionId: binding.sessionId,
      recordLocalId: binding.recordId,
      clientRecordingId: binding.clientRecordingId,
      status: TalkRecordSessionStatus.ended,
      reportedStartedAtIso: '2026-10-22T00:00:00Z',
      updatedAtIso: '2026-10-22T00:00:01Z',
      segments: [
        TalkRecordSegmentEntry.fromJson({
          'seq': 0,
          'start_ms': 0,
          'end_ms': 64,
          'cipher_file': 'segment.enc',
          'cipher_size': info.cipherSize,
          'cipher_sha256': info.cipherSha256Hex,
          'plain_size': bytes.length,
          'plain_sha256': info.plainSha256Hex,
        }),
      ],
    );
    await TalkRecordManifestStore(directory).write(manifest);
    checkpoint = TalkRecordUploadCheckpoint(
      identity: TalkRecordUploadCheckpointStore.identity(binding),
      sourceHash: talkRecordManifestHash(manifest.toJson()),
      parts: {
        '0': {'part_id': 10, 'confirmed': true},
      },
    );
    await TalkRecordUploadCheckpointStore(directory).save(checkpoint);
    final recordings = TalkRecordRecordingCoordinator(
      store: store,
      keys: keys,
      currentAccount: () => account,
      recorderFactory: (_) => throw StateError('Must not start recording'),
    );
    audio = TalkRecordAiLocalAudio(recordings, '1', () {});
    chunk = {
      'seq': 0,
      'byte_size': bytes.length,
      'duration_ms': 64,
      'offset_ms': 0,
      'source_ranges': [
        {'part_id': 10, 'sha256': info.plainSha256Hex},
      ],
    };
  });
  tearDown(() async => root.delete(recursive: true));

  test('local recording upload receipt maps to verified memory audio without file writes', () async {
    final before = directory.listSync().map((file) => file.path).toSet();
    final result = await audio.read(chunk);
    expect(await result.openRead().expand((part) => part).toList(), bytes);
    expect(result.durationMs, 64);
    expect(directory.listSync().map((file) => file.path).toSet(), before);
  });

  test('unconfirmed upload part is rejected without plaintext file', () async {
    checkpoint.parts['0']['confirmed'] = false;
    await TalkRecordUploadCheckpointStore(directory).save(checkpoint);
    final before = directory.listSync().map((file) => file.path).toSet();
    await expectLater(audio.read(chunk), throwsStateError);
    expect(directory.listSync().map((file) => file.path).toSet(), before);
  });

  test(
    'accepted progress timeline survives independent ADTS sample timing',
    () async {
      final store = TalkRecordManifestStore(directory);
      final original = (await store.read())!;
      final json = original.toJson();
      (json['segments'] as List).single['end_ms'] = 100;
      final recorded = TalkRecordManifest.fromJson(json);
      await store.write(recorded);
      await TalkRecordUploadCheckpointStore(directory).save(
        TalkRecordUploadCheckpoint(
          identity: checkpoint.identity,
          sourceHash: talkRecordManifestHash(recorded.toJson()),
          parts: checkpoint.parts,
        ),
      );
      chunk['duration_ms'] = 100;
      final before = directory.listSync().map((file) => file.path).toSet();
      final result = await audio.read(chunk);
      expect(result.durationMs, 100);
      expect(result.mediaDurationMs, 64);
      expect(await result.openRead().expand((part) => part).toList(), bytes);
      expect(directory.listSync().map((file) => file.path).toSet(), before);
      expect((await store.read())!.segments.single.durationMs, 100);
    },
  );

  test('changed upload source is rejected before decryption', () async {
    await TalkRecordUploadCheckpointStore(directory).save(
      TalkRecordUploadCheckpoint(
        identity: checkpoint.identity,
        sourceHash: 'foreign-source',
        parts: checkpoint.parts,
      ),
    );
    await expectLater(audio.read(chunk), throwsStateError);
  });
}
