import 'dart:io';
import 'dart:typed_data';

import 'package:imboy/service/talk_record/talk_record_manifest.dart';
import 'package:imboy/service/talk_record/talk_record_segment_crypto.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

import '../talk_record_recording_coordinator.dart';
import '../talk_record_upload_checkpoint.dart';
import '../talk_record_upload_manifest.dart';
import 'talk_record_minimax_result.dart';

class TalkRecordAiLocalAudio {
  TalkRecordAiLocalAudio(this.recordings, this.recordId, this.guard);
  final TalkRecordRecordingCoordinator recordings;
  final EntityId recordId;
  final void Function() guard;

  Future<TalkRecordAiAudioChunk> read(Map<String, dynamic> chunk) async {
    guard();
    final account = recordings.currentAccount();
    final bindings = (await recordings.store.list(account))
        .where((item) => item.recordId == recordId && item.completed)
        .toList();
    guard();
    if (bindings.length != 1) throw StateError('Local recording unavailable');
    final binding = bindings.single;
    final directory = Directory(
      '${recordings.store.audioDirectory(account).path}/${binding.sessionId}',
    );
    final manifest = await TalkRecordManifestStore(directory).read();
    if (manifest == null) throw StateError('Local manifest unavailable');
    final upload = await TalkRecordUploadCheckpointStore(directory)
        .load(binding, talkRecordManifestHash(manifest.toJson()));
    final range = (chunk['source_ranges'] as List).single as Map;
    final entries = upload.parts.entries
        .where(
          (entry) =>
              '${(entry.value as Map)['part_id']}' == '${range['part_id']}',
        )
        .toList();
    if (entries.length != 1 ||
        (entries.single.value as Map)['confirmed'] != true) {
      throw StateError('Local part unavailable');
    }
    final segment = manifest.segments.singleWhere(
      (segment) => '${segment.seq}' == entries.single.key,
    );
    if (segment.plainSha256Hex != range['sha256'] ||
        segment.plainSize != chunk['byte_size'] ||
        segment.durationMs != chunk['duration_ms'] ||
        segment.startMs != chunk['offset_ms']) {
      throw StateError('Local part changed');
    }
    guard();
    final stored = await recordings.keys.readRecordKey(binding.sessionId);
    if (stored == null) throw StateError('Local key unavailable');
    final key = Uint8List.fromList(stored);
    try {
      guard();
      final bytes = await TalkRecordSegmentCrypto.openSegmentBytes(
        cipherFile: File('${directory.path}/${segment.cipherFileName}'),
        recordKey: key,
        sessionId: binding.sessionId,
        seq: segment.seq,
        info: TalkRecordSegmentCipherInfo(
          plainSize: segment.plainSize,
          plainSha256Hex: segment.plainSha256Hex,
          cipherSize: segment.cipherSize,
          cipherSha256Hex: segment.cipherSha256Hex,
        ),
        mime: 'audio/aac',
      );
      try {
        guard();
        return TalkRecordAiAudioChunk.fromAdts(
          bytes,
          expectedSha256: range['sha256'] as String,
          expectedByteLength: chunk['byte_size'] as int,
          expectedDurationMs: chunk['duration_ms'] as int,
          chunkId: 'c${chunk['seq']}',
          offsetMs: chunk['offset_ms'] as int,
        );
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }
}
