// integration_test/channel/../contact/contact_report_acceptance_test.dart
//
// 资料设置页投诉验收（批次118）：用户报障「投诉失败，请稍后再试」回归。
// 缺陷背景：
//   - ReportApi.create 只返回 bool，后端可读原因（如「您已举报过该对象」）
//     被丢弃，UI 一律显示「投诉失败，请稍后再试」，真实原因被掩盖；
//     修复后失败时优先透出后端 msg（镜像 E2EE 文案路由的
//     「文案=唯一诊断通道」惯例）。
// 覆盖：
//   AT-RP1 首次投诉成功（toast「投诉已提交」）
//   AT-RP2 重复投诉透出后端真实原因（toast「您已举报过该对象」，非通用失败）
// 数据前置（本地 PG 4323 / 后端 9801，无第三方打扰）：
//   - smoke_bob(1000000056) 与 smoke_alice(1000000051) 好友
//   - 清场/自愈 SQL（保持「未举报」初态，测试结束同样恢复）：
//     DELETE FROM report_ticket WHERE reporter_uid=1000000056
//       AND target_type='user' AND target_id=1000000051;
//
// 运行配方同 channel_subscriber_acceptance_test.dart（TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true）。

import 'package:flutter/material.dart' show Navigator;
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _aliceUid = '1000000051';

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
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

/// 从当前路由栈返回上一页（people_info → 复位，便于第二轮入口复用）
Future<void> _back(WidgetTester tester) async {
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  if (router.canPop()) router.pop();
  await _pump(tester, seconds: 2);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-RP 资料设置页投诉 2 行', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    app.main();
    await _pump(tester, seconds: 12);
    if (!await checkPreconditions(tester)) return;
    final loggedIn = await autoLoginOrSkip(tester);
    if (!loggedIn) return;
    expect(
      UserRepoLocal.to.currentUid,
      _expectedUid,
      reason: '必须是 smoke_bob（举报人）',
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.chat);
    await _pump(tester, seconds: 2);

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.push('/people_info/$_aliceUid?scene=contact_page');
    await _pump(tester, seconds: 5);

    // ---- 前置：资料页渲染 + 打开联系人设置 ----
    final settingBtn = find.bySemanticsLabel('联系人设置');
    final settingReady = await _waitFor(
      tester,
      () => tester.any(settingBtn),
      seconds: 10,
    );
    expect(settingReady, isTrue, reason: '资料页应渲染联系人设置（⋯）按钮');
    await tester.tap(settingBtn.first, warnIfMissed: false);
    await _pump(tester, seconds: 2);

    // ---- 打开投诉原因 action sheet ----
    await _tapText(tester, '投诉');
    final reasonReady = await _waitFor(
      tester,
      () => tester.any(find.text('垃圾信息')),
      seconds: 6,
    );
    expect(reasonReady, isTrue, reason: '投诉原因 action sheet 应弹出');

    // ---- AT-RP1 首次投诉成功 ----
    await _tapText(tester, '垃圾信息');
    final okToast = await _waitFor(
      tester,
      () => tester.any(find.text('投诉已提交')),
      seconds: 10,
    );
    expect(okToast, isTrue, reason: 'AT-RP1 首次投诉应提示「投诉已提交」');
    flowLog('[AT-RP1] 首次投诉：toast=投诉已提交');
    // 等 toast 自动消失，避免其文本干扰 AT-RP2 的断言
    final toastGone = await _waitFor(
      tester,
      () => !tester.any(find.text('投诉已提交')),
      seconds: 12,
    );
    expect(toastGone, isTrue, reason: 'AT-RP1 收尾：成功 toast 应自动消失');

    // ---- AT-RP2 重复投诉：透出后端真实原因 ----
    // 回到资料页重新进入设置（投诉 sheet 已关闭，页面仍在 contact_setting）
    await _tapText(tester, '投诉');
    final reason2 = await _waitFor(
      tester,
      () => tester.any(find.text('垃圾信息')),
      seconds: 6,
    );
    expect(reason2, isTrue, reason: 'AT-RP2 前置：原因 sheet 应再次弹出');
    await _tapText(tester, '垃圾信息');
    final dupToast = await _waitFor(
      tester,
      () => tester.any(find.text('您已举报过该对象')),
      seconds: 10,
    );
    expect(dupToast, isTrue, reason: 'AT-RP2 重复投诉应透出后端原因「您已举报过该对象」');
    expect(
      tester.any(find.text('投诉失败，请稍后再试')),
      isFalse,
      reason: 'AT-RP2 不应再显示掩盖真实原因的通用失败文案',
    );
    flowLog('[AT-RP2] 重复投诉：toast=您已举报过该对象（后端消息透出）');

    // 复位路由（回到首页栈），便于整测重跑
    await _back(tester);
    await _back(tester);
  });
}
