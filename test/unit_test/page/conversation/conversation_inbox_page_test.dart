import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/conversation/channel_inbox_preferences.dart';
import 'package:imboy/page/conversation/conversation_page.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/page/conversation/message_inbox_entry.dart';
import 'package:imboy/page/conversation/subscribed_channel_strip_provider.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/page/conversation/widget/message_inbox_filter_bar.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/providers/theme_provider.dart';

class _InboxConversations extends ConversationNotifier {
  _InboxConversations(this.initial);
  final ConversationState initial;
  final watermarkAdvances = <String>[];
  final unreadWrites = <int>[];

  @override
  ConversationState build() => initial;

  @override
  Future<void> syncManualPendingFromServer() async {}

  @override
  Future<void> syncAuthoritativeConversationList({
    String trigger = 'manual',
  }) async {}

  @override
  Future<void> advanceWatermarkToLatest(ConversationModel model) async {
    watermarkAdvances.add(model.uk3);
  }

  @override
  Future<void> setConversationRemind(ConversationModel model, int value) async {
    unreadWrites.add(value);
  }
}

class _InboxChannels extends SubscribedChannelStripNotifier {
  _InboxChannels(this.summaries);
  final List<SubscribedChannelSummary> summaries;
  int builds = 0;
  Completer<List<SubscribedChannelSummary>>? nextLoad;

  @override
  Future<List<SubscribedChannelSummary>> build() async {
    builds++;
    final pending = nextLoad;
    nextLoad = null;
    if (pending != null) return pending.future;
    return summaries;
  }

  void fail() => state = AsyncError(
    StateError('channel fixture failed'),
    StackTrace.current,
  );
}

class _VisibleChannels extends ChannelInboxHiddenIdsNotifier {
  int builds = 0;

  @override
  Future<Set<String>> build() async {
    builds++;
    return <String>{};
  }
}

class _SearchThemeNotifier extends ThemeNotifier {
  @override
  ThemeState build() => const ThemeState(fontSizeOption: FontSizeOption.large);
}

ConversationModel _conversation(
  int id,
  String title, {
  String type = 'C2C',
  int unread = 0,
}) => ConversationModel(
  id: id,
  peerId: id,
  type: type,
  avatar: '',
  title: title,
  subtitle: 'Preview for $title',
  msgType: 'text',
  lastTime: 10000 - id,
  unreadNum: unread,
);

SubscribedChannelSummary _channel(
  int id,
  String title, {
  String? scope = 'personal',
}) => SubscribedChannelSummary(
  channel: ChannelModel(
    id: id,
    name: title,
    scope: scope,
    visibility: 0,
    accessType: 0,
    joinPolicy: 0,
    isSubscribed: true,
    userRole: ChannelUserRole.subscriber,
    creatorId: 1,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  subscription: ChannelSubscriptionModel(
    channelId: id,
    subscribedAt: DateTime(2026, 1, 1),
    unreadCount: 2,
  ),
  lastMessagePreview: 'Channel update',
  lastMessageTime: 1,
);

class _InboxHarness {
  _InboxHarness(
    this.conversations,
    this.channels,
    this.container,
    this.visited,
  );
  final _InboxConversations conversations;
  final _InboxChannels channels;
  final ProviderContainer container;
  final List<String> visited;
}

Future<_InboxHarness> _pump(
  WidgetTester tester, {
  required List<ConversationModel> conversations,
  Map<String, bool> manualPending = const {},
  Map<String, int>? remind,
  bool channelsEnabled = false,
  List<SubscribedChannelSummary> channels = const [],
  bool channelFailure = false,
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
  AppFeatureRegistry.replaceSnapshotForTest({
    FeatureKeys.channel: channelsEnabled,
  });
  final notifier = _InboxConversations(
    ConversationState(
      isLoading: false,
      conversationMap: {for (final model in conversations) model.uk3: model},
      conversationRemind:
          remind ??
          {for (final model in conversations) model.uk3: model.unreadNum},
      manualPending: manualPending,
    ),
  );
  final channelNotifier = _InboxChannels(channels);
  final container = ProviderContainer(
    overrides: [
      conversationProvider.overrideWith(() => notifier),
      subscribedChannelStripProvider.overrideWith(() => channelNotifier),
      channelInboxHiddenIdsProvider.overrideWith(_VisibleChannels.new),
    ],
  );
  addTearDown(container.dispose);
  final visited = <String>[];
  Widget destination(GoRouterState state) {
    visited.add(state.uri.path);
    return Scaffold(body: Text('Destination ${state.uri.path}'));
  }

  final router = GoRouter(
    initialLocation: '/inbox',
    routes: [
      GoRoute(path: '/inbox', builder: (_, _) => const ConversationPage()),
      for (final path in [
        '/chat/:id',
        '/channel/:id',
        '/channel',
        '/chat_setting/:id',
        '/message_search',
      ])
        GoRoute(path: path, builder: (_, state) => destination(state)),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
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
  await tester.pump();
  if (channelFailure) {
    channelNotifier.fail();
    await tester.pump();
  }
  return _InboxHarness(notifier, channelNotifier, container, visited);
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

Future<void> _filter(WidgetTester tester, MessageInboxFilter value) async {
  final target = find.byKey(ValueKey('message-filter-${value.name}'));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

const _searchKey = Key('conversation_search_input');
const _historyKey = Key('message-inbox-history-search');

void main() {
  setUpAll(() async {
    Env.uploadKey = 'synthetic-inbox-key';
    Env.uploadScene = 'synthetic-inbox';
    await StorageService.to.setString(Keys.currentUid, '92001');
  });
  tearDown(() => AppFeatureRegistry.replaceSnapshotForTest({}));
  tearDownAll(() async => StorageService.to.remove(Keys.currentUid));

  testWidgets(
    'type filter and local search combine; clearing search keeps the filter',
    (tester) async {
      await _pump(
        tester,
        conversations: [
          _conversation(1, 'Alpha direct'),
          _conversation(2, 'Alpha group', type: 'C2G'),
          _conversation(3, 'Beta group', type: 'C2G'),
        ],
      );
      await _filter(tester, MessageInboxFilter.group);
      await tester.enterText(find.byKey(_searchKey), '  ALPHA  ');
      await tester.pump();
      expect(find.text('Alpha group'), findsOneWidget);
      expect(find.text('Alpha direct'), findsNothing);
      expect(find.text('Beta group'), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byKey(_searchKey),
          matching: find.byIcon(CupertinoIcons.xmark_circle_fill),
        ),
      );
      await tester.pump();
      expect(find.text('Alpha group'), findsOneWidget);
      expect(find.text('Beta group'), findsOneWidget);
      expect(find.text('Alpha direct'), findsNothing);
      expect(
        tester
            .widget<MessageInboxFilterBar>(find.byType(MessageInboxFilterBar))
            .selected,
        MessageInboxFilter.group,
      );
      expect(find.byKey(_historyKey), findsNothing);
      await _finish(tester);
    },
  );

  testWidgets(
    'unread uses the displayed counter and manual pending without read writes',
    (tester) async {
      final unread = _conversation(11, 'Unread snapshot');
      final pending = _conversation(12, 'Needs follow-up');
      final read = _conversation(13, 'Read snapshot', unread: 5);
      final harness = await _pump(
        tester,
        conversations: [unread, pending, read],
        remind: {unread.uk3: 3, pending.uk3: 0, read.uk3: 0},
        manualPending: {pending.uk3: true},
      );
      await _filter(tester, MessageInboxFilter.unread);
      expect(find.text('Unread snapshot'), findsOneWidget);
      expect(find.text('Needs follow-up'), findsOneWidget);
      expect(find.text('Read snapshot'), findsNothing);
      expect(find.text('3'), findsOneWidget);
      final state = harness.container.read(conversationProvider);
      expect(state.conversationMap[pending.uk3]!.unreadNum, 0);
      expect(state.conversationRemind[pending.uk3], 0);
      expect(state.manualPending[pending.uk3], isTrue);
      expect(state.conversationMap[unread.uk3]!.unreadNum, 0);
      expect(state.conversationRemind[unread.uk3], 3);
      expect(state.conversationMap[read.uk3]!.unreadNum, 5);
      expect(state.conversationRemind[read.uk3], 0);
      expect(harness.conversations.watermarkAdvances, isEmpty);
      expect(harness.conversations.unreadWrites, isEmpty);
      await _finish(tester);
    },
  );

  testWidgets('CHANNEL projections render once and open the channel route', (
    tester,
  ) async {
    final harness = await _pump(
      tester,
      channelsEnabled: true,
      conversations: [
        _conversation(21, 'Direct contact'),
        _conversation(8800, 'Subscribed updates', type: 'CHANNEL'),
      ],
      channels: [_channel(8800, 'Subscribed updates')],
    );
    expect(find.byType(ConversationItem), findsOneWidget);
    expect(find.text('Subscribed updates'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('channel-inbox-row-8800')),
      findsOneWidget,
    );
    await tester.tap(find.text('Subscribed updates'));
    await tester.pumpAndSettle();
    expect(harness.visited, ['/channel/8800']);
    expect(harness.visited.where((path) => path.startsWith('/chat/')), isEmpty);
    await _finish(tester);
  });

  testWidgets(
    'history search is a labelled separate destination after typing',
    (tester) async {
      final harness = await _pump(
        tester,
        conversations: [_conversation(31, 'Local contact')],
      );
      expect(find.byKey(_historyKey), findsNothing);
      await tester.enterText(find.byKey(_searchKey), 'local');
      await tester.pump();
      expect(find.text(t.chat.inbox.searchHistory), findsOneWidget);
      await tester.tap(find.byKey(_historyKey));
      await tester.pumpAndSettle();
      expect(harness.visited, ['/message_search']);
      await _finish(tester);
    },
  );

  testWidgets(
    'disabled channel feature does not build channels or hide chats',
    (tester) async {
      final harness = await _pump(
        tester,
        conversations: [_conversation(41, 'Visible chat')],
        channels: [_channel(9000, 'Hidden channel')],
      );
      expect(find.text('Visible chat'), findsOneWidget);
      expect(find.text('Hidden channel'), findsNothing);
      expect(
        find.byKey(const ValueKey('message-filter-channel')),
        findsNothing,
      );
      expect(harness.channels.builds, 0);
      await _finish(tester);
    },
  );

  testWidgets(
    'a failed channel load preserves the chat list and a visible retry',
    (tester) async {
      await _pump(
        tester,
        channelsEnabled: true,
        channelFailure: true,
        conversations: [_conversation(51, 'Available chat')],
      );
      expect(find.text('Available chat'), findsOneWidget);
      expect(find.text(t.common.networkException), findsOneWidget);
      expect(find.text(t.chat.inbox.channelLoadFailed), findsNothing);
      expect(find.text(t.common.buttonRetry), findsOneWidget);
      await _finish(tester);
    },
  );

  for (final (width, scale, brightness) in [
    (1280.0, 1.0, Brightness.light),
    (320.0, 2.0, Brightness.dark),
  ]) {
    testWidgets('partial channel failure stays compact at $width $brightness', (
      tester,
    ) async {
      await _pump(
        tester,
        width: width,
        textScale: scale,
        brightness: brightness,
        channelsEnabled: true,
        channelFailure: true,
        conversations: [_conversation(52, 'Preserved chat')],
      );
      expect(find.text('Preserved chat'), findsOneWidget);
      expect(find.byType(NoDataView), findsNothing);
      final noticeRect = tester.getRect(
        find.byKey(const ValueKey('message-inbox-channel-notice')),
      );
      expect(noticeRect.left, greaterThanOrEqualTo(0));
      expect(noticeRect.right, lessThanOrEqualTo(width));
      expect(find.text(t.common.buttonRetry).hitTestable(), findsOneWidget);
      if (width > 1000) {
        final errorRect = tester.getRect(find.text(t.common.networkException));
        final retryRect = tester.getRect(
          find.byKey(const ValueKey('message-inbox-channel-retry')),
        );
        expect(retryRect.left - errorRect.right, lessThan(48));
      }
      expect(tester.takeException(), isNull);
      await _finish(tester);
    });

    testWidgets(
      'empty channel failure uses the full state at $width $brightness',
      (tester) async {
        await _pump(
          tester,
          width: width,
          textScale: scale,
          brightness: brightness,
          channelsEnabled: true,
          channelFailure: true,
          conversations: [],
        );
        expect(find.byType(NoDataView), findsOneWidget);
        expect(find.text(t.common.networkException), findsOneWidget);
        expect(find.text(t.chat.inbox.channelLoadFailed), findsNothing);
        expect(find.text(t.common.noConversationMessages), findsNothing);
        expect(
          find.byKey(const ValueKey('message-inbox-channel-notice')),
          findsNothing,
        );
        expect(find.text(t.common.buttonRetry).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _finish(tester);
      },
    );
  }

  testWidgets(
    'channel retry stays busy once, preserves chats and can recover',
    (tester) async {
      final harness = await _pump(
        tester,
        channelsEnabled: true,
        channelFailure: true,
        conversations: [_conversation(53, 'Chat during retry')],
      );
      final pending = Completer<List<SubscribedChannelSummary>>();
      harness.channels.nextLoad = pending;
      final channelBuilds = harness.channels.builds;
      final preferences = harness.container.read(
        channelInboxHiddenIdsProvider.notifier,
      ) as _VisibleChannels;
      final preferenceBuilds = preferences.builds;
      final retry = find.byKey(const ValueKey('message-inbox-channel-retry'));

      await tester.tap(retry);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<CupertinoButton>(retry).onPressed, isNull);
      expect(find.text(t.common.loading), findsOneWidget);
      expect(find.text('Chat during retry'), findsOneWidget);
      await tester.tap(retry);
      await tester.pump();
      expect(harness.channels.builds, channelBuilds + 1);
      expect(preferences.builds, preferenceBuilds + 1);

      pending.completeError(
        StateError('retry fixture failed'),
        StackTrace.current,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CupertinoButton>(retry).onPressed, isNotNull);
      expect(find.text(t.common.networkException), findsOneWidget);

      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(harness.channels.builds, channelBuilds + 2);
      expect(preferences.builds, preferenceBuilds + 2);
      expect(find.text(t.common.networkException), findsNothing);
      expect(find.text('Chat during retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    },
  );

  testWidgets(
    'full channel failure shows progress while retrying then content',
    (tester) async {
      final harness = await _pump(
        tester,
        channelsEnabled: true,
        channelFailure: true,
        conversations: [],
      );
      final pending = Completer<List<SubscribedChannelSummary>>();
      harness.channels.nextLoad = pending;
      await tester.tap(find.text(t.common.buttonRetry));
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<AsyncStateView>(
              find.byKey(const ValueKey('message-inbox-channel-state')),
            )
            .isLoading,
        isTrue,
      );
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text(t.common.buttonRetry), findsNothing);

      pending.complete([_channel(9050, 'Recovered channel')]);
      await tester.pumpAndSettle();
      expect(find.text('Recovered channel'), findsOneWidget);
      expect(find.text(t.common.networkException), findsNothing);
      expect(tester.takeException(), isNull);
      await _finish(tester);
    },
  );

  testWidgets('disabling channels while selected falls back to all chats', (
    tester,
  ) async {
    await _pump(
      tester,
      channelsEnabled: true,
      conversations: [_conversation(61, 'Fallback chat')],
      channels: [_channel(9100, 'Updates')],
    );
    await _filter(tester, MessageInboxFilter.channel);
    expect(find.text('Fallback chat'), findsNothing);
    AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: false});
    await tester.pump();
    expect(find.text('Fallback chat'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-filter-channel')), findsNothing);
    expect(
      tester
          .widget<MessageInboxFilterBar>(find.byType(MessageInboxFilterBar))
          .selected,
      MessageInboxFilter.all,
    );
    await _finish(tester);
  });

  testWidgets(
    'unknown-scope subscriptions stay hidden and the empty state opens channels',
    (tester) async {
      final harness = await _pump(
        tester,
        channelsEnabled: true,
        conversations: [],
        channels: [_channel(9199, 'Unknown-scope subscription', scope: null)],
      );
      await _filter(tester, MessageInboxFilter.channel);
      expect(find.text('Unknown-scope subscription'), findsNothing);
      expect(find.text(t.chat.inbox.channelEmptyDescription), findsOneWidget);
      await tester.tap(find.text(t.chat.inbox.openChannels));
      await tester.pumpAndSettle();
      expect(harness.visited, ['/channel']);
      await _finish(tester);
    },
  );

  testWidgets('320pt at 200 percent text can scroll to and select channels', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 320,
      textScale: 2,
      channelsEnabled: true,
      conversations: [_conversation(65, 'Narrow-screen chat')],
      channels: [_channel(9200, 'Narrow-screen updates')],
    );
    final channelFilter = find.byKey(const ValueKey('message-filter-channel'));
    expect(channelFilter.hitTestable(), findsNothing);
    await _filter(tester, MessageInboxFilter.channel);
    expect(channelFilter.hitTestable(), findsOneWidget);
    expect(find.text('Narrow-screen updates'), findsOneWidget);
    expect(find.text('Narrow-screen chat'), findsNothing);
    expect(tester.takeException(), isNull);
    final filterContext = tester.element(channelFilter);
    expect(MediaQuery.textScalerOf(filterContext).scale(10), 20);
    await _finish(tester);
  });

  testWidgets(
    'search applies system scaling once while preserving app text size',
    (tester) async {
      final themeContainer = ProviderContainer(
        overrides: [themeProvider.overrideWith(_SearchThemeNotifier.new)],
      );
      // Match the app's live theme subscription, including its font-size choice.
      // Without this container, ThemeManager's fallback hides double scaling.
      themeContainer.listen(themeProvider, (_, _) {});
      ThemeManager.instance.setProviderContainer(themeContainer);
      addTearDown(() {
        ThemeManager.instance.dispose();
        themeContainer.dispose();
      });

      final appFontSize = FontSizeType.medium.size * FontSizeOption.large.scale;
      for (final systemScale in [1.0, 2.0]) {
        await _pump(
          tester,
          textScale: systemScale,
          conversations: [_conversation(66, 'Search typography')],
        );
        final search = tester.widget<CupertinoSearchTextField>(
          find.byKey(_searchKey),
        );
        final editableFinder = find.descendant(
          of: find.byKey(_searchKey),
          matching: find.byType(EditableText),
        );
        final editable = tester.widget<EditableText>(editableFinder);
        expect(editable.style.fontSize, closeTo(appFontSize, 0.001));
        expect(search.placeholderStyle!.fontSize, closeTo(appFontSize, 0.001));
        expect(
          tester
              .state<EditableTextState>(editableFinder)
              .renderEditable
              .textScaler
              .scale(appFontSize),
          closeTo(appFontSize * systemScale, 0.001),
        );
        expect(tester.takeException(), isNull);
        await _finish(tester);
      }
    },
  );

  testWidgets('long press exposes read, pin, notification and delete actions', (
    tester,
  ) async {
    final model = _conversation(71, 'Action contact', unread: 1);
    final harness = await _pump(tester, conversations: [model]);
    await tester.longPress(find.text('Action contact'));
    await tester.pumpAndSettle();
    final sheet = find.byType(CupertinoActionSheet);
    expect(sheet, findsOneWidget);
    for (final label in [
      t.chat.markRead,
      t.chat.pin,
      t.chat.inbox.notificationSettings,
      t.common.buttonDelete,
    ]) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(harness.conversations.watermarkAdvances, isEmpty);
    expect(harness.conversations.unreadWrites, isEmpty);
    await tester.tap(
      find.descendant(
        of: sheet,
        matching: find.text(t.chat.inbox.notificationSettings),
      ),
    );
    await tester.pumpAndSettle();
    expect(harness.visited, ['/chat_setting/71']);
    await _finish(tester);
  });
}
