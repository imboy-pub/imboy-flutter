// integration_test/group/member_detail_actions_test.dart
//
// 群成员详情页管理操作链验收（批次114）：解除 5 行阻塞。
// 数据前置：本地 PG 4323 群 100000000000000120（22 人，bob 群主），
// 目标成员 GMSmoke06（uid 1000000076，普通成员、未禁言）。
// 覆盖（写本地库真实 API，无生产数据、无真人打扰）：
//   AT-MD1 成员不存在时展示「暂无数据」空态
//   AT-MD2 选择时长提交禁言该成员（5分钟 → 已禁言 + 徽章）
//   AT-MD3 二次确认后解除成员禁言（恢复未禁言）
//   AT-MD4 群主设置或取消成员管理员（setAdmin → removeAdmin 往返）
//   AT-MD5 管理员确认后移出该成员（kickMember）
//
// 运行配方同 group_member_acceptance_test.dart（TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
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
const _memberUid = '1000000076'; // GMSmoke06 普通成员未禁言

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

/// 统一安全点击：确保可见 + 命中 first + 不因 miss 静默
Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (!tester.any(f)) {
    fail('AT-MD 目标文本不存在: $text');
  }
  await tester.ensureVisible(f.first);
  await _pump(tester, seconds: 1);
  await tester.tap(f.first, warnIfMissed: false);
  await _pump(tester, seconds: 2);
}

Future<void> _pushDetail(
  WidgetTester tester,
  GoRouter router, {
  required String userId,
}) async {
  router.push(
    '/group/member_detail',
    extra: <String, dynamic>{'groupId': _gid, 'userId': userId},
  );
  await _pump(tester, seconds: 4);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-MD 成员详情管理操作链 5 行', (tester) async {
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

    // ---- AT-MD1 成员不存在 → 暂无数据空态 ----
    await _pushDetail(tester, router, userId: '999999999999999');
    final emptyShown = await _waitFor(
      tester,
      () => tester.any(find.text('暂无数据')),
      seconds: 10,
    );
    expect(emptyShown, isTrue, reason: 'AT-MD1 成员不存在应显示暂无数据');
    flowLog('[AT-MD1] 不存在成员空态已渲染');
    final nav1 = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (nav1.canPop()) nav1.pop();
    await _pump(tester, seconds: 2);

    // ---- AT-MD2 禁言成员（5分钟） ----
    await _pushDetail(tester, router, userId: _memberUid);
    // 角色基线自愈：上次运行可能把成员留在管理员态
    await _tapText(tester, '更多操作');
    await _pump(tester, seconds: 2);
    if (tester.any(find.text('取消管理员'))) {
      flowLog('[MD] 检测到遗留管理员角色，先取消恢复基线');
      await _tapText(tester, '取消管理员');
      await _tapText(tester, '确认');
      await _pump(tester, seconds: 4);
    } else {
      // sheet 已开且无需操作，关闭它
      final navSheet0 = Navigator.of(
        tester.element(find.byType(Navigator).first),
        rootNavigator: true,
      );
      if (navSheet0.canPop()) navSheet0.pop();
      await _pump(tester, seconds: 2);
    }
    var notMuted = await _waitFor(
      tester,
      () => tester.any(find.text('未禁言')),
      seconds: 8,
    );
    // 自愈：上次运行遗留的禁言状态先解禁恢复基线（测试需可重复）
    if (!notMuted && tester.any(find.text('取消禁言'))) {
      flowLog('[MD] 检测到遗留禁言状态，先解禁恢复基线');
      await tester.tap(find.text('取消禁言'), warnIfMissed: false);
      await _pump(tester, seconds: 3);
      if (tester.any(find.text('确认'))) {
        await tester.tap(find.text('确认'));
        await _pump(tester, seconds: 4);
      }
      notMuted = await _waitFor(
        tester,
        () => tester.any(find.text('未禁言')),
        seconds: 12,
      );
    }
    expect(notMuted, isTrue, reason: 'AT-MD2 前置：GMSmoke06 应未禁言');
    final muteBtn = find.text('禁言成员');
    flowLog(
      '[DIAG-MD2] 禁言成员按钮=${tester.any(muteBtn)} '
      '数量=${tester.widgetList(muteBtn).length}',
    );
    if (tester.any(muteBtn)) {
      await tester.ensureVisible(muteBtn.first);
      await _pump(tester, seconds: 1);
      await tester.tap(muteBtn.first, warnIfMissed: false);
    }
    await _pump(tester, seconds: 3);
    flowLog(
      '[DIAG-MD2] tap 后: 弹层标题=${tester.any(find.textContaining('禁言时长'))} '
      '5分钟=${tester.any(find.text('5分钟'))} '
      '取消禁言按钮=${tester.any(find.text('取消禁言'))}',
    );
    expect(tester.any(find.text('5分钟')), isTrue, reason: 'AT-MD2 禁言时长弹层应出现');
    await _tapText(tester, '5分钟');
    final mutedShown = await _waitFor(
      tester,
      () => tester.any(find.text('已禁言')),
      seconds: 12,
    );
    expect(mutedShown, isTrue, reason: 'AT-MD2 禁言提交后状态应变为已禁言');
    flowLog('[AT-MD2] 选 5 分钟禁言提交成功，状态翻转为已禁言');

    // throttle：group_member_mute 三秒一次，解禁是另一操作维度但留缓冲
    await _pump(tester, seconds: 3);

    // ---- AT-MD3 取消禁言（二次确认） ----
    await _pump(tester, seconds: 3); // 等「已禁言」toast 消失，避免浮层吞 tap
    await _tapText(tester, '取消禁言');
    expect(
      tester.any(find.textContaining('取消禁言此成员')),
      isTrue,
      reason: 'AT-MD3 解禁应弹二次确认',
    );
    await _tapText(tester, '确认');
    final unmuted = await _waitFor(
      tester,
      () => tester.any(find.text('未禁言')),
      seconds: 12,
    );
    expect(unmuted, isTrue, reason: 'AT-MD3 解禁后应恢复未禁言');
    flowLog('[AT-MD3] 二次确认解禁成功，状态恢复未禁言');
    await _pump(tester, seconds: 3);

    // ---- AT-MD4 设为/取消管理员（ActionSheet + 确认） ----
    await _tapText(tester, '更多操作');
    expect(
      tester.any(find.text('设为管理员')),
      isTrue,
      reason: 'AT-MD4 群主视角 ActionSheet 应含设为管理员',
    );
    await _tapText(tester, '设为管理员');
    await _tapText(tester, '确认');
    await _pump(tester, seconds: 4); // 等 updateRole 成功 toast 消失
    // 重开 ActionSheet 验证 role 已变（sheet 已关，文案只在 sheet 内）
    await _tapText(tester, '更多操作');
    final adminSet = await _waitFor(
      tester,
      () => tester.any(find.text('取消管理员')),
      seconds: 8,
    );
    expect(adminSet, isTrue, reason: 'AT-MD4 设为管理员后 sheet 文案应切换');
    flowLog('[AT-MD4] 设管理员成功（sheet 文案切到取消管理员）');

    // 取消管理员，恢复普通成员
    await _tapText(tester, '取消管理员');
    await _tapText(tester, '确认');
    await _pump(tester, seconds: 4);
    await _tapText(tester, '更多操作');
    final adminRemoved = await _waitFor(
      tester,
      () => tester.any(find.text('设为管理员')),
      seconds: 8,
    );
    expect(adminRemoved, isTrue, reason: 'AT-MD4 取消后文案应切回设为管理员');
    // 关闭 sheet（无取消按钮，pop 根导航的弹层 route）
    final navSheet = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (navSheet.canPop()) navSheet.pop();
    await _pump(tester, seconds: 2);
    flowLog('[AT-MD4] 取消管理员成功，成员恢复普通角色');
    await _pump(tester, seconds: 3);

    // ---- AT-MD5 移出成员（牺牲目标换成 GMSmoke06 本身，测试后数据无需保留） ----
    await _pump(tester, seconds: 3); // 等上一 toast 消失
    await _tapText(tester, '更多操作');
    expect(
      tester.any(find.text('移出成员')),
      isTrue,
      reason: 'AT-MD5 ActionSheet 应含移出成员',
    );
    await _tapText(tester, '移出成员');
    expect(
      tester.any(find.textContaining('移出群聊')),
      isTrue,
      reason: 'AT-MD5 移出应弹二次确认',
    );
    await _tapText(tester, '确认');
    await _pump(tester, seconds: 4);
    // 移出成功后页面应 pop 回列表页（标题 群成员）
    final backToList = await _waitFor(
      tester,
      () =>
          tester.any(find.textContaining('群成员')) ||
          !tester.any(find.text('更多操作')),
      seconds: 12,
    );
    expect(backToList, isTrue, reason: 'AT-MD5 移出后应离开详情页');
    flowLog('[AT-MD5] 移出成员成功，详情页已退出');
  });
}
