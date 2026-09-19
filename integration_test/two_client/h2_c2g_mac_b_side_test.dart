// integration_test/two_client/h2_c2g_mac_b_side_test.dart
//
// hardening2 P1 · C2G E2EE 真链路 · macOS B 侧（orgA_member=13000000003）。
// 前置（编排脚本铺底）：A 已建群（member_uids 含 B）、set_e2ee_mode=1。
// B 侧：登录 → 群详情同步 e2ee 旗标 → 深链群聊页 → 等 A 的 Megolm 密文
// 经 WS 到达（room-key 已按设备 Olm 分发）→ 解密渲染断言 → 回复 marker。
//
// 运行（编排脚本启动，勿单跑）：
//   flutter test <file> -d macos --dart-define=...（同 h2_c2c 系列 + H2_C2G_GID）

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
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

  testWidgets('C2G E2EE 真链路 B 侧：收 room-key→解密群消息→回复', (tester) async {
    if (!_allow || _gid.isEmpty || _runTag.isEmpty) {
      markTestSkipped('需 H2_C2G_REAL_RUN=true + H2_C2G_GID/H2_RUN_TAG');
      return;
    }
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 15);
    if (!await checkPreconditions(tester)) return;
    await settle(tester, maxSeconds: 2);
    await _dismissBootPopups(tester);

    final selfUid = UserRepoLocal.to.currentUid;
    final aMarker = 'h2c2g-A2G-$_runTag';
    final bMarker = 'h2c2g-B2G-$_runTag';

    await GroupApi().detail(gid: _gid);
    final flagOn = await GroupSessionService.to.isGroupE2EE(_gid);
    // ignore: avoid_print
    print('[H2-C2G] B 侧旗标 flagOn=$flagOn gid=$_gid 等 A marker=$aMarker');

    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).push('/chat/$_gid?type=C2G');
    await settle(tester, maxSeconds: 6);
    if (!tester.any(find.byType(ChatPage))) {
      fail('群聊页未打开（深链 /chat/$_gid?type=C2G 失败）');
    }
    await takeScreenshot(tester, 'h2_c2g_macB_01_ready');
    // ignore: avoid_print
    print('[H2-C2G] B 侧就绪，等待 A 的 marker=$aMarker');

    var received = false;
    for (var i = 0; i < 300 && !received; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (i % 15 == 14) {
        // ignore: avoid_print
        print('[H2-C2G] B 侧等待 A 群消息 ${(i + 1)}s');
      }
      received = tester.any(find.text(aMarker));
    }
    if (!received) {
      fail('300 秒内 B 侧未解密 A 的群消息（room-key Olm 分发 / Megolm 入站解密断裂）');
    }
    await takeScreenshot(tester, 'h2_c2g_macB_02_received');
    // ignore: avoid_print
    print('[H2-C2G] B 侧已解密 A 的群消息：$aMarker');

    // 回复：白盒 C2G 发送链（groupMegolm → ensureOutboundSession → WS）
    final msgId =
        'h2c2gb${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final ok = await const ChatNetworkService().sendMessage({
      'id': msgId,
      'type': 'C2G',
      'from': selfUid,
      'to': _gid,
      'msg_type': 'text',
      'action': '',
      'payload': <String, dynamic>{'msg_type': 'text', 'text': bMarker},
    });
    expect(ok, isTrue, reason: 'B 侧群消息回复应成功（Megolm 出站+WS）');
    await settle(tester, maxSeconds: 4);
    // ignore: avoid_print
    print('[H2-C2G] B 侧已回复：$bMarker msgId=$msgId');

    // 等新成员阶段 A 的第三条（可选加分：B 也能看到 m3）
    var sawM3 = false;
    const m3Marker = String.fromEnvironment('H2_C2G_M3');
    if (m3Marker.isNotEmpty) {
      for (var i = 0; i < 120 && !sawM3; i++) {
        await tester.pump(const Duration(seconds: 1));
        sawM3 = tester.any(find.text(m3Marker));
      }
    }
    // ignore: avoid_print
    print('[H2-C2G] B 侧 sawM3=$sawM3 PASS');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 11)));
}
