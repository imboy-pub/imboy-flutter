// integration_test/group/group_member_acceptance_test.dart
//
// group_member_page 大群验收（批次113）：解除「需建 20 人以上测试群」阻塞。
// 数据前置（本地 PG 4323 已造）：
//   群 100000000000000120「GMSmoke大群验收」22 人：
//   SmokeBob=群主(4)、GMSmoke01=管理员(3)、GMSmoke02=副群主(5)、
//   GMSmoke03=嘉宾(2)、GMSmoke04~21=成员(1)，
//   其中 GMSmoke04/05 禁言中（约2天/约3小时）。
//   服务端分页 size=20（m.id desc）：第1页 GMSmoke02~21，第2页 GMSmoke01+SmokeBob。
// 覆盖：AT-GM1 首屏本地+服务端加载 / AT-GM2 下拉刷新 /
//       AT-GM3 上拉分页 / AT-GM5 搜索过滤 / AT-GM7 角色三档 /
//       AT-GM8 群主管理员徽章 / AT-GM9 禁言徽章 /
//       AT-GM10 解禁事件实时更新 / AT-GM11 点成员进详情 /
//       AT-GM12 筛选无结果两类空态。
// AT-GM4（分页失败回滚）与本文件分离，见 gm_pagination_failover_test.dart。
//
// 运行配方（绝对路径，cwd 易漂移）：
// cd /Users/leeyi/project/imboy.pub/imboyapp && flutter test \
//   integration_test/group/group_member_acceptance_test.dart -d macos \
//   --dart-define=APP_ENV=local_office \
//   --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//   --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//   --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//   --dart-define=TEST_LOGIN_TYPE=account \
//   --dart-define=TEST_EXPECTED_UID=1000000056 \
//   --dart-define=TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/group/group_member/group_member_detail_page.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/user_events.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _gid = 100000000000000120;
const _muted04Uid = '1000000074'; // GMSmoke04 禁言约2天

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

/// 点角色分段控件里的指定标签（列表行徽章与 segment 同名，必须限定祖先）
Future<void> _tapSegment(WidgetTester tester, String label) async {
  final segText = find.descendant(
    of: find.byType(CupertinoSlidingSegmentedControl<int>),
    matching: find.text(label),
  );
  expect(segText, findsOneWidget, reason: 'segment 标签 $label 应唯一');
  await tester.ensureVisible(segText.first);
  await tester.tap(segText.first);
  await _pump(tester, seconds: 1);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-GM group_member_page 大群 12 行验收', (tester) async {
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
    router.push('/group/member', extra: <String, dynamic>{'groupId': '$_gid'});
    await _pump(tester, seconds: 5);

    // ---- AT-GM1 首屏加载：服务端第一页 20 条 → 标题「群成员 (20)」 ----
    final title20 = await _waitFor(
      tester,
      () => tester.any(find.text('群成员 (20)')),
      seconds: 15,
    );
    expect(title20, isTrue, reason: 'AT-GM1 首屏应加载第一页 20 名成员');
    expect(
      tester.any(find.text('GMSmoke21')),
      isTrue,
      reason: 'AT-GM1 第一页应含 GMSmoke21',
    );
    flowLog('[AT-GM1] 首屏 20 条已渲染（服务端分页第一页）');

    // ---- AT-GM5 搜索过滤：昵称即时过滤 ----
    final searchField = find.byType(CupertinoSearchTextField);
    expect(searchField, findsOneWidget, reason: '搜索框应在顶部');
    await tester.enterText(searchField, 'GMSmoke07');
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.text('GMSmoke07')),
      isTrue,
      reason: 'AT-GM5 搜索 GMSmoke07 应命中该成员',
    );
    expect(
      tester.any(find.text('GMSmoke08')),
      isFalse,
      reason: 'AT-GM5 过滤后其他成员不应可见',
    );
    flowLog('[AT-GM5] 昵称过滤命中唯一行');

    // ---- AT-GM12a 搜索无结果空态 ----
    await tester.enterText(searchField, 'zzz_nomatch_gm');
    await _pump(tester, seconds: 2);
    expect(
      tester.any(find.text('无搜索结果')),
      isTrue,
      reason: 'AT-GM12a 搜索无结果应显示「无搜索结果」空态',
    );
    flowLog('[AT-GM12a] 搜索无结果空态已渲染');
    await tester.enterText(searchField, '');
    await _pump(tester, seconds: 2);

    // ---- AT-GM3 上拉加载更多（第2页：GMSmoke01+SmokeBob） ----
    final listFinder = find.byType(ListView);
    expect(listFinder, findsOneWidget);
    for (var i = 0; i < 6; i++) {
      await tester.drag(listFinder, const Offset(0, -800));
      await _pump(tester, seconds: 1);
    }
    final title22 = await _waitFor(
      tester,
      () => tester.any(find.text('群成员 (22)')),
      seconds: 15,
    );
    expect(title22, isTrue, reason: 'AT-GM3 触底加载后应共 22 名成员');
    expect(
      tester.any(find.text('SmokeBob')),
      isTrue,
      reason: 'AT-GM3 第2页应含群主 SmokeBob',
    );
    flowLog('[AT-GM3] 上拉分页 20→22 全量加载');

    // ---- AT-GM9 禁言徽章：GMSmoke04/05 禁言中 ----
    // 数据层诊断：repo 落库后的 muteUntilMs（区分「存库丢字段」vs「渲染丢」）
    try {
      final savedRows = await GroupMemberRepo().page(
        limit: 30,
        where: '${GroupMemberRepo.groupId} = ?',
        whereArgs: ['$_gid'],
      );
      for (final m in savedRows.take(6)) {
        flowLog(
          '[DIAG] repo.uid=${m.userId} nick=${m.nickname} '
          'role=${m.role} muteUntilMs=${m.muteUntilMs}',
        );
      }
    } catch (e) {
      flowLog('[DIAG] repo.page 异常: $e');
    }
    // 懒加载视口裁剪：04/05 排第 5/6 位（role DESC 全量序：
    // SmokeBob(4) 01(3) 02(5) 03(2) 04 05 ...21），向下拖 2 屏进入视口
    for (var i = 0; i < 2; i++) {
      await tester.drag(listFinder, const Offset(0, -400));
      await _pump(tester, seconds: 1);
    }
    final muteBadges = find.textContaining('禁言');
    final badgeCount9 = await _waitFor(
      tester,
      () => tester.any(muteBadges) && tester.widgetList(muteBadges).length >= 2,
      seconds: 5,
    );
    expect(badgeCount9, isTrue, reason: 'AT-GM9 应有 2 个禁言徽章（04/05）');
    flowLog(
      '[AT-GM9] 禁言徽章 2 枚：${tester.widgetList<Text>(muteBadges).map((w) => w.data).toList()}',
    );

    // ---- AT-GM8 群主/管理员徽章（segment 之外行内徽章同现） ----
    // role DESC 排序：SmokeBob(群主) 首行、GMSmoke01(管理员) 次行
    expect(
      find.text('群主'),
      findsAtLeastNWidgets(2),
      reason: 'AT-GM8 segment 标签+SmokeBob 行徽章均含「群主」',
    );
    expect(
      find.text('管理员'),
      findsAtLeastNWidgets(2),
      reason: 'AT-GM8 segment 标签+GMSmoke01 行徽章均含「管理员」',
    );
    flowLog('[AT-GM8] 群主/管理员行内徽章渲染（与 segment 同名共存）');

    // ---- AT-GM7 角色三档筛选 ----
    await _tapSegment(tester, '群主');
    expect(
      tester.any(find.text('SmokeBob')),
      isTrue,
      reason: 'AT-GM7 群主档应只剩 SmokeBob',
    );
    expect(
      tester.any(find.text('GMSmoke07')),
      isFalse,
      reason: 'AT-GM7 群主档普通成员应被过滤',
    );
    flowLog('[AT-GM7] 群主档筛选命中');

    await _tapSegment(tester, '管理员');
    expect(
      tester.any(find.text('GMSmoke01')),
      isTrue,
      reason: 'AT-GM7 管理员档应显示 GMSmoke01',
    );
    flowLog('[AT-GM7] 管理员档筛选命中');

    await _tapSegment(tester, '成员');
    // 服务端顺序（m.id desc）= 21..01,bob；成员档 role<=2 filtered 头部仍是
    // GMSmoke21，而 04 排第 18 位。判定：01（管理员，上一档可见）应被滤掉，
    // 再向下拖到 04 进入视口证明成员行保留。
    expect(
      tester.any(find.text('GMSmoke01')),
      isFalse,
      reason: 'AT-GM7 成员档（role<=2）不应含管理员 GMSmoke01',
    );
    for (var i = 0; i < 3; i++) {
      await tester.drag(listFinder, const Offset(0, -600));
      await _pump(tester, seconds: 1);
    }
    final g04Visible = await _waitFor(
      tester,
      () => tester.any(find.text('GMSmoke04')),
      seconds: 10,
    );
    // DIAG：打印当前可见 Text 样本（区分「筛选没生效」vs「视口没滚到」）
    final visibleTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
    flowLog(
      '[DIAG] 成员档滚动后可见文本(${visibleTexts.length}): '
      '${visibleTexts.take(30).toList()}',
    );
    expect(g04Visible, isTrue, reason: 'AT-GM7 成员档应含 GMSmoke04');
    expect(
      tester.any(find.text('GMSmoke01')),
      isFalse,
      reason: 'AT-GM7 成员档（role<=2）不应含管理员',
    );
    flowLog('[AT-GM7] 成员档筛选 role<=2 生效（成员+嘉宾）');

    await _tapSegment(tester, '全部');
    await _pump(tester, seconds: 1);

    // ---- AT-GM2 下拉刷新 ----
    // 刷新语义 = 重载第一页：标题应从 22 回到 20（服务端 size=20）
    for (var i = 0; i < 8; i++) {
      await tester.drag(listFinder, const Offset(0, 800));
      await _pump(tester, seconds: 1);
    }
    await tester.drag(listFinder, const Offset(0, 300));
    final title20After = await _waitFor(
      tester,
      () => tester.any(find.text('群成员 (20)')),
      seconds: 15,
    );
    expect(title20After, isTrue, reason: 'AT-GM2 下拉刷新后应重载第一页（20）');
    flowLog('[AT-GM2] 下拉刷新触发 onRefresh，列表重载第一页 20 条');

    // ---- AT-GM10 解禁事件实时更新（S2C 事件注入 → 徽章消失） ----
    // 刷新后 offset 在顶部，04/05 徽章在视口外——先滚到可见再计数
    for (var i = 0; i < 3; i++) {
      await tester.drag(listFinder, const Offset(0, -500));
      await _pump(tester, seconds: 1);
    }
    final beforeFire = await _waitFor(tester, () {
      final badges = find.textContaining('禁言');
      return tester.any(badges) && tester.widgetList(badges).length >= 2;
    }, seconds: 8);
    expect(beforeFire, isTrue, reason: 'AT-GM10 fire 前应见 2 枚禁言徽章');
    AppEventBus.fire(
      GroupMemberUnmuteEvent(
        gid: _gid,
        userId: _muted04Uid,
        adminNickname: 'SmokeBob',
      ),
    );
    final unmuted = await _waitFor(tester, () {
      final badges = find.textContaining('禁言');
      return tester.any(badges) && tester.widgetList(badges).length == 1;
    }, seconds: 8);
    expect(unmuted, isTrue, reason: 'AT-GM10 解禁事件后 GMSmoke04 徽章应消失');
    flowLog('[AT-GM10] GroupMemberUnmuteEvent 驱动徽章 2→1 实时更新');

    // ---- AT-GM11 点成员进详情并返回 ----
    await tester.tap(find.text('GMSmoke02'));
    await _pump(tester, seconds: 4);
    expect(
      tester.any(find.byType(GroupMemberDetailPage)),
      isTrue,
      reason: 'AT-GM11 点成员应进入成员详情页',
    );
    flowLog('[AT-GM11] GroupMemberDetailPage 已挂载');
    final nav = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (nav.canPop()) nav.pop();
    await _pump(tester, seconds: 3);
    expect(
      tester.any(find.text('群成员 (22)')),
      isTrue,
      reason: 'AT-GM11 返回后成员列表应保留',
    );

    // 返回群成员列表入口页
    final nav2 = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (nav2.canPop()) nav2.pop();
    await _pump(tester, seconds: 2);

    // ---- AT-GM12b 纯角色无成员空态（bob 独群 107668258368522240） ----
    router.push(
      '/group/member',
      extra: <String, dynamic>{'groupId': '107668258368522240'},
    );
    await _pump(tester, seconds: 5);
    final soloLoaded = await _waitFor(
      tester,
      () => tester.any(find.text('群成员 (1)')),
      seconds: 15,
    );
    expect(soloLoaded, isTrue, reason: 'AT-GM12b 独群应只有 bob 自己');
    await _tapSegment(tester, '管理员');
    expect(
      tester.any(find.text('暂无管理员')),
      isTrue,
      reason: 'AT-GM12b 角色无成员应显示「暂无管理员」空态',
    );
    flowLog('[AT-GM12b] 纯角色筛选空态（区别于搜索空态）已渲染');
    final nav3 = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (nav3.canPop()) nav3.pop();
    await _pump(tester, seconds: 2);
  });
}
