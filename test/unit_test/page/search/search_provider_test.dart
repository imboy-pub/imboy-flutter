import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/search/search_provider.dart';
import 'package:imboy/store/model/contact_model.dart';

void main() {
  group('SearchDataState 纯内存方法', () {
    test('SD-1 默认值正确', () {
      const s = SearchDataState();
      expect(s.searchResults, isEmpty);
      expect(s.currentQuery, '');
      expect(s.currentPage, 1);
      expect(s.hasMore, isTrue);
      expect(s.selectedMessageType, 'all');
      expect(s.selectedTimeRange, 'all');
      expect(s.selectedSender, 'all');
      expect(s.hasActiveFilters(), isFalse);
      expect(s.hasSearchHistory(), isFalse);
    });

    test('SD-2 copyWith 选择性覆盖且不影响其他字段', () {
      const s = SearchDataState(currentQuery: 'a', currentPage: 2);
      final s2 = s.copyWith(currentPage: 5);
      expect(s2.currentPage, 5);
      expect(s2.currentQuery, 'a');
      expect(s.currentPage, 2); // 原对象不可变
    });

    test('SD-3 resetSearch 清空结果保留过滤器与历史', () {
      const s = SearchDataState(
        searchResults: [],
        currentPage: 3,
        totalResults: 9,
        searchHistory: ['x'],
        selectedMessageType: 'image',
      );
      final s2 = s.resetSearch();
      expect(s2.currentPage, 1);
      expect(s2.totalResults, 0);
      expect(s2.searchHistory, ['x']);
      expect(s2.selectedMessageType, 'image');
    });

    test('SD-4 resetFilters 复位过滤项', () {
      const s = SearchDataState(
        selectedMessageType: 'image',
        selectedTimeRange: 'week',
        selectedSender: 'u1',
      );
      expect(s.hasActiveFilters(), isTrue);
      final s2 = s.resetFilters();
      expect(s2.selectedMessageType, 'all');
      expect(s2.selectedTimeRange, 'all');
      expect(s2.selectedSender, 'all');
      expect(s2.hasActiveFilters(), isFalse);
    });

    test('SD-5 cacheContact 写入并可读取，clearContactCache 清空', () {
      const s = SearchDataState();
      final c = ContactModel(peerId: 1, nickname: 'A');
      final s2 = s.cacheContact('1', c);
      expect(s2.getCachedContact('1'), c);
      expect(s.getCachedContact('1'), isNull); // 原对象不变
      final s3 = s2.clearContactCache();
      expect(s3.getCachedContact('1'), isNull);
    });

    test('SD-6 getEffectiveQuery 去首尾空白', () {
      const s = SearchDataState(currentQuery: '  hello  ');
      expect(s.getEffectiveQuery(), 'hello');
    });
  });
}
