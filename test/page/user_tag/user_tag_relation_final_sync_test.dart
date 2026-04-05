import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_provider.dart';

void main() {
  group('UserTagRelation final sync helpers', () {
    test('diffs original and final tag sets', () {
      final plan = buildTagSyncPlan(
        originalTags: const ['A', 'B'],
        nextTags: const ['A', 'C'],
      );

      expect(plan.originalTags, equals(const ['A', 'B']));
      expect(plan.finalTags, equals(const ['A', 'C']));
      expect(plan.toAdd, equals(const ['C']));
      expect(plan.toRemove, equals(const ['B']));
      expect(plan.hasChanges, isTrue);
    });

    test('clearing tags removes every existing relation', () {
      final plan = buildTagSyncPlan(
        originalTags: const ['A', 'B'],
        nextTags: const <String>[],
      );

      expect(plan.finalTags, isEmpty);
      expect(plan.toAdd, isEmpty);
      expect(plan.toRemove, equals(const ['A', 'B']));
      expect(plan.hasChanges, isTrue);
    });

    test('ignores duplicate and reordered tags without producing changes', () {
      final plan = buildTagSyncPlan(
        originalTags: const ['A', 'B'],
        nextTags: const [' B ', 'A', 'A'],
      );

      expect(plan.finalTags, equals(const ['B', 'A']));
      expect(plan.toAdd, isEmpty);
      expect(plan.toRemove, isEmpty);
      expect(plan.hasChanges, isFalse);
    });

    test('builds tag id and usage maps from api payload items', () {
      final items = <Map<String, dynamic>>[
        {'id': 11, 'name': 'work', 'usage_count': 3},
        {'tag_id': 22, 'name': 'family'},
        {'id': 11, 'name': 'work', 'usage_count': 2},
        {'id': 33, 'name': ''},
      ];

      expect(buildTagNameList(items), equals(const ['work', 'family']));
      expect(
        buildTagIdByNameMap(items),
        equals(const {'work': 11, 'family': 22}),
      );
      expect(
        buildTagUsageCountMap(items),
        equals(const {'work': 5, 'family': 1}),
      );
    });
  });
}
