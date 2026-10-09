import 'dart:convert';

import 'generated_product_features.dart';

/// Configuration belongs to one server, account and compiled capability set.
class FeatureScope {
  static String? _key;
  static int _epoch = 0;

  static String? get key => _key;
  static int get epoch => _epoch;

  static bool bind({required String endpoint, required String uid}) {
    final uri = Uri.parse(endpoint.trim()).normalizePath();
    final normalized = uri
        .replace(fragment: '')
        .toString()
        .replaceFirst(RegExp(r'/+$'), '');
    final next = base64Url.encode(
      utf8.encode(jsonEncode([normalized, uid, productFeatureManifestHash])),
    );
    if (_key == next) return false;
    _key = next;
    _epoch++;
    return true;
  }

  static void invalidate() => _epoch++;

  static bool matches(String? key, int epoch) =>
      key != null && key == _key && epoch == _epoch;

  static String cacheKey(String prefix, [String? scope]) =>
      '${prefix}_scoped_${scope ?? _key}';
}
