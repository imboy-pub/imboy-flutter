// ChannelDiscoverPage Widget 测试
//
// 验证依赖注入重构成果：页面 initState 即调用
// ChannelService.getSubscribedChannels / discoverChannels，重构前为
// ChannelService.to 单例不可注入而被 skip。现通过 channelServiceProvider
// override 注入 mock，使页面渲染可测且无真实网络。
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_discover_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_discover_page.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/model/channel_model.dart';

class _MockChannelService extends Mock implements ChannelService {}

ChannelModel _makeChannel({required int id, required String name}) {
  return ChannelModel(
    id: id,
    name: name,
    subscriberCount: 10,
    userRole: ChannelUserRole.subscriber,
    isSubscribed: false,
    creatorId: 1,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

Widget _buildTestApp(ChannelService service) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [channelServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(home: ChannelDiscoverPage()),
    ),
  );
}

void main() {
  late _MockChannelService service;

  setUp(() {
    service = _MockChannelService();
  });

  testWidgets('推荐频道为空时渲染空态 / renders empty view for no recommendations', (
    tester,
  ) async {
    when(
      () => service.getSubscribedChannels(limit: any(named: 'limit')),
    ).thenAnswer((_) async => const []);
    when(
      () => service.discoverChannels(limit: any(named: 'limit')),
    ).thenAnswer((_) async => const []);

    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    // 注入的 mock 被调用，证明 channelServiceProvider override 生效
    verify(
      () => service.discoverChannels(limit: any(named: 'limit')),
    ).called(1);
    expect(find.text(t.channel.noRecommendedChannels), findsOneWidget);
  });

  testWidgets('有推荐频道时渲染频道名称 / renders recommended channel names', (
    tester,
  ) async {
    when(
      () => service.getSubscribedChannels(limit: any(named: 'limit')),
    ).thenAnswer((_) async => const []);
    when(
      () => service.discoverChannels(limit: any(named: 'limit')),
    ).thenAnswer((_) async => [_makeChannel(id: 201, name: '推荐频道A')]);

    await tester.pumpWidget(_buildTestApp(service));
    await tester.pumpAndSettle();

    expect(find.text('推荐频道A'), findsOneWidget);
  });
}
