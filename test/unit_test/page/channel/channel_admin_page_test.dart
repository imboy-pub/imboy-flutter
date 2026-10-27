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

  testWidgets('creator(role=3) 渲染创建者徽标且无操作菜单，防止创建者被降级/移除', (tester) async {
    when(() => api.getAdmins(any())).thenAnswer(
      (_) async => [
        {
          'user_id': '3003',
          'nickname': '创建者老王',
          'role': 3,
          'created_at': '2024-01-01T00:00:00Z',
        },
      ],
    );

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();

    expect(find.text(t.channel.roleCreator), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('admin(role=2) 渲染操作菜单（可改角色/移除）且无创建者徽标', (tester) async {
    when(() => api.getAdmins(any())).thenAnswer(
      (_) async => [
        {
          'user_id': '2002',
          'nickname': '管理员小李',
          'role': 2,
          'created_at': '2024-01-02T00:00:00Z',
        },
      ],
    );

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();

    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
    expect(find.text(t.channel.roleCreator), findsNothing);
  });

  testWidgets('加载失败时渲染可重试的失败态 / renders retryable error view on load failure', (
    tester,
  ) async {
    var calls = 0;
    when(() => api.getAdmins(any())).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('network down');
      return const [];
    });

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();

    // 失败态：友好文案 + 重试入口，而非空态"暂无管理员"
    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.text(t.common.buttonRetry), findsOneWidget);
    expect(find.text(t.channel.noAdmins), findsNothing);

    // 点击重试真的重新拉取，并切换到空态
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text(t.channel.noAdmins), findsOneWidget);
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

  // ─── R13：管理员添加时间标签按本地日历日（非滚动 24 小时）─────────────────
  //
  // 构造相对真实 now 的本地日历时间：无论测试何时运行、运行在哪个 TZ，
  // "本地昨天 23:59"永远属于日历意义上的昨天。旧实现（滚动 24h）在
  // 当天较晚时段会把它显示成"今天"。
  group('R13 calendar day labels', () {
    Map<String, dynamic> adminAt(DateTime localTime) => {
      'user_id': '2002',
      'nickname': '日历测试员',
      'role': 2,
      'created_at': localTime.millisecondsSinceEpoch,
    };

    DateTime localTodayAt(int h, int m) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, h, m);
    }

    DateTime localYesterdayAt(int h, int m) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - 1, h, m);
    }

    DateTime localDaysAgoAt(int days) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - days);
    }

    Future<String> pumpSubtitleText(WidgetTester tester, DateTime at) async {
      when(() => api.getAdmins(any())).thenAnswer((_) async => [adminAt(at)]);
      await tester.pumpWidget(_buildTestApp(api));
      await tester.pumpAndSettle();
      final subtitle =
          tester.widget<ListTile>(find.byType(ListTile).first).subtitle as Text;
      return subtitle.data!;
    }

    testWidgets('R13-1 本地昨天 23:59 显示昨天（00:01 看昨天 23:59 同理）', (tester) async {
      final subtitle = await pumpSubtitleText(tester, localYesterdayAt(23, 59));
      expect(subtitle, contains(t.channel.yesterday));
      expect(subtitle, isNot(contains(t.channel.today)));
    });

    testWidgets('R13-1b 本地今天 00:01 显示今天（仅隔 2 分钟仍跨日界）', (tester) async {
      final subtitle = await pumpSubtitleText(tester, localTodayAt(0, 1));
      expect(subtitle, contains(t.channel.today));
    });

    testWidgets('R13-5 本地今天 23:59 仍是今天；次日开头不重叠', (tester) async {
      final subtitle = await pumpSubtitleText(tester, localTodayAt(23, 59));
      expect(subtitle, contains(t.channel.today));
    });

    testWidgets('R13-3 日历日差 3 天按日历计（"3 天前"）', (tester) async {
      final subtitle = await pumpSubtitleText(tester, localDaysAgoAt(3));
      expect(subtitle, contains('3'));
      expect(subtitle, contains(t.channel.daysAgo));
    });

    testWidgets('R13-3b 超过 7 个日历日显示本地 yyyy-MM-dd 日期', (tester) async {
      final at = localDaysAgoAt(8);
      final subtitle = await pumpSubtitleText(tester, at);
      final expected =
          '${at.year}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')}';
      expect(subtitle, contains(expected));
    });
  });
}
