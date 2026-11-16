@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/env_dev.dart';
import 'package:imboy/config/env_factory_native.dart' as envFactory;
import 'package:imboy/config/env_local.dart';
import 'package:imboy/config/env_local_home.dart';
import 'package:imboy/config/env_local_office.dart';
import 'package:imboy/config/env_pro.dart';
import 'package:imboy/config/init.dart' show currentEnv;

void main() {
  test('Native 五环境键及包装类型保持不变', () {
    final map = envFactory.createEnvMap();
    expect(
      map.keys,
      unorderedEquals(['pro', 'dev', 'local', 'local_home', 'local_office']),
    );
    expect(map['pro'], isA<EnvPro>());
    expect(map['dev'], isA<EnvDev>());
    expect(map['local'], isA<EnvLocal>());
    expect(map['local_home'], isA<EnvLocalHome>());
    expect(map['local_office'], isA<EnvLocalOffice>());
  });

  test('Native仍动态读取注入环境，签名密钥和WS不进入Web bootstrap', () async {
    final previous = Map<String, Env>.of(envMap);
    final previousName = currentEnv;
    addTearDown(() {
      envMap
        ..clear()
        ..addAll(previous);
      currentEnv = previousName;
    });
    currentEnv = 'dev';
    envMap['dev'] = const _NativeSyntheticEnv('first');
    expect(await Env.signKey(), 'synthetic-first');
    expect(Env().wsUrl, 'wss://first.example.invalid/ws');
    envMap['dev'] = const _NativeSyntheticEnv('second');
    expect(await Env.signKey(), 'synthetic-second');
    expect(Env().wsUrl, 'wss://second.example.invalid/ws');
  });

  test('Native 未知环境仍每次返回新的 EnvPro', () {
    final previous = currentEnv;
    addTearDown(() => currentEnv = previous);
    currentEnv = 'unknown-native-env';
    final first = Env();
    final second = Env();
    expect(first, isA<EnvPro>());
    expect(second, isA<EnvPro>());
    expect(first, isNot(same(second)));
  });
}

final class _NativeSyntheticEnv implements Env {
  const _NativeSyntheticEnv(this.name);
  final String name;
  @override
  String get apiBaseUrl => 'https://$name.example.invalid';
  @override
  String get solidifiedKey => 'synthetic-$name';
  @override
  String? get wsUrl => 'wss://$name.example.invalid/ws';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
