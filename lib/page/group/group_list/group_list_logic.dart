import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/provider/group_member_provider.dart';
import 'package:imboy/store/provider/group_provider.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';

import 'group_list_state.dart';

class GroupListLogic extends GetxController {
  final GroupListState state = GroupListState();

  Future<List<String>> computeAvatar(String gid) async {
    const limit = 9;
    String sql =
        "select c.avatar from ${ContactRepo.tableName} as c left join ${GroupMemberRepo.tableName} gm on gm.${GroupMemberRepo.userId} = c.${ContactRepo.peerId} WHERE gm.group_id = '$gid' limit $limit;";
    Database db = await SqliteService.to.db;
    List<Map> list = await db.rawQuery(sql);
    iPrint("computeAvatar l $gid, ${list.length} $sql");
    iPrint("computeAvatar $gid, ${list.toString()}");
    // List<String> li = [UserRepoLocal.to.current.avatar];
    List<String> li = [];
    if (list.isNotEmpty) {
      for (var e in list) {
        String t = e['avatar'] ?? '';
        if (t.isNotEmpty) {
          li.add(t);
        }
      }
      if (li.isNotEmpty) {
        return li;
      }
    }

    Map<String, dynamic>? payload = await GroupMemberProvider().page(
      gid: gid,
      size: limit,
    );
    if (payload != null && payload['list'] != null) {
      GroupMemberRepo repo = GroupMemberRepo();
      for (var item in payload['list']) {
        repo.save(item);
        String t = item['avatar'] ?? '';
        if (t.trim().isNotEmpty) {
          li.add(t);
        }
      }
    }
    return li;
  }

  Future<String> computeTitle(String gid) async {
    const limit = 3;
    String title = '';
    String sql =
        "select c.remark, c.nickname, c.account, gm.${GroupMemberRepo.alias} from ${ContactRepo.tableName} as c left join ${GroupMemberRepo.tableName} gm on gm.${GroupMemberRepo.userId} = c.${ContactRepo.peerId} WHERE gm.group_id = '$gid' limit $limit;";
    Database db = await SqliteService.to.db;
    List<Map> list = await db.rawQuery(sql);
    iPrint("computeTitle $gid, ${list.length} $sql");
    iPrint("computeTitle $gid, ${list.toString()}");
    if (list.isNotEmpty) {
      for (var e in list) {
        String t = e['alias'] ?? '';
        if (t.isEmpty) {
          t = e['nickname'] ?? '';
        }
        if (t.isEmpty) {
          t = e['account'] ?? '';
        }
        title = title.isEmpty ? t : "$title、$t";
        iPrint("computeTitle title: $title");
      }
      return title;
    }

    Map<String, dynamic>? payload = await GroupMemberProvider().page(
      gid: gid,
      size: limit,
    );
    if (payload != null && payload['list'] != null) {
      GroupMemberRepo repo = GroupMemberRepo();
      for (var item in payload['list']) {
        repo.save(item);
        String t = item['alias'] ?? '';
        if (t.isEmpty) {
          t = "${item['nickname'] ?? ''}";
        }
        title = title.isEmpty ? t : "$title、$t";
      }
    }
    return title;
  }

  Future<List<GroupModel>> page(
      {int page = 1,
      int size = 10,
      bool onRefresh = false,
      String attr = 'owner'}) async {
    List<GroupModel> list = [];
    page = page > 1 ? page : 1;
    int offset = (page - 1) * size;
    var repo = GroupRepo();
    if (onRefresh == false) {
      list = await repo.page(limit: size, offset: offset);
    }
    if (list.isNotEmpty) {
      // for (var m in list) {
      //   Map<String, dynamic> json1 = m.toJson();
      //   await repo.save(json1);
      // }
      return list;
    }
    Map<String, dynamic>? payload = await GroupProvider().page(
      page: page,
      size: size,
      attr: attr,
    );
    if (payload == null) {
      return [];
    }
    for (var json in payload['list']) {
      GroupModel m = await repo.save('', json);
      list.add(m);
    }
    return list;
  }

  Future<bool> delete(String groupId) async {
    // return true;
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    // bool res2 = await GroupProvider().delete(
    //   groupId: groupId,
    // );
    // if (res2 == false) {
    //   return false;
    // }
    // await GroupRepo().delete(groupId);
    return true;
  }

  Future<void> memberJoin(
      {required String groupId,
      required String userId,
      required int userIdSum}) async {
    GroupRepo gRepo = GroupRepo();
    GroupModel? g = await gRepo.findById(groupId);
    // 面对面建群的时候，也会发送 group_member_join
    // 这个时候服务端只分配了一个group_id也没有创建 group表的记录，所以返回null
    // 待客户端点击进入群聊的时候，会创建 group 记录，
    // 届时再从服务端拉取group记录和group_member记录同步到各客户端？ TODO leeyi2024-04-26 15:32:22
    iPrint("memberJoin g ${g?.toJson().toString()};");
    if (g == null) {
      return;
    }
    GroupMemberRepo gmRepo = GroupMemberRepo();
    GroupMemberModel? gm = await gmRepo.findByUserId(groupId, userId);
    if (gm == null) {
      ContactModel? c = await ContactRepo().findByUid(userId);
      await gmRepo.insert(GroupMemberModel(
        id: null,
        groupId: groupId,
        userId: userId,
        alias: c?.nickname ?? '',
        nickname: c?.nickname ?? '',
        avatar: c?.avatar ?? '',
        account: c?.account ?? '',
        sign: c?.sign ?? '',
        createdAt: DateTimeHelper.utc(),
      ));
      // int? memberCount = await gmRepo.countByGid(groupId);
      await gRepo.save(groupId, {
        GroupRepo.userIdSum: userIdSum,
        GroupRepo.memberCount: g.memberCount + 1,
      });
    }

    // iPrint("memberJoin userIdSum $userIdSum g ${g.userIdSum}: ${g.userIdSum < userIdSum} ");
    // if (g.userIdSum < userIdSum) {
    // GroupModel? g2 = await (GroupRepo()).findById(groupId);
    // iPrint("memberJoin groupId ${g2?.groupId} memberCount ${g2?.memberCount}");
    // }
  }

  Future<void> memberLeave(
      {required String groupId,
      required String userId,
      required int userIdSum}) async {
    GroupRepo gRepo = GroupRepo();
    GroupModel? g = await gRepo.findById(groupId);
    // 面对面建群的时候，也会发送 group_member_join
    // 这个时候服务端只分配了一个group_id也没有创建 group表的记录，所以返回null
    // 待客户端点击进入群聊的时候，会创建 group 记录，
    // 届时再从服务端拉取group记录和group_member记录同步到各客户端？ TODO leeyi2024-04-26 15:32:22
    iPrint("memberLeave g ${g?.toJson().toString()};");

    int res = await (GroupMemberRepo()).delete(groupId, userId);
    iPrint("memberLeave $res;");

    // int? memberCount = await gmRepo.countByGid(groupId);
    await gRepo.save(groupId, {
      GroupRepo.userIdSum: userIdSum,
      GroupRepo.memberCount: g!.memberCount - 1,
    });
  }
}
