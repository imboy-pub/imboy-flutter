/// Explicit isolation for owned local device tests; never a feature acceptance mode.
abstract final class LocalExternalServicesPolicy {
  static const _requested = bool.fromEnvironment(
    'IMBOY_LOCAL_EXTERNAL_SERVICES_DISABLED',
  );
  static const _environment = String.fromEnvironment('APP_ENV');
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL_OVERRIDE');

  static bool get suppressed => evaluate(
    requested: _requested,
    environment: _environment,
    apiBaseUrl: _apiBaseUrl,
  );

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
