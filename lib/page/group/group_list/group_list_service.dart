import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/api/group_member_api.dart';
import 'package:imboy/store/api/group_api.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';

/// 群组列表服务类 - 处理业务逻辑
class GroupListService {
  /// 计算群组头像
  Future<List<String>> computeAvatar(String gid) async {
    const limit = 9;
    String sql =
        "select c.avatar from ${ContactRepo.tableName} as c left join ${GroupMemberRepo.tableName} gm on gm.${GroupMemberRepo.userId} = c.${ContactRepo.peerId} WHERE gm.group_id = '$gid' limit $limit;";
    Database? db = await SqliteService.to.db;
    if (db == null) {
      return [];
    }
    List<Map> list = await db.rawQuery(sql);
    List<String> li = [UserRepoLocal.to.current.avatar];
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

    Map<String, dynamic>? payload = await GroupMemberApi().page(
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

  /// 计算群组标题
  Future<String> computeTitle(String gid) async {
    if (gid.trim().isEmpty) {
      iPrint("computeTitle: gid is empty");
      return '';
    }

    const limit = 3;
    String title = '';
    String sql =
        "select c.remark, c.nickname, c.account, gm.${GroupMemberRepo.alias} from ${ContactRepo.tableName} as c left join ${GroupMemberRepo.tableName} gm on gm.${GroupMemberRepo.userId} = c.${ContactRepo.peerId} WHERE gm.group_id = ? limit $limit;";
    Database? db = await SqliteService.to.db;
    if (db == null) {
      iPrint("computeTitle: database is null");
      return '';
    }

    try {
      List<Map> list = await db.rawQuery(sql, [gid]);
      iPrint("computeTitle $gid, ${list.length} members found in local db");

      if (list.isNotEmpty) {
        List<String> names = [];
        for (var e in list) {
          String t = (e['alias']?.toString() ?? '').trim();
          if (t.isEmpty) {
            t = (e['remark']?.toString() ?? '').trim();
          }
          if (t.isEmpty) {
            t = (e['nickname']?.toString() ?? '').trim();
          }
          if (t.isEmpty) {
            t = (e['account']?.toString() ?? '').trim();
          }
          if (t.isNotEmpty) {
            names.add(t);
          }
        }

        if (names.isNotEmpty) {
          title = names.join('、');
          iPrint("computeTitle local result: $title");
          return title;
        }
      }

      // 如果本地没有数据，尝试从服务器获取
      iPrint("computeTitle: fetching from server for gid: $gid");
      Map<String, dynamic>? payload = await GroupMemberApi().page(
        gid: gid,
        size: limit,
      );

      if (payload != null &&
          payload['list'] != null &&
          payload['list'] is List) {
        GroupMemberRepo repo = GroupMemberRepo();
        List<String> names = [];

        for (var item in payload['list']) {
          if (item is Map<String, dynamic>) {
            await repo.save(item);
            String t = (item['alias']?.toString() ?? '').trim();
            if (t.isEmpty) {
              t = (item['nickname']?.toString() ?? '').trim();
            }
            if (t.isEmpty) {
              t = (item['account']?.toString() ?? '').trim();
            }
            if (t.isNotEmpty) {
              names.add(t);
            }
          }
        }

        if (names.isNotEmpty) {
          title = names.join('、');
          iPrint("computeTitle server result: $title");
        }
      }
    } catch (e, s) {
      iPrint("computeTitle error: $e\n$s");
    }

    iPrint("computeTitle final result for $gid: '$title'");
    return title;
  }

  /// 分页获取群组列表
  Future<List<GroupModel>> page({
    int page = 1,
    int size = 10,
    bool onRefresh = false,
    String attr = 'owner',
  }) async {
    List<GroupModel> list = [];
    page = page > 1 ? page : 1;
    int offset = (page - 1) * size;
    var repo = GroupRepo();
    if (onRefresh == false) {
      list = await repo.page(limit: size, offset: offset);
    }
    if (list.isNotEmpty) {
      return list;
    }
    Map<String, dynamic>? payload = await GroupApi().page(
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

  /// 删除群组
  Future<bool> delete(String groupId) async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return false;
    }
    return true;
  }

  /// 成员加入群组
  Future<Map<String, dynamic>?> memberJoin({
    required String groupId,
    required String userId,
    required int userIdSum,
  }) async {
    GroupRepo gRepo = GroupRepo();
    GroupModel? g = await gRepo.findById(groupId);
    iPrint("memberJoin g ${g?.toJson().toString()};");
    if (g == null) {
      return null;
    }
    GroupMemberRepo gmRepo = GroupMemberRepo();
    GroupMemberModel? gm = await gmRepo.findByUserId(groupId, userId);
    if (gm == null) {
      ContactModel? c = await ContactRepo().findByUid(userId);
      await gmRepo.insert(
        GroupMemberModel(
          id: null,
          groupId: groupId,
          userId: userId,
          alias: c?.nickname ?? '',
          nickname: c?.nickname ?? '',
          avatar: c?.avatar ?? '',
          account: c?.account ?? '',
          sign: c?.sign ?? '',
          createdAt: DateTimeHelper.millisecond(),
        ),
      );
      await gRepo.save(groupId, {
        GroupRepo.userIdSum: userIdSum,
        GroupRepo.memberCount: g.memberCount + 1,
      });
    }
    return {"isFirst": gm == null ? true : false};
  }

  /// 成员离开群组
  Future<void> memberLeave({
    required String groupId,
    required String userId,
    required int userIdSum,
  }) async {
    GroupRepo gRepo = GroupRepo();
    GroupModel? g = await gRepo.findById(groupId);
    iPrint("memberLeave g ${g?.toJson().toString()};");

    if (userId == UserRepoLocal.to.currentUid) {
      await GroupMemberRepo().deleteByGid(groupId);
      await gRepo.delete(groupId);
    } else {
      int res = await GroupMemberRepo().delete(groupId, userId);
      iPrint("memberLeave $res;");
      await gRepo.save(groupId, {
        GroupRepo.userIdSum: userIdSum,
        GroupRepo.memberCount: g!.memberCount - 1,
      });
    }
  }

  /// 获取群组列表
  Future<List<GroupModel>> listGroup() async {
    return await page(page: 1, size: 100);
  }

  /// 根据 ID 查找群组
  Future<GroupModel?> findById(String groupId) async {
    return await GroupRepo().findById(groupId);
  }
}
