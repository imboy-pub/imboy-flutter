// ChannelSubscriberPage Widget 测试
//
// 验证依赖注入重构成果：页面 _api = ChannelApi() 直接实例化，重构前不可注入
// 而被 skip。现 _api 经 channelApiProvider 获取，可通过 override 注入 mock，
// initState 的订阅者加载不触发真实网络，空态/列表态可测。
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_subscriber_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_subscriber_page.dart';
import 'package:imboy/store/api/channel_api.dart';

class _MockChannelApi extends Mock implements ChannelApi {}

Widget _buildTestApp(ChannelApi api) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [channelApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: ChannelSubscriberPage(channelId: '1001')),
    ),
  );
}

void main() {
  late _MockChannelApi api;

  setUp(() {
    api = _MockChannelApi();
  });

  testWidgets('无订阅者时渲染空态 / renders empty view when no subscribers', (
    tester,
  ) async {
    when(
      () => api.getSubscribers(
        channelId: any(named: 'channelId'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const <Map<String, dynamic>>[]);

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();

    // 注入的 mock 被调用，证明 channelApiProvider override 生效
    verify(
      () => api.getSubscribers(
        channelId: any(named: 'channelId'),
        cursor: any(named: 'cursor'),
        limit: any(named: 'limit'),
      ),
    ).called(1);
    expect(find.byType(ChannelSubscriberPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
