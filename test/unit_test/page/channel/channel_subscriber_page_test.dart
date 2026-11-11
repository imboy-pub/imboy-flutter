// ChannelSubscriberPage Widget 测试
//
// 验证依赖注入重构成果：页面 _api = ChannelApi() 直接实例化，重构前不可注入
// 而被 skip。现 _api 经 channelApiProvider 获取，可通过 override 注入 mock，
// initState 的订阅者加载不触发真实网络，空态/列表态可测。
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_subscriber_page_test.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_subscriber_page.dart';
import 'package:imboy/store/api/channel_api.dart';

class _MockChannelApi extends Mock implements ChannelApi {}

Map<String, dynamic> _subscriber(int id) => {
  'user_id': '$id',
  'nickname': '成员-$id',
  'subscribed_at': '2024-01-01T12:00:00Z',
};

void _stubSubscribers(
  _MockChannelApi api,
  Future<List<Map<String, dynamic>>> Function(int) load,
) {
  when(
    () => api.getSubscribers(
      channelId: any(named: 'channelId'),
      cursor: any(named: 'cursor'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((call) => load(call.namedArguments[#cursor] as int));
}

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

  testWidgets('分页异常保留原行，停止自动重试并从同一cursor显式重试', (tester) async {
    final cursors = <int>[];
    final retry = Completer<List<Map<String, dynamic>>>();
    var moreAttempts = 0;
    _stubSubscribers(api, (cursor) async {
      cursors.add(cursor);
      if (cursor == 0) return List.generate(30, _subscriber);
      moreAttempts++;
      if (moreAttempts == 1) {
        throw StateError('channel_subscribers_request_failed');
      }
      return retry.future;
    });

    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(cursors, [0, 30]);
    expect(find.text('${t.channel.manageSubscribers} (30)'), findsOneWidget);
    expect(find.text('成员-29'), findsOneWidget);
    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);

    controller.jumpTo(controller.position.maxScrollExtent - 30);
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(cursors, [0, 30]);
    await tester.ensureVisible(find.text(t.common.buttonRetry));
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pump();
    expect(cursors, [0, 30, 30]);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(find.text('${t.channel.manageSubscribers} (30)'), findsOneWidget);
    retry.complete([_subscriber(100)]);
    await tester.pumpAndSettle();
    expect(find.text('${t.channel.manageSubscribers} (31)'), findsOneWidget);
    expect(find.text('成员-100'), findsOneWidget);
    expect(find.text(t.common.loadError), findsNothing);
    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('刷新进行中及异常后保留已读行，重试第一页成功才替换', (tester) async {
    final cursors = <int>[];
    final refresh = Completer<List<Map<String, dynamic>>>();
    _stubSubscribers(api, (cursor) async {
      cursors.add(cursor);
      if (cursors.length == 1) return [_subscriber(1)];
      if (cursors.length == 2) return refresh.future;
      return [_subscriber(2)];
    });
    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();

    unawaited(
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(cursors, [0, 0]);
    expect(find.text('成员-1'), findsOneWidget);
    refresh.completeError(StateError('channel_subscribers_request_failed'));
    await tester.pumpAndSettle();
    expect(find.text('成员-1'), findsOneWidget);
    expect(find.text(t.common.loadError), findsOneWidget);

    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pumpAndSettle();
    expect(cursors, [0, 0, 0]);
    expect(find.text('成员-1'), findsNothing);
    expect(find.text('成员-2'), findsOneWidget);
    expect(find.text(t.common.loadError), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('刷新后旧分页回包不能追加到新列表', (tester) async {
    final cursors = <int>[];
    final oldPage = Completer<List<Map<String, dynamic>>>();
    _stubSubscribers(api, (cursor) async {
      cursors.add(cursor);
      if (cursor == 30) return oldPage.future;
      return cursors.length == 1
          ? List.generate(30, _subscriber)
          : [_subscriber(500)];
    });
    await tester.pumpWidget(_buildTestApp(api));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<ListView>(find.byType(ListView))
        .controller!;
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(cursors, [0, 30]);
    unawaited(
      tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show(),
    );
    await tester.pumpAndSettle();
    expect(cursors, [0, 30, 0]);
    expect(find.text('成员-500'), findsOneWidget);
    oldPage.complete([_subscriber(999)]);
    await tester.pumpAndSettle();
    expect(find.text('${t.channel.manageSubscribers} (1)'), findsOneWidget);
    expect(find.text('成员-500'), findsOneWidget);
    expect(find.text('成员-999'), findsNothing);
    expect(tester.takeException(), isNull);
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

  testWidgets(
    '有订阅者且包含各种非标准类型数据时仍能正常渲染 / renders subscribers successfully with loose JSON types',
    (tester) async {
      when(
        () => api.getSubscribers(
          channelId: any(named: 'channelId'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          {
            'user_id': 3003, // int instead of String
            'nickname': null,
            'subscribed_at':
                '2024-01-01T12:00:00Z', // ISO-8601 string instead of int ms
            'is_muted': 1, // int instead of bool
          },
        ],
      );

      await tester.pumpWidget(_buildTestApp(api));
      await tester.pumpAndSettle();

      expect(find.text('3003'), findsOneWidget);
    },
  );

  // ─── R13：订阅时间标签按本地日历日（非滚动 24 小时）───────────────────────
  group('R13 calendar day labels', () {
    DateTime localYesterdayAt(int h, int m) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - 1, h, m);
    }

    DateTime localTodayAt(int h, int m) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, h, m);
    }

    Future<String> pumpSubtitleText(WidgetTester tester, DateTime at) async {
      when(
        () => api.getSubscribers(
          channelId: any(named: 'channelId'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer(
        (_) async => [
          {
            'user_id': '3003',
            'nickname': '日历测试员',
            'subscribed_at': at.millisecondsSinceEpoch,
            'is_muted': 0,
          },
        ],
      );
      await tester.pumpWidget(_buildTestApp(api));
      await tester.pumpAndSettle();
      final subtitle =
          tester.widget<ListTile>(find.byType(ListTile).first).subtitle as Text;
      return subtitle.data!;
    }

    testWidgets('R13-1 本地昨天 23:59 显示昨天，不受运行时刻影响', (tester) async {
      final subtitle = await pumpSubtitleText(tester, localYesterdayAt(23, 59));
      expect(subtitle, contains(t.channel.yesterday));
      expect(subtitle, isNot(contains(t.channel.today)));
    });

    testWidgets('R13-5 本地今天 00:01 与 23:59 都是今天（日界无重漏）', (tester) async {
      final early = await pumpSubtitleText(tester, localTodayAt(0, 1));
      expect(early, contains(t.channel.today));
      final late = await pumpSubtitleText(tester, localTodayAt(23, 59));
      expect(late, contains(t.channel.today));
    });
  });
}
