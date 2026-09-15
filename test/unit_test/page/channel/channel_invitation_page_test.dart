// ChannelInvitationPage Widget 测试
//
// 验证依赖注入重构成果：页面 initState 即调用
// ChannelService.getMyInvitations / getSentInvitations，重构前为
// ChannelService.to 单例不可注入而被 skip。现通过 channelServiceProvider
// override 注入 mock，使页面渲染可测且无真实网络。
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_invitation_page_test.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_invitation_page.dart';
import 'package:imboy/service/channel_service.dart';

class _MockChannelService extends Mock implements ChannelService {}

/// 上一页占位文案（返回键用例断言「确实退回去了」）。
const String _previousPageText = '上一页占位';

Widget _buildTestApp(ChannelService service) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [channelServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: ChannelInvitationPage()),
    ),
  );
}

/// 把邀请页 push 到一条已有路由之上——复刻本页真实入口
/// （频道详情 → `context.push('/channel/invitations')`）。
/// `home:` 直挂时 Navigator.canPop 恒 false，返回键永远不会渲染（假绿）。
Widget _buildPushedApp(
  ChannelService service,
  GlobalKey<NavigatorState> navKey,
) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [channelServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Center(child: Text(_previousPageText))),
      ),
    ),
  );
}

void main() {
  late _MockChannelService service;

  setUp(() {
    service = _MockChannelService();
  });

  testWidgets('空邀请数据时渲染两类空态视图 / renders empty views when no invitations', (
    tester,
  ) async {
    when(() => service.getMyInvitations()).thenAnswer((_) async => const []);
    when(() => service.getSentInvitations()).thenAnswer((_) async => const []);

    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    // 注入的 mock 被调用，证明 channelServiceProvider override 生效
    verify(() => service.getMyInvitations()).called(1);
    verify(() => service.getSentInvitations()).called(1);

    // 我收到的邀请：空态文案
    expect(find.text(t.common.noReceivedInvitations), findsOneWidget);
    expect(find.byType(ChannelInvitationPage), findsOneWidget);
  });

  testWidgets('加载抛异常时不崩溃并停止 loading / shows page without crash on error', (
    tester,
  ) async {
    when(() => service.getMyInvitations())
        .thenThrow(Exception('NetworkException'));
    when(() => service.getSentInvitations()).thenAnswer((_) async => const []);

    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    // 不抛出异常即通过；页面仍在树中
    expect(find.byType(ChannelInvitationPage), findsOneWidget);
    // 加载结束后不再显示进度指示器
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // 2026-09-15 举一反三排查（用户报「频道内容详情页没有返回键」后的同族问题）：
  // 本页主态本来就有返回键，但 **加载态与失败态的 AppBar 漏开了开关** ——
  // 失败态最严重：页面只剩「重试」，用户被困在一个错误提示上出不去。
  group('返回上一页（加载态 / 失败态同样要有退路）', () {
    Future<void> pushPage(
      WidgetTester tester,
      GlobalKey<NavigatorState> navKey,
    ) async {
      await tester.pumpWidget(_buildPushedApp(service, navKey));
      navKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const ChannelInvitationPage()),
      );
    }

    testWidgets('加载中也有返回键', (tester) async {
      // 用永不完成的 Completer 把页面钉在 loading 态（不用 Future.delayed，
      // 避免留下 pending timer 让 testWidgets 判失败）。
      final pending = Completer<List<Map<String, dynamic>>>();
      when(() => service.getMyInvitations()).thenAnswer((_) => pending.future);
      when(() => service.getSentInvitations())
          .thenAnswer((_) => pending.future);

      final navKey = GlobalKey<NavigatorState>();
      await pushPage(tester, navKey);
      // 注意：这里**不能用 pumpAndSettle** —— CupertinoActivityIndicator 是
      // 常驻动画组件，页面停在 loading 时永远「settle 不了」，会直接超时。
      // 定长推进把转场推完即可。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(CupertinoActivityIndicator),
        findsOneWidget,
        reason: '前置条件：页面确实处于 loading 态',
      );
      expect(
        find.byType(GlassBackButton),
        findsOneWidget,
        reason: '加载期间不能把用户困在转圈页面上',
      );

      pending.complete(const []);
      await tester.pumpAndSettle();
    });

    testWidgets('失败态有返回键，点击可退回上一页', (tester) async {
      when(() => service.getMyInvitations())
          .thenThrow(Exception('NetworkException'));
      when(() => service.getSentInvitations())
          .thenAnswer((_) async => const []);

      final navKey = GlobalKey<NavigatorState>();
      await pushPage(tester, navKey);
      await tester.pumpAndSettle();

      // 失败态：只剩「重试」按钮，返回键必须存在
      expect(find.text(t.common.buttonRetry), findsOneWidget);
      expect(
        find.byType(GlassBackButton),
        findsOneWidget,
        reason: '错误态没有任何退路是最严重的形态',
      );

      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(ChannelInvitationPage), findsNothing);
      expect(find.text(_previousPageText), findsOneWidget);
    });
  });
}
