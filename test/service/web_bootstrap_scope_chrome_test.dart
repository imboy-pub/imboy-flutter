@TestOn('chrome')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart' as http;
import 'package:imboy/component/http/http_config.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/env_factory_web.dart' as webEnv;
import 'package:imboy/config/init.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:pointycastle/asn1.dart' as asn1;

const _firstRoot = 'http://127.0.0.1:19801';
const _secondRoot = 'http://127.0.0.1:19802';
const _secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

Map<String, dynamic> _payload(String suffix) => {
  'ws_url': 'wss://ws-$suffix.example.invalid/api/v1/web/ws',
  'login_pwd_rsa_encrypt': '0',
  'login_rsa_pub_key': '',
  'public_base_url': 'https://assets-$suffix.example.invalid/public/',
  'features': {'rtc': true},
  'effective_product_experience': 'chat',
  'config_version': 'synthetic-$suffix',
  'terminology': {
    'profile': 'generic',
    'hash': 'synthetic-hash',
    'terms': {'group': 'Synthetic group'},
  },
};

// Same synthetic SPKI encoding used by the native password transport regression.
String _publicKey() {
  final random = Random.secure();
  final rng = pc.SecureRandom('Fortuna')
    ..seed(
      pc.KeyParameter(
        Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
      ),
    );
  final generator = pc.RSAKeyGenerator()
    ..init(
      pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        rng,
      ),
    );
  final public = generator.generateKeyPair().publicKey;
  final algorithm = asn1.ASN1Sequence()
    ..add(asn1.ASN1ObjectIdentifier.fromName('rsaEncryption'))
    ..add(asn1.ASN1Null());
  final key = asn1.ASN1Sequence()
    ..add(asn1.ASN1Integer(public.modulus))
    ..add(asn1.ASN1Integer(public.exponent));
  final spki = asn1.ASN1Sequence()
    ..add(algorithm)
    ..add(asn1.ASN1BitString(stringValues: key.encode()));
  return '-----BEGIN PUBLIC KEY-----\n${base64Encode(spki.encode())}\n'
      '-----END PUBLIC KEY-----';
}

// Only the existing HttpClient service boundary is substituted. No HTTP proof.
class _BootstrapClient extends http.HttpClient {
  _BootstrapClient(this.respond)
    : super(conf: HttpConfig(baseUrl: Env().apiBaseUrl), retryEnabled: false);

  final Future<IMBoyHttpResponse> Function(String) respond;

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) => respond(uri);
}

void main() {
  late Map<String, Env> previousMap;
  late String previousEnv;
  late _BootstrapClient client;
  late List<Completer<IMBoyHttpResponse>> pending;
  late List<String> requests;
  var secureCalls = 0;

  setUpAll(() async {
    previousMap = Map<String, Env>.of(envMap);
    previousEnv = currentEnv;
    envMap.addAll(webEnv.createEnvMap(apiBaseUrl: _firstRoot));
    currentEnv = 'dev';
    await prepareWebWriter();
  });
  tearDownAll(() {
    envMap
      ..clear()
      ..addAll(previousMap);
    currentEnv = previousEnv;
  });
  setUp(() async {
    envMap.addAll(webEnv.createEnvMap(apiBaseUrl: _firstRoot));
    currentEnv = 'dev';
    AppInitializer.clearInitConfigCache();
    SharedPreferences.setMockInitialValues({
      Keys.wsUrl: 'wss://old.example.invalid/ws',
      Keys.publicBaseUrl: 'https://old.example.invalid',
      Keys.apiPublicKey: 'stale-native-key',
      Keys.uploadUrl: 'retained-legacy-upload',
      Keys.uploadScene: 'retained-legacy-scene',
    });
    await StorageService.init();
    secureCalls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secure, (call) async {
          secureCalls++;
          throw StateError('Web bootstrap must not access secure legacy keys');
        });
    pending = [];
    requests = [];
    client = _BootstrapClient((uri) {
      requests.add(uri);
      final response = Completer<IMBoyHttpResponse>();
      pending.add(response);
      return response.future;
    });
    serviceContainer.put<http.HttpClient>(client);
  });
  tearDown(() {
    client.dio.close(force: true);
    serviceContainer.clear();
    AppInitializer.clearInitConfigCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secure, null);
  });

  test('RSA启用时接受真实合成2048位SPKI公钥，不降级明文', () {
    final payload = AppInitializer.validateWebBootstrapPayload({
      ..._payload('rsa'),
      'login_pwd_rsa_encrypt': '1',
      'login_rsa_pub_key': _publicKey(),
    });
    expect(payload['login_pwd_rsa_encrypt'], '1');
    expect(
      payload['login_rsa_pub_key'],
      startsWith('-----BEGIN PUBLIC KEY-----'),
    );
  });

  test('八字段类型、Web WS路径、URL凭据及缺失/无效RSA公钥必须失败', () {
    final valid = AppInitializer.validateWebBootstrapPayload(_payload('a'));
    expect(valid.keys, hasLength(8));
    expect(valid['public_base_url'], 'https://assets-a.example.invalid/public');
    for (final mutation in <Map<String, dynamic>>[
      {
        'features': {'rtc': 'true'},
      },
      {'config_version': 1},
      {
        'terminology': {'profile': 'generic'},
      },
      {'login_pwd_rsa_encrypt': 'on'},
      {'login_pwd_rsa_encrypt': '1', 'login_rsa_pub_key': ''},
      {'login_pwd_rsa_encrypt': '1', 'login_rsa_pub_key': 'invalid-key'},
      {'ws_url': 'wss://ws.example.invalid/ws'},
      {'ws_url': 'wss://user@ws.example.invalid/api/v1/web/ws'},
      {'ws_url': 'wss://ws.example.invalid/api/v1/web/ws?tk=synthetic'},
      {'public_base_url': 'https://user:pass@assets.example.invalid'},
    ]) {
      expect(
        () => AppInitializer.validateWebBootstrapPayload({
          ..._payload('a'),
          ...mutation,
        }),
        throwsA(anything),
      );
    }
    for (final field in _payload('a').keys) {
      final incomplete = _payload('a')..remove(field);
      expect(
        () => AppInitializer.validateWebBootstrapPayload(incomplete),
        throwsA(anything),
      );
    }
  });

  test('成功bootstrap的嵌套Map/List不可修改且不共享响应容器', () async {
    final source = _payload('immutable');
    final sourceTerms = source['terminology'] as Map;
    sourceTerms['labels'] = [
      {
        'values': ['initial'],
      },
    ];
    final request = AppInitializer.initConfig();
    pending.single.complete(IMBoyHttpResponse.success(source));
    final result = await request;
    expect(result, isNot(contains('error')));
    for (final config in [result, AppInitializer.currentWebBootstrap!]) {
      final features = config['features'] as Map;
      final terminology = config['terminology'] as Map;
      final terms = terminology['terms'] as Map;
      final labels = terminology['labels'] as List;
      final label = labels.single as Map;
      final values = label['values'] as List;
      expect(() => features['rtc'] = false, throwsUnsupportedError);
      expect(() => terminology['profile'] = 'changed', throwsUnsupportedError);
      expect(() => terms['group'] = 'changed', throwsUnsupportedError);
      expect(() => labels.add({}), throwsUnsupportedError);
      expect(() => label['values'] = [], throwsUnsupportedError);
      expect(() => values[0] = 'changed', throwsUnsupportedError);
    }
    (source['features'] as Map)['rtc'] = false;
    sourceTerms['profile'] = 'changed';
    (sourceTerms['terms'] as Map)['group'] = 'changed';
    ((sourceTerms['labels'] as List).single['values'] as List)[0] = 'changed';
    (sourceTerms['labels'] as List).clear();
    for (final config in [
      await AppInitializer.initConfig(),
      AppInitializer.currentWebBootstrap!,
    ]) {
      expect((config['features'] as Map)['rtc'], isTrue);
      final terminology = config['terminology'] as Map;
      expect(terminology['profile'], 'generic');
      expect((terminology['terms'] as Map)['group'], 'Synthetic group');
      expect(terminology['labels'], [
        {
          'values': ['initial'],
        },
      ]);
    }
    expect(requests, hasLength(1));
    expect(secureCalls, 0);
  });

  for (final clearOnly in [false, true]) {
    test('迟到请求不完成新Completer或污染当前根：clearOnly=$clearOnly', () async {
      expect(Env.effectiveWsUrl, isNull);
      expect(Env.publicBaseUrl, isEmpty);
      expect(Env.apiPublicKey, isNull);
      final oldRequest = AppInitializer.initConfig();
      final oldWaiter = AppInitializer.initConfig();
      final root = clearOnly ? _firstRoot : _secondRoot;
      if (clearOnly) {
        AppInitializer.clearInitConfigCache();
      } else {
        envMap['dev'] = webEnv.createEnvMap(apiBaseUrl: root)['dev']!;
      }
      final newRequest = AppInitializer.initConfig();
      var newDone = false;
      unawaited(newRequest.then((_) => newDone = true));
      expect(requests, [
        '$_firstRoot/api/v1/web/bootstrap',
        '$root/api/v1/web/bootstrap',
      ]);
      pending[0].complete(IMBoyHttpResponse.success(_payload('old')));
      expect(await oldRequest, contains('error'));
      expect(await oldWaiter, contains('error'));
      expect(newDone, isFalse);
      expect(Env.effectiveWsUrl, isNull);
      pending[1].complete(IMBoyHttpResponse.success(_payload('new')));
      final current = await newRequest;
      expect(current, isNot(contains('error')));
      expect(Env.effectiveWsUrl, 'wss://ws-new.example.invalid/api/v1/web/ws');
      expect(Env.publicBaseUrl, 'https://assets-new.example.invalid/public');
      expect(() => current['ws_url'] = 'mutated', throwsUnsupportedError);
      expect(
        () => AppInitializer.currentWebBootstrap!['ws_url'] = 'mutated',
        throwsUnsupportedError,
      );
      expect(
        StorageService.to.getString(Keys.uploadUrl),
        'retained-legacy-upload',
      );
      expect(
        StorageService.to.getString(Keys.uploadScene),
        'retained-legacy-scene',
      );
      expect(secureCalls, 0);
      envMap['pro'] = webEnv.createEnvMap(apiBaseUrl: root)['pro']!;
      currentEnv = 'pro';
      expect(Env.effectiveWsUrl, isNull);
      expect(Env.publicBaseUrl, isEmpty);
      final changedEnv = AppInitializer.initConfig();
      expect(requests, hasLength(3));
      pending[2].complete(IMBoyHttpResponse.success(_payload('environment')));
      expect(await changedEnv, isNot(contains('error')));
      expect(
        Env.effectiveWsUrl,
        'wss://ws-environment.example.invalid/api/v1/web/ws',
      );
    });
  }
}
