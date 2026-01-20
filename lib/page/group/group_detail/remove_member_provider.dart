import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';

part 'remove_member_provider.g.dart';

/// 移除群成员状态
class RemoveMemberState {
  final List<GroupMemberModel> groupMemberList;
  final List<GroupMemberModel> selects;
  final String selectsTips;
  final bool isLoading;

  const RemoveMemberState({
    this.groupMemberList = const [],
    this.selects = const [],
    this.selectsTips = '',
    this.isLoading = false,
  });

  RemoveMemberState copyWith({
    List<GroupMemberModel>? groupMemberList,
    List<GroupMemberModel>? selects,
    String? selectsTips,
    bool? isLoading,
  }) {
    return RemoveMemberState(
      groupMemberList: groupMemberList ?? this.groupMemberList,
      selects: selects ?? this.selects,
      selectsTips: selectsTips ?? this.selectsTips,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 移除群成员 Notifier
@Riverpod(keepAlive: false)
class RemoveMemberNotifier extends _$RemoveMemberNotifier {
  @override
  RemoveMemberState build() {
    return const RemoveMemberState();
  }

  /// 设置加载状态
  void setLoading(bool value) {
    state = state.copyWith(isLoading: value);
  }

  /// 设置群成员列表
  void setGroupMemberList(List<GroupMemberModel> list, String currentUid) {
    // 过滤掉当前用户和群主
    final filteredList = list.where((obj) {
      if (obj.userId == currentUid) {
        return false;
      }
      // 是否加入的群： 1 是 0 否 （0 是群创建者或者拥有者; 1 是 成员 嘉宾 管理员等）
      if (obj.isJoin == 0) {
        return false;
      }
      return true;
    }).toList();

    state = state.copyWith(groupMemberList: filteredList);
  }

  /// 切换选中状态
  void toggleSelection(GroupMemberModel model) {
    final isSelected = _isSelected(model);

    final newSelects = List<GroupMemberModel>.from(state.selects);
    if (isSelected) {
      newSelects.removeWhere((s) => s.userId == model.userId);
    } else {
      newSelects.add(model);
    }

    final newSelectsTips = newSelects.isNotEmpty
        ? '(${newSelects.length})'
        : '';

    state = state.copyWith(selects: newSelects, selectsTips: newSelectsTips);
  }

  /// 检查是否选中
  bool _isSelected(GroupMemberModel model) {
    return state.selects.any((s) => s.userId == model.userId);
  }

  /// 检查是否选中
  bool isSelected(GroupMemberModel model) {
    return _isSelected(model);
  }

  /// 重置数据
  void resetData() {
    state = state.copyWith(selects: [], selectsTips: '');
  }

  /// 移除成员
  Future<bool> removeMembers(String groupId) async {
    if (state.selects.isEmpty) {
      return false;
    }

    final memberUserIds = state.selects.map((item) => item.userId).toList();

    final service = RemoveMemberService();
    final result = await service.leaveGroup(groupId, memberUserIds);

    if (result) {
      resetData();
    }

    return result;
  }

  /// 加载群成员列表
  Future<void> loadGroupMembers(String groupId) async {
    final service = RemoveMemberService();
    final members = await service.listGroupMembers(groupId);
    setGroupMemberList(members, service.currentUid);
  }
}

/// 移除群成员服务
class RemoveMemberService {
  final String currentUid = ''; // TODO: 从 UserRepoLocal 获取

  Future<bool> leaveGroup(String groupId, List<String> memberUserIds) async {
    final provider = GroupMemberApi();
    final payload = await provider.leave(
      gid: groupId,
      memberUserIds: memberUserIds,
    );

    if (payload != null) {
      final gRepo = GroupRepo();
      final g = await gRepo.findById(groupId);
      final gmRepo = GroupMemberRepo();

      final sum = payload['user_id_sum'] ?? 0;
      final memberList = payload['member_list'] ?? [];

      final gData = {
        GroupRepo.memberCount: (g?.memberCount ?? 0) - memberList.length,
      };
      if (sum > 0) {
        gData[GroupRepo.userIdSum] = sum;
      }
      await gRepo.update(groupId, gData);

      for (var userId in memberUserIds) {
        await gmRepo.delete(groupId, userId);
      }
      return true;
    }
    return false;
  }

  Future<List<GroupMemberModel>> listGroupMembers(String groupId) async {
    final repo = GroupMemberRepo();
    return await repo.page(
      limit: 2000,
      where: "${GroupMemberRepo.groupId} = ?",
      whereArgs: [groupId],
    );
  }
}
