/// Exact manifest contract: talk_record_assembly_logic:build_manifest/2.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:imboy/service/talk_record/talk_record_manifest.dart';

String canonicalTalkRecordJson(dynamic value) {
  if (value == null || value is bool || value is String || value is int) {
    return jsonEncode(value);
  }
  if (value is List) return '[${value.map(canonicalTalkRecordJson).join(',')}]';
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${canonicalTalkRecordJson(value[k])}').join(',')}}';
  }
  throw const FormatException('Non-canonical manifest value');
}

int talkRecordManifestId(String id) {
  if (!RegExp(r'^[1-9][0-9]*$').hasMatch(id)) {
    throw const FormatException('Invalid manifest entity ID');
  }
  return int.parse(id);
}

Map<String, dynamic> talkRecordCanonicalManifest(
  String captureId,
  List<TalkRecordSegmentEntry> segments,
  Map<String, dynamic> confirmed,
) {
  var offset = 0, bytes = 0;
  final parts = <Map<String, dynamic>>[];
  for (final segment in segments) {
    final part = Map<String, dynamic>.from(confirmed['${segment.seq}'] as Map);
    parts.add({
      'seq': segment.seq,
      'part_id': talkRecordManifestId(part['part_id'] as String),
      'attachment_id': talkRecordManifestId(part['attachment_id'] as String),
      'sha256': segment.plainSha256Hex,
      'byte_size': segment.plainSize,
      'offset_ms': offset,
      'duration_ms': segment.durationMs,
    });
    offset += segment.durationMs;
    bytes += segment.plainSize;
  }
  return {
    'v': 1,
    'capture_id': talkRecordManifestId(captureId),
    'parts': parts,
    'total_duration_ms': offset,
    'total_bytes': bytes,
  };
}

String talkRecordManifestHash(Map<String, dynamic> manifest) =>
    sha256.convert(utf8.encode(canonicalTalkRecordJson(manifest))).toString();
