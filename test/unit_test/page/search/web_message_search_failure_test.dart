import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/page/search/web_search_page.dart';
import 'package:imboy/page/search/web_search_state.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class _SearchFactsDatabase implements Database {
  _SearchFactsDatabase(this.lookup);
  final Future<List<Map<String, Object?>>> Function() lookup;
  int queries = 0;
  @override
  bool get isOpen => true;
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    queries++;
    return lookup();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthChanges extends ChangeNotifier {
  void change() => notifyListeners();
}

Finder resultTitle(String text) => find.byWidgetPredicate(
  (widget) => widget is TextHighlight && widget.text == text,
);

Future<void> waitForHistoryWrites(WidgetTester tester, Finder page) async {
  final dynamic state = tester.state(page);
  var completed = false;
  (state.historyWritesForTest as Future<void>).then((_) => completed = true);
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (completed && state.historyWritesPendingForTest == false) return;
  }
  fail('History writes did not finish after 30 pumps');
}

void main() {
  for (final type in ['C2C', 'C2G']) {
    testWidgets('点击会话搜索结果保留 $type 类型和 peerId', (tester) async {
      resetWebSearchHistoryQueueForTest();
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      String? arrivedPeer;
      String? arrivedType;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => WebSearchPage(
              initialQuery: 'conversation',
              messageSearchForTest: (_) async => [],
              otherSearchForTest: (_) async => [
                SearchItem(
                  type: SearchItemType.conversation,
                  id: '300',
                  title: '目标会话',
                  metadata: {'type': type},
                ),
              ],
            ),
          ),
          GoRoute(
            path: '/chat/:peerId',
            builder: (_, state) {
              arrivedPeer = state.pathParameters['peerId'];
              arrivedType = state.uri.queryParameters['type'];
              return const Scaffold(body: Text('已打开会话'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      await waitForHistoryWrites(tester, find.byType(WebSearchPage));
      await tester.tap(resultTitle('目标会话'));
      await tester.pumpAndSettle();
      expect(find.text('已打开会话'), findsOneWidget);
      expect(arrivedPeer, '300');
      expect(arrivedType, type);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('全局失败在矮窗口可重试，成功后清除旧错误并保留查询', (tester) async {
    resetWebSearchHistoryQueueForTest();
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    tester.view.physicalSize = const Size(360, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final queries = <String>[];
    var recover = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: WebSearchPage(
            initialQuery: 'first query',
            messageSearchForTest: (_) async => [],
            otherSearchForTest: (query) async {
              queries.add(query);
              if (!recover) throw Exception('temporary search failure');
              return [SearchItem(type: SearchItemType.contact, id: '200', title: 'Recovered $query')];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.common.searchError), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'first query');
    expect(tester.takeException(), isNull);
    recover = true;
    await tester.ensureVisible(find.text(t.common.buttonRetry));
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pumpAndSettle();
    expect(queries, ['first query', 'first query']);
    expect(resultTitle('Recovered first query'), findsOneWidget);
    expect(find.text(t.common.searchError), findsNothing);
    expect(tester.takeException(), isNull);
    await waitForHistoryWrites(tester, find.byType(WebSearchPage));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('失败后清空再输入新词不会继续显示旧错误', (tester) async {
    resetWebSearchHistoryQueueForTest();
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    final queries = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WebSearchPage(
            initialQuery: 'failed query',
            messageSearchForTest: (_) async => [],
            otherSearchForTest: (query) async {
              queries.add(query);
              if (query == 'failed query') throw Exception('temporary failure');
              return [SearchItem(type: SearchItemType.contact, id: '200', title: 'Found $query')];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.common.searchError), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text(t.common.searchError), findsNothing);
    await tester.enterText(find.byType(TextField), 'fresh query');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(queries, ['failed query', 'fresh query']);
    expect(resultTitle('Found fresh query'), findsOneWidget);
    expect(find.text(t.common.searchError), findsNothing);
    await waitForHistoryWrites(tester, find.byType(WebSearchPage));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  // 每例退出前 drain，再在下一例重建 Future；已完成的旧 Future 仍属于旧
  // FakeAsync zone。reset 保留 pending 检查，不能丢弃未完成写入。
  for (final navigate in [false, true]) {
    testWidgets(
      'Web ${navigate ? 'return' : 'resume'} reloads a countdown started after search',
      (tester) async {
        resetWebSearchHistoryQueueForTest();
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        NtpHelper.debugReset();
        var readAt = 0;
        final db = _SearchFactsDatabase(
          () async => [
            {
              'payload': jsonEncode({
                'text': 'unread fixture',
                'burn': true,
                'burn_after_ms': 60000,
                if (readAt > 0) 'burn_read_at': readAt,
              }),
              'created_at': 1,
              'is_author': 0,
              'status': 20,
              'msg_type': 'text',
            },
          ],
        );
        SqliteService.setDbForTest(db);
        addTearDown(() {
          SqliteService.setDbForTest(null);
          NtpHelper.debugReset();
        });
        final item = SearchItem(
          type: SearchItemType.message,
          id: 'unread',
          title: 'unread fixture',
          metadata: const {'conversationId': '200', 'type': 'C2C'},
          message: MessageSearchResult(
            id: 'unread',
            content: 'unread fixture',
            fromId: '200',
            toId: '100',
            type: 'C2C',
            createdAt: 1,
            payload: {
              'text': 'unread fixture',
              'burn': true,
              'burn_after_ms': 60000,
            },
          ),
        );
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => WebSearchPage(
                initialQuery: 'fixture',
                messageSearchForTest: (_) async => [item],
                otherSearchForTest: (_) async => [],
              ),
            ),
            GoRoute(
              path: '/chat/:peer',
              builder: (_, _) => const Scaffold(body: Text('isolated chat')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();
        expect(resultTitle('unread fixture'), findsOneWidget);
        if (navigate) {
          await tester.tap(resultTitle('unread fixture'));
          await tester.pumpAndSettle();
          expect(find.text('isolated chat'), findsOneWidget);
        } else {
          for (final state in [
            AppLifecycleState.inactive,
            AppLifecycleState.hidden,
            AppLifecycleState.paused,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        }
        readAt = DateTimeHelper.millisecond() - 61000;
        if (navigate) {
          router.pop();
        } else {
          for (final state in [
            AppLifecycleState.hidden,
            AppLifecycleState.inactive,
            AppLifecycleState.resumed,
          ]) {
            tester.binding.handleAppLifecycleStateChanged(state);
          }
        }
        await tester.pumpAndSettle();
        expect(db.queries, greaterThanOrEqualTo(navigate ? 2 : 1));
        expect(resultTitle('unread fixture'), findsNothing);
        await waitForHistoryWrites(tester, find.byType(WebSearchPage));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'Web click retains first local observation so deletion during chat cannot revive it',
    (tester) async {
      resetWebSearchHistoryQueueForTest();
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      var present = true;
      var searches = 0;
      final db = _SearchFactsDatabase(
        () async => present
            ? [
                {
                  'payload': '{"text":"click fixture","burn":true,"burn_after_ms":60000}',
                  'msg_type': 'text',
                  'created_at': 1,
                  'is_author': 0,
                  'status': 20,
                },
              ]
            : [],
      );
      SqliteService.setDbForTest(db);
      addTearDown(() => SqliteService.setDbForTest(null));
      final item = SearchItem(
        type: SearchItemType.message,
        id: 'clicked',
        title: 'click fixture',
        metadata: const {'conversationId': '200', 'type': 'C2C'},
        message: MessageSearchResult(
          id: 'clicked',
          content: 'click fixture',
          fromId: '200',
          toId: '100',
          type: 'C2C',
          createdAt: 1,
          payload: {
            'text': 'click fixture',
            'burn': true,
            'burn_after_ms': 60000,
          },
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => WebSearchPage(
              initialQuery: 'fixture',
              messageSearchForTest: (_) async {
                searches++;
                return [item];
              },
              otherSearchForTest: (_) async => [],
            ),
          ),
          GoRoute(
            path: '/chat/:peer',
            builder: (_, _) => const Scaffold(body: Text('isolated chat')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      expect(item.message!.localRowObserved, isFalse);
      expect(resultTitle('click fixture'), findsOneWidget);
      expect(db.queries, 0);
      await tester.tap(resultTitle('click fixture'));
      await tester.pumpAndSettle();
      expect(find.text('isolated chat'), findsOneWidget);
      expect(db.queries, 1);
      present = false;
      router.pop();
      await tester.pumpAndSettle();
      expect(db.queries, 2);
      expect(resultTitle('click fixture'), findsNothing);
      expect(searches, 1);
      await waitForHistoryWrites(tester, find.byType(WebSearchPage));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'visible Web burn result is removed at expiry while unread remains',
    (tester) async {
      resetWebSearchHistoryQueueForTest();
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      NtpHelper.debugReset();
      addTearDown(NtpHelper.debugReset);
      final nowMs = DateTimeHelper.millisecond();
      SearchItem message(String id, {bool unread = false}) => SearchItem(
        type: SearchItemType.message,
        id: id,
        title: id,
        message: MessageSearchResult(
          id: id,
          content: id,
          fromId: unread ? '200' : '100',
          toId: '200',
          type: 'C2C',
          createdAt: nowMs,
          payload: {'text': id, 'burn': true, 'burn_after_ms': 60000},
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: WebSearchPage(
              initialQuery: 'fixture',
              messageSearchForTest: (_) async => [
                message('live fixture'),
                message('unread fixture', unread: true),
              ],
              otherSearchForTest: (_) async => [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(resultTitle('live fixture'), findsOneWidget);
      expect(resultTitle('unread fixture'), findsOneWidget);
      NtpHelper.updateOffsetFromServer(nowMs + 61000);
      await tester.pump(const Duration(seconds: 61));
      expect(resultTitle('live fixture'), findsNothing);
      expect(resultTitle('unread fixture'), findsOneWidget);
      await waitForHistoryWrites(tester, find.byType(WebSearchPage));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('two pages synchronize history clearing and adding', (
    tester,
  ) async {
    resetWebSearchHistoryQueueForTest();
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    final key =
        'web_search_history_v2_${sha256.convert(utf8.encode(jsonEncode([Env().apiBaseUrl, '100'])))}';
    await StorageService.to.setList(key, ['old history']);
    Future<List<SearchItem>> empty(String _) async => [];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Row(
            children: [
              Expanded(
                child: WebSearchPage(
                  key: const ValueKey('first'),
                  messageSearchForTest: empty,
                  otherSearchForTest: empty,
                ),
              ),
              Expanded(
                child: WebSearchPage(
                  key: const ValueKey('second'),
                  messageSearchForTest: empty,
                  otherSearchForTest: empty,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey('first'));
    final second = find.byKey(const ValueKey('second'));
    expect(find.text('old history'), findsNWidgets(2));
    await tester.tap(
      find.descendant(of: first, matching: find.text(t.common.clear)),
    );
    await tester.pumpAndSettle();
    expect(find.text('old history'), findsNothing);
    await tester.enterText(
      find.descendant(of: first, matching: find.byType(TextField)),
      'new history',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await waitForHistoryWrites(tester, first);
    expect(
      find.descendant(of: second, matching: find.text('new history')),
      findsOneWidget,
    );
  });

  testWidgets('history is scoped and stale in-flight write is restored', (
    tester,
  ) async {
    resetWebSearchHistoryQueueForTest();
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '100',
      'web_search_history': '["legacy"]',
    });
    await StorageService.init();
    String key(String uid) =>
        'web_search_history_v2_${sha256.convert(utf8.encode(jsonEncode([Env().apiBaseUrl, uid])))}';
    await StorageService.to.setList(key('200'), ['account B']);
    final entered = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    var first = true;
    final changes = _AuthChanges();
    addTearDown(changes.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WebSearchPage(
            initialQuery: 'account A',
            authChangesForTest: changes,
            messageSearchForTest: (_) async => [],
            otherSearchForTest: (_) async => [],
            persistHistoryForTest: (write) async {
              if (first) {
                first = false;
                entered.complete();
                await release.future;
              }
              await write();
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 30 && !entered.isCompleted; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(entered.isCompleted, isTrue, reason: 'History write did not start');
    await StorageService.to.setString(Keys.currentUid, '200');
    changes.change();
    release.complete();
    await tester.pumpAndSettle();
    await waitForHistoryWrites(tester, find.byType(WebSearchPage));
    expect(StorageService.to.getStringList(key('100')), isEmpty);
    expect(find.text('account B'), findsOneWidget);
    expect(find.text('account A'), findsNothing);
    expect(find.text('legacy'), findsNothing);
  });

  testWidgets('search during auth transition does not remain loading', (
    tester,
  ) async {
    resetWebSearchHistoryQueueForTest();
    var transitioning = true;
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WebSearchPage(
            authTransitioningForTest: () => transitioning,
            messageSearchForTest: (_) async {
              calls++;
              return [];
            },
            otherSearchForTest: (_) async => [],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(calls, 0);
    expect(find.text(t.common.searchFailedRetry), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    transitioning = false;
    await tester.tap(find.text(t.common.retry));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await waitForHistoryWrites(tester, find.byType(WebSearchPage));
  });

  testWidgets(
    'auth change clears prior results and invalidates pending search',
    (tester) async {
      resetWebSearchHistoryQueueForTest();
      final changes = _AuthChanges();
      addTearDown(changes.dispose);
      final pending = Completer<List<SearchItem>>();
      var calls = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: WebSearchPage(
              initialQuery: 'first',
              authChangesForTest: changes,
              messageSearchForTest: (_) {
                calls++;
                return calls == 1
                    ? Future.value([
                        const SearchItem(
                          type: SearchItemType.message,
                          id: '1',
                          title: 'Old result',
                        ),
                      ])
                    : pending.future;
              },
              otherSearchForTest: (_) async => [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(resultTitle('Old result'), findsOneWidget);
      changes.change();
      await tester.pump();
      expect(resultTitle('Old result'), findsNothing);
      await tester.enterText(find.byType(TextField), 'second');
      await tester.pump(const Duration(milliseconds: 350));
      changes.change();
      await tester.pump();
      pending.complete([
        const SearchItem(
          type: SearchItemType.message,
          id: '2',
          title: 'Late result',
        ),
      ]);
      await tester.pumpAndSettle();
      expect(resultTitle('Late result'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await waitForHistoryWrites(tester, find.byType(WebSearchPage));
    },
  );

  testWidgets('explicit search cancels pending debounce', (tester) async {
    resetWebSearchHistoryQueueForTest();
    final calls = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WebSearchPage(
            messageSearchForTest: (query) async {
              calls.add(query);
              return [];
            },
            otherSearchForTest: (_) async => [],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'old');
    final dynamic state = tester.state(find.byType(WebSearchPage));
    await state.runSearchForTest('new');
    await tester.pump(const Duration(milliseconds: 350));
    expect(calls, ['new']);
    await waitForHistoryWrites(tester, find.byType(WebSearchPage));
  });

  testWidgets('message failure preserves contacts and retry shows messages', (
    tester,
  ) async {
    resetWebSearchHistoryQueueForTest();
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WebSearchPage(
            initialQuery: 'alice',
            messageSearchForTest: (_) async {
              attempts++;
              if (attempts == 1) throw Exception('offline');
              return [
                const SearchItem(
                  type: SearchItemType.message,
                  id: '2',
                  title: 'Message result',
                ),
              ];
            },
            otherSearchForTest: (_) async => [
              const SearchItem(
                type: SearchItemType.contact,
                id: '1',
                title: 'Contact result',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(resultTitle('Contact result'), findsOneWidget);
    expect(find.text(t.common.searchFailedRetry), findsOneWidget);
    await tester.tap(find.text(t.common.retry));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(resultTitle('Contact result'), findsOneWidget);
    expect(resultTitle('Message result'), findsOneWidget);
    expect(find.text(t.common.searchFailedRetry), findsNothing);
    await waitForHistoryWrites(tester, find.byType(WebSearchPage));
  });

  testWidgets('disabled message search is shown with other results', (
    tester,
  ) async {
    resetWebSearchHistoryQueueForTest();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: WebSearchPage(
            initialQuery: 'alice',
            messageSearchForTest: (_) async =>
                throw FtsFeatureDisabledException(),
            otherSearchForTest: (_) async => [
              const SearchItem(
                type: SearchItemType.contact,
                id: '1',
                title: 'Contact result',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(resultTitle('Contact result'), findsOneWidget);
    expect(find.text(t.common.searchDisabledByEncryption), findsOneWidget);
    expect(find.text(t.common.retry), findsNothing);
    await waitForHistoryWrites(tester, find.byType(WebSearchPage));
  });

  test('message search preserves successful results', () async {
    const item = SearchItem(type: SearchItemType.message, id: '1', title: 'a');
    final result = await runWebMessageSearch(() async => [item]);
    expect(result.$1, [item]);
    expect(result.$2, isNull);
  });

  test('message search distinguishes unavailable and disabled', () async {
    final unavailable = await runWebMessageSearch(
      () async => throw Exception(),
    );
    final disabled = await runWebMessageSearch(
      () async => throw FtsFeatureDisabledException(),
    );
    expect(unavailable.$1, isEmpty);
    expect(unavailable.$2, WebMessageSearchFailure.unavailable);
    expect(disabled.$1, isEmpty);
    expect(disabled.$2, WebMessageSearchFailure.disabled);
  });
}
