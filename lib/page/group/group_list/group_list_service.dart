import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/page/group/group_detail/group_detail_service.dart';
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
  String _normalizeAttr(String attr) {
    switch (attr) {
      case 'all':
      case 'join':
      case 'manager':
      case 'owner':
        return attr;
      default:
        return 'all';
    }
  }

  Future<List<GroupModel>> _pullAndSyncAllViews({
    required int page,
    required int size,
    required int offset,
  }) async {
    final repo = GroupRepo();
    final merged = <int, GroupModel>{};
    for (final attr in const ['manager', 'join', 'owner']) {
      final payload = await GroupApi().page(page: page, size: size, attr: attr);
      if (payload == null) {
        continue;
      }
      final rows = payload['list'];
      if (rows is! List || rows.isEmpty) {
        continue;
      }
      for (final item in rows) {
        if (item is! Map) {
          continue;
        }
        final json = Map<String, dynamic>.from(item);
        final group = await repo.save('', json);
        await _syncSelfMembershipShadow(attr: attr, group: group);
        merged[group.groupId] = group;
      }
    }

    if (merged.isEmpty) {
      // 远端为空时使用本地激活群兜底，避免因关系字段脏数据导致整页空白。
      return repo.pageActive(limit: size, offset: offset);
    }
    final local = await repo.pageByAttr(
      attr: 'all',
      limit: size,
      offset: offset,
    );
    if (local.isNotEmpty) {
      return local;
    }
    final list = merged.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _syncSelfMembershipShadow({
    required String attr,
    required GroupModel group,
  }) async {
    final currentUid = UserRepoLocal.to.currentUid;
    if (currentUid.isEmpty || group.groupId == 0) {
      return;
    }

    final gmRepo = GroupMemberRepo();
    final existed = await gmRepo.findByUserId(group.groupId.toString(), currentUid);
    if (existed != null) {
      final patch = <String, dynamic>{};
      if (existed.status != 1) {
        patch[GroupMemberRepo.status] = 1;
      }
      if (group.ownerUid.toString() == currentUid) {
        if (existed.role < 4) {
          patch[GroupMemberRepo.role] = 4;
        }
        if (existed.isJoin != 0) {
          patch[GroupMemberRepo.isJoin] = 0;
        }
      } else {
        if (attr == 'manager' && existed.role < 3) {
          patch[GroupMemberRepo.role] = 3;
        }
        if (existed.isJoin != 1) {
          patch[GroupMemberRepo.isJoin] = 1;
        }
      }
      if (patch.isNotEmpty) {
        await gmRepo.update(group.groupId.toString(), currentUid, patch);
      }
      return;
    }

    final now = DateTimeHelper.millisecond();
    int role = 1;
    int isJoin = 1;
    if (group.ownerUid.toString() == currentUid) {
      role = 4;
      isJoin = 0;
    } else if (attr == 'manager') {
      role = 3;
    }

    await gmRepo.insert(
      GroupMemberModel(
        id: null,
        groupId: group.groupId,
        userId: int.tryParse(currentUid) ?? 0,
        nickname: UserRepoLocal.to.current.nickname,
        avatar: UserRepoLocal.to.current.avatar,
        sign: UserRepoLocal.to.current.sign,
        account: UserRepoLocal.to.current.account,
        alias: '',
        role: role,
        isJoin: isJoin,
        joinMode: 'page_sync_$attr',
        status: 1,
        updatedAt: now,
        createdAt: now,
      ),
    );
  }

  Future<int> _pullAndSyncByAttr({
    required String attr,
    int pageSize = 200,
    int maxPages = 20,
  }) async {
    final normalizedAttr = _normalizeAttr(attr);
    int syncedCount = 0;
    final repo = GroupRepo();

    for (int p = 1; p <= maxPages; p++) {
      final payload = await GroupApi().page(
        page: p,
        size: pageSize,
        attr: normalizedAttr,
      );
      if (payload == null) {
        break;
      }
      final rows = payload['list'];
      if (rows is! List || rows.isEmpty) {
        break;
      }

      for (final item in rows) {
        if (item is! Map) {
          continue;
        }
        final json = Map<String, dynamic>.from(item);
        final group = await repo.save('', json);
        await _syncSelfMembershipShadow(attr: normalizedAttr, group: group);
        syncedCount += 1;
      }

      if (rows.length < pageSize) {
        break;
      }
    }

    return syncedCount;
  }

  Future<Map<String, int>> selfHealMembershipShadows({
    int pageSize = 200,
    int maxPages = 20,
  }) async {
    final repo = GroupRepo();
    final beforeOwner = await repo.countByAttr(attr: 'owner');
    final beforeJoin = await repo.countByAttr(attr: 'join');
    final beforeManager = await repo.countByAttr(attr: 'manager');

    int groupRows = 0;
    int errors = 0;
    final perAttr = <String, int>{'owner': 0, 'join': 0, 'manager': 0};
    for (final attr in const ['manager', 'join', 'owner']) {
      try {
        final count = await _pullAndSyncByAttr(
          attr: attr,
          pageSize: pageSize,
          maxPages: maxPages,
        );
        perAttr[attr] = count;
        groupRows += count;
      } catch (e, s) {
        iPrint("selfHealMembershipShadows attr=$attr error: $e\n$s");
        errors += 1;
      }
    }

    final afterOwner = await repo.countByAttr(attr: 'owner');
    final afterJoin = await repo.countByAttr(attr: 'join');
    final afterManager = await repo.countByAttr(attr: 'manager');

    return {
      'groupRows': groupRows,
      'errors': errors,
      'ownerRows': perAttr['owner'] ?? 0,
      'joinRows': perAttr['join'] ?? 0,
      'managerRows': perAttr['manager'] ?? 0,
      'beforeOwner': beforeOwner,
      'beforeJoin': beforeJoin,
      'beforeManager': beforeManager,
      'afterOwner': afterOwner,
      'afterJoin': afterJoin,
      'afterManager': afterManager,
      'deltaOwner': afterOwner - beforeOwner,
      'deltaJoin': afterJoin - beforeJoin,
      'deltaManager': afterManager - beforeManager,
    };
  }

  /// 计算群组头像
  Future<List<String>> computeAvatar(String gid) async {
    const limit = 9;
    String sql =
        "select c.avatar from ${ContactRepo.tableName} as c left join ${GroupMemberRepo.tableName} gm on gm.${GroupMemberRepo.userId} = c.${ContactRepo.peerId} WHERE gm.group_id = ? limit $limit;";
    Database? db = await SqliteService.to.db;
    if (db == null) {
      return [];
    }
    List<Map> list = await db.rawQuery(sql, [gid]);
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
        unawaited(repo.save(item));
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
    String attr = 'all',
  }) async {
    final normalizedAttr = _normalizeAttr(attr);
    List<GroupModel> list = [];
    page = page > 1 ? page : 1;
    int offset = (page - 1) * size;
    var repo = GroupRepo();
    if (onRefresh == false) {
      list = await repo.pageByAttr(
        attr: normalizedAttr,
        limit: size,
        offset: offset,
      );
    }
    if (list.isNotEmpty) {
      return list;
    }
    if (normalizedAttr == 'all') {
      return _pullAndSyncAllViews(page: page, size: size, offset: offset);
    }
    Map<String, dynamic>? payload = await GroupApi().page(
      page: page,
      size: size,
      attr: normalizedAttr,
    );
    if (payload == null) {
      return [];
    }
    for (var json in payload['list']) {
      GroupModel m = await repo.save('', json);
      await _syncSelfMembershipShadow(attr: normalizedAttr, group: m);
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
    iPrint("memberJoin gid=$groupId exists=${g != null}");
    if (g == null) {
      // 群记录不存在时，先从服务端补齐群详情，避免 join 事件被丢弃
      g = await GroupDetailService().detail(gid: groupId, sync: true);
      if (g == null) {
        return null;
      }
    }
    GroupMemberRepo gmRepo = GroupMemberRepo();
    GroupMemberModel? gm = await gmRepo.findByUserId(groupId, userId);
    if (gm == null) {
      ContactModel? c = await ContactRepo().findByUid(userId);
      await gmRepo.insert(
        GroupMemberModel(
          id: null,
          groupId: parseModelInt(groupId),
          userId: parseModelInt(userId),
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
    iPrint("memberLeave gid=$groupId exists=${g != null}");

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
    return await page(page: 1, size: 100, attr: 'all');
  }

  /// 根据 ID 查找群组
  Future<GroupModel?> findById(String groupId) async {
    return await GroupRepo().findById(groupId);
  }
}
