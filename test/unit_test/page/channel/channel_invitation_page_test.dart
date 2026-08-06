// ChannelInvitationPage Widget 测试
//
// 验证依赖注入重构成果：页面 initState 即调用
// ChannelService.getMyInvitations / getSentInvitations，重构前为
// ChannelService.to 单例不可注入而被 skip。现通过 channelServiceProvider
// override 注入 mock，使页面渲染可测且无真实网络。
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_invitation_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_invitation_page.dart';
import 'package:imboy/service/channel_service.dart';

class _MockChannelService extends Mock implements ChannelService {}

Widget _buildTestApp(ChannelService service) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [channelServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: ChannelInvitationPage()),
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
    when(
      () => service.getMyInvitations(),
    ).thenThrow(Exception('NetworkException'));
    when(() => service.getSentInvitations()).thenAnswer((_) async => const []);

    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    // 不抛出异常即通过；页面仍在树中
    expect(find.byType(ChannelInvitationPage), findsOneWidget);
    // 加载结束后不再显示进度指示器
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
