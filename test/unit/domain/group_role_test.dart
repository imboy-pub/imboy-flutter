// GroupRole 值对象测试（纯 domain，权限矩阵对齐后端 group_role.hrl）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/group_collab/domain/value/group_role.dart';

void main() {
  group('GroupRole', () {
    test('parse 合法角色码 1..5', () {
      expect(GroupRole.parse(1).code, GroupRole.member);
      expect(GroupRole.parse(5).code, GroupRole.viceOwner);
    });

    test('parse 越界抛 FormatException', () {
      expect(() => GroupRole.parse(0), throwsFormatException);
      expect(() => GroupRole.parse(6), throwsFormatException);
    });

    test('群主(4)：全部权限', () {
      const r = GroupRole(GroupRole.owner);
      expect(r.isOwner, isTrue);
      expect(r.isSeniorAdmin, isTrue);
      expect(r.isAdmin, isTrue);
      expect(r.canKick, isTrue);
      expect(r.canMute, isTrue);
      expect(r.canDissolve, isTrue);
      expect(r.canTransfer, isTrue);
    });

    test('副群主(5)：管理权限但不可解散/转让', () {
      const r = GroupRole(GroupRole.viceOwner);
      expect(r.isOwner, isFalse);
      expect(r.isSeniorAdmin, isTrue);
      expect(r.isAdmin, isTrue);
      expect(r.canKick, isTrue);
      expect(r.canMute, isTrue);
      expect(r.canDissolve, isFalse);
      expect(r.canTransfer, isFalse);
    });

    test('管理员(3)：管理权限但非高级管理员', () {
      const r = GroupRole(GroupRole.admin);
      expect(r.isAdmin, isTrue);
      expect(r.isSeniorAdmin, isFalse);
      expect(r.canKick, isTrue);
      expect(r.canMute, isTrue);
      expect(r.canDissolve, isFalse);
    });

    test('嘉宾(2)/普通成员(1)：无管理权限', () {
      for (final code in [GroupRole.guest, GroupRole.member]) {
        final r = GroupRole(code);
        expect(r.isAdmin, isFalse);
        expect(r.canKick, isFalse);
        expect(r.canMute, isFalse);
        expect(r.canDissolve, isFalse);
        expect(r.canTransfer, isFalse);
      }
    });
  });
}
