import 'dart:convert';

/// Safe diagnostics only; provider text/payloads never escape through errors.
enum TalkRecordDoubaoResultError {
  providerNotSuccessful,
  invalidDuration,
  invalidResult,
  invalidUtterance,
  missingSpeaker,
  invalidSpeaker,
  tooManySpeakers,
}

class TalkRecordDoubaoFormatException implements Exception {
  const TalkRecordDoubaoFormatException(this.reason);
  final TalkRecordDoubaoResultError reason;
  @override
  String toString() => 'TalkRecordDoubaoFormatException(${reason.name})';
}

/// Parses the HTTP query BODY after its header status has been checked. HTTP
/// 200 alone is insufficient: X-Api-Status-Code must equal 20000000. The resource
/// identifies the public provider model, not a claimed internal weights version.
/// Labels/timestamps stay chunk-local; only BE adds its bound sequence/offset.
Map<String, Object?> parseTalkRecordDoubaoResult(
  Map<String, Object?> body, {
  required int durationMs,
  required String providerStatusCode,
}) {
  if (providerStatusCode != '20000000') {
    _reject(TalkRecordDoubaoResultError.providerNotSuccessful);
  }
  // Submission docs allow five hours; conservatively stay below that boundary.
  if (durationMs <= 0 || durationMs >= 18000000) {
    _reject(TalkRecordDoubaoResultError.invalidDuration);
  }
  final info = body['audio_info'], result = body['result'];
  if (info is! Map ||
      info['duration'] is! int ||
      info['duration'] != durationMs ||
      result is! Map) {
    _reject(TalkRecordDoubaoResultError.invalidResult);
  }
  final text = result['text'], utterances = result['utterances'];
  if (!_text(text, 1000000, empty: true) ||
      utterances is! List ||
      utterances.length > 20000) {
    _reject(TalkRecordDoubaoResultError.invalidResult);
  }
  return _normalize(utterances, text as String, durationMs);
}

Map<String, Object?> _normalize(List<Object?> utterances, String text, int ms) {
  final labels = <String>{}, segments = <Map<String, Object?>>[];
  var previous = 0;
  for (final raw in utterances) {
    final segment = _segment(raw, ms, previous);
    previous = segment['start_ms']! as int;
    labels.add(segment['speaker_label']! as String);
    if (labels.length > 200) {
      _reject(TalkRecordDoubaoResultError.tooManySpeakers);
    }
    segments.add(segment);
  }
  if (segments.isEmpty != text.trim().isEmpty) {
    _reject(TalkRecordDoubaoResultError.invalidResult);
  }
  return Map<String, Object?>.unmodifiable({
    'model_version': 'volc.seedasr.auc',
    'status': segments.isEmpty ? 'no_speech' : 'ready',
    'speakers': List<Map<String, Object?>>.unmodifiable(
      labels.map(
        (label) => Map<String, Object?>.unmodifiable({'label': label}),
      ),
    ),
    'segments': List<Map<String, Object?>>.unmodifiable(segments),
  });
}

Map<String, Object?> _segment(Object? raw, int duration, int previous) {
  if (raw is! Map) _reject(TalkRecordDoubaoResultError.invalidUtterance);
  final start = raw['start_time'], end = raw['end_time'], text = raw['text'];
  if (start is! int ||
      end is! int ||
      start < 0 ||
      start < previous ||
      end <= start ||
      end > duration ||
      !_text(text, 20000)) {
    _reject(TalkRecordDoubaoResultError.invalidUtterance);
  }
  final additions = raw['additions'];
  if (additions is! Map || additions['speaker'] == null) {
    _reject(TalkRecordDoubaoResultError.missingSpeaker);
  }
  final speaker = additions['speaker'];
  if (speaker is! String ||
      !RegExp(r'^[A-Za-z0-9_-]{1,48}$').hasMatch(speaker)) {
    _reject(TalkRecordDoubaoResultError.invalidSpeaker);
  }
  return Map<String, Object?>.unmodifiable({
    'start_ms': start,
    'end_ms': end,
    'speaker_label': speaker,
    'text': text,
  });
}

bool _text(Object? value, int limit, {bool empty = false}) =>
    value is String &&
    value.length <= limit &&
    (empty || value.trim().isNotEmpty) &&
    utf8.encode(value).length <= limit &&
    utf8.decode(utf8.encode(value)) == value;

Never _reject(TalkRecordDoubaoResultError reason) =>
    throw TalkRecordDoubaoFormatException(reason);
