// integration_test/auth/local_login_journey_test.dart
//
// 本地隔离后端登录旅程（macOS 桌面 debug 真跑 UI）：
// 账号须先用万能验证码/管理端预先注册（本机 gzv2_local_e2e_r1 库）。
//
// 运行：
//   flutter test integration_test/auth/local_login_journey_test.dart \
//     --dart-define=APP_ENV=local \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9800 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//     --dart-define=TEST_LOGIN_ACCOUNT=<email> \
//     --dart-define=TEST_LOGIN_PASSWORD=<pwd> \
//     -d macos

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/websocket.dart';
import 'package:integration_test/integration_test.dart';

import '../enterprise/macos_storage_isolation.dart';
import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const String _account = String.fromEnvironment(
  'TEST_LOGIN_ACCOUNT',
  defaultValue: '',
);
const String _password = String.fromEnvironment(
  'TEST_LOGIN_PASSWORD',
  defaultValue: '',
);
const int _lingerSeconds = int.fromEnvironment(
  'TEST_LINGER_SECONDS',
  defaultValue: 0,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('本地后端账号密码登录到主界面', (tester) async {
    // 同 bundle id 的生产 App 会在 Keychain/Preferences 留下登录态；
    // 隔离到临时命名空间，确保本次从未登录状态开始且不触碰用户真实存储。
    if (Platform.isMacOS) {
      final root = await isolateMacosStorage();
      flowLog('journey: isolated storage at ${root.path}');
    } else {
      flowLog(
        'journey: non-macOS, fresh install storage (no isolation needed)',
      );
    }

    await ensureAppLaunched(tester, maxSeconds: 3);
    flowLog('journey: app launched');

    if (!await ensureBackendAvailable()) {
      markTestSkipped('本地后端不可达，跳过');
      return;
    }
    if (_account.isEmpty || _password.isEmpty) {
      markTestSkipped('缺少 TEST_LOGIN_ACCOUNT/TEST_LOGIN_PASSWORD，跳过');
      return;
    }
    if (!await waitForEntryState(tester)) {
      markTestSkipped('App 入口状态超时，跳过');
      return;
    }
    flowLog('journey: entry state ready');

    if (isOnWelcomePage(tester)) {
      final left = await leaveWelcomePage(tester);
      flowLog('journey: left welcome=$left');
    }

    // 桌面端默认落 WebLoginPage（二维码），performLogin 内部先切账号密码页。
    final loggedIn = await performLogin(
      tester,
      phone: _account,
      password: _password,
    );
    flowLog('journey: performLogin=$loggedIn');

    // 登录成功后等主 Shell 出现；期间关掉升级弹窗与 E2EE 备份向导遮罩。
    var onShell = false;
    for (var i = 0; i < 30; i++) {
      await dismissUpgradeDialog(tester);
      await dismissE2eeBackupSetupPage(tester);
      if (isOnMainShell(tester)) {
        onShell = true;
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
    }
    flowLog('journey: onMainShell=$onShell');
    expect(loggedIn, isTrue, reason: '应成功离开登录页');
    expect(onShell, isTrue, reason: '登录后应进入主界面 Shell');

    // WS 握手同样过设备签名门 + JWT；connected 即证明 /api/v1/ws 对本地后端联通。
    var wsConnected = false;
    for (var i = 0; i < 30; i++) {
      if (WebSocketService.to.status == SocketStatus.connected) {
        wsConnected = true;
        break;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
    }
    flowLog(
      'journey: wsConnected=$wsConnected status=${WebSocketService.to.status}',
    );
    expect(wsConnected, isTrue, reason: '登录后 WebSocket 应连通本地后端');

    // 可选驻留：让服务端的离线消息推送（上线后按设备补投）在日志里留下
    // `[WS] msg type=C2C id=...` 帧，用于离线取件取证；默认 0 不改变原旅程。
    if (_lingerSeconds > 0) {
      flowLog('journey: linger ${_lingerSeconds}s for offline push');
      for (var i = 0; i < _lingerSeconds; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
      }
      flowLog('journey: linger done');
    }
  });
}
