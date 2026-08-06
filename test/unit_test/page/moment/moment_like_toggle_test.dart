import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 2: pure helper for optimistic like-toggle math.
///
/// Both moment_feed_page and moment_detail_page need the same flip rules:
///   - `liked` is inverted
///   - `stats.like_count` is incremented when turning on, decremented when
///     turning off, and clamped to 0 so we never go negative.
///   - The input map is not mutated; a new map with a fresh `stats` child is
///     returned so the caller can do rollback by holding on to the original.
void main() {
  group('applyOptimisticLikeToggle', () {
    test('flips liked=false → true and increments like_count', () {
      final moment = <String, dynamic>{
        'id': 'm1',
        'liked': false,
        'stats': {'like_count': 3, 'comment_count': 9},
      };

      final next = applyOptimisticLikeToggle(moment);

      expect(next['liked'], isTrue);
      expect(next['stats']['like_count'], 4);
      // comment_count must survive untouched
      expect(next['stats']['comment_count'], 9);
    });

    test('flips liked=true → false and decrements like_count', () {
      final moment = <String, dynamic>{
        'id': 'm1',
        'liked': true,
        'stats': {'like_count': 5},
      };

      final next = applyOptimisticLikeToggle(moment);

      expect(next['liked'], isFalse);
      expect(next['stats']['like_count'], 4);
    });

    test('clamps like_count at 0 when unliking from 0', () {
      final moment = <String, dynamic>{
        'id': 'm1',
        'liked': true,
        'stats': {'like_count': 0},
      };

      final next = applyOptimisticLikeToggle(moment);

      expect(next['liked'], isFalse);
      expect(next['stats']['like_count'], 0);
    });

    test('does not mutate the input map or stats submap', () {
      final originalStats = <String, dynamic>{'like_count': 2};
      final moment = <String, dynamic>{
        'id': 'm1',
        'liked': false,
        'stats': originalStats,
      };

      applyOptimisticLikeToggle(moment);

      expect(moment['liked'], isFalse);
      expect(moment['stats'], same(originalStats));
      expect(originalStats['like_count'], 2);
    });

    test('treats missing stats map as empty and starts at 1', () {
      final moment = <String, dynamic>{'id': 'm1', 'liked': false};

      final next = applyOptimisticLikeToggle(moment);

      expect(next['liked'], isTrue);
      expect(next['stats'], isA<Map<String, dynamic>>());
      expect(next['stats']['like_count'], 1);
    });

    test('treats missing liked as false and turns on', () {
      final moment = <String, dynamic>{
        'id': 'm1',
        'stats': {'like_count': 7},
      };

      final next = applyOptimisticLikeToggle(moment);

      expect(next['liked'], isTrue);
      expect(next['stats']['like_count'], 8);
    });
  });
}
