import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/widgets/channel_inbox_restore_action.dart';
import 'package:imboy/page/conversation/channel_inbox_preferences.dart';
import 'package:imboy/page/conversation/message_inbox_channel_host.dart';
import 'package:imboy/page/conversation/subscribed_channel_strip_provider.dart';
import 'package:imboy/page/conversation/widget/subscribed_channel_strip.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/model/channel_subscription_model.dart';
import 'package:imboy/store/repository/channel_inbox_preference_repo_sqlite.dart';

class _Session extends ChangeNotifier implements AuthSessionReader {
  @override
  AuthSessionScope current = (
    uid: 'fixture',
    generation: 1,
    transitioning: false,
  );
  @override
  bool isCurrent(AuthSessionScope scope) => current == scope;
}

class _Summaries extends SubscribedChannelStripNotifier {
  _Summaries(this.items);
  final List<SubscribedChannelSummary> items;
  @override
  Future<List<SubscribedChannelSummary>> build() async => items;
}

class _Hidden extends ChannelInboxHiddenIdsNotifier {
  _Hidden([this.initial = const {}]);
  final Set<String> initial;
  Completer<Set<String>>? pending;
  int writes = 0;
  @override
  Future<Set<String>> build() async => pending?.future ?? initial;
  @override
  Future<bool> setHidden(
    ChannelInboxPreferenceScope scope,
    String id,
    bool hidden,
  ) async {
    writes++;
    final ids = {...?state.value};
    if (hidden) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    state = AsyncData(ids);
    return true;
  }
}

class _Service extends Fake implements ChannelService {}

SubscribedChannelSummary _summary({
  int id = 1001,
  bool muted = false,
  int unread = 5,
  bool pinned = false,
  bool hasMessage = true,
  String? scope = 'personal',
  String? customId,
}) => SubscribedChannelSummary(
  channel: ChannelModel(
    id: id,
    name: '测试频道',
    scope: scope,
    customId: customId,
    visibility: 0,
    accessType: 0,
    joinPolicy: 0,
    isSubscribed: true,
    userRole: ChannelUserRole.subscriber,
    creatorId: 1,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
  subscription: ChannelSubscriptionModel(
    channelId: id,
    subscribedAt: DateTime.utc(2026),
    unreadCount: unread,
    isMuted: muted,
    isPinned: pinned,
  ),
  lastMessagePreview: hasMessage ? '新消息内容' : null,
  lastMessageTime: hasMessage
      ? DateTime.utc(2026).millisecondsSinceEpoch
      : null,
);
ProviderContainer _container(
  List<SubscribedChannelSummary> summaries, {
  _Hidden? hidden,
}) {
  final session = _Session();
  final container = ProviderContainer(
    overrides: [
      subscribedChannelStripProvider.overrideWith(() => _Summaries(summaries)),
      channelInboxHiddenIdsProvider.overrideWith(() => hidden ?? _Hidden()),
      channelInboxPreferenceRepoProvider.overrideWithValue(
        ChannelInboxPreferenceRepo(
          session: session,
          endpoint: () => 'https://fixture.invalid',
        ),
      ),
      channelServiceProvider.overrideWithValue(_Service()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _app(
  ProviderContainer container, {
  Widget child = const SubscribedChannelStrip(),
}) => UncontrolledProviderScope(
  container: container,
  child: TranslationProvider(
    child: MaterialApp(home: Scaffold(body: child)),
  ),
);
void main() {
  testWidgets(
    'a row retained across account change cannot open an old action menu',
    (tester) async {
      final hidden = _Hidden();
      final container = _container([_summary()], hidden: hidden);
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();
      final session =
          container.read(channelInboxPreferenceRepoProvider).session
              as _Session;
      session.current = (
        uid: 'next-account',
        generation: 2,
        transitioning: false,
      );
      await tester.longPress(find.text('测试频道'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(hidden.writes, 0);
    },
  );
  for (final muted in [false, true]) {
    testWidgets('muted=$muted keeps unread visible with the correct status', (
      tester,
    ) async {
      final container = _container([_summary(muted: muted, unread: 8)]);
      await tester.pumpWidget(_app(container));
      await tester.pumpAndSettle();
      expect(find.text('8'), findsOneWidget);
      expect(
        find.byIcon(CupertinoIcons.bell_slash_fill),
        muted ? findsOneWidget : findsNothing,
      );
    });
  }
  testWidgets(
    'host receives every active permitted channel without a five-item cap',
    (tester) async {
      final summaries = [
        for (var id = 1; id <= 7; id++) _summary(id: id),
        _summary(id: 8, scope: null),
        _summary(id: 9, scope: 'workspace'),
        _summary(id: 10, hasMessage: false, unread: 0),
        _summary(id: 11, hasMessage: false, unread: 0, pinned: true),
      ];
      final container = _container(summaries, hidden: _Hidden({'2'}));
      MessageInboxChannelData? data;
      await tester.pumpWidget(
        _app(
          container,
          child: MessageInboxChannelHost(
            builder: (_, value) {
              data = value;
              return const SizedBox();
            },
            child: const SubscribedChannelStrip(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(data!.entries.map((entry) => entry.key), [
        'channel:1',
        'channel:3',
        'channel:4',
        'channel:5',
        'channel:6',
        'channel:7',
        'channel:11',
      ]);
      expect(
        container.read(subscribedChannelStripProvider).value,
        hasLength(11),
      );
    },
  );
  testWidgets('preferences must finish loading before any channel is exposed', (
    tester,
  ) async {
    final hidden = _Hidden()..pending = Completer<Set<String>>();
    final container = _container([_summary()], hidden: hidden);
    await tester.pumpWidget(_app(container));
    await tester.pump();
    expect(find.text('测试频道'), findsNothing);
    hidden.pending!.complete({'1001'});
    await tester.pumpAndSettle();
    expect(find.text('测试频道'), findsNothing);
  });
  testWidgets('duplicate names show authoritative custom ids', (tester) async {
    final container = _container([
      _summary(id: 1, customId: 'news_one'),
      _summary(id: 2, customId: 'news_two'),
    ]);
    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    expect(find.text('@news_one · 新消息内容'), findsOneWidget);
    expect(find.text('@news_two · 新消息内容'), findsOneWidget);
  });
  testWidgets(
    'hide offers undo; directory restores with original unread intact',
    (tester) async {
      final summary = _summary(muted: true, unread: 8);
      final hidden = _Hidden();
      final container = _container([summary], hidden: hidden);
      await tester.pumpWidget(
        _app(
          container,
          child: Column(
            children: [
              const SubscribedChannelStrip(),
              ChannelInboxRestoreAction(channel: summary.channel),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('测试频道'));
      await tester.pumpAndSettle();
      expect(find.text(t.chat.inbox.channelOnlyDescription), findsOneWidget);
      await tester.tap(find.text(t.chat.inbox.channelOnly));
      await tester.pumpAndSettle();
      expect(find.text('测试频道'), findsNothing);
      expect(
        find.byKey(const ValueKey('restore-channel-inbox-1001')),
        findsOneWidget,
      );
      expect(
        container
            .read(subscribedChannelStripProvider)
            .value!
            .single
            .unreadCount,
        8,
      );
      await tester.tap(find.text(t.chat.inbox.undo));
      await tester.pumpAndSettle();
      expect(find.text('测试频道'), findsOneWidget);
      await hidden.setHidden(
        container.read(channelInboxPreferenceRepoProvider).captureScope(),
        '1001',
        true,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('restore-channel-inbox-1001')),
      );
      await tester.pumpAndSettle();
      expect(find.text('测试频道'), findsOneWidget);
      expect(
        container
            .read(subscribedChannelStripProvider)
            .value!
            .single
            .unreadCount,
        8,
      );
      expect(hidden.writes, 4);
    },
  );
}
