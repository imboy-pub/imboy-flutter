import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as testing show group;
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat/chat_provider.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/contact_model.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/announcement/announcement_model.dart';
import 'package:imboy/page/web_shell/web_group_composer_gate.dart';
import 'package:imboy/page/web_shell/web_group_info_panel.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;

class _Endpoint implements Env {
  _Endpoint(this.apiBaseUrl);
  @override
  final String apiBaseUrl;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sessions extends ChangeNotifier implements AuthSessionReader {
  @override
  bool get transitionFailed => false;
  @override
  AuthSessionScope current = (uid: '1', generation: 1, transitioning: false);
  @override
  bool isCurrent(AuthSessionScope scope) =>
      current == scope && !current.transitioning;
  void change(String uid) {
    current = (
      uid: uid,
      generation: current.generation + 1,
      transitioning: false,
    );
    notifyListeners();
  }
}

GroupModel group(String gid, {String title = 'GROUP'}) => GroupModel(
  groupId: gid,
  type: 2,
  joinLimit: 2,
  contentLimit: 1,
  ownerUid: '1',
  creatorUid: '1',
  memberMax: 100,
  memberCount: 2,
  createdAt: 0,
  title: title,
);
GroupMemberModel member(String gid, {int role = 1, int status = 1}) =>
    GroupMemberModel(
      id: '3',
      groupId: gid,
      userId: '1',
      nickname: 'MEMBER',
      avatar: '',
      sign: 'PRIVATE_SIGN',
      account: 'PRIVATE_ACCOUNT',
      alias: '',
      role: role,
      status: status,
      createdAt: 0,
    );
WebGroupInfoSnapshot snapshot(String gid, {String title = 'GROUP'}) =>
    WebGroupInfoSnapshot(
      group: group(gid, title: title),
      currentMember: member(gid, role: 5),
      members: [member(gid)],
      announcements: [
        AnnouncementModel(
          id: '9007199254740993123',
          groupId: gid,
          content: 'NOTICE_BODY',
          publisherId: '1',
          publisherName: 'NAME',
          createdAt: 0,
        ),
      ],
    );

class _GroupMessageChat extends ChatNotifier {
  _GroupMessageChat({this.chatType = 'C2G', this.authorId = '2'});
  final String chatType, authorId;
  @override
  ChatState build() => ChatState(
    currentConversationId: '${chatType}_1_100',
    messages: [
      TextMessage(
        id: 'group-owned-message',
        authorId: authorId,
        text: 'GROUP_MESSAGE_BODY',
      ),
    ],
  );
  @override
  bool get ownsCurrentSession => true;
  @override
  SqliteChatService? get chatService => null;
  @override
  void initChatService(String chatType) {}
  @override
  void syncMessagesToState() {}
  @override
  Future<List<Message>> loadMoreMessages(
    ConversationModel conversation, {
    bool isInitial = false,
    bool webNewestFirst = false,
    bool allowPendingRetry = true,
  }) async => state.messages;
}

void main() {
  late _Sessions sessions;
  late String previousEnvironment;
  setUp(() {
    previousEnvironment = currentEnv;
    envMap['web-group-fixture-a'] = _Endpoint('http://127.0.0.1:19801');
    envMap['web-group-fixture-b'] = _Endpoint('http://127.0.0.1:19801');
    currentEnv = 'web-group-fixture-a';
    sessions = _Sessions();
  });
  tearDown(() {
    sessions.dispose();
    currentEnv = previousEnvironment;
    envMap.remove('web-group-fixture-a');
    envMap.remove('web-group-fixture-b');
  });
  Future<void> mount(WidgetTester tester, Widget child) => tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(home: Material(child: child)),
    ),
  );
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() ready, {
    required String reason,
  }) async {
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump();
      if (ready()) return;
    }
    expect(ready(), isTrue, reason: reason);
  }

  Widget gate({
    Future<GroupMemberModel?> Function(String, String)? load,
    int Function()? clock,
  }) => WebGroupComposerGate(
    groupId: '100',
    currentUserId: '1',
    sessionReader: sessions,
    memberLoader: load ?? (_, _) async => member('100'),
    groupLoader: (_) async => group('100'),
    clock: clock,
    child: const TextField(key: ValueKey('retained-composer')),
  );

  testing.group('Web group message author identity', () {
    late String previousUid;
    setUp(() async {
      previousUid = StorageService.to.getString(Keys.currentUid);
      await StorageService.to.setString(Keys.currentUid, '1');
    });
    tearDown(() => StorageService.to.setString(Keys.currentUid, previousUid));
    Widget author(String gid, Future<String> Function(String, String) load) =>
        WebGroupMessageAuthor(
          key: const ValueKey('owned-author'),
          groupId: gid,
          authorId: '2',
          currentUserId: '1',
          sessionReader: sessions,
          nameLoader: load,
          child: const Text('BODY'),
        );

    for (final row in [
      (
        alias: ' ALIAS ',
        nickname: 'NICK',
        account: 'ACCOUNT',
        friend: true,
        expected: 'ALIAS',
      ),
      (
        alias: '',
        nickname: 'NICK',
        account: 'ACCOUNT',
        friend: true,
        expected: 'FRIEND',
      ),
      (
        alias: '',
        nickname: 'NICK',
        account: 'ACCOUNT',
        friend: false,
        expected: 'NICK',
      ),
      (
        alias: '',
        nickname: '',
        account: ' ACCOUNT ',
        friend: false,
        expected: '',
      ),
    ]) {
      test('Member display priority ${row.expected}', () {
        final m = member('100').copyWith(
          userId: '2',
          alias: row.alias,
          nickname: row.nickname,
          account: row.account,
        );
        final contact = ContactModel(
          peerId: '2',
          nickname: 'CONTACT',
          remark: 'FRIEND',
          isFriend: row.friend ? 1 : 0,
        );
        expect(
          webGroupMemberDisplayName(m, contact, groupId: '100', authorId: '2'),
          row.expected,
        );
      });
    }
    test('Names cannot cross a group or member identity', () {
      final m = member('100').copyWith(userId: '2', alias: 'PRIVATE_ALIAS');
      expect(
        webGroupMemberDisplayName(m, null, groupId: '200', authorId: '2'),
        isEmpty,
      );
      expect(
        webGroupMemberDisplayName(m, null, groupId: '100', authorId: '9'),
        isEmpty,
      );
      expect(
        webGroupMemberDisplayName(
          m.copyWith(status: 0),
          null,
          groupId: '100',
          authorId: '2',
        ),
        isEmpty,
      );
    });
    testWidgets('Late group names cannot overwrite the selected group', (
      tester,
    ) async {
      final old = Completer<String>();
      await mount(tester, author('100', (_, _) => old.future));
      await mount(tester, author('200', (_, _) async => 'CURRENT_ALIAS'));
      await tester.pumpAndSettle();
      old.complete('OLD_PRIVATE_ALIAS');
      await tester.pumpAndSettle();
      expect(find.text('CURRENT_ALIAS'), findsOneWidget);
      expect(find.text('OLD_PRIVATE_ALIAS'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('Same UID reauthentication rejects the old alias lookup', (
      tester,
    ) async {
      final old = Completer<String>();
      var calls = 0;
      await mount(
        tester,
        author(
          '100',
          (_, _) =>
              calls++ == 0 ? old.future : Future.value('NEW_SESSION_ALIAS'),
        ),
      );
      sessions.change('1');
      old.complete('OLD_SESSION_ALIAS');
      await tester.pumpAndSettle();
      expect(find.text('NEW_SESSION_ALIAS'), findsOneWidget);
      expect(find.text('OLD_SESSION_ALIAS'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('Changed account or endpoint cannot publish old names', (
      tester,
    ) async {
      final old = Completer<String>();
      await mount(tester, author('100', (_, _) => old.future));
      sessions.change('9');
      currentEnv = 'web-group-fixture-b';
      old.complete('OLD_ACCOUNT_ALIAS');
      await tester.pumpAndSettle();
      expect(find.text('OLD_ACCOUNT_ALIAS'), findsNothing);
      expect(find.text('BODY'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
    for (final kind in [
      (type: 'C2C', author: '2'),
      (type: 'C2G', author: 'system'),
    ]) {
      testWidgets('${kind.type}/${kind.author} does not add a group author', (
        tester,
      ) async {
        final chat = _GroupMessageChat(
          chatType: kind.type,
          authorId: kind.author,
        );
        final scope = ProviderContainer(
          overrides: [chatProvider.overrideWith(() => chat)],
        );
        final conversation = ConversationModel(
          id: 1,
          peerId: '100',
          avatar: '',
          title: 'NAME',
          subtitle: '',
          type: kind.type,
          msgType: 'text',
          unreadNum: 0,
        );
        try {
          await mount(
            tester,
            UncontrolledProviderScope(
              container: scope,
              child: WebChatPanel(
                selection: ChatSelection(peerId: '100', chatType: kind.type),
                currentUserId: '1',
                closeTooltip: 'Close',
                onClose: () {},
                inputArea: const SizedBox(),
                sessionReader: sessions,
                conversationLoader: (_, _) async => conversation,
                groupLoader: (_) async => group('100'),
                contactLoader: (_) async =>
                    ContactModel(peerId: '100', nickname: 'PERSON'),
              ),
            ),
          );
          for (var frame = 0; frame < 32; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(tester.takeException(), isNull);
          }
          expect(find.text('GROUP_MESSAGE_BODY'), findsOneWidget);
          expect(find.byType(WebGroupMessageAuthor), findsNothing);
        } finally {
          await tester.pumpWidget(const SizedBox());
          // Flush the detector package's shared batch after its widgets unmount.
          VisibilityDetectorController.instance.notifyNow();
          scope.dispose();
        }
      });
    }
    testWidgets('Long RTL names remain readable without displacing actions', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final longName = 'عضو طويل ' * 30;
      var actions = 0;
      await mount(
        tester,
        Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 240,
              child: WebGroupMessageAuthor(
                groupId: '100',
                authorId: '2',
                currentUserId: '1',
                sessionReader: sessions,
                nameLoader: (_, _) async => longName,
                child: Row(
                  children: [
                    const Expanded(child: Text('BODY')),
                    IconButton(
                      key: const ValueKey('body-action'),
                      onPressed: () => actions++,
                      icon: const Icon(Icons.more_horiz),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final name = find.text(longName.trim());
      expect(name, findsOneWidget);
      expect(tester.widget<Text>(name).maxLines, 1);
      expect(tester.getSize(name).width, lessThanOrEqualTo(240));
      expect(find.bySemanticsLabel(longName.trim()), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('body-action')));
      expect(actions, 1);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    });
  });
  test('Metadata miss shares pages, retries failures and rejects stale/wrong groups', () async {
    var active = true, calls = 0;
    final gate = Completer<Map<String, dynamic>?>();
    Map<String, dynamic> page(String gid) => {
      'total': 1,
      'page': 1,
      'size': 100,
      'list': [
        {
          'group_id': gid,
          'user_id': '2',
          'status': 1,
          'alias': 'REMOTE_ALIAS',
          'sign': 'NEVER_DISPLAY',
        },
      ],
    };
    WebGroupMetadataReader reader(
      Future<Map<String, dynamic>?> Function(int, int) load,
    ) => WebGroupMetadataReader(
      groupId: '100',
      ownerUid: '1',
      current: () => active,
      localMember: (_) async => null,
      localContact: (_) async => null,
      localTitle: () async => '',
      pageLoader: load,
    );
    final shared = reader((_, _) {
      calls++;
      return gate.future;
    });
    final author = shared.author('2'), title = shared.title();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);
    gate.complete(page('100'));
    expect(await author, 'REMOTE_ALIAS');
    expect(await title, 'REMOTE_ALIAS');
    var attempt = 0;
    final retry = reader((_, _) async {
      if (attempt++ == 0) throw StateError('read failed');
      return page('100');
    });
    await expectLater(retry.author('2'), throwsStateError);
    expect(await retry.author('2'), 'REMOTE_ALIAS');
    expect(attempt, 2);
    await expectLater(
      reader((_, _) async => page('OTHER')).author('2'),
      throwsFormatException,
    );
    final friend = WebGroupMetadataReader(
      groupId: '100',
      ownerUid: '1',
      current: () => active,
      localMember: (_) async => null,
      localTitle: () async => '',
      localContact: (_) async => ContactModel(
        peerId: '2',
        nickname: '',
        remark: 'FRIEND',
        isFriend: 1,
      ),
      pageLoader: (_, _) async => {
        'total': 0,
        'page': 1,
        'size': 100,
        'list': <dynamic>[],
      },
    );
    expect(await friend.author('2'), 'FRIEND');
    var cappedCalls = 0;
    final capped = reader((number, size) async {
      cappedCalls++;
      return {
        'total': 2100,
        'page': number,
        'size': size,
        'list': [
          for (var i = 0; i < size; i++)
            {
              'group_id': '100',
              'user_id': '${1000 + number * size + i}',
              'status': 1,
            },
        ],
      };
    });
    await expectLater(capped.author('2'), throwsStateError);
    expect(cappedCalls, 20);
    final late = Completer<Map<String, dynamic>?>();
    final stale = reader((_, _) => late.future).author('2');
    await Future<void>.delayed(Duration.zero);
    active = false;
    late.complete(page('100'));
    expect(await stale, isEmpty);
  });
  test('Group metadata never uses an account-only member name', () async {
    final cached = member('100').copyWith(
      userId: '2',
      alias: '',
      nickname: '',
      account: 'PRIVATE_SENTINEL',
    );
    WebGroupMetadataReader reader({required bool local}) =>
        WebGroupMetadataReader(
          groupId: '100',
          ownerUid: '1',
          current: () => true,
          localMember: (_) async => local ? cached : null,
          localContact: (_) async => null,
          localTitle: () async => '',
          pageLoader: (page, size) async => {
            'total': 1,
            'page': page,
            'size': size,
            'list': [
              {
                'group_id': '100',
                'user_id': '2',
                'status': 1,
                'account': 'PRIVATE_SENTINEL',
              },
            ],
          },
        );
    expect(await reader(local: true).author('2'), isEmpty);
    expect(await reader(local: false).author('2'), isEmpty);
    expect(await reader(local: false).title(), isEmpty);
  });
  for (final formalName in [false, true]) {
    testWidgets(
      'Panel wires remote metadata and preserves formal unnamed name=$formalName',
      (tester) async {
        SqliteService.setDbUnavailableForTest();
        final previousUid = StorageService.to.getString(Keys.currentUid);
        await StorageService.to.setString(Keys.currentUid, '1');
        final scope = ProviderContainer(
          overrides: [chatProvider.overrideWith(() => _GroupMessageChat())],
        );
        var calls = 0;
        try {
          await mount(
            tester,
            UncontrolledProviderScope(
              container: scope,
              child: WebChatPanel(
                selection: const ChatSelection(peerId: '100', chatType: 'C2G'),
                currentUserId: '1',
                closeTooltip: 'Close',
                onClose: () {},
                inputArea: const SizedBox(),
                sessionReader: sessions,
                conversationLoader: (_, _) async => ConversationModel(
                  id: 1,
                  peerId: '100',
                  avatar: '',
                  title: t.main.unnamed,
                  subtitle: '',
                  type: 'C2G',
                  msgType: 'text',
                  unreadNum: 0,
                )..computeTitle = t.main.unnamed,
                groupLoader: (_) async =>
                    group('100', title: formalName ? t.main.unnamed : ''),
                groupMemberPageLoader: (gid, page, size) async {
                  calls++;
                  expect(gid, '100');
                  expect(page, 1);
                  expect(size, 100);
                  return {
                    'total': 1,
                    'page': page,
                    'size': size,
                    'list': [
                      {
                        'group_id': gid,
                        'user_id': '2',
                        'status': 1,
                        'alias': 'REMOTE_PANEL_ALIAS',
                      },
                    ],
                  };
                },
              ),
            ),
          );
          for (var i = 0; i < 32; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(tester.takeException(), isNull);
          if (formalName) expect(find.text(t.main.unnamed), findsOneWidget);
          expect(find.text('GROUP_MESSAGE_BODY'), findsOneWidget);
          expect(
            find.text('REMOTE_PANEL_ALIAS'),
            findsNWidgets(formalName ? 1 : 2),
          );
          expect(calls, 1);
          final authorLoader = tester
              .widget<WebGroupMessageAuthor>(find.byType(WebGroupMessageAuthor))
              .nameLoader;
          scope.read(chatProvider.notifier).updateComposerHeight(80);
          await tester.pump();
          expect(
            identical(
              tester
                  .widget<WebGroupMessageAuthor>(
                    find.byType(WebGroupMessageAuthor),
                  )
                  .nameLoader,
              authorLoader,
            ),
            isTrue,
          );
          expect(
            find.text('REMOTE_PANEL_ALIAS'),
            findsNWidgets(formalName ? 1 : 2),
          );
          expect(calls, 1);
        } finally {
          await tester.pumpWidget(const SizedBox());
          VisibilityDetectorController.instance.notifyNow();
          scope.dispose();
          await StorageService.to.setString(Keys.currentUid, previousUid);
          SqliteService.setDbForTest(null);
        }
      },
    );
  }
  for (final mode in ['online', 'offline', 'pending']) {
    testWidgets('Web group header ignores unsafe cached names, mode=$mode', (
      tester,
    ) async {
      SqliteService.setDbUnavailableForTest();
      final previousUid = StorageService.to.getString(Keys.currentUid);
      await StorageService.to.setString(Keys.currentUid, '1');
      final chat = _GroupMessageChat();
      final scope = ProviderContainer(
        overrides: [chatProvider.overrideWith(() => chat)],
      );
      final conversation = ConversationModel(
        id: 1,
        peerId: '100',
        avatar: '',
        title: '',
        subtitle: '',
        type: 'C2G',
        msgType: 'text',
        unreadNum: 0,
      )..computeTitle = 'DERIVED_GROUP_TITLE';
      try {
        await mount(
          tester,
          UncontrolledProviderScope(
            container: scope,
            child: WebChatPanel(
              selection: const ChatSelection(peerId: '100', chatType: 'C2G'),
              currentUserId: '1',
              closeTooltip: 'Close',
              onClose: () {},
              inputArea: const SizedBox(),
              sessionReader: sessions,
              conversationLoader: (_, _) async => conversation,
              groupLoader: (_) async => group('100', title: ''),
              groupMemberPageLoader: (_, page, size) async {
                if (mode == 'offline') throw StateError('offline');
                if (mode == 'pending') {
                  return Completer<Map<String, dynamic>?>().future;
                }
                return {
                  'total': 0,
                  'page': page,
                  'size': size,
                  'list': <dynamic>[],
                };
              },
            ),
          ),
        );
        for (var frame = 0; frame < 32; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull);
        }
        expect(find.text('GROUP_MESSAGE_BODY'), findsOneWidget);
        expect(find.byType(WebGroupMessageAuthor), findsOneWidget);
        expect(find.text('DERIVED_GROUP_TITLE'), findsNothing);
        expect(find.text(t.main.unnamed), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
        VisibilityDetectorController.instance.notifyNow();
        scope.dispose();
        await StorageService.to.setString(Keys.currentUid, previousUid);
        SqliteService.setDbForTest(null);
      }
    });
  }

  testWidgets('Late group title cannot overwrite a reauthenticated session', (
    tester,
  ) async {
    SqliteService.setDbUnavailableForTest();
    final previousUid = StorageService.to.getString(Keys.currentUid);
    await StorageService.to.setString(Keys.currentUid, '1');
    final scope = ProviderContainer(
      overrides: [chatProvider.overrideWith(() => _GroupMessageChat())],
    );
    final first = Completer<Map<String, dynamic>?>();
    var calls = 0;
    try {
      await mount(
        tester,
        UncontrolledProviderScope(
          container: scope,
          child: WebChatPanel(
            selection: const ChatSelection(peerId: '100', chatType: 'C2G'),
            currentUserId: '1',
            closeTooltip: 'Close',
            onClose: () {},
            inputArea: const SizedBox(),
            sessionReader: sessions,
            conversationLoader: (_, _) async => ConversationModel(
              id: 1,
              peerId: '100',
              avatar: '',
              title: '',
              subtitle: '',
              type: 'C2G',
              msgType: 'text',
              unreadNum: 0,
            ),
            groupLoader: (_) async => group('100', title: ''),
            groupMemberPageLoader: (_, page, size) {
              if (calls++ == 0) return first.future;
              return Future.value({
                'total': 1,
                'page': page,
                'size': size,
                'list': [
                  {
                    'group_id': '100',
                    'user_id': '2',
                    'status': 1,
                    'alias': 'CURRENT_NAME',
                  },
                ],
              });
            },
          ),
        ),
      );
      for (var i = 0; i < 32; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('GROUP_MESSAGE_BODY'), findsOneWidget);
      sessions.change('1');
      for (var i = 0; i < 32; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(calls, greaterThanOrEqualTo(2));
      expect(find.text('CURRENT_NAME'), findsWidgets);
      first.complete({
        'total': 1,
        'page': 1,
        'size': 100,
        'list': [
          {'group_id': '100', 'user_id': '2', 'status': 1, 'alias': 'OLD_NAME'},
        ],
      });
      for (var i = 0; i < 32; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('OLD_NAME'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      VisibilityDetectorController.instance.notifyNow();
      scope.dispose();
      await StorageService.to.setString(Keys.currentUid, previousUid);
      SqliteService.setDbForTest(null);
    }
  });

  testWidgets(
    'Read-only group view shows existing identity/notice without account fields or management',
    (tester) async {
      await mount(
        tester,
        WebGroupInfoView(snapshot: snapshot('9007199254740993', title: '')),
      );
      expect(find.text(t.main.unnamed), findsOneWidget);
      expect(find.text('9007199254740993'), findsNothing);
      expect(find.text(t.enterpriseApp.groupRoleViceOwner), findsOneWidget);
      expect(find.text('NOTICE_BODY'), findsOneWidget);
      expect(find.text('PRIVATE_ACCOUNT'), findsNothing);
      expect(find.text('PRIVATE_SIGN'), findsNothing);
      expect(find.byIcon(CupertinoIcons.add), findsNothing);
      expect(find.byIcon(CupertinoIcons.trash), findsNothing);
    },
  );

  testWidgets(
    'Late old group and denied membership never publish a stale snapshot',
    (tester) async {
      final old = Completer<WebGroupInfoSnapshot>();
      await mount(
        tester,
        WebGroupInfoPanel(
          groupId: '100',
          sessionReader: sessions,
          loader: (_, _, _) => old.future,
        ),
      );
      await mount(
        tester,
        WebGroupInfoPanel(
          groupId: '200',
          sessionReader: sessions,
          loader: (_, _, _) async =>
              throw const GroupMemberApiException(403, 'SERVER_DENIED'),
        ),
      );
      await tester.pumpAndSettle();
      old.complete(snapshot('100', title: 'OLD_GROUP'));
      await tester.pumpAndSettle();
      expect(find.text('OLD_GROUP'), findsNothing);
      expect(find.text('NOTICE_BODY'), findsNothing);
      expect(find.text(t.common.noPermission), findsOneWidget);
    },
  );

  testWidgets(
    'Own leave clears the currently displayed private member/notice preview',
    (tester) async {
      await mount(
        tester,
        WebGroupInfoPanel(
          groupId: '100',
          sessionReader: sessions,
          loader: (_, _, _) async => snapshot('100'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NOTICE_BODY'), findsOneWidget);
      AppEventBus.fire(
        const ChatExtendEvent(
          type: 'leave_group',
          payload: {'groupId': '100', 'userId': '1'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NOTICE_BODY'), findsNothing);
      expect(find.text(t.common.noPermission), findsOneWidget);
    },
  );

  testWidgets('Account change rejects pending group data', (tester) async {
    final pending = Completer<WebGroupInfoSnapshot>();
    await mount(
      tester,
      WebGroupInfoPanel(
        groupId: '100',
        sessionReader: sessions,
        loader: (_, _, _) => pending.future,
      ),
    );
    sessions.change('9');
    pending.complete(snapshot('100', title: 'OLD_ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.text('OLD_ACCOUNT'), findsNothing);
    expect(find.text('NOTICE_BODY'), findsNothing);
  });

  testWidgets(
    'Missing local membership stays unknown and uses the existing backend send check',
    (tester) async {
      await mount(tester, gate(load: (_, _) async => null));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('retained-composer')), findsOneWidget);
      expect(find.text(t.common.noPermission), findsNothing);
    },
  );

  testWidgets('Owner isJoin zero does not imply removal', (tester) async {
    await mount(
      tester,
      gate(load: (_, _) async => member('100', role: 4).copyWith(isJoin: 0)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('retained-composer')), findsOneWidget);
    expect(find.text(t.common.noPermission), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Known disabled membership blocks input with a denial', (
    tester,
  ) async {
    await mount(tester, gate(load: (_, _) async => member('100', status: 0)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('retained-composer')), findsNothing);
    expect(find.text(t.common.noPermission), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Mute/unmute preserves composer text and ignores other/legacy-unlocated members',
    (tester) async {
      var now = 1000;
      await mount(tester, gate(clock: () => now));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('retained-composer'));
      final original = tester.element(field);
      await tester.enterText(field, 'retained draft');
      void muted(String uid) => AppEventBus.fire(
        GroupMemberMuteEvent(
          gid: '100',
          userId: uid,
          muteUntilMs: now + 60000,
          remainingSeconds: 60,
          durationText: '1m',
          adminNickname: 'ADMIN',
        ),
      );
      muted('2');
      muted('');
      await tester.pumpAndSettle();
      expect(field, findsOneWidget);
      muted('1');
      await tester.pumpAndSettle();
      expect(field, findsNothing);
      expect(find.text(t.chat.youAreMuted), findsOneWidget);
      final hidden = find.byKey(
        const ValueKey('retained-composer'),
        skipOffstage: false,
      );
      expect(tester.element(hidden), same(original));
      expect(
        tester
            .widget<EditableText>(
              find.byType(EditableText, skipOffstage: false),
            )
            .focusNode
            .hasFocus,
        isFalse,
      );
      AppEventBus.fire(const GroupMemberUnmuteEvent(gid: '100', userId: '1'));
      await tester.pumpAndSettle();
      expect(tester.element(field), same(original));
      expect(find.text('retained draft'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Stale membership read cannot clear a newer authoritative mute or leave',
    (tester) async {
      final pending = Completer<GroupMemberModel?>();
      await mount(
        tester,
        gate(load: (_, _) => pending.future, clock: () => 1000),
      );
      AppEventBus.fire(
        const GroupMemberMuteEvent(
          gid: '100',
          userId: '1',
          muteUntilMs: 61000,
          remainingSeconds: 60,
          durationText: '1m',
          adminNickname: 'ADMIN',
        ),
      );
      await tester.pump();
      pending.complete(member('100'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('retained-composer')), findsNothing);
      AppEventBus.fire(
        const ChatExtendEvent(
          type: 'leave_group',
          payload: {'groupId': '100', 'userId': '1'},
        ),
      );
      AppEventBus.fire(const GroupMemberUnmuteEvent(gid: '100', userId: '1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('retained-composer')), findsNothing);
      expect(find.text(t.common.noPermission), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Finite mute expiry restores the same composer', (tester) async {
    var now = 1000;
    await mount(tester, gate(clock: () => now));
    await tester.pumpAndSettle();
    final original = tester.element(
      find.byKey(const ValueKey('retained-composer')),
    );
    AppEventBus.fire(
      const GroupMemberMuteEvent(
        gid: '100',
        userId: '1',
        muteUntilMs: 1100,
        remainingSeconds: 1,
        durationText: '1s',
        adminNickname: 'ADMIN',
      ),
    );
    await pumpUntil(
      tester,
      () => find.byKey(const ValueKey('retained-composer')).evaluate().isEmpty,
      reason:
          'the async mute event must hide input before advancing expiry time',
    );
    expect(find.byKey(const ValueKey('retained-composer')), findsNothing);
    now = 1200;
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.element(find.byKey(const ValueKey('retained-composer'))),
      same(original),
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Global unmute cannot override a still-active group mute', (
    tester,
  ) async {
    await mount(tester, gate(clock: () => 1000));
    await tester.pumpAndSettle();
    AppEventBus.fire(const UserMutedEvent(muteUntilMs: 0));
    AppEventBus.fire(
      const GroupMemberMuteEvent(
        gid: '100',
        userId: '1',
        muteUntilMs: 61000,
        remainingSeconds: 60,
        durationText: '1m',
        adminNickname: 'ADMIN',
      ),
    );
    await tester.pumpAndSettle();
    AppEventBus.fire(const UserUnmutedEvent());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('retained-composer')), findsNothing);
    AppEventBus.fire(const GroupMemberUnmuteEvent(gid: '100', userId: '1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('retained-composer')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Old account membership completion cannot restore a composer', (
    tester,
  ) async {
    final pending = Completer<GroupMemberModel?>();
    await mount(tester, gate(load: (_, _) => pending.future));
    sessions.change('9');
    pending.complete(member('100'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('retained-composer'), skipOffstage: false),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
  });
  for (final endpointOnly in [false, true]) {
    testWidgets(
      'Pending group preview rejects ${endpointOnly ? "endpoint" : "environment"} drift with the same auth generation',
      (tester) async {
        final pending = Completer<WebGroupInfoSnapshot>();
        await mount(
          tester,
          WebGroupInfoPanel(
            groupId: '100',
            sessionReader: sessions,
            loader: (_, _, _) => pending.future,
          ),
        );
        final originalState = tester.state(find.byType(WebGroupInfoPanel));
        if (endpointOnly) {
          envMap['web-group-fixture-a'] = _Endpoint('http://127.0.0.1:19802');
        } else {
          currentEnv = 'web-group-fixture-b';
        }
        // These configuration globals have no notifier; rebuild the same state,
        // without rebinding its captured resource owner or awaiting the spinner.
        await mount(
          tester,
          WebGroupInfoPanel(
            groupId: '100',
            sessionReader: sessions,
            loader: (_, _, _) => pending.future,
          ),
        );
        expect(
          tester.state(find.byType(WebGroupInfoPanel)),
          same(originalState),
        );
        expect(pending.isCompleted, isFalse);
        pending.complete(snapshot('100', title: 'FOREIGN_RESOURCE'));
        await pumpUntil(
          tester,
          () => find.text(t.common.noPermission).evaluate().isNotEmpty,
          reason:
              'invalid resource owner must remain denied after late completion',
        );
        expect(find.text('FOREIGN_RESOURCE'), findsNothing);
        expect(find.text('NOTICE_BODY'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
    testWidgets(
      'Pending membership cannot enable input after ${endpointOnly ? "endpoint" : "environment"} drift',
      (tester) async {
        final pending = Completer<GroupMemberModel?>();
        await mount(tester, gate(load: (_, _) => pending.future));
        final originalState = tester.state(find.byType(WebGroupComposerGate));
        if (endpointOnly) {
          envMap['web-group-fixture-a'] = _Endpoint('http://127.0.0.1:19802');
        } else {
          currentEnv = 'web-group-fixture-b';
        }
        await mount(tester, gate(load: (_, _) => pending.future));
        expect(
          tester.state(find.byType(WebGroupComposerGate)),
          same(originalState),
        );
        expect(pending.isCompleted, isFalse);
        pending.complete(member('100'));
        await pumpUntil(
          tester,
          () => find
              .byKey(const ValueKey('retained-composer'), skipOffstage: false)
              .evaluate()
              .isEmpty,
          reason: 'late membership must not restore input under a different resource owner',
        );
        expect(
          find.byKey(const ValueKey('retained-composer'), skipOffstage: false),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('Same UID reauthentication rejects a pending group preview', (
    tester,
  ) async {
    final pending = Completer<WebGroupInfoSnapshot>();
    await mount(
      tester,
      WebGroupInfoPanel(
        groupId: '100',
        sessionReader: sessions,
        loader: (_, _, _) => pending.future,
      ),
    );
    sessions.change('1');
    pending.complete(snapshot('100', title: 'OLD_GENERATION'));
    await tester.pumpAndSettle();
    expect(find.text('OLD_GENERATION'), findsNothing);
    expect(find.text('NOTICE_BODY'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
