import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 群成员详情服务类
class GroupMemberDetailService {
  final GroupMemberApi _memberApi = GroupMemberApi();
  final GroupApi _groupApi = GroupApi();
  final GroupMemberRepo _memberRepo = GroupMemberRepo();

  /// 获取成员信息
  Future<GroupMemberModel?> getMemberInfo({
    required String groupId,
    required String userId,
  }) async {
    GroupMemberModel? member = await _memberRepo.findByUserId(groupId, userId);
    return member;
  }

  /// 获取当前用户在群中的角色
  Future<int> getMyRole(String groupId) async {
    String currentUid = UserRepoLocal.to.currentUid;
    GroupMemberModel? member = await _memberRepo.findByUserId(
      groupId,
      currentUid,
    );
    return member?.role ?? 1;
  }

  /// 设置管理员
  Future<bool> setAdmin({
    required String groupId,
    required String userId,
  }) async {
    bool success = await _memberApi.updateRole(
      gid: groupId,
      userId: userId,
      role: 3, // 管理员
    );

    if (success) {
      // 更新本地数据库
      await _memberRepo.update(groupId, userId, {
        GroupMemberRepo.role: 3,
        GroupMemberRepo.updatedAt:
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    }

    iPrint("GroupMemberDetailService/setAdmin success: $success");
    return success;
  }

  /// 取消管理员
  Future<bool> removeAdmin({
    required String groupId,
    required String userId,
  }) async {
    bool success = await _memberApi.updateRole(
      gid: groupId,
      userId: userId,
      role: 1, // 普通成员
    );

    if (success) {
      // 更新本地数据库
      await _memberRepo.update(groupId, userId, {
        GroupMemberRepo.role: 1,
        GroupMemberRepo.updatedAt:
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    }

    iPrint("GroupMemberDetailService/removeAdmin success: $success");
    return success;
  }

  /// 禁言成员
  /// [duration] 禁言时长（秒），0 表示取消禁言
  Future<bool> muteMember({
    required String groupId,
    required String userId,
    required int duration,
  }) async {
    bool success = await _memberApi.mute(
      gid: groupId,
      userId: userId,
      duration: duration,
    );

    iPrint("GroupMemberDetailService/muteMember success: $success");
    return success;
  }

  /// 踢出成员
  Future<bool> kickMember({
    required String groupId,
    required String userId,
  }) async {
    Map<String, dynamic>? result = await _memberApi.leave(
      gid: groupId,
      memberUserIds: [userId],
    );

    if (result != null) {
      // 删除本地数据库记录
      await _memberRepo.delete(groupId, userId);
    }

    iPrint("GroupMemberDetailService/kickMember success: ${result != null}");
    return result != null;
  }

  /// 转让群主
  Future<bool> transferGroup({
    required String groupId,
    required String newOwnerUid,
  }) async {
    bool success = await _groupApi.transfer(
      gid: groupId,
      newOwnerUid: newOwnerUid,
    );

    if (success) {
      // 更新本地数据库：新群主角色
      await _memberRepo.update(groupId, newOwnerUid, {
        GroupMemberRepo.role: 4,
        GroupMemberRepo.updatedAt:
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      // 更新本地数据库：原群主变为管理员
      String currentUid = UserRepoLocal.to.currentUid;
      await _memberRepo.update(groupId, currentUid, {
        GroupMemberRepo.role: 3,
        GroupMemberRepo.updatedAt:
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    }

    iPrint("GroupMemberDetailService/transferGroup success: $success");
    return success;
  }
}
