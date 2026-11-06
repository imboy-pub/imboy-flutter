import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:fake_async/fake_async.dart';
import 'package:imboy/page/search/message_search_provider.dart';
import 'package:imboy/page/search/search_result_expiry.dart';
import 'package:imboy/store/api/fts_api.dart';
import 'package:imboy/store/model/contact_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
            if (readAt != null) 'burn_read_at': readAt,
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
