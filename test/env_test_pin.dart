// 测试环境固定 loopback / Pin loopback test env（A04）
//
// flutter test 输出必须零生产域名：此前 currentEnv 为空时 Env() 静默回退
// EnvPro()，apiBaseUrl 解析为生产域名——HTTP 虽被测试钩子全局拦截，但任何
// 打印 apiBaseUrl 的日志都会把生产域名泄漏进测试输出。
//
// 用法：各 flutter_test_config.dart 的 testExecutable 首行调用
// pinLoopbackTestEnv()。实现上原地覆盖 envMap['dev'] 并把 currentEnv
// 钉到 'dev'（而不是注册新键）：SettingPage 等环境切换 UI 的
// DropdownMenuItem 白名单是硬编码 local/dev/pro，新键会让
// DropdownButton 的唯一值断言在页面测试里崩溃。真机构建不含测试
// config，EnvDev 行为不变。

import 'package:imboy/config/env.dart';
import 'package:imboy/config/env_field.dart';
import 'package:imboy/config/init.dart' show currentEnv;

/// 把当前测试 isolate 的 Env() 钉在 loopback 合成环境。
///
/// 幂等：多次调用（根 config + 子目录 config 各一次）效果一致。
void pinLoopbackTestEnv() {
  envMap['dev'] = const _LoopbackTestEnv();
  currentEnv = 'dev';
}

/// 合成测试环境：全部端点固定 loopback / 空值，不含任何真实域名。
class _LoopbackTestEnv implements Env, EnvField {
  const _LoopbackTestEnv();

  @override
  String get apiBaseUrl => 'http://127.0.0.1:9800';

  @override
  String get wsUrl => 'ws://127.0.0.1:9800/ws';

  @override
  String get iosAppId => '';

  @override
  String get solidifiedKey => '';

  @override
  String get solidifiedKeyIv => '';

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
