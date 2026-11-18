import 'package:flutter/foundation.dart' show kReleaseMode;

import 'env.dart';

const _publicApiRoot = String.fromEnvironment('WEB_API_BASE_URL');

Map<String, Env> createEnvMap({String apiBaseUrl = _publicApiRoot}) => {
  for (final name in ['pro', 'dev', 'local', 'local_home', 'local_office'])
    name: _PublicWebEnv(apiBaseUrl),
};

Env fallbackEnv() => const _PublicWebEnv(_publicApiRoot);

bool isWebLoopbackHost(String host) =>
    const {'localhost', '127.0.0.1', '::1'}.contains(host);

String validateWebApiBaseUrl(String value, {bool releaseMode = kReleaseMode}) {
  final uri = Uri.tryParse(value);
  if (value.isEmpty ||
      value != value.trim() ||
      RegExp(r'\s').hasMatch(value) ||
      uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.authority.contains('@') ||
      uri.path.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) ||
      !(uri.scheme == 'https' ||
          (!releaseMode &&
              uri.scheme == 'http' &&
              isWebLoopbackHost(uri.host)))) {
    throw StateError('Web requires an explicit public API origin.');
  }
  return uri.origin;
}

final class _PublicWebEnv implements Env {
  const _PublicWebEnv(this._apiBaseUrl);

  final String _apiBaseUrl;

  Never _unavailable(String field) =>
      throw StateError('Web 不提供 Native 私密或平台配置：$field。');

  @override
  String get apiBaseUrl => validateWebApiBaseUrl(_apiBaseUrl);
  @override
  String get iosAppId => _unavailable('iosAppId');
  @override
  String get solidifiedKey => _unavailable('solidifiedKey');
  @override
  String get solidifiedKeyIv => _unavailable('solidifiedKeyIv');
  @override
  String get aMapIosKey => _unavailable('aMapIosKey');
  @override
  String get aMapAndroidKey => _unavailable('aMapAndroidKey');
  @override
  String get aMapWebKey => _unavailable('aMapWebKey');
  @override
  String get jiguangAppKey => _unavailable('jiguangAppKey');
  @override
  String get alipayAppId => _unavailable('alipayAppId');
  @override
  String get alipayUniversalLink => _unavailable('alipayUniversalLink');
  @override
  String? get wsUrl => null;
  @override
  String get openaiApiKey => _unavailable('openaiApiKey');
  @override
  String get anthropicApiKey => _unavailable('anthropicApiKey');
  @override
  bool get aiTestEnabled => false;
}
