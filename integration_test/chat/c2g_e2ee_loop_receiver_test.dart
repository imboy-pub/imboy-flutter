// integration_test/chat/c2g_e2ee_loop_receiver_test.dart
//
// 批次181：C2G E2EE 双端回环·接收侧（真机 smoke_alice）。
//
// 必须先于发送侧启动：登录（自动注册/刷新设备密钥）→ WS 在线 →
// 群详情同步 e2ee 旗标 → 深链进入群聊页 → 轮询等「解密明文 marker」出现。
// 断言的是 UI 级明文：C2G 密文落库、读时经 Megolm inbound session 解密，
// marker 能渲染 = room-key 分发（e2ee_room_key 中继）+ 入站解密全链通。
//
// 运行：flutter test <file> -d XWE6R19916004085 --dart-define=...
//       （TEST_PHONE=smoke_alice / TEST_EXPECTED_UID=1000000051，
//         与发送侧共用 C2G_E2EE_LOOP_MARKER）

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _gid = '110073884384167936';
const _marker = String.fromEnvironment(
  'C2G_E2EE_LOOP_MARKER',
  defaultValue: 'c2g-loop-marker',
);

Future<void> _dismissBootPopups(WidgetTester tester) async {
  for (final label in ['稍后', '以后再说', '取消', '知道了']) {
    final btn = find.text(label);
    if (tester.any(btn)) {
      await tester.tap(btn, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 600));
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('C2G E2EE 回环·接收侧：等待 room-key 分发并断言解密明文渲染', (tester) async {
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 15);
    if (!await checkPreconditions(tester)) return;
    await settle(tester, maxSeconds: 2);
    await _dismissBootPopups(tester);

    // 群详情同步 e2ee 旗标（幂等；mode=1 已由发送侧前置开启）
    await GroupApi().detail(gid: _gid);
    final flagOn = await GroupSessionService.to.isGroupE2EE(_gid);
    // ignore: avoid_print
    print('[C2G-LOOP] RX 就绪 flagOn=$flagOn gid=$_gid 等待 marker=$_marker');

    // 深链进入群聊页（读时解密渲染在此页发生）
    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).push('/chat/$_gid?type=C2G');

    // 轮询最多 150 秒：等发送侧的 room-key + 密文经 WS 到达并解密渲染
    var found = false;
    for (var i = 0; i < 300 && !found; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (tester.any(find.text(_marker))) {
        found = true;
      }
      if (i % 20 == 19) {
        // ignore: avoid_print
        print('[C2G-LOOP] RX 等待中 ${(i + 1) / 2}s flagOn=$flagOn');
      }
    }
    if (!found) {
      fail(
        '150 秒内群聊页未出现解密明文 marker——'
        'room-key 分发（e2ee_room_key 中继）或入站 Megolm 解密链断裂',
      );
    }
    // ignore: avoid_print
    print('[C2G-LOOP] RX PASS：解密明文已渲染 marker=$_marker');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
