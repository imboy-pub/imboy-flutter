import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 5: when the user adds or deletes a comment locally, the
/// moment's `stats.comment_count` must shift with the list so the number in
/// the header matches what's on screen. Without this helper the count comes
/// only from the network and drifts until the next refresh.
void main() {
  group('applyCommentCountDelta', () {
    test('increments comment_count by +1', () {
      final moment = <String, dynamic>{
        'id': 'm1',
        'stats': {'comment_count': 3, 'like_count': 10},
      };

      final next = applyCommentCountDelta(moment, 1);

      expect(next['stats']['comment_count'], 4);
      // like_count must survive untouched
      expect(next['stats']['like_count'], 10);
    });

    test('decrements comment_count by -1', () {
      final moment = <String, dynamic>{
        'id': 'm1',
        'stats': {'comment_count': 3},
      };

      final next = applyCommentCountDelta(moment, -1);

      expect(next['stats']['comment_count'], 2);
    });

    test('clamps at 0 when decrementing from 0', () {
      final moment = <String, dynamic>{
        'id': 'm1',
        'stats': {'comment_count': 0},
      };

      final next = applyCommentCountDelta(moment, -1);

      expect(next['stats']['comment_count'], 0);
    });

    test('clamps at 0 when delta would go negative', () {
      final moment = <String, dynamic>{
        'id': 'm1',
        'stats': {'comment_count': 2},
      };

      final next = applyCommentCountDelta(moment, -5);

      expect(next['stats']['comment_count'], 0);
    });

    test('does not mutate the input map or stats submap', () {
      final originalStats = <String, dynamic>{'comment_count': 2};
      final moment = <String, dynamic>{'id': 'm1', 'stats': originalStats};

      applyCommentCountDelta(moment, 1);

      expect(moment['stats'], same(originalStats));
      expect(originalStats['comment_count'], 2);
    });

    test('treats missing stats as empty and starts from 0', () {
      final moment = <String, dynamic>{'id': 'm1'};

      final next = applyCommentCountDelta(moment, 1);

      expect(next['stats'], isA<Map<String, dynamic>>());
      expect(next['stats']['comment_count'], 1);
    });

    test('zero delta returns an equivalent map', () {
      final moment = <String, dynamic>{
        'id': 'm1',
        'stats': {'comment_count': 5},
      };

      final next = applyCommentCountDelta(moment, 0);

      expect(next['stats']['comment_count'], 5);
    });
  });
}
