// 测试环境惰性化 flutter_secure_storage / Pin inert secure storage (G17)
//
// 真机侧 flutter_secure_storage 走 iOS Keychain / Android
// EncryptedSharedPreferences；flutter test 无插件实现，任何 read 都抛
// MissingPluginException。该异常会沿 UserRepoLocal.accessToken /
// refreshToken 的 catch 分支被打成「令牌解密失败」，持久化
// `token_decryption_failed` 标记（StorageService.setBool）。
//
// 后果链（G17 30 个契约流失败的根因，2026-10-07 归因）：
//   同一用例第 1 次 HTTP 请求 → accessToken 抛异常 → 写标记（本次请求不受
//   影响）→ 第 2 次请求 → HttpClient._setDefaultConfig 见标记 →
//   quitLogin（sessionGeneration 递增）→ 请求前后代次校验失败 →
//   IMBoyHttpResponse.failure(409, 网络错误)。
// 于是：单请求用例全绿、多请求用例（契约流/状态机类）必挂——cs_api_contract、
// cs_session_flow、enterprise_api_contract 等 30 例即此模式。
//
// 用法：根 flutter_test_config.dart 的 testExecutable 统一调用（与
// pinLoopbackTestEnv 同层，A04 的姊妹钉）。已自带同款 mock 的套件
// （organization/、cs_workspace_org、cs_session_page、cs_seat_contexts、
// ux_harness 等）setUp 里重设 handler 会覆盖本钉，语义不变。
//
// 不覆盖 test/unit_test/：该域有自己的 flutter_test_config.dart（就近生效），
// 且其中 migration_atomic_failure_test 等用例**依赖** MissingPluginException
// 语义，本钉不得触达。
//
// 语义：惰性空存储——read → null（未登录、无 token），readAll → 空表，
// write/delete/deleteAll → 成功，containsKey → false。绝不抛异常。

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter_secure_storage 插件平台通道（与
/// lib/service/storage_secure.dart 使用的默认通道一致）。
const MethodChannel secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// 把当前测试 isolate 的 flutter_secure_storage 钉为惰性空存储。
///
/// 幂等：多次调用（根 config + 套件内再钉）效果一致——后者覆盖前者。
void pinInertSecureStorage() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (call) async {
        switch (call.method) {
          case 'read':
            return null;
          case 'readAll':
            return <String, String>{};
          case 'containsKey':
            return false;
          // write / delete / deleteAll 及未知方法：成功返回空。
          default:
            return null;
        }
      });
}
