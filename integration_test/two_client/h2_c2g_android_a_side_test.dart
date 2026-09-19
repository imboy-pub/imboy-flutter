// integration_test/two_client/h2_c2g_android_a_side_test.dart
//
// hardening2 P1 · C2G E2EE 真链路 · Android 真机 A 侧（orgA_owner=13000000001，
// 群主）。前置（编排）：群已建（A 群主+B 成员）、e2ee_mode=1、B 侧已就绪。
// A：登录 → 旗标同步 → 白盒 Megolm 发送 m1（分发 room-key）→ 等 B 回复 m2 →
// [新成员阶段] 编排已让 spare7 入群 → 再发 m3 → 断言 m2/m3 均解密渲染。
//
// 运行（编排脚本启动，勿单跑）：flutter test <file> -d XWE6R19916004085 ...

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

Future<bool> _sendGroupText(String gid, String selfUid, String text) async {
  final msgId =
      'h2c2ga${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
  final ok = await const ChatNetworkService().sendMessage({
    'id': msgId,
    'type': 'C2G',
    'from': selfUid,
    'to': gid,
    'msg_type': 'text',
    'action': '',
    'payload': <String, dynamic>{'msg_type': 'text', 'text': text},
  });
  return ok;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('C2G E2EE 真链路 A 侧：发密文→B 解密回复→新成员后续消息', (tester) async {
    if (!_allow || _gid.isEmpty || _runTag.isEmpty) {
      markTestSkipped('需 H2_C2G_REAL_RUN=true + H2_C2G_GID/H2_RUN_TAG');
      return;
    }
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 20);
    if (!await checkPreconditions(tester)) return;
    await settle(tester, maxSeconds: 2);
    await _dismissBootPopups(tester);

    final selfUid = UserRepoLocal.to.currentUid;
    final aMarker = 'h2c2g-A2G-$_runTag';
    final bMarker = 'h2c2g-B2G-$_runTag';
    final m3Marker = 'h2c2g-M3-$_runTag';

    await GroupApi().detail(gid: _gid);
    final flagOn = await GroupSessionService.to.isGroupE2EE(_gid);
    expect(flagOn, isTrue, reason: '群 e2ee 旗标应已同步（detail 带 e2ee_mode=1）');

    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).push('/chat/$_gid?type=C2G');
    await settle(tester, maxSeconds: 6);
    expect(tester.any(find.byType(ChatPage)), isTrue, reason: '群聊页应已打开');
    await takeScreenshot(tester, 'h2_c2g_andA_01_ready');

    // m1：首条群消息（触发 room-key 按设备 Olm 分发）
    final ok1 = await _sendGroupText(_gid, selfUid, aMarker);
    expect(ok1, isTrue, reason: 'A 侧群消息发送应成功（Megolm 出站+room-key 分发+WS）');
    // ignore: avoid_print
    print('[H2-C2G] A 侧已发送 m1：$aMarker');

    // 等 B 回复 m2 解密渲染
    var received = false;
    for (var i = 0; i < 300 && !received; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (i % 15 == 14) {
        // ignore: avoid_print
        print('[H2-C2G] A 侧等待 B 回复 ${(i + 1)}s');
      }
      received = tester.any(find.text(bMarker));
    }
    expect(
      received,
      isTrue,
      reason: '300 秒内 A 侧未解密 B 的群回复（room-key / Megolm 入站断裂）',
    );
    await takeScreenshot(tester, 'h2_c2g_andA_02_reply_decrypted');
    // ignore: avoid_print
    print('[H2-C2G] A 侧已解密 B 的回复：$bMarker');

    // 新成员阶段：spare7 已由编排入群，A 发 m3（room-key 应分发到新设备）
    await Future<void>.delayed(const Duration(seconds: 5));
    final ok3 = await _sendGroupText(_gid, selfUid, m3Marker);
    expect(ok3, isTrue, reason: 'A 侧 m3（新成员在场）发送应成功');
    var sawM3 = false;
    for (var i = 0; i < 60 && !sawM3; i++) {
      await tester.pump(const Duration(seconds: 1));
      sawM3 = tester.any(find.text(m3Marker));
    }
    expect(sawM3, isTrue, reason: 'A 侧应看到自己的 m3 回显');
    // ignore: avoid_print
    print('[H2-C2G] A 侧 m3 已发送并回显：$m3Marker PASS');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 11)));
}
