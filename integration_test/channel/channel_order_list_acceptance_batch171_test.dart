// integration_test/channel/channel_order_list_acceptance_batch171_test.dart
//
// channel_order_list_page「加载失败态展示与点击重试」行解锁（批次171，
// automation 第四十四轮）。原阻塞理由「付费功能开启后（入口不可达）」
// 处置：订单列表页路由 /channel/orders 可直 push，无需经付费频道详情
// 入口；入口判定（paid+channelOrder flag）属频道详情页已通过行。
//
// 本行挖出并修复真 bug BUG#151：myOrders 对业务/网络失败静默 return
// null → channelMyOrdersProvider 把失败压成空列表 → 页面 async.when 的
// error 分支为死代码，且 error 文案与空态共用 noOrders（加载失败时用户
// 看到「暂无订单」有误导）。修复对齐 throwIfFailed 治理模式：失败抛
// 异常进 error 态 + 文案改 loadError。
//
// 双层证据组合：
//   - widget test（channel_order_list_page_error_retry_test.dart）：
//     注入抛错 api，真实驱动失败态渲染 + 点击重试 + 失败可恢复（9/9）
//   - 本集成测试：真实路由 + 真实服务端链路，入口可达性与正常态回归
//
//   AT-OL1 真实路由进入订单列表页，正常链路渲染空态（无失败态误显）
//
// 运行（define 与批次170 同配方）：
//   flutter test integration_test/channel/channel_order_list_acceptance_batch171_test.dart \
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次171：AT-OL1 订单列表真实路由进入+空态回归', (tester) async {
    if (!await _boot(tester)) return;
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // smoke_bob 在沙盒库无付费订单（批次122 造数已清理），
    // 正常链路下页面应渲染空态而非失败态。
    router.push('/channel/orders');
    final pageReady = await _waitFor(
      tester,
      () =>
          tester.any(find.text('我的订单')) &&
          (tester.any(find.text('暂无订单记录')) ||
              tester.any(find.text('加载失败，请重试'))),
      seconds: 20,
    );
    if (!pageReady) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText())
          .where((s) => s != null && s.trim().isNotEmpty)
          .take(30)
          .toList();
      flowLog('[DIAG] 订单页未稳定，可见文本: $texts');
    }
    expect(pageReady, isTrue, reason: 'AT-OL1：/channel/orders 应打开订单列表页');

    expect(
      tester.any(find.text('暂无订单记录')),
      isTrue,
      reason: 'AT-OL1：bob 无订单，正常链路应渲染空态「暂无订单记录」',
    );
    expect(
      tester.any(find.text('加载失败，请重试')),
      isFalse,
      reason: 'AT-OL1：BUG#151 回归——服务端正常时不得误入失败态',
    );
    flowLog('[AT-OL1] PASS：真实路由空态渲染，无误入失败态');
    await _pump(tester, seconds: 2);
  });
}
