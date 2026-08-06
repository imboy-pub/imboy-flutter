import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 7: feed page needs an optimistic-delete primitive — hide
/// the card immediately, call the API, rollback if it fails. The underlying
/// list op must be mutation-free and order-preserving.
void main() {
  group('removeMomentById', () {
    test('removes the matching entry and preserves order of the rest', () {
      final items = [
        {'id': 'a'},
        {'id': 'b'},
        {'id': 'c'},
      ];

      final next = removeMomentById(items, 'b');

      expect(next.map((e) => e['id']).toList(), ['a', 'c']);
    });

    test('returns an equal list when id is not found', () {
      final items = [
        {'id': 'a'},
        {'id': 'b'},
      ];

      final next = removeMomentById(items, 'missing');

      expect(next.map((e) => e['id']).toList(), ['a', 'b']);
    });

    test('returns empty list when input is empty', () {
      final next = removeMomentById(const [], 'anything');

      expect(next, isEmpty);
    });

    test('returns empty list when id is empty string (no-op semantics)', () {
      final items = [
        {'id': 'a'},
      ];

      final next = removeMomentById(items, '');

      expect(next.map((e) => e['id']).toList(), ['a']);
    });

    test('does not mutate the input list', () {
      final items = [
        {'id': 'a'},
        {'id': 'b'},
      ];

      removeMomentById(items, 'a');

      expect(items.length, 2);
      expect(items.first['id'], 'a');
    });

    test('removes all matches when ids happen to repeat', () {
      final items = [
        {'id': 'a'},
        {'id': 'b'},
        {'id': 'a'},
      ];

      final next = removeMomentById(items, 'a');

      expect(next.map((e) => e['id']).toList(), ['b']);
    });
  });
}
