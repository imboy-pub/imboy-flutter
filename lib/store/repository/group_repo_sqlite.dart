import 'package:imboy/component/helper/func.dart';
import 'package:imboy/modules/group_collab/infrastructure/group_repository.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class GroupRepo implements GroupRepository {
  static String tableName = 'group';

  static String groupId = 'id'; //
  static String type = 'type'; // 类型: 1 公开群组  2 私有群组
  static String joinLimit = 'join_limit'; //  加入限制: 1 不需审核  2 需要审核  3 只允许邀请加入
  static String contentLimit =
      'content_limit'; // 内部发布限制: 1 圈内不需审核  2 圈内需要审核  3 圈外需要审核
  static String userIdSum =
      'user_id_sum'; // 主要用于添加群聊的时候排重；还可以用于校验客户端memberCount是否应该增加
  static String ownerUid = 'owner_uid'; //  群组拥有者ID
  static String creatorUid = 'creator_uid'; //群组创建者ID
  static String memberMax = 'member_max'; // 允许最大成员数量
  static String memberCount = 'member_count'; // 成员数量
  static String introduction = 'introduction'; // 简介
  static String avatar = 'avatar';
  static String title = 'title';
  static String status = 'status';
  static String updatedAt = 'updated_at';
  static String createdAt = 'created_at';

  // 公共列名列表
  static final List<String> defaultColumns = [
    GroupRepo.groupId,
    GroupRepo.type,
    GroupRepo.joinLimit,
    GroupRepo.contentLimit,
    GroupRepo.userIdSum,
    GroupRepo.ownerUid,
    GroupRepo.creatorUid,
    GroupRepo.memberMax,
    GroupRepo.memberCount,
    GroupRepo.introduction,
    GroupRepo.avatar,
    GroupRepo.title,
    GroupRepo.status,
    GroupRepo.updatedAt,
    GroupRepo.createdAt,
  ];

  final SqliteService _db = SqliteService.to;

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

  List<GroupModel> _mapsToModels(List<Map<String, dynamic>> maps) {
    if (maps.isEmpty) {
      return [];
    }
    List<GroupModel> items = [];
    for (int i = 0; i < maps.length; i++) {
      items.add(GroupModel.fromJson(maps[i]));
    }
    return items;
  }

  int _firstCount(List<Map<String, Object?>> maps) {
    if (maps.isEmpty) {
      return 0;
    }
    final raw = maps.first['count'];
    if (raw is int) {
      return raw;
    }
    return int.tryParse('${raw ?? 0}') ?? 0;
  }

  Future<List<GroupModel>> page({
    int limit = 1000,
    int offset = 0,
    String where = "",
    List<Object?>? whereArgs,
    String orderBy = '',
  }) async {
    if (where.isEmpty) {
      where = "${GroupRepo.ownerUid} = ? AND ${GroupRepo.status} = 1";
      whereArgs = [UserRepoLocal.to.currentUid];
    }
    if (orderBy.isEmpty) {
      orderBy = "${GroupRepo.createdAt} desc";
    }
    List<Map<String, dynamic>> maps = await _db.query(
      GroupRepo.tableName,
      columns: defaultColumns,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    return _mapsToModels(maps);
  }

  Future<List<GroupModel>> pageByAttr({
    required String attr,
    int limit = 1000,
    int offset = 0,
  }) async {
    final normalizedAttr = _normalizeAttr(attr);
    final currentUid = UserRepoLocal.to.currentUid;

    if (normalizedAttr == 'owner') {
      return page(limit: limit, offset: offset);
    }

    final groupTable = '"${GroupRepo.tableName}"';
    final gmTable = GroupMemberRepo.tableName;
    final orderBy = "g.${GroupRepo.createdAt} DESC";

    String sql;
    List<Object?> params;
    if (normalizedAttr == 'join') {
      sql =
          '''
        SELECT g.*
        FROM $groupTable g
        INNER JOIN $gmTable gm ON gm.${GroupMemberRepo.groupId} = g.${GroupRepo.groupId}
        WHERE g.${GroupRepo.status} = 1
          AND gm.${GroupMemberRepo.status} = 1
          AND gm.${GroupMemberRepo.userId} = ?
          AND g.${GroupRepo.ownerUid} != ?
        ORDER BY $orderBy
        LIMIT ? OFFSET ?
      ''';
      params = [currentUid, currentUid, limit, offset];
    } else if (normalizedAttr == 'all') {
      sql =
          '''
        SELECT DISTINCT g.*
        FROM $groupTable g
        LEFT JOIN $gmTable gm
          ON gm.${GroupMemberRepo.groupId} = g.${GroupRepo.groupId}
         AND gm.${GroupMemberRepo.userId} = ?
         AND gm.${GroupMemberRepo.status} = 1
        WHERE g.${GroupRepo.status} = 1
          AND (
            g.${GroupRepo.ownerUid} = ?
            OR gm.${GroupMemberRepo.userId} = ?
          )
        ORDER BY $orderBy
        LIMIT ? OFFSET ?
      ''';
      params = [currentUid, currentUid, currentUid, limit, offset];
    } else {
      sql =
          '''
        SELECT DISTINCT g.*
        FROM $groupTable g
        LEFT JOIN $gmTable gm ON gm.${GroupMemberRepo.groupId} = g.${GroupRepo.groupId}
        WHERE g.${GroupRepo.status} = 1
          AND (
            g.${GroupRepo.ownerUid} = ?
            OR (
              gm.${GroupMemberRepo.userId} = ?
              AND gm.${GroupMemberRepo.status} = 1
              AND gm.${GroupMemberRepo.role} >= 3
            )
          )
        ORDER BY $orderBy
        LIMIT ? OFFSET ?
      ''';
      params = [currentUid, currentUid, limit, offset];
    }

    final maps = await _db.rawQuery(sql, params);
    return _mapsToModels(List<Map<String, dynamic>>.from(maps));
  }

  /// 兜底读取当前账号下本地激活群（不依赖 owner/member 关系字段）。
  Future<List<GroupModel>> pageActive({
    int limit = 1000,
    int offset = 0,
  }) async {
    final sql =
        '''
      SELECT *
      FROM "${GroupRepo.tableName}"
      WHERE ${GroupRepo.status} = 1
      ORDER BY ${GroupRepo.createdAt} DESC
      LIMIT ? OFFSET ?
    ''';
    final maps = await _db.rawQuery(sql, [limit, offset]);
    return _mapsToModels(List<Map<String, dynamic>>.from(maps));
  }

  Future<int> countByAttr({required String attr}) async {
    final normalizedAttr = _normalizeAttr(attr);
    final currentUid = UserRepoLocal.to.currentUid;
    if (currentUid.isEmpty) {
      return 0;
    }

    final groupTable = '"${GroupRepo.tableName}"';
    final gmTable = GroupMemberRepo.tableName;
    String sql;
    List<Object?> params;

    if (normalizedAttr == 'owner') {
      sql =
          '''
        SELECT COUNT(*) AS count
        FROM $groupTable g
        WHERE g.${GroupRepo.status} = 1
          AND g.${GroupRepo.ownerUid} = ?
      ''';
      params = [currentUid];
    } else if (normalizedAttr == 'join') {
      sql =
          '''
        SELECT COUNT(DISTINCT g.${GroupRepo.groupId}) AS count
        FROM $groupTable g
        INNER JOIN $gmTable gm ON gm.${GroupMemberRepo.groupId} = g.${GroupRepo.groupId}
        WHERE g.${GroupRepo.status} = 1
          AND gm.${GroupMemberRepo.status} = 1
          AND gm.${GroupMemberRepo.userId} = ?
          AND g.${GroupRepo.ownerUid} != ?
      ''';
      params = [currentUid, currentUid];
    } else if (normalizedAttr == 'all') {
      sql =
          '''
        SELECT COUNT(DISTINCT g.${GroupRepo.groupId}) AS count
        FROM $groupTable g
        LEFT JOIN $gmTable gm
          ON gm.${GroupMemberRepo.groupId} = g.${GroupRepo.groupId}
         AND gm.${GroupMemberRepo.userId} = ?
         AND gm.${GroupMemberRepo.status} = 1
        WHERE g.${GroupRepo.status} = 1
          AND (
            g.${GroupRepo.ownerUid} = ?
            OR gm.${GroupMemberRepo.userId} = ?
          )
      ''';
      params = [currentUid, currentUid, currentUid];
    } else {
      sql =
          '''
        SELECT COUNT(DISTINCT g.${GroupRepo.groupId}) AS count
        FROM $groupTable g
        LEFT JOIN $gmTable gm ON gm.${GroupMemberRepo.groupId} = g.${GroupRepo.groupId}
        WHERE g.${GroupRepo.status} = 1
          AND (
            g.${GroupRepo.ownerUid} = ?
            OR (
              gm.${GroupMemberRepo.userId} = ?
              AND gm.${GroupMemberRepo.status} = 1
              AND gm.${GroupMemberRepo.role} >= 3
            )
          )
      ''';
      params = [currentUid, currentUid];
    }

    final maps = await _db.rawQuery(sql, params);
    return _firstCount(List<Map<String, Object?>>.from(maps));
  }

  Future<List<GroupModel>> search({
    required String kwd,
    int limit = 1000,
  }) async {
    String pattern = "%$kwd%";
    List<Map<String, dynamic>> maps = await _db.query(
      GroupRepo.tableName,
      columns: defaultColumns,
      where:
          '${GroupRepo.ownerUid}=? AND ${GroupRepo.status}=1 and ('
          '${GroupRepo.title} like ? or ${GroupRepo.introduction} like ?'
          ')',
      whereArgs: [UserRepoLocal.to.currentUid, pattern, pattern],
      orderBy: "${GroupRepo.createdAt} desc",
      limit: limit,
    );
    return _mapsToModels(maps);
  }

  Future<List<GroupModel>> searchByAttr({
    required String attr,
    required String kwd,
    int limit = 1000,
  }) async {
    final normalizedAttr = _normalizeAttr(attr);
    if (normalizedAttr == 'owner') {
      return search(kwd: kwd, limit: limit);
    }

    final currentUid = UserRepoLocal.to.currentUid;
    final pattern = "%$kwd%";
    final groupTable = '"${GroupRepo.tableName}"';
    final gmTable = GroupMemberRepo.tableName;
    final orderBy = "g.${GroupRepo.createdAt} DESC";

    String sql;
    List<Object?> params;
    if (normalizedAttr == 'join') {
      sql =
          '''
        SELECT g.*
        FROM $groupTable g
        INNER JOIN $gmTable gm ON gm.${GroupMemberRepo.groupId} = g.${GroupRepo.groupId}
        WHERE g.${GroupRepo.status} = 1
          AND gm.${GroupMemberRepo.status} = 1
          AND gm.${GroupMemberRepo.userId} = ?
          AND g.${GroupRepo.ownerUid} != ?
          AND (
            g.${GroupRepo.title} LIKE ?
            OR g.${GroupRepo.introduction} LIKE ?
          )
        ORDER BY $orderBy
        LIMIT ?
      ''';
      params = [currentUid, currentUid, pattern, pattern, limit];
    } else if (normalizedAttr == 'all') {
      sql =
          '''
        SELECT DISTINCT g.*
        FROM $groupTable g
        LEFT JOIN $gmTable gm
          ON gm.${GroupMemberRepo.groupId} = g.${GroupRepo.groupId}
         AND gm.${GroupMemberRepo.userId} = ?
         AND gm.${GroupMemberRepo.status} = 1
        WHERE g.${GroupRepo.status} = 1
          AND (
            g.${GroupRepo.ownerUid} = ?
            OR gm.${GroupMemberRepo.userId} = ?
          )
          AND (
            g.${GroupRepo.title} LIKE ?
            OR g.${GroupRepo.introduction} LIKE ?
          )
        ORDER BY $orderBy
        LIMIT ?
      ''';
      params = [currentUid, currentUid, currentUid, pattern, pattern, limit];
    } else {
      sql =
          '''
        SELECT DISTINCT g.*
        FROM $groupTable g
        LEFT JOIN $gmTable gm ON gm.${GroupMemberRepo.groupId} = g.${GroupRepo.groupId}
        WHERE g.${GroupRepo.status} = 1
          AND (
            g.${GroupRepo.ownerUid} = ?
            OR (
              gm.${GroupMemberRepo.userId} = ?
              AND gm.${GroupMemberRepo.status} = 1
              AND gm.${GroupMemberRepo.role} >= 3
            )
          )
          AND (
            g.${GroupRepo.title} LIKE ?
            OR g.${GroupRepo.introduction} LIKE ?
          )
        ORDER BY $orderBy
        LIMIT ?
      ''';
      params = [currentUid, currentUid, pattern, pattern, limit];
    }

    final maps = await _db.rawQuery(sql, params);
    return _mapsToModels(List<Map<String, dynamic>>.from(maps));
  }

  // 插入一条数据
  @override
  Future<GroupModel> insert(GroupModel obj, {Transaction? txn}) async {
    Map<String, dynamic> insert = {
      GroupRepo.groupId: obj.groupId,
      GroupRepo.type: obj.type,
      GroupRepo.joinLimit: obj.joinLimit,
      GroupRepo.contentLimit: obj.contentLimit,
      GroupRepo.userIdSum: obj.userIdSum,
      GroupRepo.ownerUid: obj.ownerUid,
      GroupRepo.creatorUid: obj.creatorUid,
      GroupRepo.memberMax: obj.memberMax,
      GroupRepo.memberCount: obj.memberCount,
      GroupRepo.introduction: obj.introduction,
      GroupRepo.avatar: obj.avatar,
      GroupRepo.title: obj.title,
      GroupRepo.status: obj.status,
      GroupRepo.updatedAt: obj.updatedAt,
      GroupRepo.createdAt: obj.createdAt,
    };
    if (txn != null) {
      await txn.insert(GroupRepo.tableName, insert);
    } else {
      await _db.insert(GroupRepo.tableName, insert);
    }
    return obj;
  }

  // 根据ID删除信息
  @override
  Future<int> delete(String gid) async {
    return await _db.delete(
      GroupRepo.tableName,
      where: '${GroupRepo.groupId} = ?',
      whereArgs: [gid],
    );
  }

  // 更新信息
  @override
  Future<int> update(
    String gid,
    Map<String, dynamic> json, {
    Transaction? txn,
  }) async {
    Map<String, Object?> data = {};
    // 服务端全量同步与本地局部更新都走这里：
    // 使用 containsKey 判断，保证旧脏数据可被回填修复。
    if (json.containsKey(GroupRepo.type)) {
      data[GroupRepo.type] = json[GroupRepo.type];
    }
    if (json.containsKey(GroupRepo.joinLimit)) {
      data[GroupRepo.joinLimit] = json[GroupRepo.joinLimit];
    }
    if (json.containsKey(GroupRepo.contentLimit)) {
      data[GroupRepo.contentLimit] = json[GroupRepo.contentLimit];
    }
    if (json.containsKey(GroupRepo.userIdSum)) {
      data[GroupRepo.userIdSum] = json[GroupRepo.userIdSum];
    }
    if (json.containsKey(GroupRepo.ownerUid)) {
      data[GroupRepo.ownerUid] = json[GroupRepo.ownerUid];
    }
    if (json.containsKey(GroupRepo.creatorUid)) {
      data[GroupRepo.creatorUid] = json[GroupRepo.creatorUid];
    }
    if (json.containsKey(GroupRepo.memberMax)) {
      data[GroupRepo.memberMax] = json[GroupRepo.memberMax];
    }
    if (json.containsKey(GroupRepo.memberCount)) {
      data[GroupRepo.memberCount] = json[GroupRepo.memberCount];
    }
    if (json.containsKey(GroupRepo.introduction)) {
      data[GroupRepo.introduction] = json[GroupRepo.introduction];
    }
    if (json.containsKey(GroupRepo.avatar)) {
      data[GroupRepo.avatar] = json[GroupRepo.avatar];
    }
    if (json.containsKey(GroupRepo.title)) {
      data[GroupRepo.title] = json[GroupRepo.title];
    }
    if (json.containsKey(GroupRepo.status)) {
      data[GroupRepo.status] = json[GroupRepo.status];
    }
    if (json.containsKey(GroupRepo.updatedAt)) {
      data[GroupRepo.updatedAt] = json[GroupRepo.updatedAt];
    }
    if (json.containsKey(GroupRepo.createdAt)) {
      data[GroupRepo.createdAt] = json[GroupRepo.createdAt];
    }

    if (data.isEmpty) {
      return 0;
    }
    if (gid.isEmpty) {
      gid =
          (json[GroupRepo.groupId] ?? (json['group_id'] ?? (json['gid'] ?? '')))
              .toString();
    }
    iPrint("GroupRepo_update ${data.toString()};");
    if (gid.isNotEmpty) {
      if (txn != null) {
        return await txn.update(
          GroupRepo.tableName,
          data,
          where: '${GroupRepo.groupId} = ?',
          whereArgs: [gid],
        );
      } else {
        return await _db.update(
          GroupRepo.tableName,
          data,
          where: '${GroupRepo.groupId} = ?',
          whereArgs: [gid],
        );
      }
    } else {
      return 0;
    }
  }

  @override
  Future<GroupModel> save(String gid, Map<String, dynamic> json) async {
    if (gid.isEmpty) {
      gid =
          (json[GroupRepo.groupId] ?? (json['group_id'] ?? (json['gid'] ?? '')))
              .toString();
    }
    return await _db.transaction<GroupModel>((txn) async {
      GroupModel? old = await findById(gid, txn: txn);
      iPrint("GroupRepo_save $gid, ${old?.toJson().toString()};");
      if (old == null) {
        GroupModel model = GroupModel.fromJson(json);
        await insert(model, txn: txn);
        return model;
      } else {
        await update(gid, json, txn: txn);
        return (await findById(gid, txn: txn))!;
      }
    });
  }

  @override
  Future<GroupModel?> findById(String gid, {Transaction? txn}) async {
    List<Map<String, dynamic>> maps;
    if (txn != null) {
      maps = await txn.query(
        GroupRepo.tableName,
        columns: [],
        where: '${GroupRepo.groupId} = ?',
        whereArgs: [gid],
      );
    } else {
      maps = await _db.query(
        GroupRepo.tableName,
        columns: [],
        where: '${GroupRepo.groupId} = ?',
        whereArgs: [gid],
      );
    }
    if (maps.isNotEmpty) {
      return GroupModel.fromJson(maps.first);
    } else {
      return null;
    }
  }

  // 记得及时关闭数据库，防止内存泄漏
  // close() async {
  //   await _db.close();
  // }
}
