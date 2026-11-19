@TestOn('chrome')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/env_factory_web.dart' as env_factory;
import 'package:imboy/config/init.dart' show AppInitializer, currentEnv;

void main() {
  late Map<String, Env> savedMap;
  late String savedCurrentEnv;

  setUp(() {
    savedMap = Map<String, Env>.of(envMap);
    savedCurrentEnv = currentEnv;
    AppInitializer.clearInitConfigCache();
    envMap
      ..clear()
      ..addAll(env_factory.createEnvMap());
  });

  tearDown(() {
    AppInitializer.clearInitConfigCache();
    envMap
      ..clear()
      ..addAll(savedMap);
    currentEnv = savedCurrentEnv;
  });

  test('Web 默认五环境和未知环境明确未配置，不返回空签名密钥', () async {
    expect(
      envMap.keys,
      unorderedEquals(['pro', 'dev', 'local', 'local_home', 'local_office']),
    );
    for (final name in [...envMap.keys, 'unknown-web-env']) {
      currentEnv = name;
      expect(() => Env().apiBaseUrl, throwsStateError);
      expect(Env().wsUrl, isNull);
      expect(Env.effectiveWsUrl, isNull);
      expect(Env.publicBaseUrl, isEmpty);
      expect(() => Env().solidifiedKeyIv, throwsStateError);
      expect(() => Env().openaiApiKey, throwsStateError);
      expect(() => Env().anthropicApiKey, throwsStateError);
      expect(Env().aiTestEnabled, isFalse);
      await expectLater(Env.signKey(), throwsStateError);
    }
  });

  test('公开根只接受显式origin，release拒绝http且开发仅允许loopback', () {
    for (final invalid in [
      '',
      'https://user:pass@example.invalid',
      'https://@example.invalid',
      'https://example.invalid/',
      'https://example.invalid/path',
      'https://example.invalid?x=1',
      'https://example.invalid#fragment',
      'http://example.invalid',
      'https://example.invalid:0',
    ]) {
      expect(
        () => env_factory.validateWebApiBaseUrl(invalid),
        throwsStateError,
      );
    }
    expect(
      env_factory.validateWebApiBaseUrl('https://api.example.invalid'),
      'https://api.example.invalid',
    );
    expect(
      env_factory.validateWebApiBaseUrl('http://127.0.0.1:19801'),
      'http://127.0.0.1:19801',
    );
    expect(
      () => env_factory.validateWebApiBaseUrl(
        'http://127.0.0.1:19801',
        releaseMode: true,
      ),
      throwsStateError,
    );
    envMap.addAll(
      env_factory.createEnvMap(apiBaseUrl: 'https://api.example.invalid'),
    );
    currentEnv = 'dev';
    expect(Env().apiBaseUrl, 'https://api.example.invalid');
    expect(Env().wsUrl, isNull);
    expect(Env.effectiveWsUrl, isNull);
    expect(Env.publicBaseUrl, isEmpty);
    expect(() => Env().solidifiedKey, throwsStateError);
  });

  test('envMap注入也不能绕过bootstrap的严格public origin边界', () async {
    currentEnv = 'dev';
    envMap['dev'] = const _SyntheticEnv(
      'https://example.invalid/path',
      'unused',
    );
    await expectLater(AppInitializer.initConfig(), throwsStateError);
    expect(Env.effectiveWsUrl, isNull);
    expect(Env.publicBaseUrl, isEmpty);
  });

  test('Web 保留 envMap 注入，currentEnv 切换和 map 替换每次生效', () async {
    const first = _SyntheticEnv('http://127.0.0.1:19801', 'synthetic-a');
    const second = _SyntheticEnv('http://127.0.0.1:19802', 'synthetic-b');
    envMap['dev'] = first;
    envMap['pro'] = second;
    currentEnv = 'dev';
    expect(Env(), same(first));
    expect(Env().apiBaseUrl, first.apiBaseUrl);
    await expectLater(Env.signKey(), throwsStateError);
    currentEnv = 'pro';
    expect(Env(), same(second));
    await expectLater(Env.signKey(), throwsStateError);
    envMap['pro'] = first;
    expect(Env(), same(first));
    await expectLater(Env.signKey(), throwsStateError);
  });
}

final class _SyntheticEnv implements Env {
  const _SyntheticEnv(this.apiBaseUrl, this.solidifiedKey);

  @override
  final String apiBaseUrl;
  @override
  final String solidifiedKey;
  @override
  String get solidifiedKeyIv => 'synthetic-iv';
  @override
  String? get wsUrl => 'ws://127.0.0.1:19801/ws';
  @override
  String get iosAppId => '';
  @override
  String get aMapIosKey => '';
  @override
  String get aMapAndroidKey => '';
  @override
  String get aMapWebKey => '';
  @override
  String get jiguangAppKey => '';
  @override
  String get alipayAppId => '';
  @override
  String get alipayUniversalLink => '';
  @override
  String get openaiApiKey => '';
  @override
  String get anthropicApiKey => '';
  @override
  bool get aiTestEnabled => false;
}
