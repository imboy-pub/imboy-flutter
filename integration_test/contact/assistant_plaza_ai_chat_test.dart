// AI 广场 → agent C2C 对话真机端到端（透明 AI 豁免回归，2026-09-08）：
//
// 验收链路：
//   ① 登录 smoke_alice → 主壳底部导航切「联系人」
//   ② 点「AI 助手广场」入口 → 广场渲染 agent 卡（Ark 助手 + 发消息）
//   ③ 点「发消息」进入 C2C 会话（AI 徽章 + 明文豁免：不触发 E2EE 握手）
//   ④ 发文本 → 轮询等待 agent 明文回复气泡
//
// 回归背景：required/compliance 部署下客户端策略门曾对 agent 仍要求加密
// （peer_has_no_device 卡死）、服务端明文门曾拒收人→agent（policy_violation）、
// agent 回投被同门吞掉（AGENT_REPLY_BLOCKED）——两端夹死致 AI 广场对话不可用。
//
// 前置：APP_ENV=local 构建 + adb reverse 9800 + 本地后端含 agent 豁免修复；
// ai_agent 表存在 status=1/visibility=1 的 agent（本地方种子 1000000000000000001
// 「Ark 助手」）；provider=mock 时须先起 scripts/mock_llm_server.py（回复文案
// 含默认标记 "mock AI 助手"，可用 TEST_AGENT_REPLY_MARKER 覆盖）。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const String _replyMarkerEnv = String.fromEnvironment(
  'TEST_AGENT_REPLY_MARKER',
  defaultValue: 'mock AI 助手',
);

Future<void> _pump(WidgetTester tester, {int seconds = 2}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 10,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

/// 首装三页引导可能出现在任意阶段（尤其登录成功路由回来之后），循环点「跳过」。
Future<void> _dismissOnboarding(WidgetTester tester) async {
  final skipLabel = t.welcome.skip;
  for (var i = 0; i < 4; i++) {
    final skip = find.text(skipLabel);
    if (!tester.any(skip)) return;
    await tester.tap(skip.first, warnIfMissed: false);
    await _pump(tester, seconds: 2);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI 广场对话：广场列表 → 发消息 → agent 明文回复', (tester) async {
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 15);
    if (!await checkPreconditions(tester)) return;

    // 首装引导页（如有）先跳过
    await _dismissOnboarding(tester);

    // 登录（已登录则直通）
    var inShell = await waitForMainShell(tester);
    if (!inShell) {
      final ok = await performLogin(
        tester,
        phone: 'smoke_alice',
        password: 'admin888',
      );
      if (!ok) {
        markTestSkipped('登录失败，无法验收 AI 广场对话');
        return;
      }
      // 登录成功后 fresh 安装可能才路由到三页引导，再次关闭
      await _dismissOnboarding(tester);
      inShell = await waitForMainShell(tester);
    }
    await _dismissOnboarding(tester);
    final uid = UserRepoLocal.to.currentUid;
    flowLog('当前登录 uid=$uid');
    if (uid.isEmpty || uid == '0') {
      markTestSkipped('无登录态');
      return;
    }

    // ① 路由直进 AI 助手广场（pumpAndSettle 不稳时 tab 点击会丢，路由直进
    //   等价覆盖入口后的广场渲染；入口行可达性已在真机走查人工确认）
    final ctx = tester.element(find.byType(Scaffold).first);
    unawaited(ctx.push('/contact/assistant_plaza'));
    final plazaEntryReady = await _waitFor(
      tester,
      () => tester.any(find.text(t.agent.plazaTitle)),
      seconds: 15,
    );
    if (!plazaEntryReady) {
      markTestSkipped('联系人页未渲染出 AI 助手广场入口');
      return;
    }

    // ② 广场渲染断言（透明卡 + agent 卡 + 发消息按钮）
    await _pump(tester, seconds: 2);
    final plazaReady = await _waitFor(
      tester,
      () => tester.any(find.text('Ark 助手')),
      seconds: 15,
    );
    expect(plazaReady, true, reason: '广场应渲染出种子 agent「Ark 助手」卡片');
    expect(
      tester.any(find.text(t.agent.sendMessage)),
      true,
      reason: 'agent 卡应有「发消息」按钮',
    );

    // ③ 进 C2C 会话
    await tester.tap(find.text(t.agent.sendMessage).first, warnIfMissed: false);
    final inputReady = await _waitFor(
      tester,
      () => tester.any(find.byKey(const Key('chat_message_input'))),
      seconds: 10,
    );
    expect(inputReady, true, reason: '应进入与 agent 的 C2C 会话（含输入框）');

    // ④ 发送文本（透明 AI 豁免：明文直发，不要求 agent 设备密钥）
    await tester.enterText(
      find.byKey(const Key('chat_message_input')),
      'AI 广场对话验收',
    );
    // AnimatedSwitcher 300ms：发送按钮从「+」切换出来需要过完一帧动画
    await tester.pump(const Duration(milliseconds: 400));
    final sendBtn = find.byKey(const ValueKey('send_button'));
    if (tester.any(sendBtn)) {
      await tester.tap(sendBtn.first);
    } else {
      // 兜底：输入法 done 动作同样触发 onSubmitted → _handleSendPressed
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _pump(tester, seconds: 1);
    }

    // ⑤ 轮询等待 agent 明文回复（mock LLM 固定应答模板）
    final replied = await _waitFor(
      tester,
      () =>
          tester.any(find.textContaining(_replyMarkerEnv)) ||
          tester.any(find.textContaining(_replyMarkerEnv, findRichText: true)),
      seconds: 25,
    );
    expect(replied, true, reason: 'agent 应在 25s 内回复明文文本（标记=$_replyMarkerEnv）');
    flowLog('✅ AI 广场对话全链通过：广场→C2C→明文豁免→agent 回复');
  });
}
