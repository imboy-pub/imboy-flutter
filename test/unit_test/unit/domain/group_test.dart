// Group 充血实体测试（纯 domain，成员上限/角色/转让·解散不变量）。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/group_collab/domain/group.dart';
import 'package:imboy/modules/group_collab/domain/value/group_id.dart';
import 'package:imboy/modules/group_collab/domain/value/group_role.dart';

Group _group({int count = 3, bool dissolved = false}) => Group(
  id: GroupId.parse('1'),
  ownerId: '100',
  memberCount: count,
  dissolved: dissolved,
);

void main() {
  group('Group', () {
    test('fromCounts 负成员数规整为 0', () {
      final g = Group.fromCounts(
        id: GroupId.parse('1'),
        ownerId: '100',
        memberCount: -5,
      );
      expect(g.memberCount, 0);
    });

    test('成员上限 500：未满可加、满员拒绝', () {
      expect(_group(count: 499).canAddMember, isTrue);
      expect(_group(count: 499).isFull, isFalse);
      expect(_group(count: 500).isFull, isTrue);
      expect(_group(count: 500).canAddMember, isFalse);
    });

    test('已解散群不可加成员', () {
      expect(_group(count: 3, dissolved: true).canAddMember, isFalse);
    });

    test('roleOf：群主→owner，其余→member', () {
      final g = _group();
      expect(g.roleOf('100').code, GroupRole.owner);
      expect(g.roleOf('999').code, GroupRole.member);
    });

    test('转让/解散仅群主可发起', () {
      final g = _group();
      expect(g.canTransferBy('100'), isTrue);
      expect(g.canTransferBy('999'), isFalse);
      expect(g.canDissolveBy('100'), isTrue);
      expect(g.canDissolveBy('999'), isFalse);
    });

    test('已解散群不可转让/解散', () {
      final g = _group(dissolved: true);
      expect(g.canTransferBy('100'), isFalse);
      expect(g.canDissolveBy('100'), isFalse);
    });
  });
}
