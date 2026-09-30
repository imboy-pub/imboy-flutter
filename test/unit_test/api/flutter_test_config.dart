// test/unit_test/api/flutter_test_config.dart
//
// 本目录（Tier 1 API 契约测试）打**真实后端**，与 test/unit_test/ 根 config
// 的全局禁网口径相反。flutter_test 框架与根 config 都会安装 HttpOverrides
// mock（真实请求恒假响应 → 登录必败 → 整目录 SKIP → pre-push 门禁空转）。
// package:test 的 config 就近优先：本文件生效后根 config 对本目录不再加载，
// 这里把 HttpOverrides.global 显式恢复为 null 以找回真实网络。
//
// 运行方式（与 scripts/pre_push_gate.sh 一致）：
//   API_BASE_URL=http://127.0.0.1:9800 TEST_PHONE=xxx TEST_PASSWORD=xxx \
//   flutter test test/unit_test/api/ --concurrency=1 --timeout=60s
import 'dart:async';
import 'dart:io';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  HttpOverrides.global = null;
  await testMain();
}
