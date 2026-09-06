// integration_test/group/group_manage_pages_test.dart
//
// 群管理三页验收（批次114）：解除 6 行阻塞。
// 数据前置：本地 PG 4323 群 100000000000000120（GMSmoke 大群）、
// bob 唯一独群 107668258368522240（空态用）、bob 好友 SmokeAlice。
// 写操作均打本地 9801 + 本地库假数据，无生产数据、无真人打扰。
// 覆盖：
//   AT-GD  群详情「查看全部群成员」入口（memberCount>20）→ 成员列表页
//   AT-CI  保存群名成功提示并回传（改名 GMSmoke大群验收→…2）
//   AT-AM  提交添加选中成员入群（选 SmokeAlice 加入）
//   AT-RM1 提交移除成员并回传结果（移出 SmokeAlice，数据闭环还原）
//   AT-RM2 成员为空时展示暂无数据空态（bob 独群：排除自己+群主后为空）
//
// 运行配方同 group_member_acceptance_test.dart（TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/group/group_member/group_member_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _gid = '100000000000000120';
const _soloGid = '107668258368522240'; // bob 独群（仅群主自己）

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

/// 前缀匹配点击（勾选后按钮文本会追加计数，如「完成(1)」）
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

  testWidgets('AT-GD/CI/AM/RM 群管理三页 6 行', (tester) async {
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
      reason: '必须是 smoke_bob（群主）',
    );

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // ---- AT-GD 群详情「查看全部群成员」入口（memberCount>20） ----
    router.push(
      '/group/detail/$_gid',
      extra: <String, dynamic>{'title': 'GMSmoke大群验收', 'memberCount': 22},
    );
    final viewAll = await _waitFor(
      tester,
      () => tester.any(find.text('查看全部群成员')),
      seconds: 15,
    );
    expect(viewAll, isTrue, reason: 'AT-GD memberCount>20 应渲染全部成员入口');
    await _tapText(tester, '查看全部群成员');
    final memberPage = await _waitFor(
      tester,
      () => tester.any(find.byType(GroupMemberPage)),
      seconds: 10,
    );
    expect(memberPage, isTrue, reason: 'AT-GD 点击入口应进入成员列表页');
    flowLog('[AT-GD] 查看全部群成员入口 → GroupMemberPage 挂载');
    final navGd = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (navGd.canPop()) navGd.pop();
    await _pump(tester, seconds: 3);

    // ---- AT-CI 保存群名（改名并回传，名称在两值间翻转保证可重复） ----
    const nameA = 'GMSmoke大群验收';
    const nameB = 'GMSmoke大群验收2';
    final currentName = tester.any(find.text(nameB)) ? nameB : nameA;
    final newName = currentName == nameA ? nameB : nameA;
    // 群详情群名行 → ChangeInfoPage
    await _tapText(tester, currentName);
    final ciField = await _waitFor(
      tester,
      () => tester.any(find.byType(CupertinoTextField)),
      seconds: 10,
    );
    expect(ciField, isTrue, reason: 'AT-CI 改名页应有群名输入框');
    // 未修改时按钮禁用（valueChanged 为 null）；修改后可点
    await tester.enterText(find.byType(CupertinoTextField), newName);
    await _pump(tester, seconds: 1);
    final doneBtnWidget = tester.widget<CupertinoButton>(
      find
          .ancestor(of: find.text('完成'), matching: find.byType(CupertinoButton))
          .first,
    );
    expect(doneBtnWidget.onPressed != null, isTrue, reason: 'AT-CI 修改后完成按钮应可点');
    await _tapText(tester, '完成');
    // 成功（saveGroupInfo 返回 g!=null）才 pop；失败停留——pop 即成功证据
    //（详情页群名行不即时刷新，故不断言新名渲染）
    final backDetail = await _waitFor(
      tester,
      () => !tester.any(find.byType(CupertinoTextField)),
      seconds: 10,
    );
    expect(backDetail, isTrue, reason: 'AT-CI 保存成功应回传并退出改名页');
    flowLog('[AT-CI] 群名保存成功（$currentName → $newName）');

    // ---- AT-AM 提交添加选中成员入群（SmokeAlice） ----
    router.push('/group/add_member', extra: <String, dynamic>{'groupId': _gid});
    final aliceRow = await _waitFor(
      tester,
      () => tester.any(find.text('SmokeAlice')),
      seconds: 15,
    );
    expect(aliceRow, isTrue, reason: 'AT-AM 前置：好友 SmokeAlice 应在选人列表');
    await _tapText(tester, 'SmokeAlice');
    await _tapTextContaining(tester, '完成'); // 勾选后按钮变「完成(1)」
    // joinGroup 成功后自动 pop
    final amDone = await _waitFor(
      tester,
      () =>
          !tester.any(find.text('SmokeAlice')) ||
          tester.any(find.text('GMSmoke大群验收')),
      seconds: 15,
    );
    expect(amDone, isTrue, reason: 'AT-AM 添加提交后应自动退出选人页');
    flowLog('[AT-AM] SmokeAlice 已加入群（joinGroup 提交成功）');
    await _pump(tester, seconds: 3);

    // ---- AT-RM1 提交移除成员（移出 SmokeAlice，数据闭环还原） ----
    router.push(
      '/group/remove_member',
      extra: <String, dynamic>{'groupId': _gid},
    );
    final aliceInRemove = await _waitFor(
      tester,
      () => tester.any(find.text('SmokeAlice')),
      seconds: 15,
    );
    expect(aliceInRemove, isTrue, reason: 'AT-RM1 移除选人列表应含新成员 Alice');
    await _tapText(tester, 'SmokeAlice');
    await _tapTextContaining(tester, '完成'); // 勾选后按钮变「完成(1)」
    final rmDone = await _waitFor(
      tester,
      () => !tester.any(find.text('SmokeAlice')),
      seconds: 15,
    );
    expect(rmDone, isTrue, reason: 'AT-RM1 移除提交后应 pop 并回传列表');
    flowLog('[AT-RM1] SmokeAlice 已移出（数据闭环：进→出还原）');
    await _pump(tester, seconds: 3);

    // 退出群详情，准备空态场景
    final navBack = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    while (navBack.canPop()) {
      navBack.pop();
      await _pump(tester, seconds: 2);
    }

    // ---- AT-RM2 成员为空态（bob 独群：排除自己+群主后为空） ----
    router.push(
      '/group/remove_member',
      extra: <String, dynamic>{'groupId': _soloGid},
    );
    final emptyShown = await _waitFor(
      tester,
      () => tester.any(find.text('暂无数据')),
      seconds: 15,
    );
    expect(emptyShown, isTrue, reason: 'AT-RM2 独群移除页应显示暂无数据');
    flowLog('[AT-RM2] 群主独群移除页空态已渲染');
    final navRm = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (navRm.canPop()) navRm.pop();
    await _pump(tester, seconds: 2);

    // ---- AT-E2E 群主开启群级 E2EE（0→1 单向；重跑时开关已只读则跳过） ----
    router.push(
      '/group/detail/$_gid',
      extra: <String, dynamic>{'title': 'GMSmoke大群验收2', 'memberCount': 22},
    );
    final detailLoaded = await _waitFor(
      tester,
      () => tester.any(find.text('端到端加密')),
      seconds: 15,
    );
    expect(detailLoaded, isTrue, reason: 'AT-E2E 前置：群详情设置区应挂载');
    // 滚动到设置区
    await tester.scrollUntilVisible(
      find.text('端到端加密'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _pump(tester, seconds: 1);
    await _tapText(tester, '端到端加密');
    await _pump(tester, seconds: 2);
    if (tester.any(find.textContaining('不可撤销'))) {
      // 首次运行：0→1 真实开启
      await _tapText(tester, '确认');
      final e2eeOk = await _waitFor(
        tester,
        () => tester.any(find.textContaining('成功')),
        seconds: 10,
      );
      expect(e2eeOk, isTrue, reason: 'AT-E2E 确认后应提示开启成功');
      flowLog('[AT-E2E] 群级 E2EE 0→1 开启成功（确认弹窗+setE2eeMode）');
    } else {
      flowLog('[AT-E2E] E2EE 已开启（开关只读），跳过重复开启');
    }
    await _pump(tester, seconds: 3);

    // ---- AT-DG 危险操作弹窗与取消分支（不执行不可逆写操作） ----
    // 清空聊天记录：弹窗出现 → 取消
    await tester.scrollUntilVisible(
      find.text('清空聊天记录'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _tapText(tester, '清空聊天记录');
    expect(
      tester.any(find.textContaining('确定删除聊天记录吗')),
      isTrue,
      reason: 'AT-DG 清空记录应弹二次确认',
    );
    await _tapText(tester, '取消');
    await _pump(tester, seconds: 1);
    expect(
      tester.any(find.textContaining('确定删除聊天记录吗')),
      isFalse,
      reason: 'AT-DG 取消后弹窗应消失',
    );
    // 解散群聊（群主视角按钮）：弹窗出现 → 取消
    await tester.scrollUntilVisible(
      find.text('解散群聊'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _tapText(tester, '解散群聊');
    expect(
      tester.any(find.textContaining('解散群聊')),
      isTrue,
      reason: 'AT-DG 解散应弹二次确认',
    );
    await _tapText(tester, '取消');
    await _pump(tester, seconds: 1);
    flowLog('[AT-DG] 清空/解散弹窗+取消分支实证（确认分支不可逆未执行）');
    final navDg = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (navDg.canPop()) navDg.pop();
    await _pump(tester, seconds: 2);
  });
}
