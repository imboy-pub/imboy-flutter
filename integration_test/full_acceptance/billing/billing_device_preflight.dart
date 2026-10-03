/// Structural prerequisites only; never grants resource authorization.
/// The coordinator must independently verify the referenced approval/lease.
library;

List<String> validateBillingDeviceInputs(Map<String, String> inputs) {
  final errors = <String>[];
  for (final name in ['device_id', 'lease_id', 'fixture_id']) {
    if ((inputs[name] ?? '').trim().isEmpty) {
      errors.add('MISSING_$name');
    }
  }
  if (!['android', 'macos'].contains(inputs['platform'])) {
    errors.add('PLATFORM_INVALID');
  }
  final uid = inputs['expected_uid'] ?? '';
  if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(uid) ||
      BigInt.tryParse(uid) == null ||
      BigInt.parse(uid) > BigInt.parse('9223372036854775807')) {
    errors.add('EXPECTED_UID_INVALID');
  }
  for (final name in [
    'authorization_sha256',
    'runtime_sha256',
    'fixture_sha256',
  ]) {
    final value = inputs[name] ?? '';
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value) || value == '0' * 64) {
      errors.add('INVALID_$name');
    }
  }
  for (final repo in ['imboy', 'imboyapp', 'imboyadmin']) {
    final value = inputs['head_$repo'] ?? '';
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(value) || value == '0' * 40) {
      errors.add('INVALID_HEAD_$repo');
    }
  }
  if (!_isolatedUri(inputs['api_url'], {'http', 'https'})) {
    errors.add('ISOLATED_API_INVALID');
  }
  if (!_isolatedUri(inputs['ws_url'], {'ws', 'wss'})) {
    errors.add('ISOLATED_WS_INVALID');
  }
  return errors;
}

bool _isolatedUri(String? value, Set<String> schemes) {
  try {
    return _hasLoopbackEndpoint(value, schemes);
  } on FormatException {
    return false;
  }
}

// Require an explicit non-default port for the dedicated test endpoint.
bool _hasLoopbackEndpoint(String? value, Set<String> schemes) {
  final uri = value == null ? null : Uri.tryParse(value);
  if (uri == null ||
      !schemes.contains(uri.scheme) ||
      !uri.hasPort ||
      uri.port <= 0 ||
      uri.port > 65535 ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  final host = uri.host;
  final parts = host.split('.');
  return host == '::1' ||
      (parts.length == 4 &&
          parts[0] == '127' &&
          parts.every(
            (p) =>
                int.tryParse(p) != null &&
                int.parse(p) >= 0 &&
                int.parse(p) <= 255 &&
                int.parse(p).toString() == p,
          ));
}
