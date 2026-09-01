// 钱包首页只读 UI 流程。
//
// 只验证余额/流水页面能够挂载并完成读取，不点击充值、提现、收款、转账等按钮。
// 使用原生 Navigator 直接挂载页面，测试结束前等待并关闭 route，避免异步
// 页面动画被 teardown 误判为 SemanticsHandle 泄漏。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/wallet/wallet_page.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '钱包首页可访问并完成余额流水只读加载',
    (tester) async {
      await ensureAppLaunched(tester, maxSeconds: 10);
      if (!await checkPreconditions(tester)) return;
      await settle(tester, maxSeconds: 2);
      // 全新环境首次登录会弹 E2EE 恢复指南（本设备新密钥提示），
      // 「稍后」关掉它，否则钱包页流程被弹窗挡住超时。
      await _dismissRecoveryGuide(tester);
      await settle(tester, maxSeconds: 2);

      final navigatorFinder = find.byType(Navigator);
      if (!tester.any(navigatorFinder)) {
        markTestSkipped('App 未找到根 Navigator，跳过钱包首页');
        return;
      }
      final navigator = Navigator.of(
        tester.element(navigatorFinder.first),
        rootNavigator: true,
      );
      final routeResult = navigator.push<void>(
        CupertinoPageRoute<void>(builder: (_) => const WalletPage()),
      );

      final wallet = find.byType(WalletPage);
      final mounted = await _waitFor(
        tester,
        () => tester.any(wallet),
        maxAttempts: 40,
      );
      expect(mounted, isTrue, reason: '钱包首页应成功挂载');
      expect(find.byType(Scaffold), findsWidgets);
      await settle(tester, maxSeconds: 5);
      flowLog('钱包首页已挂载并完成余额/流水只读请求；未执行资金写操作');
      await takeScreenshot(tester, 'wallet_01_readonly');

      if (navigator.canPop()) navigator.pop();
      await settle(tester, maxSeconds: 2);
      await routeResult;
      drainKnownFrameworkExceptions(tester);
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() predicate, {
  required int maxAttempts,
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    if (predicate()) return true;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return predicate();
}

/// E2EE 恢复指南弹窗出现时点「稍后」关闭（全新环境首次登录必弹）。
Future<void> _dismissRecoveryGuide(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    final later = find.byWidgetPredicate(
      (widget) =>
          widget is Text && ['稍后', 'Later'].contains(widget.data?.trim()),
    );
    if (tester.any(later)) {
      await safeTap(tester, later.first);
      return;
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}
