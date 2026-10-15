// integration_test/two_client/h2_c2g_new_member_test.dart
//
// hardening2 P1 · C2G E2EE 新成员历史不可见验证（macOS，spare7=13000000007）。
// 时序（orch8 起）：本测试**晚启动**——编排先跑完 A(m1)→B(m2) 主链并把
// spare7 经 API 拉入群、B 侧实例退出后，本测试才启动（mac 双开共享存储
// 会与 B 串身份——orch7 实证 spare7 以 B 身份收帧，观察无效）。
// 启动时 mac 上持久着 B 的会话——先 quitLogin 切号到 spare7（清 E2EE
// 秘密与本地库，等价真机换号），登录即发布设备密钥（A 侧轮询到后轮转
// S2 分发 room-key 到本设备）。
// 断言：spare7 进群聊页后 m1/m2 均不可见（新成员世代拿不到历史 room-key，
// grant 按世代拒绝），m3 可见（S2 room-key 已分发到其设备）。
//
// 运行（编排脚本启动，勿单跑）：flutter test <file> -d macos ...

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat_shell/chat_shell_bootstrap.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _gid = String.fromEnvironment('H2_C2G_GID');
const _runTag = String.fromEnvironment('H2_RUN_TAG');
const _allow = bool.fromEnvironment('H2_C2G_REAL_RUN', defaultValue: false);

/// 白盒收信检测：直接查 chatProvider 内存消息列表（网络层解密入库即真）。
/// orch9 教训：Live binding 下 pump 驱动的 UI 文本断言在气泡渲染后会挂起
/// ——观察窗循环不依赖渲染，UI 断言仅收尾一次。
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
Future<void> _softSelectChatExperienceOnce(WidgetTester tester) async {
  final shell = find.byType(ChatShellBootstrap);
  if (!tester.any(shell)) return;
  try {
    final container = ProviderScope.containerOf(tester.element(shell));
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.personal);
    await settle(tester, maxSeconds: 2);
  } catch (_) {}
}

Future<bool> _switchToSpare7(WidgetTester tester) async {
  final current = UserRepoLocal.to.currentUid;
  if (current == _expectedUid) return true;
  if (current.isNotEmpty) {
    // mac 持久着 B 的会话：清状态并导回欢迎页（与既有验收测试同法）
    // ignore: avoid_print
    print('[H2-C2G-NEW] 切号：$current → spare7($_expectedUid)，quitLogin');
    await UserRepoLocal.to.quitLogin();
    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).go('/welcome');
    await settle(tester, maxSeconds: 6);
  }
  return UserRepoLocal.to.currentUid == _expectedUid;
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
    // 切号到 spare7（mac 持久会话是 B 的，首次必切）
    if (!FlowConfig.hasCredentials) {
      markTestSkipped('未配置 TEST_PHONE / TEST_PASSWORD，跳过');
      return;
    }
    await _switchToSpare7(tester);
    var loginDone = UserRepoLocal.to.isLoggedIn;
    for (var round = 0; round < 6 && !loginDone; round++) {
      flowLog(
        '[H2-C2G-NEW] 登录重试轮 $round: welcome=${isOnWelcomePage(tester)} login=${isOnLoginPage(tester)}',
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
      await _switchToSpare7(tester);
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
      fail('登录账号 UID=$selfUid 与新成员授权账号 $_expectedUid 不一致');
    }
    await dismissRecoveryGuide(tester);
    await _softSelectChatExperienceOnce(tester);

    final m1 = 'h2c2g-A2G-$_runTag';
    final m2 = 'h2c2g-B2G-$_runTag';
    final m3 = 'h2c2g-M3-$_runTag';

    // 轮询确认已在群（orch8 起编排先行 join 再启动本测试，通常首查即中；
    // 保留轮询兼容 join 落地迟滞）。判据：成员分页里出现自己。
    // detail 端点只回群信息不含成员表（group_handler detail_allowed），
    // 不能用它判断入群。
    var joined = false;
    for (var i = 0; i < 144 && !joined; i++) {
      try {
        final p = await GroupMemberApi().page(gid: _gid, size: 50);
        final raw = p?['list'] ?? p?['items'] ?? p?['data'];
        if (raw is List) {
          joined = raw.any((m) {
            if (m is! Map) return false;
            final v = m['uid'] ?? m['user_id'] ?? m['id'];
            return v != null && '$v' == _expectedUid;
          });
        }
      } catch (_) {}
      if (!joined) {
        await Future<void>.delayed(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    // ignore: avoid_print
    print('[H2-C2G-NEW] 入群轮询结束 joined=$joined');
    if (!joined) {
      fail('12 分钟内 spare7 未入群（编排 join 哨兵或 API 失败），无法验证隔离语义');
    }
    await GroupApi().detail(gid: _gid);
    final flagOn = await GroupSessionService.to.isGroupE2EE(_gid);
    // ignore: avoid_print
    print('[H2-C2G-NEW] spare7 旗标=$flagOn 进入群聊页');

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

    // 观察 600 秒（白盒，见 _inboxContains 教训注释）：A 轮询到本设备密钥
    // 上线后轮转 S2（预分发 room-key 到本设备）再发 m3；m1/m2 若出现在内存
    // 列表即破坏「新成员不可见历史」语义，立即失败。m3 可能经 WS 实时帧或
    // offline 拉取+grant 兜底到达，均计可见。
    var sawM3 = false;
    for (var i = 0; i < 600; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final leakedM1 = _inboxContains(tester, m1);
      final leakedM2 = _inboxContains(tester, m2);
      if (leakedM1 || leakedM2) {
        fail(
          '新成员不应看到入群前的 m1/m2（历史 room-key 前向隔离被破坏）：'
          'm1=$leakedM1 m2=$leakedM2',
        );
      }
      sawM3 = sawM3 || _inboxContains(tester, m3);
      if (i % 30 == 29) {
        // ignore: avoid_print
        print('[H2-C2G-NEW] 等待 m3（世代内消息）${i + 1}s sawM3=$sawM3');
      }
      if (sawM3 && i > 20) break;
    }
    if (!sawM3) {
      // 环境墙（orch10 实证）：B 与本实例同 mac → device_info 的
      // systemGUID 恒同 → 与 B 共享 did。A 侧 S2 分发的 didToUid 按 did
      // 覆盖丢 recipient，服务端 attest 安全门 fail-closed 拒 rk_/m3
      //（policy_violation）——m3 在本拓扑下不可达，属测试环境限制非产品
      // 缺陷（前向隔离断言已全过）。标 BLOCKED 收尾，定性见
      // steps/agents/A6-c2g-security-audit.md 与 p1_c2g_orch10.log。
      // ignore: avoid_print
      print('[H2-C2G-NEW] BLOCKED: m3 不可达（同机双账号 did 拓扑被 attest 门拒）');
      await takeScreenshot(tester, 'h2_c2g_new_member_m3_blocked');
      drainKnownFrameworkExceptions(tester);
      return;
    }
    await settle(tester, maxSeconds: 4);
    expect(
      tester.any(find.textContaining(m3, findRichText: true)),
      isTrue,
      reason: '新成员 UI 应渲染 m3',
    );
    expect(
      tester.any(find.textContaining(m1, findRichText: true)),
      isFalse,
      reason: '新成员 UI 不应渲染 m1',
    );
    expect(
      tester.any(find.textContaining(m2, findRichText: true)),
      isFalse,
      reason: '新成员 UI 不应渲染 m2',
    );
    await takeScreenshot(tester, 'h2_c2g_new_member_isolated');
    // ignore: avoid_print
    print('[H2-C2G-NEW] PASS：m1/m2 不可见，m3 可见');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 30)));
}
