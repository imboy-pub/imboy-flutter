// 测试环境域名安全 / Test-env domain safety
//
// A04 守卫：flutter test（kTestMode）下 Env() 绝不能解析到生产域名。
// 此前 currentEnv 为空时 _to 静默回退 EnvPro()，apiBaseUrl 指向
// pro.imboy.pub——HTTP 虽被 testExecutable 全局拦截，但任何打印
// apiBaseUrl 的日志都会把生产域名泄漏进测试输出。
//
// 本文件是 red-green 的 red：修复前 Env().apiBaseUrl 为生产域名而失败。

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('测试模式下 Env().apiBaseUrl 固定 loopback，不含 imboy.pub 生产域', () {
    final base = Env().apiBaseUrl;
    final host = Uri.parse(base).host;
    expect(
      host,
      anyOf('127.0.0.1', 'localhost'),
      reason: '测试 API base 必须是 loopback，实际 apiBaseUrl=$base',
    );
    expect(base.contains('imboy.pub'), isFalse);
  });

  test('测试模式下 Env.effectiveWsUrl 不含 imboy.pub 生产域', () {
    final ws = Env.effectiveWsUrl;
    if (ws != null && ws.isNotEmpty) {
      expect(ws.contains('imboy.pub'), isFalse, reason: '实际 wsUrl=$ws');
    }
  });

  test('测试模式下 Env() 其余公开端点字段不含 imboy.pub 生产域', () {
    final env = Env();
    for (final entry in <String, String>{
      'alipayUniversalLink': env.alipayUniversalLink,
    }.entries) {
      expect(
        entry.value.contains('imboy.pub'),
        isFalse,
        reason: '${entry.key} 泄漏生产域：${entry.value}',
      );
    }
  });
}
