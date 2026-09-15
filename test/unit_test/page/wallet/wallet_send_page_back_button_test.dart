// 钱包「被 push 的填写页」返回键契约测试
//
// 背景（2026-09-15 举一反三排查）：用户报「频道内容详情页左上角没有返回
// 上一页按钮」后全仓排查，发现同族漏写 10 个文件 12 处，其中钱包占 4 处。
// 根因是 `GlassAppBar.automaticallyImplyLeading` **默认 false**
// （lib/component/ui/common_bar.dart），漏写不报错、不告警，只能靠眼看。
//
// 这三页都是 push 进来的：
//   wallet_page            → '/wallet/withdraw'
//   extra_item（聊天 + 面板）→ '/transfer_send'
//   extra_item（聊天 + 面板）→ '/red_packet_send'
// 所以左上角必须能返回。
//
// 关键：必须用 navigatorKey + MaterialPageRoute 把页面 **push 到已有路由之上**。
// 直接 `home: XxxPage()` 时 Navigator.canPop 恒 false，GlassAppBar 无论开关
// 怎么配都不渲染返回键 —— 那样写测试会恒绿，测不出本契约（假绿）。
//
// 全量策略守卫见 test/unit_test/page/glass_app_bar_policy_test.dart（源码级 R1/R2）。
//
// 运行方式 / How to run:
//   flutter test test/unit_test/page/wallet/wallet_send_page_back_button_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/wallet/red_packet_send_page.dart';
import 'package:imboy/page/wallet/transfer_send_page.dart';
import 'package:imboy/page/wallet/withdraw_page.dart';

const String _previousPageText = '上一页占位';

/// 把目标页 push 到「上一页」之上，返回 navigatorKey 供断言栈状态。
Future<GlobalKey<NavigatorState>> _pushPage(
  WidgetTester tester,
  Widget Function() build,
) async {
  final navKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        child: MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Center(child: Text(_previousPageText))),
        ),
      ),
    ),
  );
  navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => build()));
  await tester.pumpAndSettle();
  return navKey;
}

/// 断言：左上角有返回键，且点击后确实回到上一页。
Future<void> _expectBackAndReturn(WidgetTester tester, Type pageType) async {
  expect(find.byType(pageType), findsOneWidget);
  expect(
    find.byType(GlassBackButton),
    findsOneWidget,
    reason: '$pageType 左上角必须有返回上一页按钮',
  );

  await tester.tap(find.byType(GlassBackButton));
  await tester.pumpAndSettle();

  expect(find.byType(pageType), findsNothing);
  expect(find.text(_previousPageText), findsOneWidget);
}

void main() {
  testWidgets('提现页：被 push 进入时有返回键，点击可退回', (tester) async {
    await _pushPage(tester, WithdrawPage.new);
    await _expectBackAndReturn(tester, WithdrawPage);
  });

  testWidgets('转账页：被 push 进入时有返回键，点击可退回', (tester) async {
    await _pushPage(tester, () => const TransferSendPage(toUid: 'u-1'));
    await _expectBackAndReturn(tester, TransferSendPage);
  });

  testWidgets('发红包页：被 push 进入时有返回键，点击可退回', (tester) async {
    await _pushPage(
      tester,
      () => const RedPacketSendPage(chatType: 'C2C', toUid: 'u-1'),
    );
    await _expectBackAndReturn(tester, RedPacketSendPage);
  });
}
