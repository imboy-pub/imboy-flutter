// ChannelEditPage Widget 测试
//
// 验证依赖注入重构成果：页面 _loadChannel/_saveChanges 中的 ChannelApi() 直接
// 实例化，重构前不可注入而被 skip。现经 channelApiProvider 获取，可通过
// override 注入 mock，使 initState 的 _loadChannel 不触发真实网络，表单渲染可测。
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_edit_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_edit_page.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';

class _MockChannelApi extends Mock implements ChannelApi {}

ChannelModel _makeChannel({required int id, required String name}) {
  return ChannelModel(
    id: id,
    name: name,
    description: '频道简介',
    subscriberCount: 10,
    userRole: ChannelUserRole.creator,
    isSubscribed: true,
    creatorId: 1,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
  );
}

Widget _buildTestApp(ChannelApi api, [ChannelModel? channel]) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [channelApiProvider.overrideWithValue(api)],
      child: MaterialApp(
        home: ChannelEditPage(channelId: '1001', channel: channel),
      ),
    ),
  );
}

void main() {
  late _MockChannelApi api;

  setUp(() {
    api = _MockChannelApi();
  });

  testWidgets('初次加载失败没有空白保存表单，重试后显示真实频道', (tester) async {
    final channel = _makeChannel(id: 1001, name: '重试成功的频道');
    var attempts = 0;
    when(() => api.getChannel(any())).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) throw Exception('temporary failure');
      return channel;
    });

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();
    expect(find.text(t.channel.editChannel), findsOneWidget);
    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text(t.common.save), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text(t.common.loadError), findsNothing);
    expect(find.text('重试成功的频道'), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.text(t.common.save), findsOneWidget);
  });

  testWidgets('ID与自定义ID都未返回频道时不显示可提交空表单', (tester) async {
    when(() => api.getChannel(any())).thenAnswer((_) async => null);
    when(() => api.getChannelByCustomId(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();
    verify(() => api.getChannelByCustomId('1001')).called(1);
    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.text(t.common.buttonRetry), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text(t.common.save), findsNothing);
  });

  testWidgets('渲染编辑表单并预填频道名称 / renders form prefilled with channel name', (
    tester,
  ) async {
    final channel = _makeChannel(id: 1001, name: '我的频道');
    // 传入 channel → initState 以 showLoading=false 调用 _loadChannel，
    // mock getChannel 返回同一频道避免真实网络。
    when(() => api.getChannel(any())).thenAnswer((_) async => channel);
    when(() => api.getChannelByCustomId(any())).thenAnswer((_) async => null);

    await tester.pumpWidget(_buildTestApp(api, channel));
    await tester.pumpAndSettle();

    // 注入的 mock 被调用，证明 channelApiProvider override 生效
    verify(() => api.getChannel('1001')).called(1);
    expect(find.byType(ChannelEditPage), findsOneWidget);
    // 名称输入框预填值可见
    expect(find.text('我的频道'), findsWidgets);
    // 频道名称表单标签
    expect(find.text(t.channel.nameLabel), findsWidgets);
  });
}
