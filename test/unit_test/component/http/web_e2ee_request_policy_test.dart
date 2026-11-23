import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_request_policy.dart';

void main() {
  final origin = Uri.parse('https://example.invalid');

  test('Web feature snapshots use the existing public GET route', () {
    final features = Uri.parse('/api/v1/app/features');
    final request = webHumanRequestUri('GET', features, origin);
    expect(request, origin.resolveUri(features));
    expect(webHumanPublicPaths, contains(request.path));
    expect(
      () => webHumanRequestUri('POST', features, origin),
      throwsFormatException,
    );
    expect(
      () => webHumanRequestUri(
        'GET',
        Uri.parse('https://other.invalid/api/v1/app/features'),
        origin,
      ),
      throwsFormatException,
    );
    expect(
      () => webHumanRequestUri(
        'GET',
        features.replace(queryParameters: {'token': 'synthetic'}),
        origin,
      ),
      throwsFormatException,
    );
    expect(
      () => webHumanRequestUri(
        'GET',
        Uri.parse('/api/v1/web/app/features'),
        origin,
      ),
      throwsFormatException,
    );
  });

  test('Web E2EE aliases require the exact method and authentication', () {
    const methods = {
      'user_keys': 'GET',
      'report_device_key': 'POST',
      'devices': 'GET',
      'olm/identity': 'POST',
      'olm/prekeys': 'POST',
      'olm/fallback_key': 'POST',
      'olm/get_identity': 'GET',
      'olm/prekey_count': 'GET',
      'olm/claim': 'POST',
    };
    for (final entry in methods.entries) {
      final native = Uri.parse('/api/v1/e2ee/${entry.key}');
      final web = '/api/v1/web/e2ee/${entry.key}';
      expect(webHumanRequestUri(entry.value, native, origin).path, web);
      expect(webHumanPublicPaths, isNot(contains(web)));
      final wrongMethod = entry.value == 'GET' ? 'POST' : 'GET';
      expect(
        () => webHumanRequestUri(wrongMethod, Uri.parse(web), origin),
        throwsFormatException,
      );
    }
  });

  test('unrelated E2EE operations cannot acquire Web credentials', () {
    for (final path in [
      '/api/v1/e2ee/devices/batch_claim',
      '/api/v1/web/e2ee/trust/record',
      '/api/v1/e2ee/backup/put',
      'https://other.invalid/api/v1/web/e2ee/olm/claim',
      '/api/v1/web/e2ee/olm/claim?token=synthetic',
    ]) {
      expect(
        () => webHumanRequestUri('POST', Uri.parse(path), origin),
        throwsFormatException,
      );
    }
  });
}
