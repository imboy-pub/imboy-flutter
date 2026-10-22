import 'dart:convert';

import 'package:crypto/crypto.dart';

String talkRecordAiCanonical(Object? value) {
  if (value is Map<String, dynamic>) {
    final keys = value.keys.toList()..sort(_compareKeys);
    return '{${keys.map((key) => '${_beString(key)}:${talkRecordAiCanonical(value[key])}').join(',')}}';
  }
  if (value is List) return '[${value.map(talkRecordAiCanonical).join(',')}]';
  if (value is String) return _beString(value);
  if (value == null || value is bool || value is int) {
    return jsonEncode(value);
  }
  throw const FormatException('Non canonical AI value');
}

int _compareKeys(String left, String right) {
  final first = utf8.encode(left), second = utf8.encode(right);
  for (var index = 0; index < first.length && index < second.length; index++) {
    if (first[index] != second[index]) {
      return first[index].compareTo(second[index]);
    }
  }
  return first.length.compareTo(second.length);
}

String _beString(String value) {
  final units = value.codeUnits;
  for (var index = 0; index < units.length; index++) {
    final unit = units[index];
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++index == units.length ||
          units[index] < 0xdc00 ||
          units[index] > 0xdfff) {
        throw const FormatException('Invalid canonical Unicode');
      }
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const FormatException('Invalid canonical Unicode');
    }
  }
  return jsonEncode(value).replaceAllMapped(RegExp(r'[/\u0080-\uffff]'), (
    match,
  ) {
    final unit = match[0]!.codeUnitAt(0);
    return unit == 47 ? r'\/' : '\\u${unit.toRadixString(16).padLeft(4, '0')}';
  });
}

String talkRecordAiHash(Object? value) =>
    sha256.convert(utf8.encode(talkRecordAiCanonical(value))).toString();

Map<String, dynamic> talkRecordAiPlan(
  String mode,
  Map<String, dynamic> snapshot,
) {
  if (mode == 'summarize') {
    final segments = snapshot['segments'] as List;
    if (segments.isEmpty || segments.length > 20000) {
      throw const FormatException('AI segments');
    }
    return {
      'overlap_rule': 'none',
      'chunks': [
        {
          'seq': 0,
          'source_segment_ids': segments
              .map((segment) => segment['id'])
              .toList(),
          'source_hash': talkRecordAiHash(segments),
        },
      ],
    };
  }
  final parts = snapshot['parts'] as List;
  if (mode != 'transcribe' || parts.isEmpty || parts.length > 10000) {
    throw const FormatException('AI parts');
  }
  var offset = 0;
  final chunks = <Map<String, dynamic>>[];
  for (final raw in parts) {
    final part = Map<String, dynamic>.from(raw as Map);
    final duration = part['duration_ms'] as int;
    final bytes = part['byte_size'] as int;
    if (duration <= 0 ||
        duration > 500000 ||
        bytes <= 0 ||
        bytes > 50000000 ||
        part['offset_ms'] != offset) {
      throw const FormatException('AI chunk boundary');
    }
    chunks.add({
      'seq': chunks.length,
      'source_part_manifest_hash': talkRecordAiHash(part),
      'source_ranges': [
        {
          'part_id': part['part_id'],
          'sha256': part['sha256'],
          'start_ms': 0,
          'end_ms': duration,
        },
      ],
      'offset_ms': offset,
      'duration_ms': duration,
      'byte_size': bytes,
    });
    offset += duration;
  }
  return {'overlap_rule': 'none', 'chunks': chunks};
}

Map<String, dynamic> talkRecordAiSummary(
  Map<String, Object?> result,
  List<dynamic> segments,
) {
  if (result.keys.any(
        (key) => !{
          'model_version',
          'overview',
          'decisions',
          'actions',
        }.contains(key),
      ) ||
      result['model_version'] != 'glm-5.3-flash' ||
      !_text(result['overview'], 20000)) {
    throw const FormatException('AI summary schema');
  }
  final ids = segments.map((segment) => segment['id']).toSet();
  for (final field in ['decisions', 'actions']) {
    final items = result[field];
    if (items is! List || items.length > 200) {
      throw const FormatException('AI summary items');
    }
    for (final item in items) {
      if (item is! Map ||
          item.keys.any(
            (key) => !{
              'text',
              'segment_ids',
              'owner_user_id',
              'due_date',
            }.contains(key),
          ) ||
          !_text(item['text'], 4000) ||
          item['owner_user_id'] != null ||
          item['due_date'] != null) {
        throw const FormatException('AI summary item');
      }
      final refs = item['segment_ids'];
      if (refs is! List ||
          refs.isEmpty ||
          refs.length > 100 ||
          refs.any((id) => !ids.contains(id))) {
        throw const FormatException('AI summary references');
      }
    }
  }
  final wire = Map<String, dynamic>.from(result);
  if (utf8.encode(jsonEncode(wire)).length > 1048576) {
    throw const FormatException('AI result size');
  }
  return wire;
}

bool _text(Object? value, int limit) =>
    value is String && value.isNotEmpty && utf8.encode(value).length <= limit;
