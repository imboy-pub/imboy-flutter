import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/user_collect/user_collect_state.dart';

void main() {
  group('UserCollectState defaults', () {
    test('default values are sane', () {
      final s = UserCollectState();
      expect(s.kindActive, isFalse);
      expect(s.items, isEmpty);
      expect(s.page, 1);
      expect(s.size, 10);
      expect(s.kind, 'all');
      expect(s.recentUse, 'recent_use');
      expect(s.kwd, '');
      expect(s.isLoading, isFalse);
      expect(s.isRefreshing, isFalse);
      expect(s.hasMore, isTrue);
      expect(s.loadFailed, isFalse);
      expect(s.removingIds, isEmpty);
    });
  });

  group('UserCollectState.loadFailed', () {
    test('copyWith 可置 loadFailed 且只改该字段', () {
      final base = UserCollectState();
      final next = base.copyWith(loadFailed: true);
      expect(next.loadFailed, isTrue);
      expect(base.loadFailed, isFalse);
      // 其余字段不受影响
      expect(next.hasMore, isTrue);
      expect(next.kind, 'all');
    });

    test('copyWith 不传 loadFailed 时保留原值', () {
      final base = UserCollectState()..loadFailed = true;
      final next = base.copyWith(hasMore: false);
      expect(next.loadFailed, isTrue);
    });
  });

  group('UserCollectState.copyWith', () {
    test('overrides only provided fields, preserves the rest', () {
      final base = UserCollectState()
        ..kind = '2'
        ..page = 3;
      final next = base.copyWith(isLoading: true, page: 5);
      expect(next.isLoading, isTrue);
      expect(next.page, 5);
      // unmodified preserved
      expect(next.kind, '2');
      expect(next.size, 10);
      expect(next.hasMore, isTrue);
    });

    test('null arguments fall back to existing values', () {
      final base = UserCollectState()
        ..kwd = 'hello'
        ..kindActive = true
        ..hasMore = false;
      final next = base.copyWith();
      expect(next.kwd, 'hello');
      expect(next.kindActive, isTrue);
      expect(next.hasMore, isFalse);
    });

    test('returns a new instance (immutability)', () {
      final base = UserCollectState();
      final next = base.copyWith(kind: '3');
      expect(identical(base, next), isFalse);
      expect(base.kind, 'all');
      expect(next.kind, '3');
    });

    test('removingIds set can be replaced', () {
      final base = UserCollectState();
      final next = base.copyWith(removingIds: {'a', 'b'});
      expect(next.removingIds, containsAll(<String>['a', 'b']));
      expect(base.removingIds, isEmpty);
    });
  });
}
