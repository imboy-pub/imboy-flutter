import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Feature point 10: replace magic `visibility == 3` / `visibility == 4`
/// scatter in moment_create_page with named constants and pure predicates.
/// Keeps wire-protocol ints stable (backend contract) while giving callers a
/// readable surface.
void main() {
  group('Moment visibility constants', () {
    test('wire-protocol codes are stable', () {
      expect(momentVisibilityPublic, 0);
      expect(momentVisibilityFriends, 1);
      expect(momentVisibilityPrivate, 2);
      expect(momentVisibilityAllowList, 3);
      expect(momentVisibilityDenyList, 4);
    });
  });

  group('momentVisibilityRequiresAllowUids', () {
    test('only returns true for 3 (allow list)', () {
      expect(momentVisibilityRequiresAllowUids(momentVisibilityAllowList), isTrue);
      expect(momentVisibilityRequiresAllowUids(momentVisibilityPublic), isFalse);
      expect(momentVisibilityRequiresAllowUids(momentVisibilityFriends), isFalse);
      expect(momentVisibilityRequiresAllowUids(momentVisibilityPrivate), isFalse);
      expect(momentVisibilityRequiresAllowUids(momentVisibilityDenyList), isFalse);
    });

    test('unknown visibility codes return false (defensive)', () {
      expect(momentVisibilityRequiresAllowUids(-1), isFalse);
      expect(momentVisibilityRequiresAllowUids(99), isFalse);
    });
  });

  group('momentVisibilityRequiresDenyUids', () {
    test('only returns true for 4 (deny list)', () {
      expect(momentVisibilityRequiresDenyUids(momentVisibilityDenyList), isTrue);
      expect(momentVisibilityRequiresDenyUids(momentVisibilityPublic), isFalse);
      expect(momentVisibilityRequiresDenyUids(momentVisibilityFriends), isFalse);
      expect(momentVisibilityRequiresDenyUids(momentVisibilityPrivate), isFalse);
      expect(momentVisibilityRequiresDenyUids(momentVisibilityAllowList), isFalse);
    });

    test('unknown visibility codes return false (defensive)', () {
      expect(momentVisibilityRequiresDenyUids(-1), isFalse);
      expect(momentVisibilityRequiresDenyUids(99), isFalse);
    });
  });
}
