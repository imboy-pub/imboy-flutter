import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/search/web_search_state.dart';

void main() {
  group('WebSearchState 纯内存', () {
    test('WS-1 默认值正确', () {
      const s = WebSearchState();
      expect(s.isLoading, isFalse);
      expect(s.query, '');
      expect(s.results, isEmpty);
      expect(s.recentSearches, isEmpty);
      expect(s.error, isNull);
      expect(s.showRecent, isTrue);
    });

    test('WS-2 copyWith 选择性覆盖且原对象不变', () {
      const s = WebSearchState(query: 'a');
      final s2 = s.copyWith(isLoading: true, query: 'b');
      expect(s2.isLoading, isTrue);
      expect(s2.query, 'b');
      expect(s.query, 'a');
      expect(s.isLoading, isFalse);
    });

    test('WS-3 copyWith 写入 results 与 recentSearches', () {
      const item = SearchItem(
        type: SearchItemType.contact,
        id: '1',
        title: 'Alice',
      );
      const s = WebSearchState();
      final s2 = s.copyWith(
        results: const [item],
        recentSearches: const ['alice'],
        showRecent: false,
      );
      expect(s2.results.single.title, 'Alice');
      expect(s2.recentSearches, ['alice']);
      expect(s2.showRecent, isFalse);
      // 原对象不可变
      expect(s.results, isEmpty);
    });
  });
}
