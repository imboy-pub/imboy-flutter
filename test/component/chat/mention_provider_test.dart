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

  group('MentionState defaults', () {
    test('default state has empty fields + showAllMention=false', () {
      const s = MentionState();
      expect(s.candidates, isEmpty);
      expect(s.groupId, '');
      expect(s.showAllMention, false);
      expect(s.currentUserRole, 1);
      expect(s.keyword, '');
      expect(s.isLoading, false);
      expect(s.userIdToName, isEmpty);
      expect(s.currentUserId, '');
      expect(s.isAdmin, false); // role=1 不是 admin
    });
  });

  group('MentionState.isAdmin via currentUserRole', () {
    test('role=1 (member) → isAdmin=false', () {
      expect(const MentionState(currentUserRole: 1).isAdmin, false);
    });

    test('role=2 (guest) → isAdmin=false', () {
      expect(const MentionState(currentUserRole: 2).isAdmin, false);
    });

    test('role=3 (admin) → isAdmin=true', () {
      expect(const MentionState(currentUserRole: 3).isAdmin, true);
    });

    test('role=4 (owner) → isAdmin=true', () {
      expect(const MentionState(currentUserRole: 4).isAdmin, true);
    });

    test('role=5 (vice_owner) → isAdmin=true', () {
      expect(const MentionState(currentUserRole: 5).isAdmin, true);
    });

    test('role=0 (默认 / 未加载) → isAdmin=false（安全默认）', () {
      expect(const MentionState(currentUserRole: 0).isAdmin, false);
    });
  });

  group('MentionState.filteredCandidates - keyword edge cases', () {
    const alice = MentionCandidate(
      userId: 'uid_alice',
      displayName: 'Alice',
    );
    const bob = MentionCandidate(
      userId: 'uid_bob',
      displayName: 'BOB',
    );

    test('空候选 → 空结果（即使 keyword 非空）', () {
      const s = MentionState(candidates: [], keyword: 'a');
      expect(s.filteredCandidates, isEmpty);
    });

    test('keyword 大小写不敏感（"aLi" 匹配 "Alice"）', () {
      const s = MentionState(
        candidates: [alice, bob],
        keyword: 'aLi',
      );
      expect(s.filteredCandidates, [alice]);
    });

    test('keyword 大写匹配大写 displayName（"BOB" 候选）', () {
      const s = MentionState(
        candidates: [alice, bob],
        keyword: 'bo',
      );
      // "BOB".toLowerCase().contains("bo") → 匹配
      expect(s.filteredCandidates, [bob]);
    });

    test('keyword 子串匹配（"ic" 匹配 "Alice"）', () {
      const s = MentionState(
        candidates: [alice, bob],
        keyword: 'ic',
      );
      expect(s.filteredCandidates, [alice]);
    });

    test('keyword 无匹配 → 空结果', () {
      const s = MentionState(
        candidates: [alice, bob],
        keyword: 'xyz',
      );
      expect(s.filteredCandidates, isEmpty);
    });
  });

  group('MentionState.copyWith preserves unchanged fields', () {
    const initial = MentionState(
      candidates: [
        MentionCandidate(userId: 'u1', displayName: 'A'),
      ],
      groupId: 'g1',
      showAllMention: true,
      currentUserRole: 3,
      keyword: 'init',
      isLoading: true,
      userIdToName: {'u1': 'A'},
      currentUserId: 'self',
    );

    test('partial copyWith 仅改 keyword → 其他字段保留', () {
      final result = initial.copyWith(keyword: 'new');
      expect(result.keyword, 'new');
      expect(result.candidates, initial.candidates);
      expect(result.groupId, 'g1');
      expect(result.showAllMention, true);
      expect(result.currentUserRole, 3);
      expect(result.isLoading, true);
      expect(result.userIdToName, {'u1': 'A'});
      expect(result.currentUserId, 'self');
    });

    test('copyWith without args returns equal-shape state', () {
      final result = initial.copyWith();
      expect(result.keyword, 'init');
      expect(result.candidates, initial.candidates);
      expect(result.currentUserRole, 3);
    });
  });
}
