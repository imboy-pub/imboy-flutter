// integration_test/two_client/h2_c2g_new_member_test.dart
//
// hardening2 P1 · C2G E2EE 新成员历史不可见验证（macOS，spare7=13000000007）。
// 前置（编排）：群已建、A/B 已完成 m1/m2 对话、spare7 已入群、A 已发 m3。
// 断言：spare7 进群聊页后 m1/m2 均不可见（新成员无历史 room-key，
// E2EE 前向隔离语义），m3 可见（入群后消息的 room-key 已分发到其设备）。
//
// 运行（编排脚本启动，勿单跑）：flutter test <file> -d macos ...

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _gid = String.fromEnvironment('H2_C2G_GID');
const _runTag = String.fromEnvironment('H2_RUN_TAG');
const _allow = bool.fromEnvironment('H2_C2G_REAL_RUN', defaultValue: false);

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

  testWidgets('C2G E2EE 新成员：历史 m1/m2 不可见，入群后 m3 可见', (tester) async {
    if (!_allow || _gid.isEmpty || _runTag.isEmpty) {
      markTestSkipped('需 H2_C2G_REAL_RUN=true + H2_C2G_GID/H2_RUN_TAG');
      return;
    }
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 15);
    if (!await checkPreconditions(tester)) return;
    await settle(tester, maxSeconds: 2);
    await _dismissBootPopups(tester);

    final m1 = 'h2c2g-A2G-$_runTag';
    final m2 = 'h2c2g-B2G-$_runTag';
    final m3 = 'h2c2g-M3-$_runTag';

    await GroupApi().detail(gid: _gid);
    final flagOn = await GroupSessionService.to.isGroupE2EE(_gid);
    // ignore: avoid_print
    print('[H2-C2G-NEW] spare7 旗标=$flagOn 进入群聊页');

    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).push('/chat/$_gid?type=C2G');
    await settle(tester, maxSeconds: 6);
    expect(tester.any(find.byType(ChatPage)), isTrue, reason: '群聊页应已打开');

    // 观察 75 秒：m3 应出现（room-key 已分发到 spare7 设备）；
    // m1/m2 若出现即破坏「新成员不可见历史」语义，立即失败。
    var sawM3 = false;
    for (var i = 0; i < 75; i++) {
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.any(find.text(m1)),
        isFalse,
        reason: '新成员不应看到入群前的 m1（历史 room-key 前向隔离被破坏）',
      );
      expect(
        tester.any(find.text(m2)),
        isFalse,
        reason: '新成员不应看到入群前的 m2（历史 room-key 前向隔离被破坏）',
      );
      sawM3 = sawM3 || tester.any(find.text(m3));
    }
    expect(sawM3, isTrue, reason: '新成员应看到入群后的 m3（room-key 已分发到其设备）');
    await takeScreenshot(tester, 'h2_c2g_new_member_isolated');
    // ignore: avoid_print
    print('[H2-C2G-NEW] PASS：m1/m2 不可见，m3 可见');
  }, timeout: const Timeout(Duration(minutes: 7)));
}
