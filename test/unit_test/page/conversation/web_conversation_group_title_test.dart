import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/websocket_events.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/events/user_events.dart';
import 'package:imboy/page/conversation/message_inbox_entry.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/page/conversation/widget/web_conversation_group_title.dart';
import 'package:imboy/service/auth_session_scope.dart';

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
  bool isCurrent(AuthSessionScope scope) => current == scope;
  void changeAccount(String uid) {
    current = (
      uid: uid,
      generation: current.generation + 1,
      transitioning: false,
    );
    notifyListeners();
  }

  void renew() {
    current = (
      uid: '1',
      generation: current.generation + 1,
      transitioning: false,
    );
    notifyListeners();
  }
}

void main() {
  test('Only public display fields can supply derived member names', () {
    expect(
      safeConversationGroupNames([
        {'account': 'PRIVATE_ACCOUNT'},
        {'alias': ' ALIAS ', 'nickname': 'NICK', 'account': 'PRIVATE_ACCOUNT'},
        {'remark': ' REMARK ', 'nickname': 'NICK'},
        {'nickname': ' NICK '},
      ]),
      'ALIAS、REMARK、NICK',
    );
  });

  late String oldEnvironment;
  late _Sessions sessions;
  setUp(() {
    oldEnvironment = currentEnv;
    currentEnv = 'conversation-safe-title';
    envMap[currentEnv] = _Endpoint('http://127.0.0.1:19801');
    sessions = _Sessions();
  });
  tearDown(() {
    sessions.dispose();
    envMap.remove('conversation-safe-title');
    currentEnv = oldEnvironment;
  });

  test('Filter uses the shared safe name and never the old account', () async {
    final pending = Completer<String>();
    final titles = WebConversationGroupTitles(
      sessions: sessions,
      loader: (_, _, _) => pending.future,
    );
    addTearDown(titles.dispose);
    MessageInboxEntry row() => MessageInboxEntry(
      key: 'group:100',
      kind: MessageInboxKind.group,
      title: titles.title('100'),
      preview: '',
      lastTime: 0,
      unreadCount: 0,
      isPinned: false,
      builder: (_) => const SizedBox(),
    );
    expect(
      selectMessageInboxEntries([row()], query: 'PRIVATE_ACCOUNT'),
      isEmpty,
    );
    await Future<void>.delayed(Duration.zero);
    pending.complete('SAFE_GROUP');
    await Future<void>.delayed(Duration.zero);
    expect(
      selectMessageInboxEntries([row()], query: 'SAFE_GROUP'),
      hasLength(1),
    );
    expect(
      selectMessageInboxEntries([row()], query: 'PRIVATE_ACCOUNT'),
      isEmpty,
    );
  });

  test(
    'Metadata invalidation clears names and rejects the prior lookup',
    () async {
      final old = Completer<String>();
      var calls = 0;
      final titles = WebConversationGroupTitles(
        sessions: sessions,
        loader: (_, _, _) =>
            calls++ == 0 ? old.future : Future.value('RENAMED_GROUP'),
      );
      addTearDown(titles.dispose);
      expect(titles.title('100'), isEmpty);
      await Future<void>.delayed(Duration.zero);
      titles.invalidate();
      expect(titles.title('100'), isEmpty);
      old.complete('STALE_GROUP');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(titles.title('100'), 'RENAMED_GROUP');
      expect(calls, 2);
    },
  );

  test('Resolved metadata is refreshed for the same group', () async {
    var value = 'BEFORE_REMARK';
    final titles = WebConversationGroupTitles(
      sessions: sessions,
      loader: (_, _, _) async => value,
    );
    addTearDown(titles.dispose);
    titles.title('100');
    await Future<void>.delayed(Duration.zero);
    expect(titles.title('100'), 'BEFORE_REMARK');
    value = 'AFTER_REMARK';
    titles.invalidate();
    expect(titles.title('100'), isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(titles.title('100'), 'AFTER_REMARK');
  });

  test(
    'Real group-edit event refreshes only that group; messages do not',
    () async {
      final calls = <String, int>{};
      var name = 'OLD_NAME';
      final titles = WebConversationGroupTitles(
        sessions: sessions,
        loader: (gid, _, _) async {
          calls[gid] = (calls[gid] ?? 0) + 1;
          return name;
        },
      );
      addTearDown(titles.dispose);
      titles.title('100');
      titles.title('200');
      await Future<void>.delayed(Duration.zero);
      expect(calls, {'100': 1, '200': 1});
      AppEventBus.fire(
        const DataWrapperEvent<String>(
          data: 'ordinary-message',
          dataType: 'message',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(titles.title('100'), 'OLD_NAME');
      expect(calls, {'100': 1, '200': 1});
      name = 'NEW_NAME';
      AppEventBus.fire(
        const GroupEditEvent(gid: '100', updates: {'title': 'NEW_NAME'}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(titles.title('100'), isEmpty);
      expect(titles.title('200'), 'OLD_NAME');
      await Future<void>.delayed(Duration.zero);
      expect(titles.title('100'), 'NEW_NAME');
      expect(calls, {'100': 2, '200': 1});
    },
  );

  test(
    'Failed lookup retries on reconnect without a build retry storm',
    () async {
      var attempts = 0;
      final titles = WebConversationGroupTitles(
        sessions: sessions,
        loader: (_, _, _) async {
          if (++attempts == 1) throw StateError('temporary failure');
          return 'RECOVERED';
        },
      );
      addTearDown(titles.dispose);
      titles.title('100');
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 10; i++) {
        expect(titles.title('100'), isEmpty);
      }
      expect(attempts, 1);
      AppEventBus.fire(WebSocketStatusChangedEvent(status: 'connected'));
      await Future<void>.delayed(Duration.zero);
      titles.title('100');
      await Future<void>.delayed(Duration.zero);
      expect(titles.title('100'), 'RECOVERED');
      expect(attempts, 2);
    },
  );

  testWidgets('Temporary HTTP or DB failure recovers without WS reconnect', (
    tester,
  ) async {
    var attempts = 0;
    final titles = WebConversationGroupTitles(
      sessions: sessions,
      retryDelays: const [
        Duration(milliseconds: 10),
        Duration(milliseconds: 20),
      ],
      loader: (_, _, _) async {
        if (++attempts == 1) throw StateError('database temporarily busy');
        return 'RECOVERED_WITHOUT_RECONNECT';
      },
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WebConversationGroupTitle(
          groupId: '100',
          titles: titles,
          builder: (name) => Text(name),
        ),
      ),
    );
    await tester.pump();
    expect(attempts, 1);
    for (var i = 0; i < 10; i++) {
      titles.title('100');
    }
    expect(attempts, 1);
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();
    expect(find.text('RECOVERED_WITHOUT_RECONNECT'), findsOneWidget);
    expect(attempts, 2);
    await tester.pumpWidget(const SizedBox());
    titles.dispose();
  });

  testWidgets('Persistent failure stops after the bounded retry budget', (
    tester,
  ) async {
    var attempts = 0;
    final titles = WebConversationGroupTitles(
      sessions: sessions,
      retryDelays: const [
        Duration(milliseconds: 10),
        Duration(milliseconds: 20),
      ],
      loader: (_, _, _) async {
        attempts++;
        throw StateError('offline');
      },
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WebConversationGroupTitle(
          groupId: '100',
          titles: titles,
          builder: (name) => Text(name),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 10; i++) {
      titles.title('100');
    }
    expect(attempts, 3);
    await tester.pumpWidget(const SizedBox());
    titles.dispose();
  });

  testWidgets(
    'Account switch cancels a waiting retry without invoking loader',
    (tester) async {
      var attempts = 0;
      final titles = WebConversationGroupTitles(
        sessions: sessions,
        retryDelays: const [Duration(milliseconds: 10)],
        loader: (_, _, _) async {
          attempts++;
          throw StateError('temporary failure');
        },
      );
      titles.title('100');
      await tester.pump();
      expect(attempts, 1);
      sessions.changeAccount('9');
      await tester.pump(const Duration(seconds: 1));
      expect(
        attempts,
        1,
        reason: 'the old account retry must not run after switching',
      );
      titles.dispose();
    },
  );

  testWidgets('Disposal cancels a waiting retry without invoking loader', (
    tester,
  ) async {
    var attempts = 0;
    final titles = WebConversationGroupTitles(
      sessions: sessions,
      retryDelays: const [Duration(milliseconds: 10)],
      loader: (_, _, _) async {
        attempts++;
        throw StateError('temporary failure');
      },
    );
    titles.title('100');
    await tester.pump();
    expect(attempts, 1);
    titles.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(attempts, 1, reason: 'a disposed title cache must not retry');
  });

  testWidgets('First frame is empty and stable row rebuild does not reload', (
    tester,
  ) async {
    final pending = Completer<String>();
    var calls = 0;
    final ConversationGroupTitleLoader load = (_, _, _) {
      calls++;
      return pending.future;
    };
    Widget row() => Directionality(
      textDirection: TextDirection.ltr,
      child: WebConversationGroupTitle(
        groupId: '100',
        sessions: sessions,
        loader: load,
        builder: (title) => Text(title.isEmpty ? 'UNNAMED' : title),
      ),
    );
    await tester.pumpWidget(row());
    expect(find.text('UNNAMED'), findsOneWidget);
    await tester.pumpWidget(row());
    expect(calls, 1);
    pending.complete('SAFE_NAME');
    await tester.pumpAndSettle();
    expect(find.text('SAFE_NAME'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Same UID new session cannot publish old lookup', (tester) async {
    final old = Completer<String>();
    var calls = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WebConversationGroupTitle(
          groupId: '100',
          sessions: sessions,
          loader: (_, _, _) =>
              calls++ == 0 ? old.future : Future.value('NEW_NAME'),
          builder: (title) => Text(title),
        ),
      ),
    );
    sessions.renew();
    old.complete('OLD_NAME');
    await tester.pumpAndSettle();
    expect(find.text('OLD_NAME'), findsNothing);
    expect(find.text('NEW_NAME'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Endpoint change suppresses a late result without auth event', (
    tester,
  ) async {
    final pending = Completer<String>();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WebConversationGroupTitle(
          groupId: '100',
          sessions: sessions,
          loader: (_, _, _) => pending.future,
          builder: (title) => Text(title),
        ),
      ),
    );
    envMap[currentEnv] = _Endpoint('http://127.0.0.1:19802');
    pending.complete('FOREIGN_NAME');
    await tester.pump();
    expect(find.text('FOREIGN_NAME'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
