import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/model/group_member_model.dart';

/// 群成员详情状态
class GroupMemberDetailState {
  final GroupMemberModel? member;
  final int myRole; // 当前用户在群中的角色
  final bool isLoading;
  final String? errorMessage;
  final bool isMuted; // 是否被禁言
  final int? mutedUntil; // 禁言截止时间（时间戳）

  const GroupMemberDetailState({
    this.member,
    this.myRole = 1,
    this.isLoading = false,
    this.errorMessage,
    this.isMuted = false,
    this.mutedUntil,
  });

  GroupMemberDetailState copyWith({
    GroupMemberModel? member,
    int? myRole,
    bool? isLoading,
    String? errorMessage,
    bool? isMuted,
    int? mutedUntil,
  }) {
    return GroupMemberDetailState(
      member: member ?? this.member,
      myRole: myRole ?? this.myRole,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isMuted: isMuted ?? this.isMuted,
      mutedUntil: mutedUntil ?? this.mutedUntil,
    );
  }

  /// 是否是群主
  bool get isOwner => member?.role == 4;

  /// 是否是管理员
  bool get isAdmin => member?.role == 3;

  /// 当前用户是否是群主
  bool get amOwner => myRole == 4;

  /// 当前用户是否是管理员或群主
  bool get amAdmin => myRole == 3 || myRole == 4;

  /// 是否可以设置为管理员（群主可以设置，且目标不是群主）
  bool get canSetAdmin => amOwner && !isOwner;

  /// 是否可以取消管理员（群主可以取消，且目标是管理员）
  bool get canRemoveAdmin => amOwner && isAdmin;

  /// 是否可以禁言（群主和管理员可以禁言普通成员，但不能禁言群主和其他管理员）
  bool get canMute {
    if (!amAdmin) return false;
    if (isOwner) return false;
    if (amOwner) return true; // 群主可以禁言任何人（除了自己）
    if (isAdmin && member?.role == 1) return true; // 管理员只能禁言普通成员
    return false;
  }

  /// 是否可以踢出（群主可以踢出任何人（除了自己），管理员只能踢出普通成员）
  bool get canKick {
    if (!amAdmin) return false;
    if (isOwner) return false;
    if (amOwner) return true;
    if (isAdmin && member?.role == 1) return true;
    return false;
  }

  /// 是否可以转让群主（只有群主可以转让，且目标是其他成员）
  bool get canTransfer => amOwner && !isOwner;
}

/// 群成员详情 Notifier
class GroupMemberDetailNotifier extends StateNotifier<GroupMemberDetailState> {
  GroupMemberDetailNotifier() : super(const GroupMemberDetailState());

  /// 设置成员信息
  void setMember(GroupMemberModel member) {
    state = state.copyWith(member: member);
  }

  /// 设置当前用户角色
  void setMyRole(int role) {
    state = state.copyWith(myRole: role);
  }

  /// 设置加载状态
  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  /// 设置错误信息
  void setError(String? error) {
    state = state.copyWith(errorMessage: error, isLoading: false);
  }

  /// 设置禁言状态
  void setMuteStatus(bool isMuted, {int? mutedUntil}) {
    state = state.copyWith(isMuted: isMuted, mutedUntil: mutedUntil);
  }

  /// 更新成员角色
  void updateMemberRole(int role) {
    if (state.member != null) {
      final updatedMember = GroupMemberModel(
        id: state.member!.id,
        groupId: state.member!.groupId,
        userId: state.member!.userId,
        nickname: state.member!.nickname,
        avatar: state.member!.avatar,
        sign: state.member!.sign,
        account: state.member!.account,
        inviteCode: state.member!.inviteCode,
        alias: state.member!.alias,
        description: state.member!.description,
        role: role,
        isJoin: state.member!.isJoin,
        joinMode: state.member!.joinMode,
        status: state.member!.status,
        updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        createdAt: state.member!.createdAt,
      );
      state = state.copyWith(member: updatedMember);
    }
  }

  /// 清除状态
  void clear() {
    state = const GroupMemberDetailState();
  }
}

/// 群成员详情 Provider
final groupMemberDetailProvider =
    StateNotifierProvider<GroupMemberDetailNotifier, GroupMemberDetailState>(
  (ref) => GroupMemberDetailNotifier(),
);
