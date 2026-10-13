import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/env.dart';

import '../../integration_test/customer_service/cs_integration_fixture.dart';
import '../../integration_test/customer_service/cs_integration_runtime.dart';

Map<String, String> validFixture() => {
  'RUN_ID': 'cx-owned-native-20261013',
  'API_BASE': 'https://run.invalid:8444',
  'EXECUTION_APPROVED': 'true',
  'DEVICE_PROFILE_OWNED': 'true',
  'RESOURCE_SHA': 'a' * 64,
  'SOURCE_SHA': 'b' * 64,
  'ACTOR_PROTOCOL_SHA': 'c' * 64,
  'ENVIRONMENT': 'dev',
  'SIGN_KEY_SHA': 'd' * 64,
  'DEVICE_ID': 'owned-device',
  'ORG_ID': '1',
  'WORKSPACE_ID': '2',
  'PROBE_SESSION_ID': '3',
  'PROBE_CONVERSATION_ID': '4',
  'UI_SESSION_ID': '5',
  'UI_CONVERSATION_ID': '6',
  'SEAT_A_UID': '7',
  'SEAT_A_IDENTITY': '8',
  'SEAT_A_JWT': 'synthetic-A-token',
  'SEAT_A_REFRESH': 'synthetic-A-refresh',
  'SEAT_B_UID': '9',
  'SEAT_B_IDENTITY': '10',
  'SEAT_B_JWT': 'synthetic-B-token',
  'SEAT_B_REFRESH': 'synthetic-B-refresh',
  'TRANSFER_TARGET_ID': '10',
  'HISTORY_IDS': List.generate(200, (i) => '${1000 + i}').join(','),
  'OLDEST_MARKER': 'cx-owned-native-20261013-oldest',
  'NEWEST_MARKER': 'cx-owned-native-20261013-newest',
  'ASSET_SHA': 'e' * 64,
  'ASSET_SIZE': '12',
  'ASSET_NAME': 'owned.txt',
  'SAVED_DEVICE_PATH': '/storage/emulated/0/Download/imboy-cs/cx-owned-native-20261013/output/owned.txt',
  'ASSET_DEVICE_PATH': '/storage/emulated/0/Download/imboy-cs/cx-owned-native-20261013/input/owned.txt',
  'ASSET_MIME': 'text/plain',
  'RATING_SCORE': '4',
};
void main() {
  test('owned runtime uses the registered WebSocket route and run port', () {
    for (final origin in [
      'https://run.invalid:8444',
      'https://127.0.0.1:8445',
    ]) {
      final runtime = CsRunEnvironment(envMap['local']!, Uri.parse(origin));
      expect(
        runtime.wsUrl,
        '${origin.replaceFirst('https:', 'wss:')}/api/v1/ws',
      );
      expect(runtime.apiBaseUrl, origin);
    }
  });
  test(
    'admission pins distinct sessions, two principals and all 200 history IDs',
    () {
      final fixture = CsIntegrationFixture.parse(validFixture());
      expect(fixture.historyIds.length, 200);
      expect(fixture.uiSessionId, '5');
      expect(fixture.probeSessionId, '3');
    },
  );
  test(
    'all required missing parameters fail closed rather than optional skip',
    () {
      for (final key in validFixture().keys) {
        final values = validFixture()..remove(key);
        expect(
          () => CsIntegrationFixture.parse(values),
          throwsA(isA<CsIntegrationAdmissionRefused>()),
          reason: key,
        );
      }
    },
  );
  test(
    'unsafe origins and unapproved device profile refuse before any runtime',
    () {
      for (final origin in [
        'http://run.invalid',
        'https://user:secret@run.invalid',
        'https://run.invalid/path',
        'https://run.invalid?ticket=hidden',
        'https://run.invalid#fragment',
      ]) {
        expect(
          () =>
              CsIntegrationFixture.parse(validFixture()..['API_BASE'] = origin),
          throwsA(isA<CsIntegrationAdmissionRefused>()),
        );
      }
      expect(
        () => CsIntegrationFixture.parse(
          validFixture()..['EXECUTION_APPROVED'] = 'false',
        ),
        throwsA(isA<CsIntegrationAdmissionRefused>()),
      );
      expect(
        () => CsIntegrationFixture.parse(
          validFixture()..['DEVICE_PROFILE_OWNED'] = 'false',
        ),
        throwsA(isA<CsIntegrationAdmissionRefused>()),
      );
    },
  );
  test(
    'foreign transfer identity, duplicate scope and signed64 overflow refuse',
    () {
      for (final mutation in [
        ('TRANSFER_TARGET_ID', '11'),
        ('UI_SESSION_ID', '3'),
        ('UI_CONVERSATION_ID', '4'),
        ('SEAT_B_UID', '7'),
        ('ORG_ID', '9223372036854775808'),
      ]) {
        expect(
          () => CsIntegrationFixture.parse(
            validFixture()..[mutation.$1] = mutation.$2,
          ),
          throwsA(isA<CsIntegrationAdmissionRefused>()),
        );
      }
    },
  );
  test(
    'foreign, aliased, escaped and same-file device paths refuse admission',
    () {
      const root =
          '/storage/emulated/0/Download/imboy-cs/cx-owned-native-20261013';
      for (final mutation in [
        ('ASSET_DEVICE_PATH', '/storage/emulated/0/DCIM/private-synthetic.txt'),
        ('ASSET_DEVICE_PATH', '$root/input/../output/owned.txt'),
        (
          'ASSET_DEVICE_PATH',
          '/sdcard/Download/imboy-cs/cx-owned-native-20261013/input/owned.txt',
        ),
        ('ASSET_DEVICE_PATH', '$root/input/another.txt'),
        ('SAVED_DEVICE_PATH', '$root/input/owned.txt'),
        ('SAVED_DEVICE_PATH', '$root/output/../input/owned.txt'),
        (
          'SAVED_DEVICE_PATH',
          '/storage/emulated/0/Download/imboy-cs/cx-other-run/output/owned.txt',
        ),
      ]) {
        expect(
          () => CsIntegrationFixture.parse(
            validFixture()..[mutation.$1] = mutation.$2,
          ),
          throwsA(isA<CsIntegrationAdmissionRefused>()),
        );
      }
    },
  );
  test('dot file-name and non-canonical separators cannot name a run file', () {
    for (final name in ['.', '..', 'dir/owned.txt', r'dir\owned.txt']) {
      expect(
        () => CsIntegrationFixture.parse(validFixture()..['ASSET_NAME'] = name),
        throwsA(isA<CsIntegrationAdmissionRefused>()),
      );
    }
  });
  test('history must be exactly 200 ascending unique canonical IDs', () {
    for (final history in [
      '1,2',
      List.filled(200, '1').join(','),
      List.generate(200, (i) => '${1200 - i}').join(','),
    ]) {
      expect(
        () => CsIntegrationFixture.parse(
          validFixture()..['HISTORY_IDS'] = history,
        ),
        throwsA(isA<CsIntegrationAdmissionRefused>()),
      );
    }
  });
  test('admission exceptions never stringify credentials or offending URL', () {
    try {
      CsIntegrationFixture.parse(
        validFixture()..['API_BASE'] = 'https://user:private@run.invalid',
      );
    } on CsIntegrationAdmissionRefused catch (error) {
      expect(error.toString(), isNot(contains('private')));
      expect(error.toString(), isNot(contains('synthetic-A-token')));
    }
  });
}
