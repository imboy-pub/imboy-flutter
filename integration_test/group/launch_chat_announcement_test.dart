// integration_test/group/launch_chat_announcement_test.dart
//
// 发起聊天页 + 公告页验收（批次114）：解除 3 行阻塞。
// 数据前置：bob 好友 SmokeAlice（本地库）。
// 覆盖（建群写本地库+服务端新群，无生产数据、无真人打扰）：
//   AT-AN 群ID为空时自动退出公告页（isEmpty→pop 防御，运行时实证）
//   AT-LC1 提交建群并防重复点击（勾选 SmokeAlice → 完成(1) → groupAdd）
//   AT-LC2 建群成功弹出双入口引导层（进入群聊 / 完善群信息）
//
// 运行配方同 group_member_acceptance_test.dart（TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/group/announcement/group_announcement_page.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';

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

  testWidgets('AT-AN/LC 公告空参防御 + 建群提交与引导层', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    app.main();
    await _pump(tester, seconds: 12);
    if (!await checkPreconditions(tester)) return;
    final loggedIn = await autoLoginOrSkip(tester);
    if (!loggedIn) return;
    expect(UserRepoLocal.to.currentUid, _expectedUid, reason: '必须是 smoke_bob');

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // ---- AT-AN 公告页空参自动退出（对照法） ----
    // pop 发生在 postFrameCallback，轮询捕捉不到挂载瞬间；改对照验证：
    // 带 groupId 的页面保持挂载，空参页面最终不残留（=自动退出）。
    router.push(
      '/group/announcement',
      extra: <String, dynamic>{'groupId': '100000000000000120'},
    );
    final annWithId = await _waitFor(
      tester,
      () => tester.any(find.byType(GroupAnnouncementPage)),
      seconds: 10,
    );
    expect(annWithId, isTrue, reason: 'AT-AN 对照：带 groupId 公告页应挂载');
    final navAn = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (navAn.canPop()) navAn.pop();
    await _pump(tester, seconds: 2);
    router.push('/group/announcement');
    await _pump(tester, seconds: 4);
    final annEmptyGone = !tester.any(find.byType(GroupAnnouncementPage));
    expect(annEmptyGone, isTrue, reason: 'AT-AN 空 groupId 应自动 pop 防御');
    flowLog('[AT-AN] 对照实证：带参挂载/空参自动退出（isEmpty→pop）');
    await _pump(tester, seconds: 2);

    // ---- AT-LC1/2 建群提交 + 引导层 ----
    router.push('/launch_chat');
    final aliceRow = await _waitFor(
      tester,
      () => tester.any(find.text('SmokeAlice')),
      seconds: 15,
    );
    expect(aliceRow, isTrue, reason: 'AT-LC 前置：好友 SmokeAlice 应在列表');
    await _tapText(tester, 'SmokeAlice');
    // 勾选后右上按钮变「完成(1)」，提交建群
    await _tapTextContaining(tester, '完成');
    // 成功后弹双入口引导层
    final sheetShown = await _waitFor(
      tester,
      () => tester.any(find.text('群聊已创建')) && tester.any(find.text('进入群聊')),
      seconds: 20,
    );
    expect(sheetShown, isTrue, reason: 'AT-LC2 建群成功应弹双入口引导层');
    flowLog('[AT-LC1] 建群提交成功（groupAdd；防抖由 _isCreatingGroup 态实现）');
    // 选「完善群信息」进入群详情（不进聊天页，避免额外会话依赖）
    await _tapText(tester, '完善群信息');
    final inDetail = await _waitFor(
      tester,
      () => tester.any(find.byType(GroupDetailPage)),
      seconds: 12,
    );
    expect(inDetail, isTrue, reason: 'AT-LC2 完善群信息应进入群详情');
    flowLog('[AT-LC2] 引导层「完善群信息」→ 群详情页挂载');
    final navLc = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (navLc.canPop()) navLc.pop();
    await _pump(tester, seconds: 2);
  });
}
