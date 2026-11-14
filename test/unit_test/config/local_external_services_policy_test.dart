import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/local_external_services_policy.dart';

void main() {
  bool maps({
    bool requested = true,
    bool allowMaps = false,
    bool androidQaBuild = true,
    bool isolated = true,
    bool android = true,
    String environment = 'local',
    String apiBaseUrl = 'http://127.0.0.1:9801',
  }) => LocalExternalServicesPolicy.evaluateMaps(
    requested: requested,
    environment: environment,
    apiBaseUrl: apiBaseUrl,
    allowMaps: allowMaps,
    androidQaBuild: androidQaBuild,
    isolated: isolated,
    android: android,
  );

  test('map requests stay suppressed without an explicit grant', () {
    expect(maps(), isTrue);
    expect(
      maps(requested: false, environment: 'pro'),
      isFalse,
      reason: 'ordinary builds retain existing map behavior',
    );
  });

  test('map grant permits only maps in isolated Android QA', () {
    expect(maps(allowMaps: true), isFalse);
    expect(
      LocalExternalServicesPolicy.evaluate(
        requested: true,
        environment: 'local',
        apiBaseUrl: 'http://127.0.0.1:9801',
      ),
      isTrue,
      reason: 'NTP and push remain suppressed',
    );
  });

  test('map grant rejects missing isolation or Android QA markers', () {
    for (final call in <bool Function()>[
      () => maps(allowMaps: true, requested: false),
      () => maps(allowMaps: true, androidQaBuild: false),
      () => maps(allowMaps: true, isolated: false),
      () => maps(allowMaps: true, android: false),
      () => maps(allowMaps: true, environment: 'pro'),
      () => maps(allowMaps: true, apiBaseUrl: 'https://example.invalid'),
      () => maps(allowMaps: true, apiBaseUrl: 'http://user@127.0.0.1'),
    ]) {
      expect(call, throwsStateError);
    }
  });

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
