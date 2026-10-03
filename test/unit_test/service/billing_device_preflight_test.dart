import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/full_acceptance/billing/billing_device_preflight.dart';

Map<String, String> validInputs() => {
  'device_id': 'synthetic-device',
  'platform': 'android',
  'lease_id': 'synthetic-lease',
  'fixture_id': 'synthetic-fixture',
  'expected_uid': '9007199254740993',
  'authorization_sha256': 'a' * 64,
  'runtime_sha256': 'b' * 64,
  'fixture_sha256': 'c' * 64,
  'head_imboy': 'd' * 40,
  'head_imboyapp': 'e' * 40,
  'head_imboyadmin': 'f' * 40,
  'api_url': 'http://127.0.0.1:19880',
  'ws_url': 'ws://127.0.0.1:19880/api/v1/ws',
};

void main() {
  test('explicit synthetic descriptors structurally validate', () {
    expect(validateBillingDeviceInputs(validInputs()), isEmpty);
  });
  for (final name in validInputs().keys) {
    test('missing $name refuses preparation', () {
      expect(
        validateBillingDeviceInputs(validInputs()..remove(name)),
        isNotEmpty,
      );
    });
  }
  test('unknown platform and noncanonical UID refuse preparation', () {
    for (final uid in ['0', '-1', '01', '1.0', '9223372036854775808']) {
      expect(
        validateBillingDeviceInputs(validInputs()..['expected_uid'] = uid),
        isNotEmpty,
      );
    }
    expect(
      validateBillingDeviceInputs(validInputs()..['platform'] = 'web'),
      isNotEmpty,
    );
  });
  test('zero hashes cannot serve as approval or candidate bindings', () {
    for (final name in [
      'authorization_sha256',
      'runtime_sha256',
      'fixture_sha256',
      'head_imboy',
    ]) {
      expect(
        validateBillingDeviceInputs(
          validInputs()..[name] = '0' * (name.startsWith('head_') ? 40 : 64),
        ),
        isNotEmpty,
      );
    }
  });
  test('non-isolated ambiguous and credentialed URLs refuse preparation', () {
    for (final url in [
      'https://example.com:443',
      'http://localhost:19880',
      'http://0.0.0.0:19880',
      'http://127.0.0.1',
      'http://127.0.0.1:0',
      'http://127.0.0.1:999999999999999999999999999999',
      'http://user:secret@127.0.0.1:19880',
      'http://127.0.0.1:19880?token=x',
    ]) {
      expect(
        validateBillingDeviceInputs(validInputs()..['api_url'] = url),
        isNotEmpty,
      );
    }
  });
}
