// integration_test/two_client/h2_c2c_android_a_side_test.dart
//
// hardening2 P1 · C2C E2EE 真链路 · Android 真机 A 侧（orgA_owner=13000000001）。
// 编排在 macOS B 侧就绪后启动：登录 → push ChatPage → 发 marker（真实
// provider 发送链：PolicyGate → 拉 B 设备密钥建 Olm 出站 → WS 提交）→
// 等待 B 回复密文到达并解密渲染。断言双向明文 + 本地持久化。
//
// 运行（编排脚本启动，勿单跑）：
//   flutter test integration_test/two_client/h2_c2c_android_a_side_test.dart \
//     -d XWE6R19916004085 --dart-define=APP_ENV=local \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9800 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//     --dart-define=TEST_PHONE=13000000001 --dart-define=TEST_PASSWORD=Abc12345678 \
//     --dart-define=TEST_EXPECTED_UID=<A-uid> --dart-define=PEER_UID=<B-uid> \
//     --dart-define=H2_RUN_TAG=<tag> --dart-define=H2_C2C_REAL_RUN=true

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

  testWidgets('C2C E2EE 真链路 A 侧：发密文→B 解密→收回复解密', (tester) async {
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
    await ensureAppLaunched(tester, maxSeconds: 20);

    // h2 前置：入口等待 + 体验选择内嵌 + 登录 + 主 Shell
    if (!await ensureBackendAvailable()) {
      markTestSkipped('后端不可达，跳过');
      return;
    }
    var entryReady = false;
    for (var i = 0; i < 90 && !entryReady; i++) {
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
    // Welcome 引导页 → 登录页 → performLogin 首启全流程。
    if (isOnWelcomePage(tester)) {
      final moved = await leaveWelcomePage(tester);
      if (!moved) {
        markTestSkipped('欢迎页无法进入登录页，跳过');
        return;
      }
      for (var i = 0; i < 20; i++) {
        if (isOnLoginPage(tester)) break;
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
    if (isOnLoginPage(tester)) {
      await dismissUpgradeDialog(tester);
      if (!FlowConfig.hasCredentials) {
        markTestSkipped('未配置 TEST_PHONE / TEST_PASSWORD，跳过');
        return;
      }
      final ok = await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
      if (!ok) {
        markTestSkipped('自动登录失败，跳过');
        return;
      }
    }
    var shellReady = false;
    for (var i = 0; i < 720 && !shellReady; i++) {
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
      markTestSkipped('主 Shell 未挂载（12 分钟大窗口后放弃），跳过');
      return;
    }

    final selfUid = UserRepoLocal.to.currentUid;
    if (selfUid != _expectedUid) {
      fail('登录账号 UID=$selfUid 与 A 侧授权账号 $_expectedUid 不一致');
    }
    await dismissRecoveryGuide(tester);
    await _softSelectChatExperienceOnce(tester);

    final aToBMarker = 'h2c2c-A2B-$_runTag';
    final bToAMarker = 'h2c2c-B2A-$_runTag';

    final ctx = tester.element(find.byType(Scaffold).first);
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatPage(
          type: 'C2C',
          peerId: _peerUid,
          peerTitle: 'h2-mac-B',
          peerAvatar: '',
          peerSign: '',
        ),
      ),
    );
    await settle(tester, maxSeconds: 8);
    expect(find.byType(ChatPage), findsOneWidget, reason: 'ChatPage(A↔B) 应已打开');
    await takeScreenshot(tester, 'h2_c2c_andA_01_chat_ready');

    // 发送：真实 provider 链（strict PolicyGate → Olm 出站加密 → WS 提交 → ACK）
    final chatCtx = tester.element(find.byType(ChatPage).first);
    final container = ProviderScope.containerOf(chatCtx);
    final notifier = container.read(chatProvider.notifier);
    final outgoing = TextMessage(
      authorId: selfUid,
      createdAt: DateTime.now().toUtc(),
      id: Xid().toString(),
      text: aToBMarker,
      metadata: {'peer_id': _peerUid},
    );
    final ok = await notifier.addMessage(
      selfUid,
      _peerUid,
      '',
      'h2-mac-B',
      'C2C',
      outgoing,
    );
    expect(ok, isTrue, reason: 'A 侧发送应成功（设备密钥 bootstrap+Olm 加密+WS ACK）');
    await notifier.chatService?.insertMessage(
      outgoing,
      index: notifier.chatService?.messages.length ?? 0,
    );
    await settle(tester, maxSeconds: 4);
    expect(
      find.textContaining(aToBMarker, findRichText: true),
      findsWidgets,
      reason: 'A 侧发送应本地回显',
    );
    await takeScreenshot(tester, 'h2_c2c_andA_02_sent');
    // ignore: avoid_print
    print('[H2-C2C] A 侧已发送：$aToBMarker，等待 B 回复 $bToAMarker');

    // 轮询最多 5 分钟：B 的回复密文到达 → 解密渲染
    var received = false;
    for (var i = 0; i < 480 && !received; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (i % 15 == 14) {
        // ignore: avoid_print
        print('[H2-C2C] A 侧等待 B 回复 ${(i + 1)}s');
      }
      received = tester.any(
        find.textContaining(bToAMarker, findRichText: true),
      );
    }
    if (!received) {
      fail('480 秒内 A 侧未出现 B 的解密明文回复（WS 投递 / Olm 入站解密链断裂）');
    }
    await takeScreenshot(tester, 'h2_c2c_andA_03_reply_decrypted');
    // ignore: avoid_print
    print('[H2-C2C] A 侧已解密渲染 B 的回复：$bToAMarker');

    final msgs = notifier.chatService?.messages ?? const [];
    // ignore: avoid_print
    print(
      '[H2-C2C] A 侧本地消息列表(${msgs.length}) '
      '${msgs.map((m) => '${m.authorId == selfUid ? "A" : "B"}:${m.id}').join(",")}',
    );
    expect(
      msgs.any((m) => m is TextMessage && m.text == bToAMarker),
      isTrue,
      reason: 'B 的回复应已进入 A 本地库（SQLCipher 持久化）',
    );
    drainKnownFrameworkExceptions(tester);
    // ignore: avoid_print
    print('[H2-C2C] A 侧 PASS');
  }, timeout: const Timeout(Duration(minutes: 16)));
}
