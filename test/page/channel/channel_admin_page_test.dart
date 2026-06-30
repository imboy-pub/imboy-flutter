// ChannelAdminPage Widget 测试
//
// 验证依赖注入重构成果：页面 _api = ChannelApi() 直接实例化，重构前不可注入
// 而被 skip。现 _api 经 channelApiProvider 获取，可通过 override 注入 mock，
// initState 的 _loadAdmins 不触发真实网络，空态/列表态可测。
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_admin_page_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_admin_page.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/store/api/channel_api.dart';

class _MockChannelApi extends Mock implements ChannelApi {}

Widget _buildTestApp(ChannelApi api) {
  return TranslationProvider(
    child: ProviderScope(
      overrides: [channelApiProvider.overrideWithValue(api)],
      child: const MaterialApp(home: ChannelAdminPage(channelId: '1001')),
    ),
  );
}

void main() {
  late _MockChannelApi api;

  setUp(() {
    api = _MockChannelApi();
  });

  testWidgets('无管理员时渲染空态 / renders empty view when no admins', (tester) async {
    when(() => api.getAdmins(any())).thenAnswer((_) async => const []);

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();

    // 注入的 mock 被调用，证明 channelApiProvider override 生效
    verify(() => api.getAdmins('1001')).called(1);
    expect(find.text(t.channel.noAdmins), findsOneWidget);
  });

  testWidgets('有管理员时渲染列表 / renders admin list', (tester) async {
    when(() => api.getAdmins(any())).thenAnswer(
      (_) async => [
        {
          'user_id': '2002',
          'nickname': '管理员小李',
          'role': 2,
          'added_at': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        },
      ],
    );

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();

    expect(find.text('管理员小李'), findsOneWidget);
  });

  testWidgets(
    '管理员数据类型异常时仍能正常渲染 / handles loose data types in admins without throwing TypeError',
    (tester) async {
      when(() => api.getAdmins(any())).thenAnswer(
        (_) async => [
          {
            'user_id': 2002, // integer instead of string
            'nickname': null, // null nickname
            'role': '2', // string instead of int
            'created_at': '2024-01-01T00:00:00Z', // ISO string
          },
        ],
      );

      await tester.pumpWidget(_buildTestApp(api));
      await tester.pumpAndSettle();

      expect(
        find.text('2002'),
        findsOneWidget,
      ); // Falls back to user_id string when nickname is null
    },
  );
}
