import 'dart:ui' show SemanticsAction;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/avatar_fallback.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/widgets/channel_header_bar.dart';
import 'package:imboy/page/channel/widgets/channel_role_badge.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';

class _NotificationService extends Mock implements ChannelService {}

ChannelModel _channel({bool subscribed = false}) => ChannelModel(
  id: 1001,
  name: '测试频道',
  description: '频道简介',
  subscriberCount: 12,
  isSubscribed: subscribed,
  userRole: subscribed ? ChannelUserRole.subscriber : ChannelUserRole.none,
  creatorId: 1,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

Widget _app(Widget child) => TranslationProvider(
  child: ProviderScope(
    child: MaterialApp(home: Scaffold(body: child)),
  ),
);

Widget _themedApp(Widget child) => TranslationProvider(
  child: ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  ),
);

/// 统计行断言：以「订阅者」结尾的 Text（privacyDesc 等长文案含该子串，
/// textContaining 会误伤，须锚定词尾）
Finder statsLine() => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? '').endsWith(t.channel.subscribers),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  setUp(() async {
    await StorageService.to.setString(Keys.currentUid, 'account-a');
  });

  for (final reconcile in [false, true]) {
    for (final pending in [false, true]) {
      testWidgets('紧凑订阅头部48触达与动作语义 reconcile=$reconcile pending=$pending', (
        tester,
      ) async {
        var calls = 0;
        final label = reconcile
            ? t.channel.subscribeRefresh
            : t.channel.subscribe;
        await tester.pumpWidget(
          _app(
            ChannelHeaderBar(
              channel: _channel(),
              showIdentityTitle: false,
              isReconciliationPending: reconcile,
              isActionPending: pending,
              onActionTap: () => calls++,
            ),
          ),
        );
        for (final button in [
          find.byType(CupertinoButton).first,
          find.byType(CupertinoButton).last,
        ]) {
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        }
        expect(find.bySemanticsLabel(label), findsOneWidget);
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isEnabled.toBoolOrNull() != null, isTrue);
        expect(data.flagsCollection.isEnabled.toBoolOrNull() == true, !pending);
        expect(data.hasAction(SemanticsAction.tap), !pending);
        expect(data.value, pending ? t.common.loading : '');
        expect(data.flagsCollection.isLiveRegion, pending);
        await tester.tap(find.byType(CupertinoButton).last);
        expect(calls, pending ? 0 : 1);
      });
    }
  }

  testWidgets('紧凑头部支持 Web 的 Enter 和 Space 激活动作', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          child: MaterialApp(
            shortcuts: {
              ...WidgetsApp.defaultShortcuts,
              const SingleActivator(LogicalKeyboardKey.enter):
                  const ButtonActivateIntent(),
            },
            home: Scaffold(
              body: ChannelHeaderBar(
                channel: _channel(),
                showIdentityTitle: false,
                onActionTap: () => calls++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(calls, 2);
  });

  testWidgets('紧凑通知按钮暴露未知、开关和在途状态，阻止重复执行', (tester) async {
    final service = _NotificationService();
    final initialRead = Completer<ChannelSubscriptionModel?>();
    final update = Completer<bool>();
    var muted = false;
    var reads = 0;
    when(() => service.getSubscription('1001')).thenAnswer((_) {
      if (reads++ == 0) return initialRead.future;
      return Future.value(
        ChannelSubscriptionModel(
          channelId: 1001,
          subscribedAt: DateTime(2024),
          isMuted: muted,
        ),
      );
    });
    when(() => service.setMuted('1001', true)).thenAnswer((_) async {
      final success = await update.future;
      if (success) muted = true;
      return success;
    });
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [channelServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            builder: AppLoading.init(),
            home: Scaffold(
              body: ChannelHeaderBar(
                channel: _channel(subscribed: true),
                showIdentityTitle: false,
              ),
            ),
          ),
        ),
      ),
    );
    final unknown = tester.getSemantics(find.bySemanticsLabel(t.common.retry));
    expect(
      unknown.getSemanticsData().flagsCollection.isToggled.toBoolOrNull() !=
          null,
      isFalse,
    );
    expect(
      tester.getSize(find.byType(CupertinoButton).last),
      const Size(48, 48),
    );
    initialRead.complete(
      ChannelSubscriptionModel(channelId: 1001, subscribedAt: DateTime(2024)),
    );
    await tester.pump();
    final toggle = find.bySemanticsLabel(t.chat.chatSettingMute);
    expect(
      tester
              .getSemantics(toggle)
              .getSemanticsData()
              .flagsCollection
              .isToggled
              .toBoolOrNull() !=
          null,
      isTrue,
    );
    expect(
      tester
              .getSemantics(toggle)
              .getSemanticsData()
              .flagsCollection
              .isToggled
              .toBoolOrNull() ==
          true,
      isFalse,
    );
    await tester.tap(find.byType(CupertinoButton).last);
    await tester.pump();
    final busy = tester.getSemantics(toggle).getSemanticsData();
    expect(busy.flagsCollection.isEnabled.toBoolOrNull() == true, isFalse);
    expect(busy.hasAction(SemanticsAction.tap), isFalse);
    expect(busy.value, t.common.loading);
    await tester.tap(find.byType(CupertinoButton).last);
    verify(() => service.setMuted('1001', true)).called(1);
    update.complete(true);
    await tester.pump();
    await tester.pump();
    expect(
      tester
              .getSemantics(toggle)
              .getSemanticsData()
              .flagsCollection
              .isToggled
              .toBoolOrNull() ==
          true,
      isTrue,
    );
    expect(
      tester
              .getSemantics(toggle)
              .getSemanticsData()
              .flagsCollection
              .isEnabled
              .toBoolOrNull() ==
          true,
      isTrue,
    );
    expect(tester.getSemantics(toggle).getSemanticsData().value, isEmpty);
    final dismissal = AppLoading.dismiss(animation: false);
    await tester.pumpAndSettle();
    await dismissal;
  });

  testWidgets('切换频道后旧的静音读取不能覆盖新频道', (tester) async {
    final service = _NotificationService();
    final oldRead = Completer<ChannelSubscriptionModel?>();
    when(() => service.getSubscription('1001'))
        .thenAnswer((_) => oldRead.future);
    when(() => service.getSubscription('1002')).thenAnswer(
      (_) async => ChannelSubscriptionModel(
        channelId: 1002,
        subscribedAt: DateTime(2024),
      ),
    );
    Widget view(int id) => TranslationProvider(
      child: ProviderScope(
        overrides: [channelServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          home: Scaffold(
            body: ChannelHeaderBar(
              channel: _channel(subscribed: true).copyWith(id: id),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(view(1001));
    await tester.pumpWidget(view(1002));
    await tester.pump();
    oldRead.complete(null);
    await tester.pump();
    expect(find.text(t.chat.chatSettingMute), findsOneWidget);
    expect(find.text(t.common.retry), findsNothing);
  });

  testWidgets('账号变化后重试返回不能对账到新账号', (tester) async {
    final service = _NotificationService();
    final refresh = Completer<ChannelModel?>();
    when(() => service.getSubscription('1001')).thenAnswer((_) async => null);
    when(() => service.refreshChannel('1001'))
        .thenAnswer((_) => refresh.future);
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [channelServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            home: Scaffold(
              body: ChannelHeaderBar(channel: _channel(subscribed: true)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(t.common.retry));
    await tester.pump();
    await StorageService.to.setString(Keys.currentUid, 'account-b');
    refresh.complete(_channel(subscribed: true));
    await tester.pump();
    verifyNever(
      () => service.syncSubscribedChannels(fromList: any(named: 'fromList')),
    );
  });

  testWidgets('对账等待中切换账号后不读取新账号配置', (tester) async {
    final service = _NotificationService();
    final sync = Completer<List<ChannelModel>>();
    when(() => service.getSubscription('1001')).thenAnswer((_) async => null);
    when(() => service.refreshChannel('1001'))
        .thenAnswer((_) async => _channel(subscribed: true));
    when(() => service.syncSubscribedChannels(fromList: any(named: 'fromList')))
        .thenAnswer((_) => sync.future);
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [channelServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            home: Scaffold(
              body: ChannelHeaderBar(channel: _channel(subscribed: true)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(t.common.retry));
    await tester.pump();
    await StorageService.to.setString(Keys.currentUid, 'account-b');
    sync.complete([_channel(subscribed: true)]);
    await tester.pump();
    verify(() => service.getSubscription('1001')).called(1);
  });

  testWidgets('深链冷启动缺本地通知配置时，重试经服务端订阅对账恢复操作', (tester) async {
    final service = _NotificationService();
    bool repaired = false;
    when(() => service.getSubscription('1001')).thenAnswer(
      (_) async => repaired
          ? ChannelSubscriptionModel(
              channelId: 1001,
              subscribedAt: DateTime(2024),
            )
          : null,
    );
    when(() => service.refreshChannel('1001'))
        .thenAnswer((_) async => _channel(subscribed: true));
    when(() => service.syncSubscribedChannels(fromList: any(named: 'fromList')))
        .thenAnswer((_) async {
          repaired = true;
          return [_channel(subscribed: true)];
        });
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [channelServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            home: Scaffold(
              body: ChannelHeaderBar(channel: _channel(subscribed: true)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.common.retry), findsOneWidget);
    await tester.tap(find.text(t.common.retry));
    await tester.pumpAndSettle();
    expect(find.text(t.chat.chatSettingMute), findsOneWidget);
    verify(
      () => service.syncSubscribedChannels(fromList: any(named: 'fromList')),
    ).called(1);
  });

  testWidgets('统计未返回时回退频道自带订阅数，不渲染永久骨架条', (tester) async {
    // 2026-10-17 修复：embedded 模式 autoLoadStats=false，统计永不加载，
    // 原 skeleton 会变成永久灰色占位条；改为直显 channel.subscriberCount。
    await tester.pumpWidget(
      _app(ChannelHeaderBar(channel: _channel(), onActionTap: () {})),
    );

    expect(find.byType(CupertinoActivityIndicator), findsNothing);
    expect(find.textContaining('0'), findsNothing);
    expect(statsLine(), findsOneWidget);
    expect(find.text('12 ${t.channel.subscribers}'), findsOneWidget);
  });

  testWidgets('操作 pending 时按钮禁用并显示 spinner', (tester) async {
    await tester.pumpWidget(
      _app(
        ChannelHeaderBar(
          channel: _channel(),
          onActionTap: () {},
          isActionPending: true,
        ),
      ),
    );

    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('统计返回后显示真实紧凑统计', (tester) async {
    await tester.pumpWidget(
      _app(
        ChannelHeaderBar(
          channel: _channel(subscribed: true),
          stats: ChannelStatsModel(
            channelId: 1001,
            subscriberCount: 12,
            totalMessages: 8,
            totalViews: 20,
            totalReactions: 3,
          ),
        ),
      ),
    );

    expect(statsLine(), findsOneWidget);
    expect(find.text('12 ${t.channel.subscribers}'), findsOneWidget);
    // 本地订阅配置尚未读取成功时显示重试，不伪装为通知已开启。
    expect(find.text(t.common.retry), findsOneWidget);
  });

  testWidgets('暗色主题和动态字号下仍保留订阅语义', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      _themedApp(ChannelHeaderBar(channel: _channel(), onActionTap: () {})),
    );

    expect(find.bySemanticsLabel(t.channel.subscribe), findsOneWidget);
    expect(find.text(t.channel.subscribe), findsOneWidget);
    expect(tester.takeException(), isNull);
    semanticsHandle.dispose();
  });

  testWidgets('管理者头部只显示管理动作，不显示订阅 CTA', (tester) async {
    final managed = ChannelModel(
      id: 1001,
      name: '管理频道',
      description: '频道简介',
      subscriberCount: 12,
      userRole: ChannelUserRole.admin,
      isSubscribed: true,
      creatorId: 1,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

    await tester.pumpWidget(
      _app(ChannelHeaderBar(channel: managed, onActionTap: () {})),
    );

    expect(find.text(t.main.manage), findsOneWidget);
    expect(find.text(t.channel.subscribe), findsNothing);
    expect(find.text(t.channel.subscribed), findsNothing);
  });

  test('英文频道文案已生成且不是中文回退', () async {
    final en = await AppLocale.enUs.build();

    expect(en.channel.subscribe, 'Subscribe');
    expect(en.channel.writeArticle, 'Write Post');
  });

  for (final role in ChannelUserRole.values) {
    testWidgets('角色 $role 保留分享、转发和原主动作', (tester) async {
      final channel = _channel().copyWith(userRole: role);
      final calls = <String>[];
      await tester.pumpWidget(
        _app(
          ChannelHeaderBar(
            channel: channel,
            onShareTap: () => calls.add('share'),
            onForwardTap: () => calls.add('forward'),
            onManageTap: () => calls.add('manage'),
            onActionTap: () => calls.add('action'),
          ),
        ),
      );
      expect(
        find.byType(ChannelRoleBadge),
        channel.isManaged ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text(t.channel.share));
      await tester.tap(find.text(t.channel.shareToChat));
      if (channel.isManaged) {
        await tester.tap(find.text(t.main.manage));
      }
      await tester.tap(find.text(t.channel.subscribe));
      expect(calls, [
        'share',
        'forward',
        if (channel.isManaged) 'manage',
        'action',
      ]);
    });
  }

  testWidgets('统计优先于模型人数且不改取值口径', (tester) async {
    await tester.pumpWidget(
      _app(
        ChannelHeaderBar(
          channel: _channel(),
          stats: ChannelStatsModel(
            channelId: 1001,
            subscriberCount: 42,
            totalMessages: 0,
            totalViews: 0,
            totalReactions: 0,
          ),
        ),
      ),
    );
    expect(find.text('42 ${t.channel.subscribers}'), findsOneWidget);
    expect(find.text('12 ${t.channel.subscribers}'), findsNothing);
  });

  testWidgets('头像解码失败仍显示名称占位，无网络请求', (tester) async {
    final image = cachedImageProvider('def_avatar.png', w: 256);
    final key = await image.obtainKey(ImageConfiguration.empty);
    final decoding = Completer<ImageInfo>();
    PaintingBinding.instance.imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(decoding.future),
    );
    addTearDown(() => PaintingBinding.instance.imageCache.evict(key));
    await tester.pumpWidget(
      _app(
        ChannelHeaderBar(
          channel: _channel().copyWith(avatar: 'def_avatar.png'),
        ),
      ),
    );
    decoding.completeError(StateError('fixture decode failure'));
    await tester.pump();
    expect(find.byType(AvatarFallbackContent), findsOneWidget);
    expect(find.text('测'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
