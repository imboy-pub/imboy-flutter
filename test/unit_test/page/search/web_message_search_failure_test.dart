import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/page/search/web_search_page.dart';
import 'package:imboy/page/search/web_search_state.dart';
import 'package:imboy/store/api/fts_api.dart';

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
  testWidgets('two pages synchronize history clearing and adding', (
    tester,
  ) async {
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
  });

  testWidgets(
    'auth change clears prior results and invalidates pending search',
    (tester) async {
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
    },
  );

  testWidgets('explicit search cancels pending debounce', (tester) async {
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
  });

  testWidgets('message failure preserves contacts and retry shows messages', (
    tester,
  ) async {
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
  });

  testWidgets('disabled message search is shown with other results', (
    tester,
  ) async {
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
