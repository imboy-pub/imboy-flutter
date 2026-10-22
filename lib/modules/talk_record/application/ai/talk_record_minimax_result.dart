import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:imboy/service/talk_record/talk_record_recorder_config.dart';

class TalkRecordMinimaxFormatException implements Exception {
  const TalkRecordMinimaxFormatException();
  @override
  String toString() => 'TalkRecordMinimaxFormatException(invalid_format)';
}

/// An owned immutable snapshot, never a pathname that can change after hashing.
/// V1 accepts the recorder's independent AAC-LC ADTS chunks only. ADTS framing
/// and sample counts are checked here; actual decoder/model quality is a separate
/// device gate, not proven by this structural parser.
class TalkRecordAiAudioChunk {
  TalkRecordAiAudioChunk._(
    this._bytes,
    this.sha256Hex,
    this.durationMs,
    this.mediaDurationMs,
    this.chunkId,
    this.offsetMs,
  );

  factory TalkRecordAiAudioChunk.fromAdts(
    Uint8List input, {
    required String expectedSha256,
    required int expectedByteLength,
    required int expectedDurationMs,
    required String chunkId,
    required int offsetMs,
  }) {
    if (input.isEmpty ||
        input.length > maxBytes ||
        input.length != expectedByteLength ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedSha256) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,20}$').hasMatch(chunkId) ||
        expectedDurationMs <= 0 ||
        expectedDurationMs > maxDurationMs ||
        offsetMs < 0 ||
        offsetMs > 9007199254240991) {
      throw const TalkRecordMinimaxFormatException();
    }
    // One bounded copy; multipart later streams this same read-only snapshot.
    final snapshot = Uint8List.fromList(input).asUnmodifiableView();
    final digest = sha256.convert(snapshot).toString();
    final timing = _adtsTiming(snapshot);
    if (digest != expectedSha256 ||
        (timing.durationMs - expectedDurationMs).abs() >
            TalkRecordRecorderConfig.progressIntervalMs +
                timing.frameDurationMs) {
      throw const TalkRecordMinimaxFormatException();
    }
    return TalkRecordAiAudioChunk._(
      snapshot,
      digest,
      expectedDurationMs,
      timing.durationMs,
      chunkId,
      offsetMs,
    );
  }

  static const maxBytes = 50000000;
  static const maxDurationMs = 500000;
  final Uint8List _bytes;
  final String sha256Hex;
  final int durationMs;
  final int mediaDurationMs;
  final String chunkId;
  final int offsetMs;
  int get byteLength => _bytes.length;
  Stream<List<int>> openRead() => Stream.value(_bytes);

  @override
  String toString() => 'TalkRecordAiAudioChunk(redacted)';
}

const _adtsRates = [
  96000,
  88200,
  64000,
  48000,
  44100,
  32000,
  24000,
  22050,
  16000,
  12000,
  11025,
  8000,
  7350,
];

({int durationMs, int frameDurationMs}) _adtsTiming(Uint8List bytes) {
  var offset = 0, frames = 0;
  int? frequency, channels;
  while (offset < bytes.length) {
    if (bytes.length - offset < 7 ||
        bytes[offset] != 0xff ||
        (bytes[offset + 1] & 0xf6) != 0xf0) {
      throw const TalkRecordMinimaxFormatException();
    }
    final index = (bytes[offset + 2] >> 2) & 15;
    final channel = ((bytes[offset + 2] & 1) << 2) | (bytes[offset + 3] >> 6);
    final length =
        ((bytes[offset + 3] & 3) << 11) |
        (bytes[offset + 4] << 3) |
        (bytes[offset + 5] >> 5);
    final header = (bytes[offset + 1] & 1) == 1 ? 7 : 9;
    if (index >= _adtsRates.length ||
        ((bytes[offset + 2] >> 6) & 3) != 1 ||
        channel < 1 ||
        channel > 2 ||
        length <= header ||
        offset + length > bytes.length ||
        (bytes[offset + 6] & 3) != 0 ||
        (frequency != null && frequency != _adtsRates[index]) ||
        (channels != null && channels != channel)) {
      throw const TalkRecordMinimaxFormatException();
    }
    frequency = _adtsRates[index];
    channels = channel;
    frames++;
    if (frames * 1024000 > 500001 * frequency) {
      throw const TalkRecordMinimaxFormatException();
    }
    offset += length;
  }
  final durationMs = (frames * 1024000 / frequency!).round();
  if (durationMs <= 0 || durationMs > TalkRecordAiAudioChunk.maxDurationMs) {
    throw const TalkRecordMinimaxFormatException();
  }
  return (
    durationMs: durationMs,
    frameDurationMs: (1024000 / frequency).ceil(),
  );
}

/// Exact existing processor-result keys; no invented confidence or identities.
/// Timestamps are local to this chunk. The coordinator applies its frozen offset
/// exactly once when combining parts. Labels remain provider-local on the wire;
/// the backend alone adds its bound sequence scope, never merging equal S1s.
Map<String, Object?> parseTalkRecordMinimaxResult(
  Map<String, Object?> response,
  TalkRecordAiAudioChunk chunk,
) {
  final segments = response['segments'];
  final speakers = response['n_speakers'];
  final text = response['text'];
  final duration = _milliseconds(response['duration']);
  if (segments is! List ||
      segments.length > 20000 ||
      speakers is! int ||
      speakers < 0 ||
      speakers > 200 ||
      !_text(text, 1000000, empty: true) ||
      duration != chunk.mediaDurationMs) {
    throw const TalkRecordMinimaxFormatException();
  }
  final labels = <String>{};
  final normalized = <Map<String, Object?>>[];
  var previous = 0;
  for (final raw in segments) {
    final segment = _segment(raw, chunk, previous);
    previous = segment['start_ms']! as int;
    labels.add(segment['speaker_label']! as String);
    normalized.add(segment);
  }
  if (labels.length != speakers ||
      (normalized.isEmpty && (text as String).trim().isNotEmpty) ||
      (normalized.isNotEmpty && (text as String).trim().isEmpty)) {
    throw const TalkRecordMinimaxFormatException();
  }
  return Map.unmodifiable({
    'model_version': 'asr-1.0',
    'status': normalized.isEmpty ? 'no_speech' : 'ready',
    'speakers': List<Map<String, Object?>>.unmodifiable(
      labels.map(
        (label) => Map<String, Object?>.unmodifiable({'label': label}),
      ),
    ),
    'segments': List<Map<String, Object?>>.unmodifiable(normalized),
  });
}

Map<String, Object?> _segment(
  Object? value,
  TalkRecordAiAudioChunk chunk,
  int previous,
) {
  if (value is! Map) throw const TalkRecordMinimaxFormatException();
  final mediaStart = _milliseconds(value['start']),
      mediaEnd = _milliseconds(value['end']);
  final start = (mediaStart * chunk.durationMs / chunk.mediaDurationMs).round(),
      end = (mediaEnd * chunk.durationMs / chunk.mediaDurationMs).round();
  final speaker = value['speaker'], text = value['text'];
  if (start < previous ||
      end <= start ||
      mediaEnd > chunk.mediaDurationMs ||
      speaker is! String ||
      !RegExp(r'^[A-Za-z0-9_-]{1,20}$').hasMatch(speaker) ||
      !_text(text, 20000)) {
    throw const TalkRecordMinimaxFormatException();
  }
  return Map.unmodifiable({
    'start_ms': start,
    'end_ms': end,
    'speaker_label': speaker,
    'text': text,
  });
}

int _milliseconds(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 500) {
    throw const TalkRecordMinimaxFormatException();
  }
  return (value * 1000).round();
}

bool _text(Object? value, int maxBytes, {bool empty = false}) =>
    value is String &&
    (empty || value.trim().isNotEmpty) &&
    utf8.encode(value).length <= maxBytes &&
    utf8.decode(utf8.encode(value)) == value;
