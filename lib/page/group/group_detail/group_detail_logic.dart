import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/group/group_list/group_list_logic.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/provider/group_member_provider.dart';
import 'package:imboy/store/provider/group_provider.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class GroupDetailLogic extends GetxController {
  Future<GroupModel?> detail({required String gid, bool sync = false}) async {
    GroupModel? g;
    DateTime s = DateTime.now();
    if (sync == false) {
      g = await GroupRepo().findById(gid);
      if (g != null) {
        return g;
      }
    }

    Map<String, dynamic>? payload = await GroupProvider().detail(gid: gid);
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

  Future<int> role({required String gid, required String userId}) async {
    GroupMemberRepo repo = GroupMemberRepo();
    GroupMemberModel? m = await repo.findByUserId(gid, userId);
    if (m == null) {
      return 0;
    }
    // role; // 角色: 1 成员  2 嘉宾  3  管理员 4 群主
    return m.role;
  }

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
          whereArgs: [gid]);
      if (list.isNotEmpty) {
        for (GroupMemberModel obj in list) {
          iPrint("listGroupMember sync=false ${obj.toJson().toString()}");
          list2.add(PeopleModel(
            id: obj.userId,
            nickname: obj.alias.isEmpty ? obj.nickname : obj.alias,
            account: obj.account,
            avatar: obj.avatar,
            sign: obj.sign,
          ));
        }
        return list2;
      }
    }
    // return list2;

    Map<String, dynamic>? payload = await GroupMemberProvider().page(
      gid: gid,
      size: limit,
    );
    iPrint("GroupMemberProvider/page payload ${payload.toString()}");
    if (payload != null && payload['list'] != null) {
      for (var item in payload['list']) {
        GroupMemberModel obj2 = await repo.save(item);
        list2.add(PeopleModel(
          id: obj2.userId,
          nickname: obj2.alias.isEmpty ? obj2.nickname : obj2.alias,
          account: obj2.account,
          avatar: obj2.avatar,
          sign: obj2.sign,
        ));
      }
    }
    return list2;
  }

  //  解散群
  Future<bool> dissolve(String gid) async {
    Map<String, dynamic>? p = await GroupProvider().dissolve(gid: gid);
    if (p != null) {
      return cleanData(gid);
    }
    return false;
  }

  Future<bool> cleanData(String gid) async {
    await GroupRepo().delete(gid);
    await GroupMemberRepo().deleteByGid(gid);
    String tb = MessageRepo.getTableName('C2G');
    String uk3 = "c2g_${UserRepoLocal.to.currentUid}_$gid";
    await MessageRepo(tableName: tb).deleteByConversationId(uk3);
    await ConversationRepo().delete('C2G', gid);

    final i = Get.find<ConversationLogic>()
        .conversations
        .indexWhere((ConversationModel m) => m.uk3 == uk3);
    if (i > -1) {
      Get.find<ConversationLogic>().conversations.removeAt(i);
    }
    return true;
  }

  /// 退出群聊 删除本地群数据，聊天数据等
  Future<bool> leave(String gid) async {
    Map<String, dynamic>? p = await GroupMemberProvider().leave(
      gid: gid,
      memberUserIds: [UserRepoLocal.to.currentUid],
    );
    if (p != null) {
      return cleanData(gid);
    }
    return false;
  }

  Future<GroupModel?> find(String gid) async {
    GroupModel? group = await GroupRepo().findById(gid);

    if (group!.avatar.isEmpty) {
      group.computeAvatar = await Get.find<GroupListLogic>().computeAvatar(
        group.groupId,
      );
    }
    if (group.title.isEmpty) {
      group.computeTitle = await Get.find<GroupListLogic>().computeTitle(
        group.groupId,
      );
    }
    return group;
  }

  Future<GroupModel?> groupEdit(String gid, Map<String, dynamic> data) async {
    bool res = await GroupProvider().groupEdit(gid: gid, data: data);
    GroupModel? g;
    if (res) {
      g = await GroupRepo().save(gid, data);
    }
    return g;
  }
}
