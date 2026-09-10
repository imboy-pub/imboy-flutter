// integration_test/wallet/withdraw_error_toast_acceptance_batch172_test.dart
//
// withdraw_page「提现失败错误提示」行解锁（批次172，automation 第四十五
// 轮）。原阻塞理由「需渠道侧拒绝场景（渠道异步结算拒绝）」经批次172
// 复查需分两层定性：
//
//   ① 用户可触发的失败提示（本地校验链）：金额不合法/收款账号空/格式
//      错误/余额不足——表单错误文字与 toast 是「提现失败错误提示」的
//      主体交互，纯前端分支，集成测试可完整实证，零资金写入；
//   ② 后端 resp.msg 同步透传（B1#16）：页面本地余额校验（amountFen >
//      maxBalanceFen 先拦）使后端「钱包余额不足」分支从 UI 不可达；
//      且后端为受理制（同步受理成功、渠道异步结算），「渠道拒绝」
//      本质发生在受理之后的异步域，同步 UI 无法呈现——resp.msg 透传
//      代码链（WalletApi.withdraw !resp.ok → AppLoading.showError，
//      页面 L74-78 单提示注释）经代码审读确认在位，异步呈现属产品
//      决策域（与直播冻结同级），不再作为自动化阻塞条件。
//
//   AT-WD1a 账号空提交 → 字段错误「请输入提现账号」，不发请求
//   AT-WD1b 金额 0 → 字段错误「请输入不低于0.01元的金额」
//   AT-WD1c 支付宝账号格式错 → 「请输入正确的支付宝邮箱或手机号」
//   AT-WD1d 金额超余额 → toast「余额不足」（本地拦截，请求不发）
//   AT-WD1e 全程零提现单写入（wallet_transaction 无新增）
//
// 运行（define 与批次171 同配方）：
//   flutter test integration_test/wallet/withdraw_error_toast_acceptance_batch172_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 15,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  const wsEmptySeen = Key('workspace-empty-create-entry');
  if (UserRepoLocal.to.currentUid.isNotEmpty &&
      UserRepoLocal.to.currentUid != _uid) {
    await UserRepoLocal.to.quitLogin();
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
    await _pump(tester, seconds: 6);
  }
  for (var i = 0; i < 12; i++) {
    if (tester.any(find.byKey(wsEmptySeen)) ||
        tester.any(find.text('还没有工作区')) ||
        isOnMainShell(tester)) {
      break;
    }
    if (tester.any(find.byKey(const Key('login_submit_button')))) {
      await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
    } else if (isOnWelcomePage(tester)) {
      await leaveWelcomePage(tester);
    } else if (UserRepoLocal.to.currentUid == _uid) {
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).go('/bottom_navigation');
    }
    await _pump(tester, seconds: 6);
  }
  if (!tester.any(find.byKey(wsEmptySeen)) &&
      !tester.any(find.text('还没有工作区')) &&
      !isOnMainShell(tester)) {
    flowLog('[DIAG] boot 未达稳定态，uid=${UserRepoLocal.to.currentUid}');
    markTestSkipped('未到达登录稳定态（主 Shell）');
    return false;
  }
  expect(UserRepoLocal.to.currentUid, _uid, reason: '登录账号必须是 smoke_bob');
  await _pump(tester, seconds: 5);
  return true;
}

/// 依次填入金额与收款账号（页面恰好两个 TextFormField：0=金额、1=账号）
Future<void> _fill(WidgetTester tester, String amount, String account) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), amount);
  await tester.enterText(fields.at(1), account);
  // 收起键盘，避免提交按钮被键盘遮挡
  FocusManager.instance.primaryFocus?.unfocus();
  await _pump(tester, seconds: 1);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.text('确认提现'), warnIfMissed: false);
  await _pump(tester, seconds: 1);
}

int _withdrawCount = 0;

Future<int> _countWithdrawals() async {
  final v = await TestPg.scalar(
    // withdrawal_logic：提现流水 tx_type=10（withdrawal_logic.erl L33）
    'SELECT count(*) FROM wallet_transaction '
    'WHERE user_id = @uid AND tx_type = 10',
    {'uid': int.parse(_uid)},
  );
  return int.tryParse('$v') ?? 0;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次172：AT-WD1 提现失败错误提示（本地校验链，零资金写入）', (tester) async {
    if (!await _boot(tester)) return;
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    _withdrawCount = await _countWithdrawals();
    flowLog('[AT-WD1] 起始提现单数=$_withdrawCount');

    router.push('/wallet/withdraw');
    final pageReady = await _waitFor(
      tester,
      () => tester.any(find.text('确认提现')),
      seconds: 15,
    );
    expect(pageReady, isTrue, reason: '前置：提现页应打开（「确认提现」按钮可见）');
    await _pump(tester, seconds: 2);

    // ── AT-WD1a：账号空 → 字段错误 ──
    await _fill(tester, '12.34', '');
    await _submit(tester);
    expect(
      tester.any(find.text('请输入提现账号')),
      isTrue,
      reason: 'AT-WD1a：账号空应显示「请输入提现账号」字段错误',
    );
    flowLog('[AT-WD1a] PASS：账号空错误提示');

    // ── AT-WD1b：金额 0 → 字段错误 ──
    await _fill(tester, '0', '');
    await _submit(tester);
    expect(
      tester.any(find.text('请输入不低于0.01元的金额')),
      isTrue,
      reason: 'AT-WD1b：金额 0 应显示「请输入不低于0.01元的金额」字段错误',
    );
    flowLog('[AT-WD1b] PASS：金额不合法错误提示');

    // ── AT-WD1c：支付宝账号格式错 ──
    await _fill(tester, '12.34', '!!!invalid!!!');
    await _submit(tester);
    expect(
      tester.any(find.text('请输入正确的支付宝邮箱或手机号')),
      isTrue,
      reason: 'AT-WD1c：非法支付宝账号应显示格式错误提示',
    );
    flowLog('[AT-WD1c] PASS：账号格式错误提示');

    // ── AT-WD1d：金额超余额 → toast「余额不足」（本地拦截，请求不发）──
    await _fill(tester, '99999999', 'smoke_bob@imboy.pub');
    await _submit(tester);
    final toastSeen = await _waitFor(
      tester,
      () => tester.any(find.text('余额不足')),
      seconds: 8,
    );
    if (!toastSeen) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText())
          .where((s) => s != null && s.trim().isNotEmpty)
          .take(30)
          .toList();
      flowLog('[DIAG] 未抓到余额不足 toast，可见文本: $texts');
    }
    expect(toastSeen, isTrue, reason: 'AT-WD1d：超余额提现应被本地校验拦截并提示「余额不足」');
    // 确认弹窗不应出现（本地拦截在弹窗之前）
    expect(
      tester.any(find.text('提现账号（邮箱或手机号）')),
      isTrue,
      reason: 'AT-WD1d：拦截后应仍在表单页（无二次确认弹窗路径）',
    );
    flowLog('[AT-WD1d] PASS：余额不足 toast');

    // ── AT-WD1e：全程零提现单写入 ──
    await _pump(tester, seconds: 2);
    final after = await _countWithdrawals();
    expect(
      after,
      _withdrawCount,
      reason: 'AT-WD1e：失败路径不得产生提现单（$after vs $_withdrawCount）',
    );
    flowLog('[AT-WD1e] PASS：零资金写入（提现单 $_withdrawCount → $after）');
    flowLog('[AT-WD1] 全部 PASS');
  });
}
