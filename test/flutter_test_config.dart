// test/ 根 flutter_test_config：所有子目录测试的公共前置。
//
// flutter_test_config.dart 按测试文件所在目录向上就近生效——本文件覆盖
// test/ 下没有自己 config 的全部子目录（organization / enterprise / …）；
// test/unit_test/ 有自己的 config（做 StorageService 等重初始化），其内部
// 会再次调用 pinLoopbackTestEnv（幂等）。
//
// A04：钉住 Env() 到 loopback 合成环境，flutter test 输出零生产域名。

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'env_test_pin.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  pinLoopbackTestEnv();
  await testMain();
}
