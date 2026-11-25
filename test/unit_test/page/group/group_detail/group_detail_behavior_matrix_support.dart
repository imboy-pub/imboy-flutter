// 群详情行为矩阵共享 fixture（拆分自 group_detail_behavior_matrix_test.dart，
// ratchet <800 行约束）：固定状态 Notifier 与角色迁移 Notifier。
// 本文件不含用例。

import 'package:imboy/page/group/group_detail/group_detail_provider.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/people_model.dart';

class FixedStateMatrixNotifier extends GroupDetailNotifier {
  FixedStateMatrixNotifier(this.fixed);
  final GroupDetailState fixed;

  @override
  GroupDetailState build() => fixed;

  @override
  void setLoading(bool value) {}
  @override
  void setTitle(String title) {}
  @override
  void setMemberCount(int count) {}
  @override
  void setRoleInfo(int role, bool isAdmin) {}
  @override
  void setMemberList(List<PeopleModel> list) {}
  @override
  void setMyGroupAlias(String? alias) {}
  @override
  void setGroupRemark(String? remark) {}
  @override
  void setGroup(GroupModel group) {}
  @override
  void addMember(PeopleModel member) {}
  @override
  void removeMember(String userId) {}
}

/// UX-02:LOCAL:01：仅放行 role 迁移的状态注入。其余 setter 与
/// [FixedStateMatrixNotifier] 同款 no-op（防 initData 异步回写污染注入态、
/// 防 setLoading 翻转把页面钉在加载态）；setRoleInfo 走真实 copyWith，
/// 用「撤权/授权」状态迁移驱动页面即时收回/恢复治理动作（与 initData
/// 服务回写 role 同一条 UI 出口）。
class RoleTransitionMatrixNotifier extends GroupDetailNotifier {
  RoleTransitionMatrixNotifier(this.initial);
  final GroupDetailState initial;

  @override
  GroupDetailState build() => initial;

  @override
  void setLoading(bool value) {}
  @override
  void setTitle(String title) {}
  @override
  void setMemberCount(int count) {}
  @override
  void setRoleInfo(int role, bool isAdmin) {
    state = state.copyWith(role: role, isAdmin: isAdmin);
  }

  @override
  void setMemberList(List<PeopleModel> list) {}
  @override
  void setMyGroupAlias(String? alias) {}
  @override
  void setGroupRemark(String? remark) {}
  @override
  void setGroup(GroupModel group) {}
  @override
  void addMember(PeopleModel member) {}
  @override
  void removeMember(String userId) {}
}
