import 'package:flutter/foundation.dart';

/// Explicit isolation for owned local device tests; never a feature acceptance mode.
abstract final class LocalExternalServicesPolicy {
  static const _requested = bool.fromEnvironment(
    'IMBOY_LOCAL_EXTERNAL_SERVICES_DISABLED',
  );
  static const _environment = String.fromEnvironment('APP_ENV');
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL_OVERRIDE');
  static const _allowMaps = bool.fromEnvironment(
    'IMBOY_LOCAL_MAP_REQUESTS_ALLOWED',
  );
  static const _androidQaBuild = bool.fromEnvironment('IMBOY_ANDROID_QA_BUILD');
  static const _isolated = bool.fromEnvironment('IMBOY_TEST_ISOLATED');

  static bool get suppressed => evaluate(
    requested: _requested,
    environment: _environment,
    apiBaseUrl: _apiBaseUrl,
  );

  static bool get mapsSuppressed => evaluateMaps(
    requested: _requested,
    environment: _environment,
    apiBaseUrl: _apiBaseUrl,
    allowMaps: _allowMaps,
    androidQaBuild: _androidQaBuild,
    isolated: _isolated,
    android: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
  );

  static bool evaluateMaps({
    required bool requested,
    required String environment,
    required String apiBaseUrl,
    required bool allowMaps,
    required bool androidQaBuild,
    required bool isolated,
    required bool android,
  }) {
    final disabled = evaluate(
      requested: requested,
      environment: environment,
      apiBaseUrl: apiBaseUrl,
    );
    if (!allowMaps) return disabled;
    if (!disabled || !androidQaBuild || !isolated || !android) {
      throw StateError('Map access requires isolated local Android QA');
    }
    return false;
  }

  static void validateEnvironment(String environment) {
    if (suppressed && environment != 'local') {
      throw StateError('External service isolation requires local environment');
    }
  }

  static bool evaluate({
    required bool requested,
    required String environment,
    required String apiBaseUrl,
  }) {
    if (!requested) return false;
    final uri = Uri.tryParse(apiBaseUrl);
    if (environment != 'local' ||
        uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        !['127.0.0.1', 'localhost', '::1'].contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError(
        'External service isolation requires explicit local loopback API',
      );
    }
    return true;
  }
}
