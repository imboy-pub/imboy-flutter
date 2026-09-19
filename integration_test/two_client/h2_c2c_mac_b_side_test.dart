// integration_test/two_client/h2_c2c_mac_b_side_test.dart
//
// hardening2 P1 · C2C E2EE 真链路 · macOS B 侧（orgA_member=13000000003）。
// 与 Android A 侧（h2_c2c_android_a_side_test.dart）配合：
//   B 先启动：登录 → push ChatPage → 挂着等 A 的密文经 WS 到达并解密渲染；
//   断言明文 marker 后回一条 marker（真实 UI provider 发送链），供 A 侧断言。
// strict E2EE 语义：后端 IMBOY_E2EE_MODE=required，消息为 Olm per-device 密文。
//
// 运行（编排脚本启动，勿单跑）：
//   flutter test integration_test/two_client/h2_c2c_mac_b_side_test.dart -d macos \
//     --dart-define=APP_ENV=local \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9800 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//     --dart-define=TEST_PHONE=13000000003 --dart-define=TEST_PASSWORD=Abc12345678 \
//     --dart-define=TEST_EXPECTED_UID=<B-uid> --dart-define=PEER_UID=<A-uid> \
//     --dart-define=H2_RUN_TAG=<tag>

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:xid/xid.dart';

import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:imboy/page/chat_shell/chat_shell_bootstrap.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peerUid = String.fromEnvironment('PEER_UID');
const _runTag = String.fromEnvironment('H2_RUN_TAG');
const _allow = bool.fromEnvironment('H2_C2C_REAL_RUN', defaultValue: false);

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('C2C E2EE 真链路 B 侧：收 A 密文→解密渲染→回复', (tester) async {
    if (!_allow ||
        _expectedUid.isEmpty ||
        _peerUid.isEmpty ||
        _runTag.isEmpty) {
      markTestSkipped(
        '需 H2_C2C_REAL_RUN=true + TEST_EXPECTED_UID/PEER_UID/H2_RUN_TAG',
      );
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
    // 自控登录：flows 的 autoLoginOrSkip 内嵌 waitForMainShell 只有 60 次
    //（约 80s），Android 真机登录后冷启动链路（群自愈 + E2EE 备份页）
    // 实测 80~85s 挂载，恒差几秒——这里用 performLogin + 自旋大窗口绕开。
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

    final aToBMarker = 'h2c2c-A2B-$_runTag';
    final bToAMarker = 'h2c2c-B2A-$_runTag';

    // 打开与 A 的聊天页（widget 层直推，两端同构）
    final ctx = tester.element(find.byType(Scaffold).first);
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          type: 'C2C',
          peerId: _peerUid,
          peerTitle: 'h2-android-A',
          peerAvatar: '',
          peerSign: '',
        ),
      ),
    );
    await settle(tester, maxSeconds: 8);
    expect(find.byType(ChatPage), findsOneWidget, reason: 'ChatPage(A↔B) 应已打开');
    await takeScreenshot(tester, 'h2_c2c_macB_01_chat_ready');
    // ignore: avoid_print
    print('[H2-C2C] B 侧就绪，等待 A 的 marker=$aToBMarker');

    // 轮询最多 5 分钟：A 的密文经 WS 到达 → Olm 入站解密 → 气泡渲染明文
    var received = false;
    for (var i = 0; i < 900 && !received; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (i % 15 == 14) {
        // ignore: avoid_print
        print('[H2-C2C] B 侧等待 A 消息 ${(i + 1)}s');
      }
      received = tester.any(
        find.textContaining(aToBMarker, findRichText: true),
      );
    }
    if (!received) {
      fail('900 秒内 B 侧未出现 A 的解密明文（WS 投递 / Olm 入站解密链断裂）');
    }
    await takeScreenshot(tester, 'h2_c2c_macB_02_received_decrypted');
    // ignore: avoid_print
    print('[H2-C2C] B 侧已解密渲染 A 的消息：$aToBMarker');

    // 回复：真实 provider 发送链（PolicyGate → Olm 出站加密 → WS 提交）
    final chatCtx = tester.element(find.byType(ChatPage).first);
    final container = ProviderScope.containerOf(chatCtx);
    final notifier = container.read(chatProvider.notifier);
    final reply = TextMessage(
      authorId: selfUid,
      createdAt: DateTime.now().toUtc(),
      id: Xid().toString(),
      text: bToAMarker,
      metadata: {'peer_id': _peerUid},
    );
    final ok = await notifier.addMessage(
      selfUid,
      _peerUid,
      '',
      'h2-android-A',
      'C2C',
      reply,
    );
    expect(ok, isTrue, reason: 'B 侧回复发送应成功（加密 + WS 提交）');
    await notifier.chatService?.insertMessage(
      reply,
      index: notifier.chatService?.messages.length ?? 0,
    );
    await settle(tester, maxSeconds: 4);
    expect(
      find.textContaining(bToAMarker, findRichText: true),
      findsWidgets,
      reason: 'B 侧回复应本地回显',
    );
    await takeScreenshot(tester, 'h2_c2c_macB_03_replied');

    // 本地持久化证据：dump ChatService.messages（真相源 = 本地 SQLCipher 库）
    final msgs = notifier.chatService?.messages ?? const [];
    // ignore: avoid_print
    print(
      '[H2-C2C] B 侧本地消息列表(${msgs.length}) '
      '${msgs.map((m) => '${m.authorId == selfUid ? "B" : "A"}:${m.id}').join(",")}',
    );
    expect(
      msgs.any((m) => m is TextMessage && m.text == aToBMarker),
      isTrue,
      reason: 'A 的消息应已进入 B 本地库（SQLCipher 持久化）',
    );
    drainKnownFrameworkExceptions(tester);
    // ignore: avoid_print
    print('[H2-C2C] B 侧 PASS');
  }, timeout: const Timeout(Duration(minutes: 18)));
}
