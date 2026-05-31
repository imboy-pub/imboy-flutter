import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/denylist/denylist_provider.dart';

/// DenylistState 纯内存单测（直接 new，不依赖 SQLite/单例）。
void main() {
  group('DenylistState defaults', () {
    test(
      'default constructor yields empty items, empty index, not loading',
      () {
        const state = DenylistState();
        expect(state.items, isEmpty);
        expect(state.currIndexBarData, isEmpty);
        expect(state.isLoading, isFalse);
      },
    );
  });

  group('DenylistState copyWith', () {
    const base = DenylistState();

    test('copyWith with no args keeps fields unchanged', () {
      final next = base.copyWith();
      expect(next.items, isEmpty);
      expect(next.currIndexBarData, isEmpty);
      expect(next.isLoading, isFalse);
    });

    test('copyWith updates isLoading only', () {
      final next = base.copyWith(isLoading: true);
      expect(next.isLoading, isTrue);
      expect(next.items, isEmpty);
    });

    test('copyWith updates currIndexBarData only', () {
      final next = base.copyWith(currIndexBarData: {'A', 'B', '#'});
      expect(next.currIndexBarData, {'A', 'B', '#'});
      expect(next.isLoading, isFalse);
      expect(next.items, isEmpty);
    });
  });
}
