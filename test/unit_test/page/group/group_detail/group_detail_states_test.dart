import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_detail/add_member_provider.dart';
import 'package:imboy/page/group/group_detail/change_info_provider.dart';
import 'package:imboy/page/group/group_detail/group_detail_provider.dart';
import 'package:imboy/page/group/group_detail/remove_member_provider.dart';
import 'package:imboy/page/group/group_list/group_list_provider.dart';

/// group_detail / group_list 各 State 纯不可变状态类契约测试（TypeB）。
///
/// 仅覆盖 copyWith 纯内存行为，不触及 Notifier 的 SQLite/API 网络方法。
void main() {
  group('AddMemberState — copyWith', () {
    test('默认构造 → 各字段为空/默认', () {
      const s = AddMemberState();
      expect(s.groupMemberList, isEmpty);
      expect(s.contactItems, isEmpty);
      expect(s.currIndexBarData, isEmpty);
      expect(s.selects, isEmpty);
      expect(s.selectsTips, '');
      expect(s.isLoading, false);
    });

    test('copyWith 不传参数 → 所有字段保持不变', () {
      const s = AddMemberState(selectsTips: '(2)', isLoading: true);
      final c = s.copyWith();
      expect(c.selectsTips, '(2)');
      expect(c.isLoading, true);
    });

    test('copyWith 单字段覆盖 → 仅该字段变化，其余不动', () {
      const s = AddMemberState(selectsTips: '(2)', isLoading: true);
      final c = s.copyWith(isLoading: false);
      expect(c.isLoading, false);
      expect(c.selectsTips, '(2)');
      expect(c.groupMemberList, isEmpty);
    });
  });

  group('ChangeInfoState — copyWith', () {
    test('默认构造 → text 空、未变更、未保存、group 为 null', () {
      const s = ChangeInfoState();
      expect(s.text, '');
      expect(s.valueChanged, false);
      expect(s.isSaving, false);
      expect(s.group, isNull);
    });

    test('copyWith 不传参数 → 所有字段保持不变', () {
      const s = ChangeInfoState(text: 'abc', valueChanged: true);
      final c = s.copyWith();
      expect(c.text, 'abc');
      expect(c.valueChanged, true);
    });

    test('copyWith 多字段覆盖 → 同步更新', () {
      const s = ChangeInfoState(text: 'abc', valueChanged: true);
      final c = s.copyWith(text: 'xyz', isSaving: true);
      expect(c.text, 'xyz');
      expect(c.isSaving, true);
      expect(c.valueChanged, true); // 未覆盖字段保留
    });
  });

  group('GroupDetailState — copyWith', () {
    test('默认构造 → 列表空/数值 0/标志 false', () {
      const s = GroupDetailState();
      expect(s.group, isNull);
      expect(s.memberList, isEmpty);
      expect(s.title, '');
      expect(s.memberCount, 0);
      expect(s.isAdmin, false);
      expect(s.role, 0);
      expect(s.isLoading, false);
    });

    test('copyWith 单字段覆盖角色信息 → 仅该字段变化', () {
      const s = GroupDetailState(memberCount: 5);
      final c = s.copyWith(isAdmin: true, role: 9);
      expect(c.isAdmin, true);
      expect(c.role, 9);
      expect(c.memberCount, 5); // 未覆盖保留
    });

    test('copyWith 更新标题与备注 → 同步更新', () {
      const s = GroupDetailState(title: 't0');
      final c = s.copyWith(title: 't1', groupRemark: 'r1');
      expect(c.title, 't1');
      expect(c.groupRemark, 'r1');
    });
  });

  group('RemoveMemberState — copyWith', () {
    test('默认构造 → 列表空、提示空、未加载', () {
      const s = RemoveMemberState();
      expect(s.groupMemberList, isEmpty);
      expect(s.selects, isEmpty);
      expect(s.selectsTips, '');
      expect(s.isLoading, false);
    });

    test('copyWith 不传参数 → 所有字段保持不变', () {
      const s = RemoveMemberState(selectsTips: '(3)', isLoading: true);
      final c = s.copyWith();
      expect(c.selectsTips, '(3)');
      expect(c.isLoading, true);
    });

    test('copyWith 单字段覆盖提示 → 仅该字段变化', () {
      const s = RemoveMemberState(selectsTips: '(3)', isLoading: true);
      final c = s.copyWith(selectsTips: '');
      expect(c.selectsTips, '');
      expect(c.isLoading, true);
    });
  });

  group('GroupListState — copyWith', () {
    test('默认构造 → page=1 size=1000 attr=all', () {
      const s = GroupListState();
      expect(s.groupList, isEmpty);
      expect(s.page, 1);
      expect(s.size, 1000);
      expect(s.attr, 'all');
      expect(s.isSearch, false);
      expect(s.isLoading, false);
    });

    test('copyWith 切换筛选属性并重置页码 → 同步更新', () {
      const s = GroupListState(page: 5);
      final c = s.copyWith(attr: 'owner', page: 1);
      expect(c.attr, 'owner');
      expect(c.page, 1);
    });

    test('copyWith 不传参数 → 所有字段保持不变', () {
      const s = GroupListState(page: 3, attr: 'join', isSearch: true);
      final c = s.copyWith();
      expect(c.page, 3);
      expect(c.attr, 'join');
      expect(c.isSearch, true);
    });
  });
}
