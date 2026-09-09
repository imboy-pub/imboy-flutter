// integration_test/wallet/wallet_acceptance_batch156_test.dart
//
// Wallet 域两行阻塞解锁验收（批次156，配方同 batch154/155）：
//
//   AT-WTOP1 提交充值订单并刷新余额
//     （wallet_page 台账行；解锁=本地 in-app mock 支付通道（批次148 wire
//      实测 topup code=0）。BUG#82 红线：mock 入口仅非生产环境展示
//      （PaymentConfig.isMockPayAllowed 双侧环境判定），本批 APP_ENV=
//      local_office 走本地 9801+本地 PG，绝不触生产通道）
//   AT-WFLOW2 触底加载更多流水记录
//     （wallet_page 台账行；bob 现有 23 条流水 + 本批充值 1 条 = 24 条，
//      分页 size=20 → 首屏 20 条、触底加载第 2 页，无需额外造数）
//
// 载体：smoke_bob（uid=1000000056，余额基线 2080 分由批次148 fixture 就位）。
// 红线：仅本地（9801/4323）；金额 1.00 元最小额度；绝不触生产 mock 通道。
//
// 运行（配方同 batch154）：
//   flutter test integration_test/wallet/wallet_acceptance_batch156_test.dart \
//     -d <device> \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_PHONE=smoke_bob \
//     --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/wallet/wallet_page.dart';
import 'package:imboy/page/wallet/wallet_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_WORKSPACE_ACCEPTANCE',
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
  int seconds = 15,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

WalletState _walletState(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(WalletPage)),
).read(walletProvider);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次156：AT-WTOP1 + AT-WFLOW2', (tester) async {
    expect(
      _allow,
      isTrue,
      reason: '需要 TEST_ALLOW_WORKSPACE_ACCEPTANCE=true 显式放行（资金域红线）',
    );

    app.main();
    await _pump(tester, seconds: 12);
    if (UserRepoLocal.to.currentUid.isNotEmpty) {
      await UserRepoLocal.to.quitLogin();
      GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
      await _pump(tester, seconds: 4);
      await Future<void>.delayed(const Duration(seconds: 4));
      await _pump(tester, seconds: 2);
    }
    const loginSubmit = Key('login_submit_button');
    for (var i = 0; i < 8; i++) {
      if (UserRepoLocal.to.currentUid == _expectedUid &&
          isOnMainShell(tester)) {
        break;
      }
      if (tester.any(find.byKey(loginSubmit))) {
        await performLogin(
          tester,
          phone: FlowConfig.testPhone,
          password: FlowConfig.testPassword,
        );
      } else if (isOnWelcomePage(tester)) {
        await leaveWelcomePage(tester);
      }
      await _pump(tester, seconds: 6);
    }
    expect(UserRepoLocal.to.currentUid, _expectedUid, reason: '必须是 smoke_bob');
    flowLog('[批次156] bob 登录完成');

    // 前置基线：DB 余额（批次148 fixture 2080 分）+ 流水 >20 条（第 2 页存在）
    final bal0 = int.parse(
      '${await TestPg.scalar('SELECT balance FROM wallet WHERE user_id = 1000000056')}',
    );
    final tx0 = int.parse(
      '${await TestPg.scalar('SELECT count(*) FROM wallet_transaction WHERE user_id = 1000000056')}',
    );
    flowLog('[批次156] 基线 balance=$bal0 分, 流水=$tx0 条');
    expect(tx0, greaterThan(20), reason: '前置：流水须 >20 条（分页 size=20）');

    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/wallet');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(WalletPage)),
        seconds: 10,
      ),
      isTrue,
      reason: '前置：钱包页可达',
    );
    // 等余额与首屏流水加载完成
    expect(
      await _waitFor(
        tester,
        () => _walletState(tester).transactions.isNotEmpty,
        seconds: 10,
      ),
      isTrue,
      reason: '前置：流水首屏加载完成',
    );
    await _pump(tester, seconds: 2);
    expect(
      _walletState(tester).transactions.length,
      20,
      reason: '前置：首屏恰 20 条（size=20）',
    );

    // ══════════ AT-WTOP1：充值 1.00 元（mock）→ 余额刷新 ══════════
    await tester.tap(
      find.byIcon(CupertinoIcons.add_circled),
      warnIfMissed: false,
    );
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(CupertinoAlertDialog)),
        seconds: 6,
      ),
      isTrue,
      reason: 'AT-WTOP1：金额弹窗弹出',
    );
    final amountField = tester.widget<CupertinoTextField>(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      ),
    );
    amountField.controller!.text = '1.00';
    await _pump(tester, seconds: 1);
    await tester.tap(find.text('确认充值'), warnIfMissed: false);
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text('模拟支付（开发环境）')),
        seconds: 6,
      ),
      isTrue,
      reason: 'AT-WTOP1：支付方式 sheet 弹出（mock 选项=本地环境展示）',
    );
    await tester.tap(find.text('模拟支付（开发环境）'), warnIfMissed: false);
    // mock 即时入账：成功 toast + DB 余额 +100
    final okToast = await _waitFor(
      tester,
      () => tester.any(find.text('充值成功')),
      seconds: 10,
    );
    expect(okToast, isTrue, reason: 'AT-WTOP1：mock 支付成功 toast 未出现');
    // 服务端入账轮询：DB 余额 +100 分（充值流水异步落库）
    var serverCredited = false;
    for (var i = 0; i < 16 && !serverCredited; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final b = int.parse(
        '${await TestPg.scalar('SELECT balance FROM wallet WHERE user_id = 1000000056')}',
      );
      serverCredited = b == bal0 + 100;
    }
    expect(serverCredited, isTrue, reason: 'AT-WTOP1：服务端入账（DB 余额 +100 分）');
    // UI 余额刷新：基线+100 分（金额用相对基线计算——余额随历史充值
    // 累积持久化，写死绝对值会在第二次运行时失配，run2 教训）
    final expectBalanceText = '¥ ${((bal0 + 100) / 100.0).toStringAsFixed(2)}';
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text(expectBalanceText)),
        seconds: 8,
      ),
      isTrue,
      reason: 'AT-WTOP1：余额 UI 刷新为 $expectBalanceText',
    );
    flowLog('[AT-WTOP1] ✓ toast + DB +100 分 + UI 余额刷新');
    flowLog('[AT-WTOP1] ── PASS ──');

    // ══════════ AT-WFLOW2：触底加载更多流水 ══════════
    // 充值后流水 24 条：首屏 20 → 触底加载第 2 页 4 条
    final scrollable = find.byType(Scrollable).first;
    var loaded = false;
    for (var i = 0; i < 8 && !loaded; i++) {
      await tester.drag(scrollable, const Offset(0, -600));
      await _pump(tester, seconds: 2);
      loaded = _walletState(tester).transactions.length > 20;
    }
    expect(loaded, isTrue, reason: 'AT-WFLOW2：触底后应加载第 2 页流水（>20 条）');
    final txTotal = _walletState(tester).transactions.length;
    final txDb = int.parse(
      '${await TestPg.scalar('SELECT count(*) FROM wallet_transaction WHERE user_id = 1000000056')}',
    );
    expect(txTotal, txDb, reason: 'AT-WFLOW2：加载后流水条数与 DB 总数一致（$txTotal/$txDb）');
    flowLog('[AT-WFLOW2] ✓ 触底加载 $txTotal/$txDb 条');
    flowLog('[AT-WFLOW2] ── PASS ──');
  });
}
