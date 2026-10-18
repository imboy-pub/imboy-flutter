import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/flat_list_tile.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/shimmer_list.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_list_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_role_badge.dart';
import 'package:imboy/store/model/channel_model.dart';

import '../golden_baseline_guard.dart';

ChannelModel _channel({
  required int id,
  required String name,
  int visibility = 0,
  int accessType = 0,
  ChannelUserRole role = ChannelUserRole.subscriber,
  bool verified = false,
  List<String>? tags,
  String? customId,
  bool active = false,
}) {
  final timestamp = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  return ChannelModel(
    id: id,
    name: name,
    visibility: visibility,
    accessType: accessType,
    joinPolicy: accessType == 1 ? 3 : visibility,
    price: accessType == 1 ? 1200 : 0,
    creatorId: 1,
    subscriberCount: 12034,
    isVerified: verified,
    tags: tags,
    createdAt: timestamp,
    updatedAt: active ? timestamp.add(const Duration(days: 1)) : timestamp,
    userRole: role,
    isSubscribed: true,
    customId: customId,
  );
}

List<ChannelModel> _subscribedFixture() => [
  _channel(id: 1, name: '工程效率双周刊', tags: const ['效率', '工程']),
  _channel(id: 2, name: '内部公告板', visibility: 1, accessType: 1),
  _channel(
    id: 3,
    name: '产品发布频道',
    role: ChannelUserRole.creator,
    verified: true,
    tags: const ['产品', '发布', '公告'],
  ),
  _channel(id: 4, name: '一个特别特别特别特别特别特别特别特别特别特别长的频道名称测试用例'),
];

List<ChannelModel> _managedFixture() => [
  _channel(id: 11, name: '我创建的频道', role: ChannelUserRole.creator),
  _channel(id: 12, name: '我是管理员的频道', role: ChannelUserRole.admin),
  _channel(id: 13, name: '我是编辑的频道', role: ChannelUserRole.editor),
  _channel(id: 14, name: '无角色频道', role: ChannelUserRole.none),
];

class _FixedChannelListNotifier extends ChannelListNotifier {
  _FixedChannelListNotifier({
    ChannelListState? subscribed,
    ChannelListState? managed,
  }) : subscribed =
           subscribed ?? ChannelListState(channels: _subscribedFixture()),
       managed = managed ?? ChannelListState(channels: _managedFixture());

  final ChannelListState subscribed;
  final ChannelListState managed;
  int subscribedLoads = 0;
  int managedLoads = 0;
  int moreLoads = 0;

  @override
  ChannelListState build() => subscribed;

  @override
  Future<void> loadSubscribedChannels() async {
    subscribedLoads++;
    state = subscribed;
  }

  @override
  Future<void> loadManagedChannels() async {
    managedLoads++;
    state = managed;
  }

  @override
  Future<void> loadMoreSubscribedChannels() async {
    moreLoads++;
  }
}

Future<_FixedChannelListNotifier> _pumpPage(
  WidgetTester tester, {
  _FixedChannelListNotifier? notifier,
  Size size = const Size(390, 844),
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool managed = false,
}) async {
  final fixture = notifier ?? _FixedChannelListNotifier();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const ChannelListPage()),
      GoRoute(
        path: '/channel/:id',
        builder: (_, state) => Scaffold(body: Text(state.uri.path)),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        key: UniqueKey(),
        overrides: [channelListProvider.overrideWith(() => fixture)],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  if (managed) {
    tester.widget<TabBarView>(find.byType(TabBarView)).controller!.animateTo(1);
    await tester.pumpAndSettle();
  }
  return fixture;
}

void main() {
  for (final profile in [
    (width: 390.0, scale: 1.0, brightness: Brightness.light),
    (width: 360.0, scale: 1.0, brightness: Brightness.light),
    (width: 360.0, scale: 2.0, brightness: Brightness.dark),
    (width: 1280.0, scale: 1.0, brightness: Brightness.dark),
    (width: 1280.0, scale: 2.0, brightness: Brightness.light),
  ]) {
    for (final managed in [false, true]) {
      final name =
          '${managed ? 'managed' : 'subscribed'}_${profile.width.toInt()}_${profile.scale.toInt()}_${profile.brightness.name}';
      testWidgets(
        'golden: $name',
        skip: !goldenBaselineExists(
          'test/unit_test/page/channel/goldens/channel_list_$name.png',
        ),
        (tester) async {
          await _pumpPage(
            tester,
            size: Size(profile.width, 844),
            textScale: profile.scale,
            brightness: profile.brightness,
            managed: managed,
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(ChannelListPage),
            matchesGoldenFile('goldens/channel_list_$name.png'),
          );
        },
      );
    }
  }

  testWidgets('分段点击、重复点击和滑动保留原有加载次数', (tester) async {
    final notifier = await _pumpPage(tester);
    expect(notifier.subscribedLoads, 1);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(CupertinoSlidingSegmentedControl<int>), findsOneWidget);
    await tester.tap(find.text(t.channel.managed));
    await tester.pumpAndSettle();
    expect(notifier.managedLoads, 1);
    expect(find.text('我创建的频道'), findsOneWidget);
    expect(
      tester
          .widget<CupertinoSlidingSegmentedControl<int>>(
            find.byType(CupertinoSlidingSegmentedControl<int>),
          )
          .groupValue,
      1,
    );
    await tester.tap(find.text(t.channel.managed));
    await tester.pumpAndSettle();
    expect(notifier.managedLoads, 1);
    await tester.fling(find.byType(TabBarView), const Offset(320, 0), 800);
    await tester.pumpAndSettle();
    expect(notifier.subscribedLoads, 2);
    expect(
      tester
          .widget<CupertinoSlidingSegmentedControl<int>>(
            find.byType(CupertinoSlidingSegmentedControl<int>),
          )
          .groupValue,
      0,
    );
  });

  testWidgets('两段热区至少 48pt，管理角色仅在管理页显示', (tester) async {
    await _pumpPage(tester);
    expect(find.byType(ChannelRoleBadge), findsNothing);
    for (final label in [t.channel.subscribed, t.channel.managed]) {
      final segment = find
          .ancestor(of: find.text(label), matching: find.byType(SizedBox))
          .first;
      expect(tester.getSize(segment).height, greaterThanOrEqualTo(48));
    }
    await tester.tap(find.text(t.channel.managed));
    await tester.pumpAndSettle();
    expect(find.byType(ChannelRoleBadge), findsNWidgets(3));
    for (final role in [
      ChannelUserRole.creator,
      ChannelUserRole.admin,
      ChannelUserRole.editor,
    ]) {
      expect(find.text(channelRoleLabel(role)), findsOneWidget);
    }
  });

  testWidgets('公开、私有和付费及认证标识保留，标签移入详情信息', (tester) async {
    final channels = [
      for (final visibility in [0, 1])
        for (final access in [0, 1])
          _channel(
            id: visibility * 2 + access,
            name: '频道 $visibility $access',
            visibility: visibility,
            accessType: access,
            verified: true,
            tags: const ['保留标签'],
          ),
    ];
    await _pumpPage(
      tester,
      notifier: _FixedChannelListNotifier(
        subscribed: ChannelListState(channels: channels),
      ),
    );
    expect(find.byIcon(CupertinoIcons.globe), findsNWidgets(2));
    expect(find.byIcon(CupertinoIcons.lock), findsNWidgets(2));
    expect(find.text(t.channel.accessTypePaid), findsNWidgets(2));
    expect(find.byIcon(CupertinoIcons.checkmark_seal_fill), findsNWidgets(4));
    expect(find.text('保留标签'), findsNothing);
  });

  for (final customId in [null, 'release-news']) {
    testWidgets('详情路由保留 ${customId ?? 'numeric id'}', (tester) async {
      await _pumpPage(
        tester,
        notifier: _FixedChannelListNotifier(
          subscribed: ChannelListState(
            channels: [_channel(id: 42, name: '进入频道', customId: customId)],
          ),
        ),
      );
      await tester.tap(find.text('进入频道'));
      await tester.pumpAndSettle();
      expect(find.text('/channel/${customId ?? 42}'), findsOneWidget);
    });
  }

  for (final managed in [false, true]) {
    testWidgets('空列表和错误恢复保留 ${managed ? 'managed' : 'subscribed'}', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        notifier: _FixedChannelListNotifier(
          subscribed: const ChannelListState(),
          managed: const ChannelListState(),
        ),
        managed: managed,
      );
      expect(
        find.text(
          managed
              ? t.channel.noManagedChannels
              : t.channel.noSubscribedChannels,
        ),
        findsOneWidget,
      );
      final denied = ChannelListState(error: t.common.noPermission);
      final notifier = await _pumpPage(
        tester,
        notifier: _FixedChannelListNotifier(
          subscribed: denied,
          managed: denied,
        ),
        managed: managed,
      );
      expect(find.text(t.common.noPermission), findsOneWidget);
      final before = managed ? notifier.managedLoads : notifier.subscribedLoads;
      await tester.tap(find.text(t.common.buttonRetry));
      await tester.pump();
      expect(
        managed ? notifier.managedLoads : notifier.subscribedLoads,
        before + 1,
      );
    });

    testWidgets('分页边界和刷新入口保留 ${managed ? 'managed' : 'subscribed'}', (
      tester,
    ) async {
      final state = ChannelListState(
        channels: List.generate(
          40,
          (index) => _channel(id: index, name: '频道 $index'),
        ),
        hasMore: true,
        cursor: 'next',
      );
      final notifier = await _pumpPage(
        tester,
        notifier: _FixedChannelListNotifier(subscribed: state, managed: state),
        managed: managed,
      );
      final listContext = tester.element(find.byType(ListView));
      final before = notifier.moreLoads;
      for (final pixels in [799.0, 800.0]) {
        ScrollUpdateNotification(
          metrics: FixedScrollMetrics(
            minScrollExtent: 0,
            maxScrollExtent: 1000,
            pixels: pixels,
            viewportDimension: 500,
            axisDirection: AxisDirection.down,
            devicePixelRatio: 1,
          ),
          context: listContext,
        ).dispatch(listContext);
        expect(
          notifier.moreLoads,
          before + (!managed && pixels == 800 ? 1 : 0),
        );
      }
      final loads = managed ? notifier.managedLoads : notifier.subscribedLoads;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      expect(
        managed ? notifier.managedLoads : notifier.subscribedLoads,
        loads + 1,
      );
    });
  }

  testWidgets('窄屏双倍字号保留订阅数与活跃时间，标签移入详情且无溢出', (tester) async {
    await _pumpPage(
      tester,
      size: const Size(360, 844),
      textScale: 2,
      notifier: _FixedChannelListNotifier(
        subscribed: ChannelListState(
          channels: [
            _channel(id: 1, name: '活跃频道', active: true, tags: const ['保留标签']),
          ],
        ),
      ),
    );
    expect(find.byIcon(CupertinoIcons.clock), findsOneWidget);
    expect(find.textContaining('12034'), findsOneWidget);
    expect(find.text('保留标签'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('返回列表保留选中标签和滚动位置', (tester) async {
    await _pumpPage(
      tester,
      notifier: _FixedChannelListNotifier(
        subscribed: ChannelListState(
          channels: List.generate(
            30,
            (index) => _channel(id: index, name: '频道 $index'),
          ),
        ),
      ),
    );
    final scrollable = find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('频道 6'));
    await tester.pumpAndSettle();
    expect(find.text('/channel/6'), findsOneWidget);
    GoRouter.of(tester.element(find.text('/channel/6'))).pop();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TabBarView>(find.byType(TabBarView)).controller!.index,
      0,
    );
    expect(tester.state<ScrollableState>(scrollable).position.pixels, 300);
  });

  testWidgets('加载态仍为骨架，不发出额外请求', (tester) async {
    final notifier = await _pumpPage(
      tester,
      notifier: _FixedChannelListNotifier(
        subscribed: const ChannelListState(isLoading: true),
      ),
    );
    expect(find.byType(ShimmerList), findsOneWidget);
    expect(find.byType(NoDataView), findsNothing);
    expect(notifier.subscribedLoads, 1);
    expect(notifier.managedLoads, 0);
    expect(notifier.moreLoads, 0);
  });

  testWidgets('四行 fixture 保留首屏容量', (tester) async {
    await _pumpPage(tester);
    expect(find.byType(FlatListTile), findsNWidgets(4));
    expect(
      tester.getTopLeft(find.byType(FlatListTile).first).dy,
      lessThanOrEqualTo(115),
    );
    expect(
      tester.getBottomRight(find.byType(FlatListTile).last).dy,
      lessThan(844),
    );
  });
}
