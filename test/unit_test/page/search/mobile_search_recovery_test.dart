import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/search/message_search_page.dart';
import 'package:imboy/page/search/message_search_provider.dart';
import 'package:imboy/page/search/message_search_result_card.dart';
import 'package:imboy/page/search/search_chat_page.dart';
import 'package:imboy/page/search/search_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

MessageSearchResult _item(String id) => MessageSearchResult(
  id: id,
  content: id,
  fromId: '1001',
  toId: '1002',
  type: 'C2C',
  createdAt: 1,
  payload: {'text': id},
);

class _Pages implements FtsApi {
  _Pages(this.respond);
  final Future<MessageSearchResponse?> Function(String, int) respond;
  final requests = <(String, int)>[];
  final refreshed = <String>[];
  Future<MessageSearchResponse?> _search(String keyword, int page) {
    requests.add((keyword, page));
    return respond(keyword, page);
  }

  @override
  Future<MessageSearchResponse?> searchMessages({
    required String keyword,
    int page = 1,
    int size = 20,
    String type = 'all',
    int? startTime,
    int? endTime,
  }) => _search(keyword, page);
  @override
  Future<MessageSearchResponse?> searchConversationMessages({
    required String keyword,
    required String conversationUk3,
    int page = 1,
    int size = 20,
    String? msgType,
  }) => _search(keyword, page);
  @override
  Future<MessageSearchResult?> refreshResultVisibility(
    MessageSearchResult item,
  ) async {
    refreshed.add(item.id);
    return item;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LoadedSearch extends MessageSearchNotifier {
  @override
  MessageSearchState build() => MessageSearchState(
    currentQuery: 'fixture',
    searchResults: [_item('first')],
    hasMore: false,
  );
}

class _SeededSearch extends MessageSearchNotifier {
  @override
  MessageSearchState build() => const MessageSearchState();
  void history(String query) =>
      state = state.copyWith(currentQuery: '', searchHistory: [query]);
  void seed(String query, String scope) => state = MessageSearchState(
    currentQuery: query,
    conversationUk3: scope,
    conversationTitle: scope,
    selectedType: 'C2G',
    selectedTimeRange: 'today',
    hasMore: false,
  );
}

class _SearchNavigator extends Navigator {
  const _SearchNavigator({required super.onGenerateRoute});
  @override
  NavigatorState createState() => _SearchNavigatorState();
}

class _SearchNavigatorState extends NavigatorState {
  @override
  Future<T?> push<T extends Object?>(Route<T> route) => super.push<T>(
    MaterialPageRoute<T>(
      builder: (_) => const Scaffold(body: Text('isolated chat')),
    ),
  );
}

class _DelayedContactDb implements Database {
  final entered = Completer<void>();
  final release = Completer<List<Map<String, Object?>>>();
  @override
  bool get isOpen => true;
  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    if (!entered.isCompleted) entered.complete();
    return release.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _chat(WidgetTester tester, _Pages api) async {
  expect(UserRepoLocal.to.currentUid, '1001');
  expect(UserRepoLocal.to.isAuthTransitioning, isFalse);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const SearchChatPage(
          conversationUk3: 'C2C_1001_1002',
          type: 'C2C',
          peerId: '1002',
          peerTitle: '',
          peerAvatar: '',
          peerSign: '',
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
    ProviderScope(
      overrides: [ftsApiProvider.overrideWithValue(api)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  final scoped = ProviderScope.containerOf(
    tester.element(find.byType(EditableText)),
  );
  scoped
      .read(searchProvider.notifier)
      .cacheContact(
        '1001',
        ContactModel(peerId: '1001', nickname: 'synthetic sender'),
      );
  return scoped;
}

Future<void> _query(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(EditableText), query);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  expect(
    tester.widget<EditableText>(find.byType(EditableText)).controller.text,
    query,
  );
}

Future<void> _footer(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    500,
    scrollable: find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ),
    maxScrolls: 100,
  );
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _historyPage(
  WidgetTester tester,
  _Pages api,
  bool chat,
) async {
  if (chat) {
    final scope = await _chat(tester, api);
    await scope.read(searchProvider.notifier).addToHistory('A private history');
    await tester.pumpAndSettle();
    return scope;
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ftsApiProvider.overrideWithValue(api),
        messageSearchProvider.overrideWith(_SeededSearch.new),
      ],
      child: MaterialApp(
        builder: (_, child) =>
            TranslationProvider(child: Material(child: child)),
        home: const MessageSearchPage(),
      ),
    ),
  );
  final scope = ProviderScope.containerOf(
    tester.element(find.byType(EditableText)),
  );
  (scope.read(messageSearchProvider.notifier) as _SeededSearch).history(
    'A private history',
  );
  await tester.pumpAndSettle();
  return scope;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    SqliteService.setDbUnavailableForTest();
  });
  tearDown(() => SqliteService.setDbForTest(null));

  testWidgets('global next-page failure keeps rows and retries the same page', (
    tester,
  ) async {
    var failures = 1;
    final api = _Pages(
      (_, page) async => page == 1
          ? MessageSearchResponse(
              items: [_item('first')],
              total: 2,
              sourceItemCount: 20,
            )
          : failures-- > 0
          ? null
          : MessageSearchResponse(items: [_item('second')], total: 2),
    );
    final container = ProviderContainer(
      overrides: [ftsApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (_, child) =>
              TranslationProvider(child: Material(child: child)),
          home: _SearchNavigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const MessageSearchPage(),
            ),
          ),
        ),
      ),
    );
    final notifier = container.read(messageSearchProvider.notifier);
    for (final uid in ['1001', '1002']) {
      notifier.cacheContact(
        uid,
        ContactModel(peerId: uid, nickname: 'synthetic sender'),
      );
    }
    await tester.runAsync(() => notifier.performSearch(query: 'fixture'));
    await tester.pumpAndSettle();
    await tester.runAsync(notifier.loadMore);
    await tester.pumpAndSettle();
    expect(find.byType(MessageSearchResultCard), findsOneWidget);
    expect(find.text(t.common.searchFailedRetry), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate((w) => w is TextHighlight && w.text == 'first'),
    );
    await tester.pumpAndSettle();
    expect(find.text('isolated chat'), findsOneWidget);
    Navigator.of(tester.element(find.text('isolated chat'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pumpAndSettle();
    expect(api.requests.map((r) => r.$2), [1, 2, 2]);
    expect(
      container.read(messageSearchProvider).searchResults.map((r) => r.id),
      ['first', 'second'],
    );
    expect(container.read(messageSearchProvider).errorMessage, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'global page debounce cannot launch an old account query after switching',
    (tester) async {
      final api = _Pages(
        (_, _) async => MessageSearchResponse(items: [], total: 0),
      );
      final container = ProviderContainer(
        overrides: [ftsApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (_, child) =>
                TranslationProvider(child: Material(child: child)),
            home: const MessageSearchPage(),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'old-account-query');
      await StorageService.to.setString(Keys.currentUid, '2002');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(api.requests, isEmpty);
      expect(container.read(messageSearchProvider).currentQuery, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('global new-query failure does not relabel previous-query rows', (
    tester,
  ) async {
    final api = _Pages(
      (query, _) async => query == 'new'
          ? null
          : MessageSearchResponse(items: [_item('old')], total: 1),
    );
    final container = ProviderContainer(
      overrides: [ftsApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (_, child) =>
              TranslationProvider(child: Material(child: child)),
          home: const MessageSearchPage(),
        ),
      ),
    );
    final notifier = container.read(messageSearchProvider.notifier);
    for (final uid in ['1001', '1002']) {
      notifier.cacheContact(
        uid,
        ContactModel(peerId: uid, nickname: 'synthetic sender'),
      );
    }
    await tester.runAsync(() => notifier.performSearch(query: 'old'));
    await tester.pumpAndSettle();
    expect(find.byType(MessageSearchResultCard), findsOneWidget);
    await tester.runAsync(() => notifier.performSearch(query: 'new'));
    await tester.pumpAndSettle();
    expect(find.byType(MessageSearchResultCard), findsNothing);
    expect(container.read(messageSearchProvider).currentQuery, 'new');
    expect(container.read(messageSearchProvider).searchResults, isEmpty);
    expect(find.text(t.common.searchError), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'conversation 51st result is reachable and failed page retries without hiding rows',
    (tester) async {
      var failures = 1;
      final api = _Pages(
        (_, page) async => page == 1
            ? MessageSearchResponse(
                items: List.generate(50, (i) => _item('row-$i')),
                total: 51,
              )
            : failures-- > 0
            ? null
            : MessageSearchResponse(items: [_item('row-50')], total: 51),
      );
      final scoped = await _chat(tester, api);
      await _query(tester, 'fixture');
      await _footer(tester, t.common.loadMore);
      expect(scoped.read(searchProvider).searchResults, hasLength(50));
      expect(find.byType(ImBoyListTile), findsWidgets);
      await _footer(tester, t.common.buttonRetry);
      expect(api.requests.map((r) => r.$2), [1, 2, 2]);
      expect(scoped.read(searchProvider).searchResults, hasLength(51));
      expect(scoped.read(searchProvider).hasMore, isFalse);
      expect(scoped.read(searchProvider).currentPage, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'global page discards a contact loaded after the account changed',
    (tester) async {
      final db = _DelayedContactDb();
      SqliteService.setDbForTest(db);
      final container = ProviderContainer(
        overrides: [messageSearchProvider.overrideWith(_LoadedSearch.new)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (_, child) =>
                TranslationProvider(child: Material(child: child)),
            home: const MessageSearchPage(),
          ),
        ),
      );
      expect(db.entered.isCompleted, isTrue);
      await StorageService.to.setString(Keys.currentUid, '2002');
      db.release.complete([
        {'peer_id': '1001', 'nickname': 'old contact', 'avatar': ''},
      ]);
      await tester.pumpAndSettle();
      expect(container.read(messageSearchProvider).contactCache, isEmpty);
      expect(find.text('old contact'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'conversation a filtered full page continues to a later visible hit',
    (tester) async {
      final api = _Pages(
        (_, page) async => page == 1
            ? MessageSearchResponse(items: [], sourceItemCount: 50, total: 51)
            : MessageSearchResponse(items: [_item('later-live')], total: 51),
      );
      final scoped = await _chat(tester, api);
      await _query(tester, 'fixture');
      expect(api.requests.map((r) => r.$2), [1, 2]);
      expect(scoped.read(searchProvider).searchResults.single.id, 'later-live');
      expect(scoped.read(searchProvider).currentPage, 2);
      expect(scoped.read(searchProvider).hasMore, isFalse);
      await tester.tap(find.byType(ImBoyListTile));
      await tester.pumpAndSettle();
      expect(api.refreshed, ['later-live']);
      expect(find.text('isolated chat'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('conversation late next page cannot overwrite a new query', (
    tester,
  ) async {
    final next = Completer<MessageSearchResponse?>();
    final api = _Pages(
      (query, page) async => page == 2
          ? next.future
          : MessageSearchResponse(
              items: [_item(query)],
              total: 51,
              sourceItemCount: query == 'old' ? 50 : 1,
            ),
    );
    final scoped = await _chat(tester, api);
    await _query(tester, 'old');
    await tester.tap(find.text(t.common.loadMore));
    await tester.pump();
    await _query(tester, 'new');
    next.complete(MessageSearchResponse(items: [_item('stale')], total: 51));
    await tester.pumpAndSettle();
    expect(scoped.read(searchProvider).currentQuery, 'new');
    expect(scoped.read(searchProvider).searchResults.map((r) => r.id), ['new']);
    expect(scoped.read(searchProvider).isLoading, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'conversation policy denial hides old rows and offers no futile retry',
    (tester) async {
      final api = _Pages((_, page) async {
        if (page > 1) throw FtsFeatureDisabledException();
        return MessageSearchResponse(
          items: [_item('first')],
          total: 51,
          sourceItemCount: 50,
        );
      });
      await _chat(tester, api);
      await _query(tester, 'fixture');
      await tester.tap(find.text(t.common.loadMore));
      await tester.pumpAndSettle();
      expect(find.byType(ImBoyListTile), findsNothing);
      expect(find.text(t.common.searchDisabledTitle), findsOneWidget);
      expect(find.text(t.common.buttonRetry), findsNothing);
      expect(api.requests.map((r) => r.$2), [1, 2]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('old global page controls cannot change a new identity search', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [messageSearchProvider.overrideWith(_SeededSearch.new)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (_, child) =>
              TranslationProvider(child: Material(child: child)),
          home: const MessageSearchPage(
            conversationUk3: 'old-scope',
            conversationTitle: 'Old scope',
          ),
        ),
      ),
    );
    final notifier =
        container.read(messageSearchProvider.notifier) as _SeededSearch;
    notifier.seed('old query', 'old-scope');
    await tester.pumpAndSettle();
    final oldFilter = tester
        .widget<GestureDetector>(
          find
              .ancestor(
                of: find.text(t.chat.privateChat),
                matching: find.byType(GestureDetector),
              )
              .first,
        )
        .onTap!;
    final oldScope = tester
        .widget<CupertinoButton>(
          find
              .ancestor(
                of: find.text(t.common.searchAll),
                matching: find.byType(CupertinoButton),
              )
              .first,
        )
        .onPressed!;
    await StorageService.to.setString(Keys.currentUid, '2002');
    notifier.seed('new query', 'new-scope');
    await tester.pumpAndSettle();
    final newState = container.read(messageSearchProvider);
    expect(find.text(t.chat.privateChat), findsNothing);
    expect(find.text(t.common.searchAll), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    oldFilter();
    oldScope();
    await tester.pumpAndSettle();
    expect(container.read(messageSearchProvider), same(newState));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final chat in [false, true]) {
    testWidgets(
      '${chat ? 'chat' : 'global'} captured history cannot write into a changed account',
      (tester) async {
        final api = _Pages(
          (_, _) async => MessageSearchResponse(items: [], total: 0),
        );
        final scope = await _historyPage(tester, api, chat);
        final oldHistory = chat
            ? tester
                  .widget<ImBoySettingsTile>(
                    find.widgetWithText(ImBoySettingsTile, 'A private history'),
                  )
                  .onTap!
            : tester
                  .widget<ImBoyListTile>(
                    find.widgetWithText(ImBoyListTile, 'A private history'),
                  )
                  .onTap!;
        final controller = tester
            .widget<EditableText>(find.byType(EditableText))
            .controller;
        expect(controller.text, isEmpty);
        await StorageService.to.setString(Keys.currentUid, '2002');
        if (chat) {
          scope.read(searchProvider.notifier).setCurrentQuery('B query');
        } else {
          (scope.read(messageSearchProvider.notifier) as _SeededSearch).seed(
            'B query',
            'B scope',
          );
        }
        await tester.pumpAndSettle();
        final before = chat
            ? scope.read(searchProvider)
            : scope.read(messageSearchProvider);
        oldHistory();
        await tester.pumpAndSettle();
        expect(controller.text, isEmpty);
        expect(
          chat ? scope.read(searchProvider) : scope.read(messageSearchProvider),
          same(before),
        );
        expect(api.requests, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      '${chat ? 'chat' : 'global'} captured clear is inert after page disposal',
      (tester) async {
        final api = _Pages(
          (_, _) async => MessageSearchResponse(items: [], total: 0),
        );
        final scope = await _historyPage(tester, api, chat);
        final controller = tester
            .widget<EditableText>(find.byType(EditableText))
            .controller;
        controller.text = 'A draft';
        if (chat) {
          scope.read(searchProvider.notifier).setCurrentQuery('A query');
        } else {
          (scope.read(messageSearchProvider.notifier) as _SeededSearch).seed(
            'A query',
            'A scope',
          );
        }
        await tester.pumpAndSettle();
        final oldClear = chat
            ? tester
                  .widget<CupertinoButton>(
                    find
                        .ancestor(
                          of: find.byIcon(CupertinoIcons.xmark_circle_fill),
                          matching: find.byType(CupertinoButton),
                        )
                        .first,
                  )
                  .onPressed!
            : tester
                  .widget<IconButton>(
                    find.widgetWithIcon(IconButton, CupertinoIcons.clear),
                  )
                  .onPressed!;
        oldClear();
        await tester.pumpAndSettle();
        expect(controller.text, isEmpty);
        expect(
          chat
              ? scope.read(searchProvider).currentQuery
              : scope.read(messageSearchProvider).currentQuery,
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(oldClear, returnsNormally);
        expect(api.requests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('chat captured filter cannot mutate a changed account provider', (
    tester,
  ) async {
    final api = _Pages(
      (_, _) async => MessageSearchResponse(items: [], total: 0),
    );
    final scope = await _historyPage(tester, api, true);
    scope.read(searchProvider.notifier).setCurrentQuery('A query');
    await tester.pumpAndSettle();
    final oldFilter = tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, t.main.text))
        .onSelected!;
    final controller = tester
        .widget<EditableText>(find.byType(EditableText))
        .controller;
    await StorageService.to.setString(Keys.currentUid, '2002');
    scope.read(searchProvider.notifier).setCurrentQuery('B query');
    await tester.pumpAndSettle();
    final before = scope.read(searchProvider);
    oldFilter(true);
    await tester.pumpAndSettle();
    expect(scope.read(searchProvider), same(before));
    expect(controller.text, isEmpty);
    expect(api.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
