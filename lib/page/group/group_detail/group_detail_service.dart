import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// 群组详情服务类
class GroupDetailService {
  /// 获取群组详情
  Future<GroupModel?> detail({required String gid, bool sync = false}) async {
    GroupModel? g;
    DateTime s = DateTime.now();
    if (sync == false) {
      g = await GroupRepo().findById(gid);
      if (g != null) {
        return g;
      }
    }

    Map<String, dynamic>? payload = await GroupApi().detail(gid: gid);
    if (payload.isEmpty) {
      return null;
    }
    g = await GroupRepo().save(gid, payload);
    if (payload.containsKey('member_count')) {
      g.memberCount = payload['member_count'];
    }
    DateTime e = DateTime.now();
    iPrint("detail time diff: ${e.difference(s)} ${g.toJson().toString()}");
    return g;
  }

  /// 获取用户在群组中的角色
  Future<int> role({required String gid, required String userId}) async {
    GroupMemberRepo repo = GroupMemberRepo();
    GroupMemberModel? m = await repo.findByUserId(gid, userId);
    if (m == null) {
      return 0;
    }
    // role; // 角色: 1 成员  2 嘉宾  3  管理员 4 群主
    return m.role;
  }

  /// 获取我的群组成员信息
  Future<GroupMemberModel?> getMyGroupMemberInfo(String gid) async {
    GroupMemberRepo repo = GroupMemberRepo();
    String currentUid = UserRepoLocal.to.currentUid;
    return await repo.findByUserId(gid, currentUid);
  }

  /// 更新我的群组别名
  Future<bool> updateMyGroupAlias(String gid, String alias) async {
    bool res = await GroupMemberApi().changeAlias(gid, alias);
    if (res) {
      // Update local db
      GroupMemberRepo repo = GroupMemberRepo();
      String currentUid = UserRepoLocal.to.currentUid;
      await repo.update(gid, currentUid, {GroupMemberRepo.alias: alias});
    }
    return res;
  }

  /// 列出群组成员
  Future<List<PeopleModel>> listGroupMember({
    required String gid,
    required int limit,
    bool sync = false,
  }) async {
    GroupMemberRepo repo = GroupMemberRepo();
    List<PeopleModel> list2 = [];
    if (sync == false) {
      List<GroupMemberModel> list = await repo.page(
        limit: limit,
        where: "${GroupMemberRepo.groupId} = ?",
        whereArgs: [gid],
      );
      if (list.isNotEmpty) {
        for (GroupMemberModel obj in list) {
          iPrint("listGroupMember sync=false ${obj.toJson().toString()}");
          list2.add(
            PeopleModel(
              id: obj.userId,
              nickname: obj.alias.isEmpty ? obj.nickname : obj.alias,
              account: obj.account,
              avatar: obj.avatar,
              sign: obj.sign,
            ),
          );
        }
        return list2;
      }
    }

    Map<String, dynamic>? payload = await GroupMemberApi().page(
      gid: gid,
      size: limit,
    );
    iPrint("GroupMemberApi/page payload ${payload.toString()}");
    if (payload != null && payload['list'] != null) {
      for (var item in payload['list']) {
        GroupMemberModel obj2 = await repo.save(item);
        list2.add(
          PeopleModel(
            id: obj2.userId,
            nickname: obj2.alias.isEmpty ? obj2.nickname : obj2.alias,
            account: obj2.account,
            avatar: obj2.avatar,
            sign: obj2.sign,
          ),
        );
      }
    }
    return list2;
  }

  /// 解散群
  Future<bool> dissolve(String gid) async {
    Map<String, dynamic>? p = await GroupApi().dissolve(gid: gid);
    if (p != null) {
      return cleanData(gid);
    }
    return false;
  }

  /// 清理数据
  Future<bool> cleanData(String gid) async {
    await GroupRepo().delete(gid);
    await GroupMemberRepo().deleteByGid(gid);
    String tb = MessageRepo.getTableName('C2G');
    String uk3 = "c2g_${UserRepoLocal.to.currentUid}_$gid";
    await MessageRepo(tableName: tb).deleteByConversationId(uk3);
    await ConversationRepo().delete('C2G', gid);

    // 触发会话列表刷新事件
    AppEventBus.fire(
      ChatExtendEvent(type: 'refresh_conversations', payload: {'uk3': uk3}),
    );
    return true;
  }

  /// 退出群聊
  Future<bool> leave(String gid) async {
    Map<String, dynamic>? p = await GroupMemberApi().leave(
      gid: gid,
      memberUserIds: [UserRepoLocal.to.currentUid],
    );
    if (p != null) {
      return cleanData(gid);
    }
    return false;
  }

  /// 查找群组
  Future<GroupModel?> find(String gid) async {
    GroupModel? group = await GroupRepo().findById(gid);
    return group;
  }

  /// 编辑群组信息
  Future<GroupModel?> groupEdit(String gid, Map<String, dynamic> data) async {
    bool res = await GroupApi().groupEdit(gid: gid, data: data);
    GroupModel? g;
    if (res) {
      g = await GroupRepo().save(gid, data);
    }
    return g;
  }

  /// 更新群组信息
  Future<GroupModel?> updateGroup({
    required String groupId,
    String? title,
    String? avatar,
    String? notice,
  }) async {
    Map<String, dynamic> data = {};
    if (title != null) {
      data['title'] = title;
    }
    if (avatar != null) {
      data['avatar'] = avatar;
    }
    if (notice != null) {
      data['introduction'] = notice;
    }
    return await groupEdit(groupId, data);
  }

  /// 清空会话聊天记录
  Future<int> cleanMessageByPeerId(String type, String peerId) async {
    ConversationModel? model = await ConversationRepo().findByPeerId(
      type,
      peerId,
    );
    if (model == null) {
      return 0;
    }
    String tb = MessageRepo.getTableName(model.type);

    // 先查询该会话的所有消息ID，用于清理重试队列
    final repo = MessageRepo(tableName: tb);
    final messages = await repo.page(
      conversationUk3: model.uk3,
      page: 1,
      size: 10000,
    );

    // 清理重试队列中属于该会话的消息
    // TODO: 迁移到 Riverpod provider 后移除此检查
    if (messages.isNotEmpty) {
      try {
        for (final msg in messages) {
          if (msg.id != null && msg.id!.isNotEmpty) {
            MessageRetry.to.removeFromRetryQueue(msg.id!);
          }
        }
        iPrint('已从重试队列清理 ${messages.length} 条消息: conversationUk3=${model.uk3}');
      } catch (e) {
        // MessageRetry 可能未注册，忽略错误
        debugPrint('MessageRetry not registered or error: $e');
      }
    }

    // 删除数据库中的消息
    await repo.deleteByConversationId(model.uk3);

    AppEventBus.fire(
      ChatExtendEvent(type: 'clean_msg', payload: {'uk3': model.uk3}),
    );
    return model.id;
  }
}
