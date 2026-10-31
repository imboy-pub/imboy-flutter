import 'package:flutter/foundation.dart' show kIsWeb;

String? channelDecimalId(
  Object? raw, {
  bool allowNegative = false,
  bool allowZero = false,
}) {
  if (raw == null) return null;
  if (raw is! String && raw is! int) return null;
  final value = BigInt.tryParse(raw.toString());
  if (value == null ||
      (!allowZero && value == BigInt.zero) ||
      (!allowNegative && value < BigInt.zero) ||
      value < BigInt.parse('-9223372036854775808') ||
      value > BigInt.parse('9223372036854775807')) {
    return null;
  }
  if (kIsWeb && raw is int && value.abs() > BigInt.parse('9007199254740991')) {
    return null;
  }
  return value.toString();
}

/// Validate all supported resource ID aliases at group list API boundaries.
void validateGroupResourceId(Map<String, dynamic> json) {
  String? canonicalId;
  for (final key in const ['group_id', 'id', 'gid']) {
    final id = json[key];
    if (id == null) continue;
    final normalized = channelDecimalId(id);
    if ((id is! String && id is! int) ||
        !RegExp(r'^[0-9]+$').hasMatch('$id') ||
        normalized == null) {
      throw FormatException('invalid group id field: $key');
    }
    if (canonicalId != null && canonicalId != normalized) {
      throw const FormatException('conflicting group id fields');
    }
    canonicalId = normalized;
  }
  if (canonicalId == null) {
    throw const FormatException('missing group id field');
  }
}

Object decimalIdForWire(String id) {
  final value = BigInt.parse(id);
  if (kIsWeb && value.abs() > BigInt.parse('9007199254740991')) return id;
  return int.parse(id);
}
