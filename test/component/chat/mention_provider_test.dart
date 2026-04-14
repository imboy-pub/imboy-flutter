/// Tests for MentionState / MentionNotifier
///
/// Covers:
/// - C6: `@自己禁用` — current user must not appear in filteredCandidates
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/mention_model.dart';

void main() {
  group('MentionState.filteredCandidates — exclude current user (C6)', () {
    const self = MentionCandidate(
      userId: 'uid_self',
      displayName: 'Me',
      role: 1,
    );
    const alice = MentionCandidate(
      userId: 'uid_alice',
      displayName: 'Alice',
      role: 1,
    );
    const bob = MentionCandidate(
      userId: 'uid_bob',
      displayName: 'Bob',
      role: 3,
    );

    test('returns all candidates when currentUserId is empty', () {
      const state = MentionState(
        candidates: [self, alice, bob],
      );

      expect(state.filteredCandidates, [self, alice, bob]);
    });

    test('excludes current user when currentUserId is set', () {
      const state = MentionState(
        candidates: [self, alice, bob],
        currentUserId: 'uid_self',
      );

      expect(state.filteredCandidates, [alice, bob]);
    });

    test('excludes current user AND applies keyword filter', () {
      const state = MentionState(
        candidates: [self, alice, bob],
        currentUserId: 'uid_self',
        keyword: 'al',
      );

      expect(state.filteredCandidates, [alice]);
    });

    test('currentUserId not in candidate list does not error', () {
      const state = MentionState(
        candidates: [alice, bob],
        currentUserId: 'uid_ghost',
      );

      expect(state.filteredCandidates, [alice, bob]);
    });

    test('copyWith carries currentUserId through', () {
      const before = MentionState(currentUserId: 'uid_self');
      final after = before.copyWith(keyword: 'x');
      expect(after.currentUserId, 'uid_self');
    });
  });
}
