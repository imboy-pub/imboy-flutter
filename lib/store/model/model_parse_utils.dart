import 'dart:convert';

/// Parse helpers for model deserialization.
///
/// These helpers intentionally accept loose backend payload types
/// (bool/int/num/string) to avoid runtime cast exceptions.
String parseModelString(dynamic value, {String defaultValue = ''}) {
  if (value == null) return defaultValue;
  final str = value.toString();
  final normalized = str.trim().toLowerCase();
  if (normalized.isEmpty) return defaultValue;
  return str;
}

String? parseModelNullableString(dynamic value) {
  if (value == null) return null;
  final str = value.toString();
  final normalized = str.trim().toLowerCase();
  return normalized.isEmpty ? null : str;
}

int parseModelInt(dynamic value, {int defaultValue = 0}) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is bool) return value ? 1 : 0;
  if (value is String) {
    if (value.isEmpty) return defaultValue;
    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;
    final numValue = num.tryParse(value);
    if (numValue != null) return numValue.toInt();
    final lower = value.toLowerCase();
    if (lower == 'true') return 1;
    if (lower == 'false') return 0;
  }
  return defaultValue;
}

double parseModelDouble(dynamic value, {double defaultValue = 0.0}) {
  if (value == null) return defaultValue;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is bool) return value ? 1.0 : 0.0;
  if (value is String) {
    if (value.isEmpty) return defaultValue;
    final doubleValue = double.tryParse(value);
    if (doubleValue != null) return doubleValue;
    final intValue = int.tryParse(value);
    if (intValue != null) return intValue.toDouble();
    final lower = value.toLowerCase();
    if (lower == 'true') return 1.0;
    if (lower == 'false') return 0.0;
  }
  return defaultValue;
}

bool parseModelBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'on') {
      return true;
    }
    if (normalized == '0' ||
        normalized == 'false' ||
        normalized == 'no' ||
        normalized == 'off') {
      return false;
    }
  }
  return defaultValue;
}

DateTime parseModelDateTime(dynamic value, {DateTime? defaultValue}) {
  final fallback = defaultValue ?? DateTime.now();

  if (value is int || value is num) {
    final ts = (value as num).toInt();
    final ms = ts.abs() < 1000000000000 ? ts * 1000 : ts;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  if (value is String) {
    if (value.isEmpty) return fallback;
    final intValue = int.tryParse(value);
    if (intValue != null) {
      final ms = intValue.abs() < 1000000000000 ? intValue * 1000 : intValue;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    try {
      return DateTime.parse(value);
    } catch (_) {
      return fallback;
    }
  }

  return fallback;
}

DateTime? parseModelNullableDateTime(dynamic value) {
  if (value == null) return null;

  if (value is int || value is num) {
    final ts = (value as num).toInt();
    final ms = ts.abs() < 1000000000000 ? ts * 1000 : ts;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  if (value is String) {
    if (value.isEmpty) return null;
    final intValue = int.tryParse(value);
    if (intValue != null) {
      final ms = intValue.abs() < 1000000000000 ? intValue * 1000 : intValue;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return DateTime.tryParse(value);
  }

  return null;
}

List<String>? parseModelStringList(dynamic value) {
  if (value == null) return null;
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

Map<String, dynamic>? parseModelJsonMap(dynamic value) {
  if (value == null) return null;
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is String) {
    if (value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}
