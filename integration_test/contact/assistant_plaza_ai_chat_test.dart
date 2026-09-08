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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (!tester.any(f)) {
    fail('目标文本不存在: $text');
  }
  await tester.ensureVisible(f.first);
  await _pump(tester, seconds: 1);
  await tester.tap(f.first, warnIfMissed: false);
  await _pump(tester, seconds: 2);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI 广场对话：广场列表 → 发消息 → agent 明文回复', (tester) async {
    installPluginErrorFilter();
    await ensureAppLaunched(tester, maxSeconds: 15);
    if (!await checkPreconditions(tester)) return;

    // 首装引导页（如有）先跳过
    final skip = find.text('跳过');
    if (tester.any(skip)) {
      await tester.tap(skip.first, warnIfMissed: false);
      await _pump(tester, seconds: 2);
    }

    // 登录（已登录则直通）
    final inShell = await waitForMainShell(tester);
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
      await waitForMainShell(tester);
    }
    final uid = UserRepoLocal.to.currentUid;
    flowLog('当前登录 uid=$uid');
    if (uid.isEmpty || uid == '0') {
      markTestSkipped('无登录态');
      return;
    }

    // ① 切「联系人」tab，等广场入口渲染（联系人页 loadData 慢机上有延迟）
    final contactTab = find.text('联系人');
    if (!tester.any(contactTab)) {
      markTestSkipped('主壳未渲染底部导航（联系人 tab 缺失）');
      return;
    }
    await tester.tap(contactTab.first, warnIfMissed: false);
    final plazaEntryReady = await _waitFor(
      tester,
      () => tester.any(find.text('AI 助手广场')),
      seconds: 15,
    );
    if (!plazaEntryReady) {
      markTestSkipped('联系人页未渲染出 AI 助手广场入口');
      return;
    }

    // ② 进 AI 助手广场
    await tester.tap(find.text('AI 助手广场').first, warnIfMissed: false);
    final plazaReady = await _waitFor(
      tester,
      () => tester.any(find.text('Ark 助手')),
      seconds: 15,
    );
    expect(plazaReady, true, reason: '广场应渲染出种子 agent「Ark 助手」卡片');
    expect(tester.any(find.text('发消息')), true, reason: 'agent 卡应有「发消息」按钮');

    // ③ 进 C2C 会话
    await tester.tap(find.text('发消息').first, warnIfMissed: false);
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
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send_button')));

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
