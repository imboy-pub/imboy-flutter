// integration_test/two_client/h2_c2g_android_a_side_test.dart
//
// hardening2 P1 · C2G E2EE 真链路 · Android 真机 A 侧（orgA_owner=13000000001，
// 群主）。前置（编排）：群已建（A 群主+B 成员）、e2ee_mode=1、B 侧已就绪。
// A：登录 → 旗标同步 → 预建 Megolm 会话（room-key 先行分发，等对端导入）
// → 白盒发送 m1 → 等 B 回复 m2 → 轮询 spare7 设备密钥上线（B 退出后
// new_member 才在 mac 登录，mac 双开共享存储会串身份，故严格串行）→
// 轮转 S2 预分发 → 发 m3 → 保活等新成员观察窗完成。
//
// orch7 教训（2026-09-19）：sendMessage 内部 rotate→room-key→m1 背靠背，
// B 侧 m1 解密先于 room-key 导入完成 → decrypt_error 且无重试 → 480s 断裂。
// 修复：发送前显式 ensureOutboundSession 预分发 room-key，静默期后再发正文
// （_resolveOutbound 幂等复用已建会话，不会二次分发）。
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
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _spare7Uid = String.fromEnvironment('H2_C2G_SPARE7_UID');
const _gid = String.fromEnvironment('H2_C2G_GID');
const _runTag = String.fromEnvironment('H2_RUN_TAG');
const _allow = bool.fromEnvironment('H2_C2G_REAL_RUN', defaultValue: false);

/// room-key 预分发后的静默期：对端收到 e2ee_room_key 帧后要走 Olm 解包
/// （可能伴随 prekey claim / history_grant 兜底）才完成会话导入。orch7
/// 实证背靠背发送时正文解密先于导入完成。macOS 侧导入链路秒级完成，
/// 15s 覆盖正常抖动（重试+网络 RTT）。
const _keySettleDelay = Duration(seconds: 15);

/// 白盒收信检测：直接查 chatProvider 内存消息列表（网络层解密入库即真）。
/// orch9 教训：Live binding 下 pump 驱动的 UI 文本断言在气泡渲染后会挂起
/// ——等待循环不依赖渲染，UI 断言仅收尾一次。
bool _inboxContains(WidgetTester tester, String marker) {
  try {
    final ctx = tester.element(find.byType(ChatPage).first);
    final container = ProviderScope.containerOf(ctx);
    final messages = container
        .read(chatProvider.notifier)
        .chatService
        ?.messages;
    return messages?.any((m) => m is TextMessage && m.text.contains(marker)) ??
        false;
  } catch (_) {
    return false;
  }
}

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

    // m1 前置：预建 Megolm 会话并先行分发 room-key（orch7 竞态修复——
    // sendMessage 内部 rotate→key→正文背靠背，对端导入未完成即解密必败）。
    // ensureOutboundSession 幂等：随后 sendMessage 复用同一会话不再分发。
    await GroupSessionService.to.ensureOutboundSession(gid: _gid);
    // ignore: avoid_print
    print('[H2-C2G] A 侧 room-key 已预分发，静默 $_keySettleDelay 等 B 导入');
    await Future<void>.delayed(_keySettleDelay);

    // m1：首条群消息（room-key 已在握，B 侧可解密）
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

    // 等 B 回复 m2（B 要等 A 先上线才会回，给足 8 分钟）。白盒检测：
    // orch9 教训（pump 驱动 UI 断言在气泡渲染后挂起），UI 断言仅收尾一次。
    var received = false;
    for (var i = 0; i < 480 && !received; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (i % 15 == 14) {
        // ignore: avoid_print
        print('[H2-C2G] A 侧等待 B 回复 ${(i + 1)}s');
      }
      received = _inboxContains(tester, bMarker);
    }
    if (!received) {
      fail('480 秒内 A 侧未解密 B 的群回复（room-key / Megolm 入站断裂）');
    }
    await settle(tester, maxSeconds: 4);
    expect(
      tester.any(find.textContaining(bMarker, findRichText: true)),
      isTrue,
      reason: 'A 侧应渲染 B 的回复',
    );
    await takeScreenshot(tester, 'h2_c2g_andA_03_reply_decrypted');
    // ignore: avoid_print
    print('[H2-C2G] A 侧已解密 B 的回复：$bMarker');

    // 新成员阶段：编排哨兵在「B 侧已回复」后经 API 把 spare7 拉入群（世代
    // 推进），等 B 侧实例退出后在 mac 上以 spare7 登录（发布设备密钥）。
    // 本侧轮询群设备快照直到 spare7 的设备密钥可见（最多 8 分钟——覆盖
    // B 退出+mac 构建+spare7 登录上报），再轮转 S2 分发、静默后发 m3。
    var spare7Online = false;
    if (_spare7Uid.isNotEmpty) {
      for (var i = 0; i < 96 && !spare7Online; i++) {
        await Future<void>.delayed(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 300));
        try {
          final keys = await E2EEService.getGroupDevicePublicKeys(
            _gid,
            forceRefresh: true,
          );
          final didToUid = keys['didToUid'] ?? const <String, String>{};
          spare7Online = didToUid.values.any((v) => v == _spare7Uid);
        } catch (_) {}
        if (i % 6 == 5) {
          // ignore: avoid_print
          print(
            '[H2-C2G] A 侧等待 spare7 设备上线 ${(i + 1) * 5}s online=$spare7Online',
          );
        }
      }
      if (!spare7Online) {
        fail('8 分钟内未见到 spare7 设备密钥（new_member 登录/上报未完成），无法安全发 m3');
      }
    } else {
      // 未传 spare7 uid：退回固定等待（编排保证 join 已落地）
      await Future<void>.delayed(const Duration(seconds: 15));
    }
    await GroupApi().detail(gid: _gid);
    // 成员变化 → 显式 stale + 预分发：S2 轮转的 room-key 覆盖 spare7 设备，
    // 静默期后再发 m3（与 m1 同法规避 orch7 竞态）。
    GroupSessionService.to.markGroupStale(_gid);
    await GroupSessionService.to.ensureOutboundSession(gid: _gid);
    // ignore: avoid_print
    print('[H2-C2G] A 侧 S2 room-key 已预分发（含 spare7），静默 $_keySettleDelay');
    await Future<void>.delayed(_keySettleDelay);
    final ok3 = await _sendGroupText(tester, _gid, selfUid, m3Marker);
    expect(ok3, isTrue, reason: 'A 侧 m3（新成员在场）发送应成功');
    // _sendGroupText 内 insertMessage 已入列表，白盒确认回显即可
    var sawM3 = false;
    for (var i = 0; i < 30 && !sawM3; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      sawM3 = _inboxContains(tester, m3Marker);
    }
    expect(sawM3, isTrue, reason: 'A 侧应看到自己的 m3 回显');
    await takeScreenshot(tester, 'h2_c2g_andA_04_m3_sent');
    // ignore: avoid_print
    print('[H2-C2G] A 侧 m3 已发送并回显：$m3Marker');

    // 保持存活 ~7 分钟：spare7 的设备密钥上报早于其主 shell 就绪，m3 可能
    // 先于其进群聊页到达（offline 拉取+grant 兜底路径），保活覆盖其全程。
    for (var i = 0; i < 420; i++) {
      await tester.pump(const Duration(seconds: 1));
      if (i % 60 == 59) {
        // ignore: avoid_print
        print('[H2-C2G] A 侧存活保活 ${i + 1}s（等新成员观察窗完成）');
      }
    }
    drainKnownFrameworkExceptions(tester);
    // ignore: avoid_print
    print('[H2-C2G] A 侧 PASS');
  }, timeout: const Timeout(Duration(minutes: 40)));
}
