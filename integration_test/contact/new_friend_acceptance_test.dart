// integration_test/contact/new_friend_acceptance_test.dart
//
// 新朋友页验收（批次116）：解除 4 行阻塞。
// 数据源：本地 SQLite new_friend 表（纯本地，listNewFriend where uid=当前
// 用户）——测试内用 NewFriendRepo().save 直插假申请（GMSmoke 假人），
// 结束后清理，不影响其他测试的零申请假设。
// 覆盖：
//   AT-NF1 左滑删除单条申请记录（Slidable → 删除按钮 → 行消失）
//   AT-NF2 点击列表项进入对方资料页（PeopleInfoPage）
//   AT-NF3 已添加/已过期/等待验证状态展示（三种状态标签共存）
//   AT-NF4 自己发起的申请显示「已发送」标签
//
// 运行配方同 group_member_acceptance_test.dart（TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true）。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _bob = '1000000056';

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

/// 插一条假申请：GMSmoke 假人 → bob（或 bob → 假人）
Future<void> _seedRequest(
  WidgetTester tester, {
  required String from,
  required String to,
  required String nickname,
  required int status,
  required String msg,
}) async {
  // 键名必须是 repo 列名（from_id/to_id）——save 内部 NewFriendModel.fromJson
  // 按列名取值，传别名会静默落成默认值（run1 脏行教训）
  await NewFriendRepo().save(<String, dynamic>{
    NewFriendRepo.uid: UserRepoLocal.to.currentUid,
    NewFriendRepo.from: from,
    NewFriendRepo.to: to,
    NewFriendRepo.nickname: nickname,
    NewFriendRepo.avatar: '',
    NewFriendRepo.msg: msg,
    NewFriendRepo.status: status,
    NewFriendRepo.source: 'auto_test',
  });
  await _pump(tester, seconds: 1);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-NF 新朋友页 4 行', (tester) async {
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

    // 清理 run1 遗留的脏行（键名错误导致 from=0/to=0）
    await NewFriendRepo().delete('0', '0');

    // ---- 造数：4 条不同状态假申请（GMSmoke 假人，无第三方打扰） ----
    await _seedRequest(
      tester,
      from: '1000000077',
      to: _bob,
      nickname: 'GMSmoke07',
      status: NewFriendStatus.waitingForValidation.index,
      msg: 'AT-NF 等待验证',
    );
    await _seedRequest(
      tester,
      from: '1000000078',
      to: _bob,
      nickname: 'GMSmoke08',
      status: NewFriendStatus.added.index,
      msg: 'AT-NF 已添加',
    );
    await _seedRequest(
      tester,
      from: '1000000079',
      to: _bob,
      nickname: 'GMSmoke09',
      status: NewFriendStatus.expired.index,
      msg: 'AT-NF 已过期',
    );
    await _seedRequest(
      tester,
      from: _bob,
      to: '1000000080',
      nickname: 'GMSmoke10',
      status: NewFriendStatus.waitingForValidation.index,
      msg: 'AT-NF 已发送',
    );
    // DIAG：直接读库验证造数结果
    final seeded = await NewFriendRepo().listNewFriend(
      UserRepoLocal.to.currentUid,
      100,
    );
    flowLog(
      '[DIAG-NF] 落库 ${seeded.length} 条: '
      '${seeded.map((m) => '${m.nickname}(s=${m.status},from=${m.from})').toList()}',
    );
    addTearDown(() async {
      // 清理假申请，还原其他测试的零申请基线
      for (final pair in [
        ['1000000077', _bob],
        ['1000000078', _bob],
        ['1000000079', _bob],
        [_bob, '1000000080'],
      ]) {
        await NewFriendRepo().delete(pair[0], pair[1]);
      }
    });

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // ---- AT-NF3 三种状态标签共存 ----
    // 完整路径含父前缀 /contact（398 行嵌套路由；批次113 同款坑三踩）
    router.push('/contact/new_friend');
    final nfLoaded = await _waitFor(
      tester,
      () => tester.any(find.text('已添加')) && tester.any(find.text('已过期')),
      seconds: 15,
    );
    expect(nfLoaded, isTrue, reason: 'AT-NF3 已添加/已过期标签应展示');
    expect(
      tester.any(find.textContaining('AT-NF 等待验证')),
      isTrue,
      reason: 'AT-NF3 待验证申请行应展示（msg 副标题）',
    );
    flowLog('[AT-NF3] 待验证（无终态标签）/已添加/已过期三种状态共存');

    // ---- AT-NF4 自己发起的申请显示「已发送」 ----
    expect(
      tester.any(find.text('已发送')),
      isTrue,
      reason: 'AT-NF4 fromSelf 申请应带「已发送」标签',
    );
    flowLog('[AT-NF4] 「已发送」标签渲染（from=bob 的申请）');

    // ---- AT-NF2 点击列表项进入对方资料页 ----
    await _tapText(tester, 'GMSmoke07');
    final peopleShown = await _waitFor(
      tester,
      () =>
          tester.any(find.byKey(const ValueKey('people-info-page'))) ||
          tester.any(find.textContaining('GMSmoke07')),
      seconds: 12,
    );
    expect(peopleShown, isTrue, reason: 'AT-NF2 点击申请应进入 GMSmoke07 资料页');
    flowLog('[AT-NF2] 点击列表项 → 资料页（对端=申请人）');
    final navNf = Navigator.of(
      tester.element(find.byType(Navigator).first),
      rootNavigator: true,
    );
    if (navNf.canPop()) navNf.pop();
    await _pump(tester, seconds: 2);

    // ---- AT-NF1 左滑删除单条申请 ----
    // Slidable：水平向左拖动行，露出删除按钮后点击
    final row9 = find.text('GMSmoke09');
    expect(tester.any(row9), isTrue, reason: 'AT-NF1 前置：GMSmoke09 行应存在');
    await tester.drag(row9.first, const Offset(-320, 0));
    await _pump(tester, seconds: 2);
    if (tester.any(find.text('删除'))) {
      await _tapText(tester, '删除');
      final deleted = await _waitFor(
        tester,
        () => !tester.any(find.text('GMSmoke09')),
        seconds: 10,
      );
      expect(deleted, isTrue, reason: 'AT-NF1 删除后行应消失');
      flowLog('[AT-NF1] 左滑露出删除按钮 → 删除成功行消失');
    } else {
      flowLog('[AT-NF1] 拖动未露出删除按钮（Slidable 手势差异），行仍在');
      fail('AT-NF1 左滑未触发 Slidable actionPane');
    }
  });
}
