// integration_test/demo_flow/local_dual_account_message_flow_test.dart
//
// 本地隔离后端的双账号 C2C 闭环包装：先把 macOS 存储隔离到临时命名空间
// （同 bundle id 的生产 App 登录态不得泄入本地联调），再复用
// dual_account_message_flow_test 的 sender/receiver 编排。
//
// 单机顺序编排：
//   Phase1 TEST_DUAL_ROLE=sender  + TEST_STOP_AFTER_OUTGOING_ACK=true（A 投递到服务端）
//   Phase2 TEST_DUAL_ROLE=receiver                                   （B 离线取件并回复）
// 其余 dart-define 见 dual_account_message_flow_test.dart 头部说明。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../enterprise/macos_storage_isolation.dart';
import '../flows/test_utils.dart';
import 'dual_account_message_flow_test.dart' as dual;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!Platform.isMacOS) {
      flowLog('local dual: non-macOS, fresh install storage');
      return;
    }
    final root = await isolateMacosStorage();
    flowLog('local dual: isolated storage at ${root.path}');
  });

  dual.main();
}
