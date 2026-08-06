// BUG-11 修复测试：群成员禁言状态的不可变更新。
//
// 钉死契约：
// - applyMemberMuteUpdate 返回新列表，不修改入参列表与原 Model 实例
// - 禁言：匹配成员 muteUntilMs 被更新
// - 解禁：muteUntilMs 传 null → 新实例 muteUntilMs == null
// - 无匹配 userId：返回等价新列表，不抛异常
// - GroupMemberModel.copyWith 的 clearMuteUntil 语义正确
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/page/group/group_member/group_member_mute_util.dart';

GroupMemberModel _member(int userId, {int? muteUntilMs}) => GroupMemberModel(
  id: userId,
  groupId: 100,
  userId: userId,
  nickname: 'u$userId',
  avatar: '',
  sign: '',
  account: '',
  alias: '',
  createdAt: 0,
  muteUntilMs: muteUntilMs,
);

void main() {
  group('GroupMemberModel.copyWith', () {
    test('保留未指定字段，更新指定字段', () {
      final m = _member(1, muteUntilMs: null);
      final m2 = m.copyWith(muteUntilMs: 9999, nickname: 'new');
      expect(m2.muteUntilMs, 9999);
      expect(m2.nickname, 'new');
      expect(m2.userId, 1);
      // 原实例不变
      expect(m.muteUntilMs, isNull);
      expect(m.nickname, 'u1');
    });

    test('clearMuteUntil=true 显式置空 muteUntilMs', () {
      final m = _member(1, muteUntilMs: 9999);
      final m2 = m.copyWith(clearMuteUntil: true);
      expect(m2.muteUntilMs, isNull);
      expect(m.muteUntilMs, 9999); // 原实例不变
    });

    test('不传 muteUntilMs 时保留原值（不被误置空）', () {
      final m = _member(1, muteUntilMs: 8888);
      final m2 = m.copyWith(nickname: 'x');
      expect(m2.muteUntilMs, 8888);
    });
  });

  group('applyMemberMuteUpdate', () {
    test('禁言：更新匹配成员 muteUntilMs，返回新列表', () {
      final list = [_member(1), _member(2)];
      final result = applyMemberMuteUpdate(list, '2', 123456);

      expect(result[1].muteUntilMs, 123456);
      expect(result[0].muteUntilMs, isNull);
      // 不可变：返回新列表实例
      expect(identical(result, list), isFalse);
      // 不可变：原列表中的实例未被原地修改
      expect(list[1].muteUntilMs, isNull);
    });

    test('解禁：muteUntilMs 传 null → 匹配成员置空', () {
      final list = [_member(1, muteUntilMs: 999), _member(2, muteUntilMs: 999)];
      final result = applyMemberMuteUpdate(list, '1', null);

      expect(result[0].muteUntilMs, isNull);
      expect(result[1].muteUntilMs, 999);
      // 原实例不变
      expect(list[0].muteUntilMs, 999);
    });

    test('无匹配 userId：返回等价新列表，不抛异常', () {
      final list = [_member(1), _member(2)];
      final result = applyMemberMuteUpdate(list, '999', 123);

      expect(result.length, 2);
      expect(result[0].muteUntilMs, isNull);
      expect(result[1].muteUntilMs, isNull);
      expect(identical(result, list), isFalse);
    });

    test('匹配成员被替换为新实例（非同一引用）', () {
      final list = [_member(1)];
      final result = applyMemberMuteUpdate(list, '1', 555);
      expect(identical(result[0], list[0]), isFalse);
    });

    test('空列表安全', () {
      final result = applyMemberMuteUpdate(<GroupMemberModel>[], '1', 1);
      expect(result, isEmpty);
    });
  });
}
