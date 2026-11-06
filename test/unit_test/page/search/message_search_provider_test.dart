import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/search/message_search_page.dart';
import 'package:imboy/page/search/message_search_result_card.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:imboy/page/search/message_search_provider.dart';
import 'package:imboy/page/search/search_result_expiry.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';

MessageSearchResult _unreadMessage(String id, {int? deadline}) =>
    MessageSearchResult(
      id: id,
      content: id,
      fromId: '200',
      toId: '100',
      type: 'C2C',
      createdAt: 1,
      msgType: 'text',
      payload: {'text': id, 'burn': true, 'burn_after_ms': 60000},
      knownExpiresAtMs: deadline,
    );

class _VisibilityApi implements FtsApi {
  _VisibilityApi(this.items, {this.refresh});
  final List<MessageSearchResult> items;
  final Future<MessageSearchResult?> Function(MessageSearchResult)? refresh;
  final refreshed = <MessageSearchResult>[];
  int searches = 0;

  @override
  Future<MessageSearchResponse?> searchMessages({
    required String keyword,
    int page = 1,
    int size = 20,
    String type = 'all',
    int? startTime,
    int? endTime,
  }) async {
    searches++;
    return MessageSearchResponse(items: items, total: items.length);
  }

  @override
  Future<MessageSearchResult?> refreshResultVisibility(
    MessageSearchResult item,
  ) {
    refreshed.add(item);
    return refresh?.call(item) ?? FtsApi.to.refreshResultVisibility(item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ObservedMessageDatabase implements Database {
  bool present = true;
  @override
  bool get isOpen => true;
  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async => present
      ? [
          {
            'payload':
                '{"text":"click fixture","burn":true,"burn_after_ms":60000}',
            'msg_type': 'text',
            'created_at': 1,
            'is_author': 0,
            'status': 20,
          },
        ]
      : [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// 保留真实 push/pop 生命周期，用隔离页面代替依赖设备/消息服务的 ChatPage。
class _IsolatedChatNavigator extends Navigator {
  const _IsolatedChatNavigator({required super.onGenerateRoute});
  @override
  NavigatorState createState() => _IsolatedChatNavigatorState();
}

class _IsolatedChatNavigatorState extends NavigatorState {
  @override
  Future<T?> push<T extends Object?>(Route<T> route) {
    return super.push<T>(
      MaterialPageRoute<T>(
        builder: (_) => const Scaffold(body: Text('isolated chat')),
      ),
    );
  }
}

class _FilteredRemotePages implements FtsApi {
  final pages = <int>[];
  @override
  Future<MessageSearchResponse?> searchMessages({
    required String keyword,
    int page = 1,
    int size = 20,
    String type = 'all',
    int? startTime,
    int? endTime,
  }) async {
    pages.add(page);
    return page == 1
        ? MessageSearchResponse(items: [], total: 1, sourceItemCount: 20)
        : MessageSearchResponse(
            items: [
              MessageSearchResult(
                id: 'live-on-second-page',
                content: 'fixture',
                fromId: '',
                toId: '',
                type: 'C2C',
                createdAt: 1,
              ),
            ],
            total: 1,
          );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'new deadlines apply before later hydration and late results cannot revive removed rows',
    (tester) async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      NtpHelper.debugReset();
      SqliteService.setDbUnavailableForTest();
      final secondEntered = Completer<void>();
      final releaseSecond = Completer<MessageSearchResult?>();
      final nowMs = DateTimeHelper.millisecond();
      final api = _VisibilityApi(
        [_unreadMessage('first'), _unreadMessage('second')],
        refresh: (item) {
          if (item.id == 'first') {
            return Future.value(
              _unreadMessage('first', deadline: nowMs + 60000),
            );
          }
          secondEntered.complete();
          return releaseSecond.future;
        },
      );
      final container = ProviderContainer(
        overrides: [ftsApiProvider.overrideWithValue(api)],
      );
      final subscription = container.listen(messageSearchProvider, (_, _) {});
      addTearDown(() {
        if (!releaseSecond.isCompleted) releaseSecond.complete(null);
        subscription.close();
        container.dispose();
        SqliteService.setDbForTest(null);
        NtpHelper.debugReset();
      });
      final notifier = container.read(messageSearchProvider.notifier);
      for (final uid in ['100', '200']) {
        notifier.cacheContact(uid, ContactModel(peerId: uid, nickname: uid));
      }
      // 历史 Future 跨用例保留；搜索用真实异步 zone，刷新计时仍用假时钟。
      await tester.runAsync(() => notifier.performSearch(query: 'fixture'));
      final pending = notifier.refreshVisibleResults();
      await tester.pump();
      expect(secondEntered.isCompleted, isTrue);
      expect(releaseSecond.isCompleted, isFalse);
      expect(
        container
            .read(messageSearchProvider)
            .searchResults
            .first
            .expiresAtMs('100'),
        nowMs + 60000,
      );
      NtpHelper.updateOffsetFromServer(nowMs + 61000);
      await tester.pump(const Duration(seconds: 61));
      expect(
        container
            .read(messageSearchProvider)
            .searchResults
            .map((item) => item.id),
        ['second'],
      );
      expect(releaseSecond.isCompleted, isFalse);
      notifier.removeResult('second');
      releaseSecond.complete(_unreadMessage('second'));
      await pending;
      expect(container.read(messageSearchProvider).searchResults, isEmpty);
      expect(container.read(messageSearchProvider).totalResults, 0);
      expect(api.searches, 1);
    },
  );

  testWidgets(
    'Global click retains first local observation so deletion during chat cannot revive it',
    (tester) async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      SqliteService.setDbUnavailableForTest();
      final api = _VisibilityApi([_unreadMessage('click fixture')]);
      final container = ProviderContainer(
        overrides: [ftsApiProvider.overrideWithValue(api)],
      );
      addTearDown(() {
        container.dispose();
        SqliteService.setDbForTest(null);
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              // 与 run.dart 的导航器上方透明 Material 保持相同上下文。
              builder: (_, child) =>
                  Material(type: MaterialType.transparency, child: child),
              home: _IsolatedChatNavigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => const MessageSearchPage(),
                ),
              ),
            ),
          ),
        ),
      );
      final notifier = container.read(messageSearchProvider.notifier);
      for (final uid in ['100', '200']) {
        notifier.cacheContact(uid, ContactModel(peerId: uid, nickname: uid));
      }
      await tester.runAsync(() => notifier.performSearch(query: 'fixture'));
      await tester.pumpAndSettle();
      expect(find.byType(MessageSearchResultCard), findsOneWidget);
      expect(
        container
            .read(messageSearchProvider)
            .searchResults
            .single
            .localRowObserved,
        isFalse,
      );
      final db = _ObservedMessageDatabase();
      SqliteService.setDbForTest(db);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is TextHighlight && widget.text == 'click fixture',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('isolated chat'), findsOneWidget);
      expect(api.refreshed.single.localRowObserved, isFalse);
      expect(
        container
            .read(messageSearchProvider)
            .searchResults
            .single
            .localRowObserved,
        isTrue,
      );
      db.present = false;
      Navigator.of(tester.element(find.text('isolated chat'))).pop();
      await tester.pumpAndSettle();
      expect(api.refreshed.last.localRowObserved, isTrue);
      expect(container.read(messageSearchProvider).searchResults, isEmpty);
      expect(find.byType(MessageSearchResultCard), findsNothing);
      expect(api.searches, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'a filtered empty full remote page cannot hide the following live page',
    () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      SqliteService.setDbUnavailableForTest();
      final api = _FilteredRemotePages();
      final container = ProviderContainer(
        overrides: [ftsApiProvider.overrideWithValue(api)],
      );
      final subscription = container.listen(messageSearchProvider, (_, _) {});
      try {
        await container
            .read(messageSearchProvider.notifier)
            .performSearch(query: 'fixture');
        final state = container.read(messageSearchProvider);
        expect(api.pages, [1, 2]);
        expect(state.searchResults.single.id, 'live-on-second-page');
        expect(state.currentPage, 2);
        expect(state.hasMore, isFalse);
        expect(state.errorMessage, isEmpty);
      } finally {
        subscription.close();
        container.dispose();
        SqliteService.setDbForTest(null);
      }
    },
  );

  test(
    'display deadlines use one timer, preserve unread, and recheck on resume',
    () {
      fakeAsync((async) {
        int now() => 1000 + async.elapsed.inMilliseconds;
        MessageSearchResult item(String id, int? readAt) => MessageSearchResult(
          id: id,
          content: id,
          fromId: '200',
          toId: '100',
          type: 'C2C',
          createdAt: 1,
          payload: {
            'burn': true,
            'burn_after_ms': 100,
            'burn_read_at': ?readAt,
          },
        );
        var results = [
          item('first', 1100),
          item('second', 1400),
          item('unread', null),
        ];
        var callbacks = 0;
        late SearchResultExpiry expiry;
        expiry = SearchResultExpiry(() {
          callbacks++;
          results = results
              .where((item) => item.isVisibleAt(now(), '100'))
              .toList();
          expiry.schedule(results.map((item) => item.expiresAtMs('100')));
        }, nowMs: now);
        expiry.schedule(results.map((item) => item.expiresAtMs('100')));
        expect(async.nonPeriodicTimerCount, 1);
        async.elapse(const Duration(milliseconds: 199));
        expect(results, hasLength(3));
        async.elapse(const Duration(milliseconds: 1));
        expect(results.map((item) => item.id), ['second', 'unread']);
        expect(async.nonPeriodicTimerCount, 1);
        expiry.cancel();
        async.elapse(const Duration(milliseconds: 400));
        expect(callbacks, 1);
        expiry.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(results.map((item) => item.id), ['unread']);
        expect(async.nonPeriodicTimerCount, 0);
        expiry.dispose();
        expiry.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(callbacks, 2);
      });
    },
  );

  group('MessageSearchState 纯内存方法', () {
    test('MS-1 默认值正确', () {
      const s = MessageSearchState();
      expect(s.searchResults, isEmpty);
      expect(s.currentQuery, '');
      expect(s.currentPage, 1);
      expect(s.hasMore, isTrue);
      expect(s.selectedType, 'all');
      expect(s.selectedTimeRange, 'all');
      expect(s.hasActiveFilters(), isFalse);
      expect(s.conversationUk3, isNull);
    });

    test('MS-2 copyWith 选择性覆盖且原对象不变', () {
      const s = MessageSearchState(currentQuery: 'q', currentPage: 1);
      final s2 = s.copyWith(currentPage: 3, isLoading: true);
      expect(s2.currentPage, 3);
      expect(s2.isLoading, isTrue);
      expect(s2.currentQuery, 'q');
      expect(s.currentPage, 1);
    });

    test('MS-3 resetSearch 清空结果、分页与查询词', () {
      const s = MessageSearchState(
        currentQuery: 'qa-collect-59-test',
        currentPage: 4,
        totalResults: 12,
        isSearching: true,
      );
      final s2 = s.resetSearch();
      expect(s2.currentPage, 1);
      expect(s2.totalResults, 0);
      expect(s2.isSearching, isFalse);
      expect(s2.hasMore, isTrue);
      // 回归断言：清空后 currentQuery 必须归空，
      // 否则筛选 chips 残留、点筛选会用旧词重发搜索（BUG#130）。
      expect(s2.currentQuery, '');
    });

    test('MS-4 resetFilters 复位类型与时间范围', () {
      const s = MessageSearchState(
        selectedType: 'C2C',
        selectedTimeRange: 'week',
      );
      expect(s.hasActiveFilters(), isTrue);
      final s2 = s.resetFilters();
      expect(s2.selectedType, 'all');
      expect(s2.selectedTimeRange, 'all');
      expect(s2.hasActiveFilters(), isFalse);
    });

    test('MS-5 cacheContact / cacheConversation 写入可读取且不污染原对象', () {
      const s = MessageSearchState();
      final c = ContactModel(peerId: 2, nickname: 'B');
      final s2 = s.cacheContact('2', c);
      expect(s2.getCachedContact('2'), c);
      expect(s.getCachedContact('2'), isNull);
    });

    test('MS-6 getStartTimeStamp 在 startDate 指定时返回毫秒', () {
      final d = DateTime(2024, 1, 1);
      final s = MessageSearchState(startDate: d);
      expect(s.getStartTimeStamp(), d.millisecondsSinceEpoch);
      expect(s.getEndTimeStamp(), isNull);
      // all 范围且无日期 -> null
      const s2 = MessageSearchState();
      expect(s2.getStartTimeStamp(), isNull);
    });

    test('resetFilters clears custom dates without changing search scope', () {
      final state = MessageSearchState(
        selectedTimeRange: 'custom',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 2, 1),
        conversationUk3: 'C2C_100_200',
        conversationTitle: 'conversation',
      );
      final reset = state.resetFilters();
      expect(reset.startDate, isNull);
      expect(reset.endDate, isNull);
      expect(reset.hasActiveFilters(), isFalse);
      expect(reset.conversationUk3, 'C2C_100_200');
      expect(reset.conversationTitle, 'conversation');
    });

    test('copyWith can explicitly clear conversation scope', () {
      const state = MessageSearchState(
        conversationUk3: 'C2C_100_200',
        conversationTitle: 'conversation',
      );
      final reset = state.copyWith(
        conversationUk3: null,
        conversationTitle: null,
      );
      expect(reset.conversationUk3, isNull);
      expect(reset.conversationTitle, isNull);
    });
  });
}
