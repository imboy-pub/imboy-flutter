// integration_test/two_client/mac_e2ee_server_probe_test.dart
//
// 双端测试 · 服务端 E2EE 密钥上报探针（批次85 诊断用）：
// 以 QA 账号登录后直接调 E2EEApi，定位「report_device_key 落库失败」
// 究竟是服务端 handler 问题还是 Android 请求问题。
//
// 只读探查 + 对自管 QA 账号（uid4）自身上报一把真实本地公钥，不涉及第三方。

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/store/api/e2ee_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '',
);
const _peerUid = String.fromEnvironment('PEER_UID', defaultValue: '');
const _allowReport = bool.fromEnvironment(
  'TEST_ALLOW_DEVICE_KEY_REPORT',
  defaultValue: false,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('双端 · E2EE 服务端密钥上报探针', () {
    testWidgets(
      'user_keys 与 report_device_key 直连验证',
      (tester) async {
        if (!_allowReport || _expectedUid.isEmpty || _peerUid.isEmpty) {
          markTestSkipped(
            '需显式 TEST_ALLOW_DEVICE_KEY_REPORT=true、TEST_EXPECTED_UID 和 PEER_UID',
          );
          return;
        }
        await ensureAppLaunched(tester, maxSeconds: 5);
        if (!await checkPreconditions(tester)) return;

        final loggedIn = await autoLoginOrSkip(tester);
        if (!loggedIn) return;
        final actualUid = UserRepoLocal.to.currentUid;
        if (actualUid != _expectedUid || actualUid == _peerUid) {
          fail('登录账号 UID=$actualUid 与授权上报方 $_expectedUid 不一致，或查询目标为自己');
        }
        await waitForMainShell(tester);

        final api = E2EEApi();

        // 1. 对端账号的服务端设备数
        final peerKeys = await api.userKeys(uid: _peerUid);
        flowLog('user_keys(peer) devices=${peerKeys.length}');

        // 2. 本机上报自己的真实本地公钥——验证 handler+表健康
        final storage = StorageSecureService.to;
        final deviceId = (await storage.getDeviceId() ?? '').trim();
        final keyId = (await storage.getKeyId() ?? '').trim();
        final publicKey = (await storage.getPublicKey() ?? '').trim();
        expect(
          deviceId,
          allOf(isNotEmpty, isNot('unknown')),
          reason: '本机 E2EE device_id 必须有效',
        );
        expect(
          keyId,
          allOf(isNotEmpty, isNot('unknown')),
          reason: '本机 E2EE key_id 必须有效',
        );
        expect(publicKey, isNotEmpty, reason: '本机 E2EE 公钥不得为空');
        flowLog('本机 E2EE key 元数据有效');

        final resp = await api.post(
          API.e2eeReportDeviceKey,
          data: {
            'device_id': deviceId,
            'device_type': 'macos',
            'public_key': publicKey,
            'key_id': keyId,
          },
        );
        flowLog(
          'report_device_key RAW ok=${resp.ok} code=${resp.code} '
          'msg=${resp.msg} payload=${resp.payload}',
        );
        expect(resp.ok, isTrue, reason: '设备公钥上报必须收到服务端业务成功');

        // 3. 上报后复查两侧设备数
        final selfKeys = await api.userKeys(uid: _expectedUid);
        flowLog('user_keys(self) devices=${selfKeys.length}');
        expect(
          selfKeys.any(
            (row) =>
                row['device_id']?.toString() == deviceId &&
                row['key_id']?.toString() == keyId,
          ),
          isTrue,
          reason: '服务端回读必须包含本次上报的 device_id 与 key_id',
        );
        final peerKeysAfter = await api.userKeys(uid: _peerUid);
        flowLog('user_keys(peer) after devices=${peerKeysAfter.length}');
        drainKnownFrameworkExceptions(tester);
      },
      semanticsEnabled: false,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
