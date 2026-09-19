// integration_test/two_client/h2_c2c_history_test.dart
//
// hardening2 P1 · C2C E2EE 杀进程重进验证（两端共用，参数化账号）。
// 前置：h2_c2c_{android_a,mac_b}_side_test 已完成双向对话。本测试冷启动
// 新 app 实例（= 杀进程重进），断言登录态自动恢复且两条 marker 历史
// 均解密渲染——同设备密钥仍在本地，历史可读（E2EE 语义）。
//
// 运行：flutter test <file> -d <macos|XWE6R19916004085> \
//   --dart-define=APP_ENV=local \
//   --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9800 \
//   --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/api/v1/ws \
//   --dart-define=TEST_PHONE=<账号> --dart-define=TEST_PASSWORD=Abc12345678 \
//   --dart-define=TEST_EXPECTED_UID=<uid> --dart-define=PEER_UID=<对端uid> \
//   --dart-define=H2_RUN_TAG=<tag> --dart-define=H2_C2C_REAL_RUN=true

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';

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

  testWidgets('C2C E2EE 历史重进：杀进程后两条 marker 仍解密渲染', (tester) async {
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
    // 冷启动：登录态应自动恢复（不出现登录页即已登录）
    await settle(tester, maxSeconds: 3);
    // Android 冷启动恢复会话（群自愈 + E2EE 备份页）可达 2 分钟+：
    // 4 分钟大窗口自旋，内嵌体验选择与弹窗处理。
    var shellReady = false;
    for (var i = 0; i < 720 && !shellReady; i++) {
      expect(
        isOnLoginPage(tester),
        isFalse,
        reason: '杀进程重进后登录态应保持（token 持久化），出现登录页=会话丢失',
      );
      await dismissUpgradeDialog(tester);
      await dismissE2eeRecoveryDialog(tester);
      await _softSelectChatExperienceOnce(tester);
      shellReady = isOnMainShell(tester);
      if (!shellReady) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    expect(shellReady, isTrue, reason: '主 Shell 应在重进后挂载（4 分钟大窗口）');
    await dismissRecoveryGuide(tester);

    final aToBMarker = 'h2c2c-A2B-$_runTag';
    final bToAMarker = 'h2c2c-B2A-$_runTag';

    // 进入与对端的聊天页，历史经本地库+服务端补拉后解密渲染
    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).push('/chat/$_peerUid?type=C2C');
    await settle(tester, maxSeconds: 8);
    if (!tester.any(find.byType(ChatPage))) {
      // 深链未命中时回退 widget 直推（两端同构）
      final ctx2 = tester.element(find.byType(Scaffold).first);
      // ignore: avoid_unused_constructor_parameters
      Navigator.of(ctx2).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatPage(
            type: 'C2C',
            peerId: _peerUid,
            peerTitle: 'h2-peer',
            peerAvatar: '',
            peerSign: '',
          ),
        ),
      );
      await settle(tester, maxSeconds: 8);
    }
    expect(find.byType(ChatPage), findsOneWidget, reason: '聊天页应已打开');

    var gotA = false;
    var gotB = false;
    for (var i = 0; i < 240 && !(gotA && gotB); i++) {
      await tester.pump(const Duration(seconds: 1));
      gotA =
          gotA ||
          tester.any(find.textContaining(aToBMarker, findRichText: true));
      gotB =
          gotB ||
          tester.any(find.textContaining(bToAMarker, findRichText: true));
    }
    expect(gotA, isTrue, reason: '重进后 A→B marker 历史应解密渲染（同设备密钥在本地）');
    expect(gotB, isTrue, reason: '重进后 B→A marker 历史应解密渲染（同设备密钥在本地）');
    await takeScreenshot(tester, 'h2_c2c_history_reloaded');
    drainKnownFrameworkExceptions(tester);
    // ignore: avoid_print
    print('[H2-C2C] 历史 PASS：$aToBMarker / $bToAMarker 均解密渲染');
  }, timeout: const Timeout(Duration(minutes: 14)));
}
