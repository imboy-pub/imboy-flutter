import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 4: pure helper for appending a comment page with dedupe.
///
/// Detail page needs to paginate comments via cursor. Network can double-fetch
/// on fast scrolls or eventbus refreshes, so we must:
///   - Append new items in order
///   - Drop duplicates by `id` (first-seen wins — preserves existing list order)
///   - Ignore malformed items (missing id)
///   - Leave the input lists untouched
void main() {
  group('appendCommentsPage', () {
    test('appends new items to existing list', () {
      final existing = [
        {'id': 'c1', 'content': 'A'},
        {'id': 'c2', 'content': 'B'},
      ];
      final next = [
        {'id': 'c3', 'content': 'C'},
        {'id': 'c4', 'content': 'D'},
      ];

      final merged = appendCommentsPage(existing, next);

      expect(merged.map((e) => e['id']).toList(), ['c1', 'c2', 'c3', 'c4']);
    });

    test('dedupes by id — existing item wins over new item with same id', () {
      final existing = [
        {'id': 'c1', 'content': 'original'},
      ];
      final next = [
        {'id': 'c1', 'content': 'duplicate-ignored'},
        {'id': 'c2', 'content': 'new'},
      ];

      final merged = appendCommentsPage(existing, next);

      expect(merged.length, 2);
      expect(merged[0]['content'], 'original');
      expect(merged[1]['id'], 'c2');
    });

    test('dedupes within the incoming page itself', () {
      final next = [
        {'id': 'c1', 'content': 'first'},
        {'id': 'c1', 'content': 'second'},
        {'id': 'c2', 'content': 'other'},
      ];

      final merged = appendCommentsPage(const [], next);

      expect(merged.length, 2);
      expect(merged[0]['content'], 'first');
      expect(merged[1]['id'], 'c2');
    });

    test('drops items with missing or empty id', () {
      final next = [
        {'id': 'c1'},
        {'content': 'no id'},
        {'id': '', 'content': 'empty id'},
        {'id': 'c2'},
      ];

      final merged = appendCommentsPage(const [], next);

      expect(merged.map((e) => e['id']).toList(), ['c1', 'c2']);
    });

    test('does not mutate existing or next lists', () {
      final existing = [
        {'id': 'c1'},
      ];
      final next = [
        {'id': 'c2'},
      ];

      appendCommentsPage(existing, next);

      expect(existing.length, 1);
      expect(next.length, 1);
    });

    test('returns existing list unchanged when next is empty', () {
      final existing = [
        {'id': 'c1'},
        {'id': 'c2'},
      ];

      final merged = appendCommentsPage(existing, const []);

      expect(merged.map((e) => e['id']).toList(), ['c1', 'c2']);
    });
  });
}
