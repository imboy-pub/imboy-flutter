/// Tests for MentionRanking (C2 Layer A — pure sort function).
///
/// Goal: given a member list and a per-user send-count map, return a new list
/// sorted by frequency desc, with stable tiebreak (input order preserved),
/// and with the @所有人 candidate always pinned to the top.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/mention_model.dart';
import 'package:imboy/component/chat/mention_ranking.dart';

void main() {
  // Fixtures
  const alice = MentionCandidate(
    userId: 'uid_alice',
    displayName: 'Alice',
    role: 1,
  );
  const bob = MentionCandidate(
    userId: 'uid_bob',
    displayName: 'Bob',
    role: 1,
  );
  const carol = MentionCandidate(
    userId: 'uid_carol',
    displayName: 'Carol',
    role: 3, // admin
  );
  final allMention = MentionCandidate.all();

  List<String> ids(List<MentionCandidate> list) =>
      list.map((c) => c.userId).toList();

  group('MentionRanking.sortByFrequency — base contract', () {
    test('empty members returns empty list', () {
      final out = MentionRanking.sortByFrequency(const [], const {});
      expect(out, isEmpty);
    });

    test('empty countMap preserves input order', () {
      final out =
          MentionRanking.sortByFrequency([alice, bob, carol], const {});
      expect(ids(out), ['uid_alice', 'uid_bob', 'uid_carol']);
    });

    test('all zero counts preserves input order', () {
      final out = MentionRanking.sortByFrequency(
        [alice, bob, carol],
        {'uid_alice': 0, 'uid_bob': 0, 'uid_carol': 0},
      );
      expect(ids(out), ['uid_alice', 'uid_bob', 'uid_carol']);
    });
  });

  group('MentionRanking.sortByFrequency — frequency ordering', () {
    test('single highest is placed first', () {
      final out = MentionRanking.sortByFrequency(
        [alice, bob, carol],
        {'uid_bob': 10, 'uid_alice': 2, 'uid_carol': 5},
      );
      expect(ids(out), ['uid_bob', 'uid_carol', 'uid_alice']);
    });

    test('ties preserve input order (stable sort)', () {
      final out = MentionRanking.sortByFrequency(
        [alice, bob, carol],
        {'uid_alice': 5, 'uid_bob': 5, 'uid_carol': 5},
      );
      expect(ids(out), ['uid_alice', 'uid_bob', 'uid_carol'],
          reason: 'equal counts must keep the original relative order');
    });

    test('member missing in countMap is treated as 0', () {
      // Alice=10, Bob=missing (=0), Carol=5 → Alice, Carol, Bob
      final out = MentionRanking.sortByFrequency(
        [alice, bob, carol],
        {'uid_alice': 10, 'uid_carol': 5},
      );
      expect(ids(out), ['uid_alice', 'uid_carol', 'uid_bob']);
    });

    test('countMap entries for non-members are ignored (no crash)', () {
      final out = MentionRanking.sortByFrequency(
        [alice, bob],
        {'uid_alice': 3, 'uid_bob': 1, 'uid_ghost': 99},
      );
      expect(ids(out), ['uid_alice', 'uid_bob']);
      expect(out.length, 2, reason: 'ghost must NOT appear in output');
    });
  });

  group('MentionRanking.sortByFrequency — @所有人 pinning (D14)', () {
    test('all-mention candidate is always first, regardless of count', () {
      final out = MentionRanking.sortByFrequency(
        [alice, allMention, bob],
        {'uid_alice': 100, 'uid_bob': 1},
      );
      expect(out.first.isAllMention, isTrue);
      expect(ids(out).sublist(1), ['uid_alice', 'uid_bob']);
    });

    test('all-mention candidate does NOT participate in frequency compare', () {
      final out = MentionRanking.sortByFrequency(
        [bob, allMention, alice],
        {'uid_alice': 10, 'uid_bob': 3},
      );
      expect(out.first.isAllMention, isTrue);
      // The rest sorted by frequency desc
      expect(ids(out).sublist(1), ['uid_alice', 'uid_bob']);
    });

    test('no all-mention in input: output has no all-mention', () {
      final out = MentionRanking.sortByFrequency(
        [alice, bob],
        {'uid_alice': 1, 'uid_bob': 5},
      );
      expect(out.any((c) => c.isAllMention), isFalse);
    });
  });

  group('MentionRanking.sortByFrequency — purity guarantees', () {
    test('does not mutate input members list', () {
      final input = [alice, bob, carol];
      final snapshot = List<MentionCandidate>.from(input);
      MentionRanking.sortByFrequency(input, {'uid_bob': 10});
      expect(input, snapshot,
          reason: 'input list must not be mutated in place');
    });

    test('returns a new list (not the same reference) when ordering changes',
        () {
      final input = [alice, bob];
      final out = MentionRanking.sortByFrequency(input, {'uid_bob': 10});
      expect(identical(input, out), isFalse);
    });

    test('returns a new list even when ordering does NOT change', () {
      // Even if frequency map produces same order as input, output should
      // be a fresh list (so callers can safely mutate the result).
      final input = [alice, bob];
      final out = MentionRanking.sortByFrequency(
        input,
        {'uid_alice': 10, 'uid_bob': 5},
      );
      expect(ids(out), ['uid_alice', 'uid_bob']);
      expect(identical(input, out), isFalse,
          reason: 'caller must always receive an independently mutable list');
    });

    test('mutating returned list does not affect input list', () {
      final input = [alice, bob, carol];
      final out = MentionRanking.sortByFrequency(input, const {});
      // Sanity: out should reflect input order (no counts).
      expect(ids(out), ['uid_alice', 'uid_bob', 'uid_carol']);
      // Mutate the returned list — input must remain untouched.
      out.removeAt(0);
      expect(ids(input), ['uid_alice', 'uid_bob', 'uid_carol']);
    });
  });

  group('MentionRanking.sortByFrequency — edge cases', () {
    test('single member input → returned as-is', () {
      final out = MentionRanking.sortByFrequency([alice], {'uid_alice': 5});
      expect(ids(out), ['uid_alice']);
      expect(out.length, 1);
    });

    test('only @所有人 in input → output is just that one candidate', () {
      final out = MentionRanking.sortByFrequency([allMention], const {});
      expect(out.length, 1);
      expect(out.single.isAllMention, isTrue);
    });

    test('multiple @所有人 entries are all pinned at top in input order', () {
      // Defensive: if a future caller mistakenly inserts duplicate all-mention
      // candidates, all of them stay at the top in input order; no dedup logic
      // here (that's a separate concern).
      final allA = MentionCandidate.all();
      final allB = MentionCandidate.all();
      final out = MentionRanking.sortByFrequency(
        [alice, allA, bob, allB, carol],
        {'uid_alice': 1, 'uid_bob': 9, 'uid_carol': 5},
      );
      expect(out.length, 5);
      expect(out[0].isAllMention, isTrue);
      expect(out[1].isAllMention, isTrue);
      // Tail sorted by count desc: bob(9), carol(5), alice(1)
      expect(ids(out).sublist(2), ['uid_bob', 'uid_carol', 'uid_alice']);
    });

    test('multi-tier ties keep stable order within each tier', () {
      // Two tiers: count=5 for [alice, bob, carol]; count=1 for [d, e].
      // Result must keep original tier-internal order.
      const d = MentionCandidate(
        userId: 'uid_d',
        displayName: 'D',
        role: 1,
      );
      const e = MentionCandidate(
        userId: 'uid_e',
        displayName: 'E',
        role: 1,
      );
      final out = MentionRanking.sortByFrequency(
        [alice, d, bob, e, carol],
        {
          'uid_alice': 5,
          'uid_bob': 5,
          'uid_carol': 5,
          'uid_d': 1,
          'uid_e': 1,
        },
      );
      expect(
        ids(out),
        ['uid_alice', 'uid_bob', 'uid_carol', 'uid_d', 'uid_e'],
        reason: 'within each frequency tier the original order is preserved',
      );
    });

    test('negative counts sort below zero/positive counts (numeric desc)', () {
      // Defensive: contract is "by count desc"; negative numbers should fall
      // to the bottom — they are not specially clamped to 0.
      final out = MentionRanking.sortByFrequency(
        [alice, bob, carol],
        {'uid_alice': -5, 'uid_bob': 0, 'uid_carol': 3},
      );
      expect(ids(out), ['uid_carol', 'uid_bob', 'uid_alice']);
    });
  });
}
