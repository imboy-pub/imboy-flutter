import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/announcement/announcement_permission_rules.dart';

void main() {
  group('canManageAnnouncement', () {
    // ── 有权管理的角色 ─────────────────────────────────────────
    test('admin (role=3) can manage', () {
      expect(canManageAnnouncement(3), isTrue);
    });

    test('owner (role=4) can manage', () {
      expect(canManageAnnouncement(4), isTrue);
    });

    test('vice_owner (role=5) can manage', () {
      expect(canManageAnnouncement(5), isTrue);
    });

    // ── 无权管理的角色 ─────────────────────────────────────────
    test('member (role=1) cannot manage', () {
      expect(canManageAnnouncement(1), isFalse);
    });

    test('guest (role=2) cannot manage', () {
      expect(canManageAnnouncement(2), isFalse);
    });

    // ── 边界 / 防御 ─────────────────────────────────────────────
    test('role=0 (unknown) cannot manage — safe default', () {
      expect(canManageAnnouncement(0), isFalse);
    });

    test('negative role cannot manage', () {
      expect(canManageAnnouncement(-1), isFalse);
    });

    test('role=6 (unknown future) cannot manage — whitelist prevents accidental grant', () {
      expect(canManageAnnouncement(6), isFalse);
    });
  });
}
