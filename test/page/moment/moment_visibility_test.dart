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
      expect(
        momentVisibilityRequiresAllowUids(momentVisibilityAllowList),
        isTrue,
      );
      expect(
        momentVisibilityRequiresAllowUids(momentVisibilityPublic),
        isFalse,
      );
      expect(
        momentVisibilityRequiresAllowUids(momentVisibilityFriends),
        isFalse,
      );
      expect(
        momentVisibilityRequiresAllowUids(momentVisibilityPrivate),
        isFalse,
      );
      expect(
        momentVisibilityRequiresAllowUids(momentVisibilityDenyList),
        isFalse,
      );
    });

    test('unknown visibility codes return false (defensive)', () {
      expect(momentVisibilityRequiresAllowUids(-1), isFalse);
      expect(momentVisibilityRequiresAllowUids(99), isFalse);
    });
  });

  group('momentVisibilityRequiresDenyUids', () {
    test('only returns true for 4 (deny list)', () {
      expect(
        momentVisibilityRequiresDenyUids(momentVisibilityDenyList),
        isTrue,
      );
      expect(momentVisibilityRequiresDenyUids(momentVisibilityPublic), isFalse);
      expect(
        momentVisibilityRequiresDenyUids(momentVisibilityFriends),
        isFalse,
      );
      expect(
        momentVisibilityRequiresDenyUids(momentVisibilityPrivate),
        isFalse,
      );
      expect(
        momentVisibilityRequiresDenyUids(momentVisibilityAllowList),
        isFalse,
      );
    });

    test('unknown visibility codes return false (defensive)', () {
      expect(momentVisibilityRequiresDenyUids(-1), isFalse);
      expect(momentVisibilityRequiresDenyUids(99), isFalse);
    });
  });

  group('momentVisibilityNeedsFriendList', () {
    test('simple no-list visibilities do NOT need the friend picker', () {
      // 公开/仅好友/仅自己：发布页原地 ActionSheet 选中即定，不跳名单页。
      expect(momentVisibilityNeedsFriendList(momentVisibilityPublic), isFalse);
      expect(momentVisibilityNeedsFriendList(momentVisibilityFriends), isFalse);
      expect(momentVisibilityNeedsFriendList(momentVisibilityPrivate), isFalse);
    });

    test('list visibilities DO need the friend picker', () {
      // 部分可见/不给谁看：必须跳好友名单页做多选。
      expect(
        momentVisibilityNeedsFriendList(momentVisibilityAllowList),
        isTrue,
      );
      expect(momentVisibilityNeedsFriendList(momentVisibilityDenyList), isTrue);
    });

    test('equals the OR of the allow/deny list predicates', () {
      for (final v in [0, 1, 2, 3, 4, -1, 99]) {
        expect(
          momentVisibilityNeedsFriendList(v),
          momentVisibilityRequiresAllowUids(v) ||
              momentVisibilityRequiresDenyUids(v),
        );
      }
    });

    test('unknown visibility codes do not need the friend picker', () {
      expect(momentVisibilityNeedsFriendList(-1), isFalse);
      expect(momentVisibilityNeedsFriendList(99), isFalse);
    });
  });
}
