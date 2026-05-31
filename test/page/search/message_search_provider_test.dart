import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/search/message_search_provider.dart';
import 'package:imboy/store/model/contact_model.dart';

void main() {
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

    test('MS-3 resetSearch 清空结果与分页', () {
      const s = MessageSearchState(
        currentPage: 4,
        totalResults: 12,
        isSearching: true,
      );
      final s2 = s.resetSearch();
      expect(s2.currentPage, 1);
      expect(s2.totalResults, 0);
      expect(s2.isSearching, isFalse);
      expect(s2.hasMore, isTrue);
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
  });
}
