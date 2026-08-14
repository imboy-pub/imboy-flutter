// integration_test/two_client/mac_e2ee_server_probe_test.dart
//
// 双端测试 · 服务端 E2EE 密钥上报探针（批次85 诊断用）：
// 以 QA 账号登录后直接调 E2EEApi，定位「report_device_key 落库失败」
// 究竟是服务端 handler 问题还是 Android 请求问题。
//
// 只读探查 + 对自管 QA 账号（uid4）自身上报一把真实本地公钥，不涉及第三方。

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/store/api/e2ee_api.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('双端 · E2EE 服务端密钥上报探针', () {
    testWidgets(
      'user_keys 与 report_device_key 直连验证',
      (tester) async {
        await ensureAppLaunched(tester, maxSeconds: 5);
        if (!await checkPreconditions(tester)) return;

        final loggedIn = await autoLoginOrSkip(tester);
        if (!loggedIn) return;
        await waitForMainShell(tester);

        final api = E2EEApi();

        // 1. Android 真机账号(uid50)的服务端设备数（原始返回）
        final keys50 = await api.userKeys(uid: '50');
        flowLog('user_keys(uid=50) devices=${keys50.length} raw=$keys50');

        // 2. 本机(118/uid4)上报自己的真实本地公钥——验证 handler+表健康
        final keyInfo = await E2EEKeyService.getKeyInfo();
        final localKid = keyInfo?['key_id']?.toString() ?? 'null';
        flowLog('本机 keyInfo key_id=$localKid');
        if (keyInfo != null) {
          // ⚠️ 直接用底层 post 打印原始 code/msg/payload：
          // E2EEApi.reportDeviceKey 失败时把 msg 吞成 ok:false，看不到根因。
          final resp = await api.post(
            API.e2eeReportDeviceKey,
            data: {
              'device_id': keyInfo['device_id']?.toString() ?? 'mac-probe',
              'device_type': 'macos',
              'public_key': keyInfo['public_key']?.toString() ?? '',
              'key_id': keyInfo['key_id']?.toString() ?? '',
            },
          );
          flowLog(
            'report_device_key(uid4) RAW ok=${resp.ok} code=${resp.code} '
            'msg=${resp.msg} payload=${resp.payload}',
          );

          // 3. 上报后复查两侧设备数
          final keys4 = await api.userKeys(uid: '4');
          flowLog('user_keys(uid=4) devices=${keys4.length}');
          final keys50b = await api.userKeys(uid: '50');
          flowLog('user_keys(uid=50) after devices=${keys50b.length}');
        }
        drainKnownFrameworkExceptions(tester);
      },
      semanticsEnabled: false,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
