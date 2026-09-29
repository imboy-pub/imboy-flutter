import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_role_rules.dart';

void main() {
  group('isGroupAdmin', () {
    // ── 有管理权限的角色 ────────────────────────────────────────
    test('admin (role=3) is admin', () {
      expect(isGroupAdmin(3), isTrue);
    });

    test('owner (role=4) is admin', () {
      expect(isGroupAdmin(4), isTrue);
    });

    test('vice_owner (role=5) is admin', () {
      expect(isGroupAdmin(5), isTrue);
    });

    // ── 无管理权限的角色 ────────────────────────────────────────
    test('member (role=1) is not admin', () {
      expect(isGroupAdmin(1), isFalse);
    });

    test('guest (role=2) is not admin', () {
      expect(isGroupAdmin(2), isFalse);
    });

    // ── 防御性边界 ──────────────────────────────────────────────
    test('role=0 (unknown) is not admin — safe default', () {
      expect(isGroupAdmin(0), isFalse);
    });

    test('negative role is not admin', () {
      expect(isGroupAdmin(-1), isFalse);
    });

    test('role=6 (future unknown) is not admin — whitelist prevents accidental grant', () {
      expect(isGroupAdmin(6), isFalse);
    });
  });

  group('isGroupOwner', () {
    test('owner (role=4) is owner', () {
      expect(isGroupOwner(4), isTrue);
    });

    test('vice_owner (role=5) is not owner', () {
      expect(isGroupOwner(5), isFalse);
    });

    test('admin (role=3) is not owner', () {
      expect(isGroupOwner(3), isFalse);
    });

    test('member (role=1) is not owner', () {
      expect(isGroupOwner(1), isFalse);
    });

    test('role=0 is not owner', () {
      expect(isGroupOwner(0), isFalse);
    });
  });
}
