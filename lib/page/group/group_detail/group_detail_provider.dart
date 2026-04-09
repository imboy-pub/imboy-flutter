import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/people_model.dart';

part 'group_detail_provider.g.dart';

/// 群组详情状态
class GroupDetailState {
  final GroupModel? group;
  final List<PeopleModel> memberList;
  final String title;
  final int memberCount;
  final bool isAdmin;
  final int role;
  final String? myGroupAlias;
  final String? groupRemark; // 群备注（仅自己可见）
  final bool isLoading;

  const GroupDetailState({
    this.group,
    this.memberList = const [],
    this.title = '',
    this.memberCount = 0,
    this.isAdmin = false,
    this.role = 0,
    this.myGroupAlias,
    this.groupRemark,
    this.isLoading = false,
  });

  GroupDetailState copyWith({
    GroupModel? group,
    List<PeopleModel>? memberList,
    String? title,
    int? memberCount,
    bool? isAdmin,
    int? role,
    String? myGroupAlias,
    String? groupRemark,
    bool? isLoading,
  }) {
    return GroupDetailState(
      group: group ?? this.group,
      memberList: memberList ?? this.memberList,
      title: title ?? this.title,
      memberCount: memberCount ?? this.memberCount,
      isAdmin: isAdmin ?? this.isAdmin,
      role: role ?? this.role,
      myGroupAlias: myGroupAlias ?? this.myGroupAlias,
      groupRemark: groupRemark ?? this.groupRemark,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 群组详情 Notifier
@Riverpod(keepAlive: true)
class GroupDetailNotifier extends _$GroupDetailNotifier {
  @override
  GroupDetailState build() {
    return const GroupDetailState();
  }

  /// 设置加载状态
  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  /// 设置群组信息
  void setGroup(GroupModel group) {
    state = state.copyWith(group: group);
  }

  /// 设置成员列表
  void setMemberList(List<PeopleModel> list) {
    state = state.copyWith(memberList: list);
  }

  /// 添加成员
  void addMember(PeopleModel member) {
    final newList = List<PeopleModel>.from(state.memberList);
    newList.insert(0, member);
    state = state.copyWith(
      memberList: newList,
      memberCount: state.memberCount + 1,
    );
  }

  /// 移除成员
  void removeMember(int userId) {
    final newList = state.memberList.where((m) => m.id != userId).toList();
    final removedCount = state.memberList.length - newList.length;
    state = state.copyWith(
      memberList: newList,
      memberCount: state.memberCount - removedCount,
    );
  }

  /// 更新标题
  void setTitle(String title) {
    state = state.copyWith(title: title);
  }

  /// 更新成员数量
  void setMemberCount(int count) {
    state = state.copyWith(memberCount: count);
  }

  /// 设置角色信息
  void setRoleInfo(int role, bool isAdmin) {
    state = state.copyWith(role: role, isAdmin: isAdmin);
  }

  /// 设置我的群组别名
  void setMyGroupAlias(String? alias) {
    state = state.copyWith(myGroupAlias: alias);
  }

  /// 设置群备注（仅自己可见）
  void setGroupRemark(String? remark) {
    state = state.copyWith(groupRemark: remark);
  }
}
