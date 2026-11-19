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

  group('公开根只接受显式origin', () {
    for (final invalid in [
      '',
      ' https://example.invalid',
      'https://example.invalid ',
      'https://exam ple.invalid',
      'https://',
      '/api/v1',
      '//example.invalid',
      'file:///tmp/imboy',
      'https://user:pass@example.invalid',
      'https://@example.invalid',
      'HTTPS://@example.invalid:443',
      'http://@127.0.0.1:19801',
      'https://example.invalid/',
      'https://example.invalid/path',
      'https://example.invalid?x=1',
      'https://example.invalid#fragment',
      'http://example.invalid',
      'http://192.168.1.2:19801',
      'https://example.invalid:0',
      'https://example.invalid:00',
      'https://example.invalid:65536',
      'https://example.invalid:-1',
    ]) {
      test('拒绝 "$invalid"', () {
        for (final releaseMode in [false, true]) {
          expect(
            () => env_factory.validateWebApiBaseUrl(
              invalid,
              releaseMode: releaseMode,
            ),
            throwsStateError,
            reason: 'Invalid origin "$invalid", releaseMode=$releaseMode',
          );
        }
      });
    }

    for (final entry in {
      'https://api.example.invalid': 'https://api.example.invalid',
      'HTTPS://API.EXAMPLE.INVALID': 'https://api.example.invalid',
      'HTTPS://API.EXAMPLE.INVALID:443': 'https://api.example.invalid',
      'https://api.example.invalid:8443': 'https://api.example.invalid:8443',
    }.entries) {
      for (final releaseMode in [false, true]) {
        test('规范化 ${entry.key}，releaseMode=$releaseMode', () {
          expect(
            env_factory.validateWebApiBaseUrl(
              entry.key,
              releaseMode: releaseMode,
            ),
            entry.value,
          );
        });
      }
    }

    for (final host in ['localhost', '127.0.0.1', '[::1]']) {
      for (final port in ['', ':80', ':19801']) {
        final origin = 'http://$host$port';
        final normalized = 'http://$host${port == ':80' ? '' : port}';
        test('非release允许并规范化loopback $origin', () {
          expect(
            env_factory.validateWebApiBaseUrl(origin, releaseMode: false),
            normalized,
          );
        });
        test('release拒绝loopback $origin', () {
          expect(
            () => env_factory.validateWebApiBaseUrl(origin, releaseMode: true),
            throwsStateError,
          );
        });
      }
    }
  });

  test('公开根工厂保留origin且不提供Native配置', () {
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
