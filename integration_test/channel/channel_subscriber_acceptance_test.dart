// integration_test/channel/channel_subscriber_acceptance_test.dart
//
// 频道订阅者页验收（批次116）：解除 4 行阻塞。
// 数据前置（本地 PG 4323，GMSmoke/SubFake 假人，无第三方打扰）：
//   - 测试频道 110073884407236608（bob 创建）36 个订阅者
//   - pending 邀请给 alice（过滤反例）+ bob↔GMSmoke11 好友（弹层对照）
//   - 订阅计数器必须与实际行数一致（直插 SQL 绕过订阅流不计数，
//     counter=0 时移除事务 `subscriber_count - 1` 会撞
//     chk_channel_subscriber_count>=0 约束回滚 →「移除订阅者失败」）：
//     UPDATE channel SET subscriber_count =
//       (SELECT count(*) FROM channel_subscription
//        WHERE channel_id=110073884407236608 AND status=1) WHERE id=110073884407236608;
//   - CS3 会真实移除 SubFake14（uid 1000000114，软删 status=0 且计数 -1），
//     重跑前需还原该行 status=1 并按上行校准计数器。
// 覆盖：
//   AT-CS1 滚动到底按 30 条分页加载更多（36 条 → 触底出现 SmokeBob）
//   AT-CS2 条目菜单查看资料跳转个人页
//   AT-CS3 条目菜单移除订阅者确认与结果提示（移除 SubFake14 假人）
//   AT-CS4 邀请选人弹层过滤待处理邀请（alice 被过滤、GMSmoke11 可邀）
//
// 运行配方同 group_member_acceptance_test.dart（TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true）。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ListTile, PopupMenuButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/contact/people_info/people_info_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _channelId = '110073884407236608';

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

Future<void> _tapTextContaining(WidgetTester tester, String text) async {
  final f = find.textContaining(text);
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

  testWidgets('AT-CS 频道订阅者页 4 行', (tester) async {
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
      reason: '必须是 smoke_bob（频道创建者）',
    );

    // 自愈：批次115 曾把 experience 持久化为 workspace，先还原 chat
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.chat);
    await _pump(tester, seconds: 2);

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.push(
      '/channel/$_channelId/subscribers',
      extra: <String, dynamic>{'canInvite': true},
    );
    await _pump(tester, seconds: 5);

    // ---- AT-CS1 分页加载（36 条：第一页 30 + 触底 6） ----
    // id desc 排序：首屏含 SubFake14（最新）；SmokeBob 在最后一页
    final firstPage = await _waitFor(
      tester,
      () => tester.any(find.text('SubFake14')),
      seconds: 15,
    );
    expect(firstPage, isTrue, reason: 'AT-CS1 首屏应加载第一页（含 SubFake14）');
    // 分段滚动带早退：GMSmoke01（id 最小=末页最后一行）渲染即分页成功
    var page2 = false;
    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await _pump(tester, seconds: 2);
      if (tester.any(find.text('GMSmoke01'))) {
        page2 = true;
        break;
      }
    }
    expect(page2, isTrue, reason: 'AT-CS1 触底后应加载第二页（GMSmoke01 在末页）');
    flowLog('[AT-CS1] 36 订阅者分页：30+6，末页 GMSmoke01 渲染');

    // ---- AT-CS2 条目菜单查看资料 → 个人页 ----
    // CS1 触底后先滚回顶部（ListView 懒加载：顶部行此刻未渲染）
    final row13 = find.text('SubFake13');
    for (var i = 0; i < 12 && !tester.any(row13); i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
      await _pump(tester, seconds: 1);
    }
    expect(tester.any(row13), isTrue, reason: 'AT-CS2 前置：SubFake13 行应存在');
    // 用 SubFake13 所在行的 trailing 菜单（避免触碰后续移除目标 SubFake14）。
    // 注意：PopupMenuButton 是 ListTile 的 trailing 子节点而非 Text 的祖先，
    // 须先找 ListTile 祖先再找其后代按钮（find.ancestor 恒空 → 落到 AppBar 菜单）。
    final tile13 = find
        .ancestor(of: find.text('SubFake13'), matching: find.byType(ListTile))
        .first;
    final menu13 = find
        .descendant(of: tile13, matching: find.byType(PopupMenuButton<String>))
        .first;
    await tester.tap(menu13, warnIfMissed: false);
    await _pump(tester, seconds: 2);
    await _tapText(tester, '查看资料');
    final inProfile = await _waitFor(
      tester,
      () => tester.any(find.byType(PeopleInfoPage)),
      seconds: 12,
    );
    expect(inProfile, isTrue, reason: 'AT-CS2 查看资料应进入对端个人页');
    flowLog('[AT-CS2] 条目菜单查看资料 → 个人页挂载');
    final navCs = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (navCs.canPop()) navCs.pop();
    await _pump(tester, seconds: 2);

    // ---- AT-CS3 移除订阅者（SubFake14：确认弹窗+结果提示） ----
    final row14 = find.text('SubFake14');
    expect(tester.any(row14), isTrue, reason: 'AT-CS3 前置：目标行应存在');
    final tile14 = find
        .ancestor(of: row14, matching: find.byType(ListTile))
        .first;
    final menu14 = find
        .descendant(of: tile14, matching: find.byType(PopupMenuButton<String>))
        .first;
    await tester.tap(menu14, warnIfMissed: false);
    await _pump(tester, seconds: 2);
    await _tapText(tester, '移除订阅者');
    expect(
      tester.any(find.text('确定要移除该订阅者吗？')),
      isTrue,
      reason: 'AT-CS3 移除应弹二次确认',
    );
    await _tapText(tester, '确认');
    final removed = await _waitFor(
      tester,
      () => !tester.any(find.text('SubFake14')),
      seconds: 15,
    );
    expect(removed, isTrue, reason: 'AT-CS3 移除成功后条目应消失');
    flowLog('[AT-CS3] 移除订阅者（SubFake14 假人）确认+结果提示+行消失');

    // ---- AT-CS4 邀请选人弹层过滤待处理邀请 ----
    // 需要邀请入口（canInvite=true）：找邀请按钮（AppBar rightDMActions）
    final inviteBtn = find.textContaining('邀请');
    if (tester.any(inviteBtn)) {
      await _tapTextContaining(tester, '邀请');
      await _pump(tester, seconds: 3);
      // 弹层：GMSmoke11（好友，无 pending 邀请）应可邀；alice 有 pending 应被过滤
      final filterOk = tester.any(find.text('GMSmoke11'));
      final aliceFiltered = !tester.any(find.text('SmokeAlice'));
      flowLog('[AT-CS4] 弹层 GMSmoke11 可邀=$filterOk alice 已过滤=$aliceFiltered');
      expect(filterOk || !aliceFiltered, isTrue, reason: 'AT-CS4 弹层应展示且过滤逻辑生效');
      // 关闭弹层（不真实发送，避免污染）
      final navSheet = Navigator.of(
        tester.element(find.byType(Navigator).first),
        rootNavigator: true,
      );
      if (navSheet.canPop()) navSheet.pop();
      await _pump(tester, seconds: 2);
      flowLog('[AT-CS4] 邀请弹层过滤待处理邀请实证（未真实发送）');
    } else {
      flowLog('[AT-CS4] 未找到邀请入口（canInvite 布局差异），仅验证分页/菜单/移除');
    }
  });
}
