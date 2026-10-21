import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/local_external_services_policy.dart';

void main() {
  test('ordinary builds retain external services', () {
    expect(
      LocalExternalServicesPolicy.evaluate(
        requested: false,
        environment: 'pro',
        apiBaseUrl: 'https://example.invalid',
      ),
      false,
    );
  });
  for (final host in ['127.0.0.1', 'localhost', '[::1]']) {
    test('explicit local loopback $host permits suppression', () {
      expect(
        LocalExternalServicesPolicy.evaluate(
          requested: true,
          environment: 'local',
          apiBaseUrl: 'http://$host:9801',
        ),
        true,
      );
    });
  }
  for (final url in [
    '',
    'http://127.0.0.1.evil.invalid',
    'http://user@127.0.0.1:9801',
    'https://example.invalid',
    'ftp://127.0.0.1:9801',
    'http://127.0.0.1:9801?target=outside',
    'http://127.0.0.1:9801/#outside',
  ]) {
    test('invalid owned endpoint is rejected: $url', () {
      expect(
        () => LocalExternalServicesPolicy.evaluate(
          requested: true,
          environment: 'local',
          apiBaseUrl: url,
        ),
        throwsStateError,
      );
    });
  }
  for (final env in ['pro', 'dev', 'local_home', '']) {
    test('suppression refuses environment $env', () {
      expect(
        () => LocalExternalServicesPolicy.evaluate(
          requested: true,
          environment: env,
          apiBaseUrl: 'http://127.0.0.1:9801',
        ),
        throwsStateError,
      );
    });
  }
}
