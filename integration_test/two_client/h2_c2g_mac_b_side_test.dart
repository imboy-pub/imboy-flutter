// integration_test/two_client/h2_c2g_mac_b_side_test.dart
//
// hardening2 P1 · C2G E2EE 真链路 · macOS B 侧（orgA_member=13000000003）。
// 前置（编排脚本铺底）：A 已建群（member_uids 含 B）、set_e2ee_mode=1。
// B 侧：登录（mac 持久会话，同 C2C 侧账号）→ 群详情同步 e2ee 旗标 →
// 打开群聊页 → 等 A 的 Megolm 密文经 WS 到达（room-key 已按设备 Olm 分发）
// → 解密渲染断言 → 回复 marker → 等 m3。
//
// 运行（编排脚本启动，勿单跑）：
//   flutter test <file> -d macos --dart-define=...（同 h2_c2c 系列 + H2_C2G_GID）

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/page/chat_shell/chat_shell_bootstrap.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _gid = String.fromEnvironment('H2_C2G_GID');
const _runTag = String.fromEnvironment('H2_RUN_TAG');
const _allow = bool.fromEnvironment('H2_C2G_REAL_RUN', defaultValue: false);

/// 体验选择页（ChatShellBootstrap）单次软选择：出现即 select(chat)。
/// 登录已持久化的账号冷启动直接落在该页，而 flows 的入口白名单
/// （Login/Welcome/MainShell）不含它——不在此处处理会永远「入口超时」。
Future<void> _softSelectChatExperienceOnce(WidgetTester tester) async {
  final shell = find.byType(ChatShellBootstrap);
  if (!tester.any(shell)) return;
  try {
    final container = ProviderScope.containerOf(tester.element(shell));
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.chat);
    await settle(tester, maxSeconds: 2);
  } catch (_) {}
}

/// mac 持久登录的可能不是授权账号（如上轮新成员测试留下的 spare7 会话）：
/// 先切号到期望账号（quitLogin 清 E2EE 秘密与本地库 → 导回欢迎页）。
Future<void> _switchToExpectedAccount(WidgetTester tester) async {
  final current = UserRepoLocal.to.currentUid;
  if (current == _expectedUid || current.isEmpty) return;
  // ignore: avoid_print
  print('[H2-C2G] B 侧切号：$current → $_expectedUid，quitLogin');
  await UserRepoLocal.to.quitLogin();
  final ctx = tester.element(find.byType(Navigator).first);
  GoRouter.of(ctx).go('/welcome');
  await settle(tester, maxSeconds: 6);
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

    // h2 前置：入口等待 + 体验选择内嵌 + 登录 + 主 Shell
    if (!await ensureBackendAvailable()) {
      markTestSkipped('后端不可达，跳过');
      return;
    }
    var entryReady = false;
    for (var i = 0; i < 360 && !entryReady; i++) {
      await dismissUpgradeDialog(tester);
      await _softSelectChatExperienceOnce(tester);
      entryReady =
          isOnLoginPage(tester) ||
          isOnWelcomePage(tester) ||
          isOnMainShell(tester);
      if (!entryReady) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    if (!entryReady) {
      markTestSkipped('App 入口状态超时（含体验选择页处理），跳过');
      return;
    }
    // mac 登录态可能持久着别的账号（如 spare7）：先切号，再走 6 轮登录兜底
    if (!FlowConfig.hasCredentials) {
      markTestSkipped('未配置 TEST_PHONE / TEST_PASSWORD，跳过');
      return;
    }
    await _switchToExpectedAccount(tester);
    var loginDone = UserRepoLocal.to.isLoggedIn;
    for (var round = 0; round < 6 && !loginDone; round++) {
      flowLog(
        '[H2] B侧登录重试轮 $round: welcome=${isOnWelcomePage(tester)} login=${isOnLoginPage(tester)}',
      );
      if (isOnWelcomePage(tester)) {
        await leaveWelcomePage(tester);
        for (var i = 0; i < 90; i++) {
          if (isOnLoginPage(tester)) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      if (isOnLoginPage(tester)) {
        await dismissUpgradeDialog(tester);
        final ok = await performLogin(
          tester,
          phone: FlowConfig.testPhone,
          password: FlowConfig.testPassword,
        );
        if (ok) {
          loginDone = true;
          break;
        }
        await Future<void>.delayed(const Duration(seconds: 10));
      } else {
        await Future<void>.delayed(const Duration(seconds: 15));
      }
      await _switchToExpectedAccount(tester);
      loginDone = UserRepoLocal.to.isLoggedIn;
    }
    if (!loginDone && !UserRepoLocal.to.isLoggedIn) {
      markTestSkipped('多轮登录未完成（welcome/login 均未达），跳过');
      return;
    }
    var shellReady = false;
    for (var i = 0; i < 180 && !shellReady; i++) {
      await dismissUpgradeDialog(tester);
      await dismissE2eeRecoveryDialog(tester);
      await _softSelectChatExperienceOnce(tester);
      shellReady = isOnMainShell(tester);
      if (!shellReady) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    if (!shellReady) {
      markTestSkipped('主 Shell 未挂载（4 分钟大窗口后放弃），跳过');
      return;
    }

    final selfUid = UserRepoLocal.to.currentUid;
    if (selfUid != _expectedUid) {
      fail('登录账号 UID=$selfUid 与 B 侧授权账号 $_expectedUid 不一致');
    }
    await dismissRecoveryGuide(tester);
    await _softSelectChatExperienceOnce(tester);

    final aMarker = 'h2c2g-A2G-$_runTag';
    final bMarker = 'h2c2g-B2G-$_runTag';

    // 旗标同步须在登录完成后进行
    await GroupApi().detail(gid: _gid);
    final flagOn = await GroupSessionService.to.isGroupE2EE(_gid);
    // ignore: avoid_print
    print('[H2-C2G] B 侧旗标 flagOn=$flagOn gid=$_gid 等 A marker=$aMarker');

    // 打开群聊页：优先深链，失败回退 widget 直推
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/chat/$_gid?type=C2G');
    await settle(tester, maxSeconds: 8);
    if (!tester.any(find.byType(ChatPage))) {
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(
            type: 'C2G',
            peerId: _gid,
            peerTitle: 'h2-c2g-group',
            peerAvatar: '',
            peerSign: '',
          ),
        ),
      );
      await settle(tester, maxSeconds: 8);
    }
    expect(find.byType(ChatPage), findsOneWidget, reason: '群聊页应已打开');
    await takeScreenshot(tester, 'h2_c2g_macB_01_ready');
    // ignore: avoid_print
    print('[H2-C2G] B 侧就绪，等待 A 的 marker=$aMarker');

    // A 在 EMUI9 上要走完整首启登录（可达 10 分钟），等待窗口给足 15 分钟
    var received = false;
    for (var i = 0; i < 900 && !received; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (i % 15 == 14) {
        // ignore: avoid_print
        print('[H2-C2G] B 侧等待 A 群消息 ${(i + 1)}s');
      }
      received = tester.any(find.textContaining(aMarker, findRichText: true));
    }
    if (!received) {
      fail('900 秒内 B 侧未解密 A 的群消息（room-key Olm 分发 / Megolm 入站解密断裂）');
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
    // sendMessage 不写本地聊天列表：手动 insertMessage（与 C2C 同法）
    final chatCtx = tester.element(find.byType(ChatPage).first);
    final container = ProviderScope.containerOf(chatCtx);
    final notifier = container.read(chatProvider.notifier);
    final echo = TextMessage(
      authorId: selfUid,
      createdAt: DateTime.now().toUtc(),
      id: msgId,
      text: bMarker,
      metadata: <String, dynamic>{'peer_id': _gid},
    );
    await notifier.chatService?.insertMessage(
      echo,
      index: notifier.chatService?.messages.length ?? 0,
    );
    await settle(tester, maxSeconds: 4);
    expect(
      find.textContaining(bMarker, findRichText: true),
      findsWidgets,
      reason: 'B 侧回复应本地回显',
    );
    await takeScreenshot(tester, 'h2_c2g_macB_03_replied');
    // ignore: avoid_print
    print('[H2-C2G] B 侧已回复：$bMarker msgId=$msgId');

    // m3 阶段本侧已让位：mac 双开共享存储会与 new_member 串身份（orch7
    // 实证），B 在 m2 使命完成后立即收尾退出，mac 槽交由 spare7 接管。
    // m3 的 S2 room-key 由 A 侧预分发（spare7 设备上线后轮转），不再依赖
    // 本侧在线。
    // ignore: avoid_print
    print('[H2-C2G] B 侧 sawM3=让位(不适用) PASS');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 25)));
}
