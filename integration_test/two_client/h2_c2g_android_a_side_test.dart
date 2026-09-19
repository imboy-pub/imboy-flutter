// integration_test/two_client/h2_c2g_android_a_side_test.dart
//
// hardening2 P1 · C2G E2EE 真链路 · Android 真机 A 侧（orgA_owner=13000000001，
// 群主）。前置（编排）：群已建（A 群主+B 成员）、e2ee_mode=1、B 侧已就绪。
// A：登录 → 旗标同步 → 白盒 Megolm 发送 m1（分发 room-key）→ 等 B 回复 m2 →
// 再发 m3（此时新成员 spare7 已入群但其设备尚未上线）→ m3 后保持存活
// ~7 分钟：新成员测试此刻在 mac 上登录 spare7 并发起 room-key 请求，
// 需要本侧在线应答（分享当前 ratchet，前向隔离入群前的 m1/m2）。
//
// 运行（编排脚本启动，勿单跑）：flutter test <file> -d XWE6R19916004085 ...

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

/// 白盒 C2G 发送 + 本地回显：ChatNetworkService.sendMessage 只走网络链
/// （Megolm 出站+WS），不写本地聊天列表——C2C 的 addMessage 才带本地落库。
/// 群聊页断言回显前需手动 insertMessage（与 C2C 同法，写本地 SQLCipher）。
Future<bool> _sendGroupText(
  WidgetTester tester,
  String gid,
  String selfUid,
  String text,
) async {
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
  if (!ok) return false;
  final chatCtx = tester.element(find.byType(ChatPage).first);
  final container = ProviderScope.containerOf(chatCtx);
  final notifier = container.read(chatProvider.notifier);
  final echo = TextMessage(
    authorId: selfUid,
    createdAt: DateTime.now().toUtc(),
    id: msgId,
    text: text,
    metadata: <String, dynamic>{'peer_id': gid},
  );
  await notifier.chatService?.insertMessage(
    echo,
    index: notifier.chatService?.messages.length ?? 0,
  );
  await settle(tester, maxSeconds: 3);
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('C2G E2EE 真链路 A 侧：发密文→B 解密回复→m3+新成员密钥应答', (tester) async {
    if (!_allow || _gid.isEmpty || _runTag.isEmpty) {
      markTestSkipped('需 H2_C2G_REAL_RUN=true + H2_C2G_GID/H2_RUN_TAG');
      return;
    }
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 20);

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
    // flutter test 在 Android 上每轮重装 app（数据清空）→ 必走
    // Welcome 引导页 → 登录页 → performLogin 首启全流程。低端机页面切换
    // 慢，welcome→login 与 login 判定均需多轮重试与加长等待。
    if (!FlowConfig.hasCredentials) {
      markTestSkipped('未配置 TEST_PHONE / TEST_PASSWORD，跳过');
      return;
    }
    var loginDone = UserRepoLocal.to.isLoggedIn;
    for (var round = 0; round < 6 && !loginDone; round++) {
      flowLog(
        '[H2] 登录重试轮 $round: welcome=${isOnWelcomePage(tester)} login=${isOnLoginPage(tester)}',
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
        // 登录失败（网络/控件时序）：等 10s 再进下一轮重试
        await Future<void>.delayed(const Duration(seconds: 10));
      } else {
        // 既无 welcome 也无 login（仍在 splash/初始化）：等 15s 再查
        await Future<void>.delayed(const Duration(seconds: 15));
      }
    }
    if (!loginDone && !UserRepoLocal.to.isLoggedIn) {
      markTestSkipped('多轮登录未完成（welcome/login 均未达），跳过');
      return;
    }
    // 主 Shell 只是软目标：EMUI9 32 位低端机内存压力下 BottomNavigationPage
    // 挂载可达 10 分钟+，但登录会话/WS/本地库此时均已就绪（实证：WS 连接成功
    // + 群自愈完成）。ChatPage 直推不依赖主 Shell 导航壳——等待 120s 后无论
    // shell 与否继续推进。
    for (var i = 0; i < 120; i++) {
      await dismissUpgradeDialog(tester);
      await dismissE2eeRecoveryDialog(tester);
      await _softSelectChatExperienceOnce(tester);
      if (isOnMainShell(tester)) break;
      await Future<void>.delayed(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
    }

    final selfUid = UserRepoLocal.to.currentUid;
    if (selfUid != _expectedUid) {
      fail('登录账号 UID=$selfUid 与 A 侧授权账号 $_expectedUid 不一致');
    }
    await dismissRecoveryGuide(tester);
    await _softSelectChatExperienceOnce(tester);

    final aMarker = 'h2c2g-A2G-$_runTag';
    final bMarker = 'h2c2g-B2G-$_runTag';
    final m3Marker = 'h2c2g-M3-$_runTag';

    // 旗标同步须在登录完成后进行（未登录调用 detail 会被 401 打断）
    await GroupApi().detail(gid: _gid);
    final flagOn = await GroupSessionService.to.isGroupE2EE(_gid);
    expect(flagOn, isTrue, reason: '群 e2ee 旗标应已同步（detail 带 e2ee_mode=1）');

    // 打开群聊页：优先深链（需 router 已就绪），失败回退 widget 直推
    final ctx = tester.element(find.byType(Scaffold).first);
    GoRouter.of(ctx).push('/chat/$_gid?type=C2G');
    await settle(tester, maxSeconds: 8);
    if (!tester.any(find.byType(ChatPage))) {
      // ignore: avoid_unused_constructor_parameters
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
    await takeScreenshot(tester, 'h2_c2g_andA_01_chat_ready');

    // m1：首条群消息（触发 room-key 按设备 Olm 分发）
    final ok1 = await _sendGroupText(tester, _gid, selfUid, aMarker);
    expect(ok1, isTrue, reason: 'A 侧群消息发送应成功（Megolm 出站+room-key 分发+WS）');
    await settle(tester, maxSeconds: 4);
    expect(
      find.textContaining(aMarker, findRichText: true),
      findsWidgets,
      reason: 'A 侧 m1 应本地回显',
    );
    await takeScreenshot(tester, 'h2_c2g_andA_02_m1_sent');
    // ignore: avoid_print
    print('[H2-C2G] A 侧已发送 m1：$aMarker');

    // 等 B 回复 m2 解密渲染（B 要等 A 先上线才会回，给足 8 分钟）
    var received = false;
    for (var i = 0; i < 480 && !received; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (i % 15 == 14) {
        // ignore: avoid_print
        print('[H2-C2G] A 侧等待 B 回复 ${(i + 1)}s');
      }
      received = tester.any(find.textContaining(bMarker, findRichText: true));
    }
    if (!received) {
      fail('480 秒内 A 侧未解密 B 的群回复（room-key / Megolm 入站断裂）');
    }
    await takeScreenshot(tester, 'h2_c2g_andA_03_reply_decrypted');
    // ignore: avoid_print
    print('[H2-C2G] A 侧已解密 B 的回复：$bMarker');

    // 新成员阶段：编排哨兵此刻正把 spare7 经 API 入群（世代推进）。
    // 等 15s 让入群事务落地，再 detail 刷新成员表——ensureOutboundSession
    // 检测到成员变化后轮转 Megolm 会话（S2），room-key 覆盖 spare7 新设备。
    await Future<void>.delayed(const Duration(seconds: 15));
    await GroupApi().detail(gid: _gid);
    final ok3 = await _sendGroupText(tester, _gid, selfUid, m3Marker);
    expect(ok3, isTrue, reason: 'A 侧 m3（新成员在场）发送应成功');
    var sawM3 = false;
    for (var i = 0; i < 60 && !sawM3; i++) {
      await tester.pump(const Duration(seconds: 1));
      sawM3 = tester.any(find.textContaining(m3Marker, findRichText: true));
    }
    expect(sawM3, isTrue, reason: 'A 侧应看到自己的 m3 回显');
    await takeScreenshot(tester, 'h2_c2g_andA_04_m3_sent');
    // ignore: avoid_print
    print('[H2-C2G] A 侧 m3 已发送并回显：$m3Marker');

    // 保持存活 ~5 分钟：新成员（早启动）此刻应已登录并进入观察窗解 m3。
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (i % 60 == 59) {
        // ignore: avoid_print
        print('[H2-C2G] A 侧存活保活 ${i + 1}s（等新成员 key-request 完成）');
      }
    }
    drainKnownFrameworkExceptions(tester);
    // ignore: avoid_print
    print('[H2-C2G] A 侧 PASS');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
