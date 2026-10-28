import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/list_cursor_client.dart' show CursorPage;
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
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';

/// 群组列表服务类 - 处理业务逻辑
class GroupListService {
  /// W07.c 收尾（C2）：manifest 清单合同声明才启用个人群游标协议；
  /// 未声明 → 全部 legacy page/size 路径逐字节零变化（J27.a/b）。
  bool get _cursorGateEnabled =>
      AppManifestService.manifest?.listCursorGateEnabled ?? false;

  /// 服务端游标 limit 上限（group_handler resolve_cursor_limit: 1..200）。
  static const int _cursorPageCap = 200;

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

  /// W07.c 收尾：manifest 门开启时的个人群游标拉取循环。
  ///
  /// token 线程化翻页：取满 [want] 条（null = 至终止页）或 next_cursor
  /// 为空（终止页契约）即停；每页行即时落库 + 成员阴影同步（部分失败
  /// 保留已完成部分）。服务端拒绝（绑定不符/篡改/过期 400）**不回落
  /// 第 1 页**（J27.c）：记录并终止，返回已同步部分——与 legacy
  /// `payload == null → 终止` 同类，绝无第一页伪全量。
  Future<List<GroupModel>> _pullAndSyncViaCursor({
    required String attr,
    int? want,
    int maxPages = 20,
  }) async {
    final repo = GroupRepo();
    final acc = <GroupModel>[];
    String? token;
    for (var p = 0; p < maxPages; p++) {
      if (want != null && acc.length >= want) break;
      final CursorPage<Map<String, dynamic>> page;
      try {
        page = await GroupApi().pageCursor(
          attr: attr,
          token: token,
          limit: want == null ? _cursorPageCap : want.clamp(1, _cursorPageCap),
        );
      } catch (e, s) {
        iPrint(
          "GroupListService cursor pull attr=$attr page=${p + 1} "
          "rejected: $e\n$s",
        );
        break;
      }
      for (final item in page.list) {
        final group = await repo.save('', item);
        await _syncSelfMembershipShadow(attr: attr, group: group);
        acc.add(group);
      }
      token = page.nextCursor;
      if (token == null) break; // 终止页契约：空 next_cursor 收口
    }
    return acc;
  }

  Future<List<GroupModel>> _pullAndSyncAllViews({
    required int page,
    required int size,
    required int offset,
  }) async {
    final repo = GroupRepo();
    final merged = <int, GroupModel>{};
    for (final attr in const ['manager', 'join', 'owner']) {
      if (_cursorGateEnabled) {
        for (final group in await _pullAndSyncViaCursor(
          attr: attr,
          want: size,
        )) {
          merged[group.groupId] = group;
        }
        continue;
      }
      final payload = await GroupApi().page(page: page, size: size, attr: attr);
      if (payload == null) {
        continue;
      }
      final rows = payload['list'];
      if (rows is! List || rows.isEmpty) {
        continue;
      }
      for (final item in rows) {
        if (item is! Map<String, dynamic>) {
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
    final existed = await gmRepo.findByUserId(
      group.groupId.toString(),
      currentUid,
    );
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

    // W07.c 收尾：门开启走签名游标循环（终止页契约收口）；失败中断时
    // 已同步部分保留，与 legacy `payload == null → break` 同类。
    if (_cursorGateEnabled) {
      return (await _pullAndSyncViaCursor(
        attr: normalizedAttr,
        maxPages: maxPages,
      )).length;
    }

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
        if (item is! Map<String, dynamic>) {
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

  /// 计算群组头像（成员头像 URL 列表，九宫格拼图数据源）。
  ///
  /// 确定性契约（group_avatar_compute_test.dart 锁死）：
  /// - 驱动表是 group_member：非好友成员也能出头像。原 SQL 以 contact 为
  ///   驱动表 LEFT JOIN group_member、`gm.group_id = ?` 落在被 join 表上，
  ///   只能取到同时是我好友的成员，拼图缺格（computeTitle 修过的同款 bug）。
  /// - `order by gm.user_id`：同一群任何时刻排列一致，不随查询时刻/位置漂移。
  /// - `is_join in (0, 1)`：0=群主 1=普通成员（写入侧见 _syncSelfMembershipShadow
  ///   的 owner 分支强制 0，消费侧见 remove_member_provider 过滤注释），用 in
  ///   而非 `= 1`，否则群主头像从拼图消失；`or gm.user_id = ?` 兜底自己行的
  ///   is_join 脏值（DDL DEFAULT 0，正常写入只会是 0/1）。
  /// - 空头像保留占位：格子顺序由 user_id 决定，不因缺头像漂移；GroupAvatar
  ///   对空串渲染灰格（avatar_group.dart _buildAvatarTile）。
  Future<List<String>> computeAvatar(String gid) async {
    const limit = 9;
    final String currentUid = UserRepoLocal.to.currentUid;
    Database? db = await SqliteService.to.db;
    if (db == null) {
      return [];
    }
    List<Map<String, dynamic>> list = await db.rawQuery(
      memberAvatarSql(limit: limit),
      [gid, currentUid],
    );
    if (list.isNotEmpty) {
      return rowsToAvatarList(list);
    }

    // 本地无成员行（新装/冷数据）：服务端拉一页，落库后按与本地分支同一
    // 规则（user_id 升序、自己去重、空位保留）返回。
    Map<String, dynamic>? payload = await GroupMemberApi().page(
      gid: gid,
      size: limit,
    );
    if (payload == null || payload['list'] == null) {
      return [];
    }
    final rows = <Map<String, dynamic>>[];
    for (var item in IMBoyHttpResponse.payloadList(payload)) {
      await GroupMemberRepo().save(item);
      rows.add(item);
    }
    return serverRowsToAvatarList(
      rows,
      selfUid: currentUid,
      selfAvatar: UserRepoLocal.to.current.avatar,
    );
  }

  /// computeAvatar 的 SQL。抽成静态方法便于契约测试锁死驱动表方向、
  /// 排序与 is_join 过滤 —— 这三处任何一处回退都会复活已修的缺格/漂移 bug。
  static String memberAvatarSql({int limit = 9}) {
    return "select coalesce(c.${ContactRepo.avatar}, gm.${GroupMemberRepo.avatar}, '') as avatar"
        " from ${GroupMemberRepo.tableName} as gm"
        " left join ${ContactRepo.tableName} as c"
        " on c.${ContactRepo.peerId} = gm.${GroupMemberRepo.userId}"
        " where gm.${GroupMemberRepo.groupId} = ?"
        " and (gm.${GroupMemberRepo.isJoin} in (0, 1)"
        " or gm.${GroupMemberRepo.userId} = ?)"
        " order by gm.${GroupMemberRepo.userId}"
        " limit $limit;";
  }

  /// 本地 SQL 行 → 头像列表。空串保留占位（顺序由 user_id 决定），
  /// 全员空头像时返回空列表交由 GroupAvatar 走默认群图（灰格拼图不如
  /// 默认图直观）。
  static List<String> rowsToAvatarList(List<Map<String, dynamic>> rows) {
    final li = [for (final e in rows) (e['avatar'] as String? ?? '')];
    if (li.every((url) => url.isEmpty)) {
      return [];
    }
    return li;
  }

  /// 服务端回退分支的列表构造：按 user_id 升序输出，与本地分支同一
  /// 确定性顺序（同一群冷启动两次排列一致）；服务端未返回自己时用自己的
  /// 头像补位（对齐原实现「至少显示自己」的兜底），返回了则不重复插队
  /// （原实现自己固定首位 + 服务端可能再带一份，会重复）。
  static List<String> serverRowsToAvatarList(
    List<Map<String, dynamic>> rows, {
    required String selfUid,
    required String selfAvatar,
  }) {
    final byUid = <int, String>{
      if (selfUid.isNotEmpty) int.tryParse(selfUid) ?? 0: selfAvatar,
    };
    for (final row in rows) {
      final uid = parseModelInt(row[GroupMemberRepo.userId]);
      if (uid <= 0) {
        continue;
      }
      byUid[uid] = (row[GroupMemberRepo.avatar] as String? ?? '').trim();
    }
    final uids = byUid.keys.toList()..sort();
    final li = [for (final uid in uids) byUid[uid]!];
    if (li.every((url) => url.isEmpty)) {
      return [];
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
    final String currentUid = UserRepoLocal.to.currentUid;
    // 原 SQL 以 contact 为驱动表 LEFT JOIN group_member，过滤条件
    // `gm.group_id = ?` 却落在被 join 的表上 —— 实际只能取到**同时是我好友**
    // 的群成员，非好友成员一个都出不来。
    //
    // 群成员名的权威来源是 group_member 自己，contact 只用来补「好友备注」。
    // 同时排除自己，否则只剩自己的无名群会显示成自己的昵称。
    //
    // 📝 一处更正：清单曾把「两个群都显示 IMBoy」记为本函数的缺陷。
    // 真机复验后不成立 —— 那两个群都是 2 人群、另一位成员确实都是 IMBoy，
    // 同名是数据决定的，微信同样如此。本次改的是「取不到非好友成员」
    // 与「没排除自己」这两个真问题，不改变那个场景的显示结果。
    String sql =
        "select gm.${GroupMemberRepo.alias} as alias"
        ", gm.${GroupMemberRepo.nickname} as nickname"
        ", gm.${GroupMemberRepo.account} as account"
        ", c.${ContactRepo.remark} as remark"
        " from ${GroupMemberRepo.tableName} as gm"
        " left join ${ContactRepo.tableName} as c"
        " on c.${ContactRepo.peerId} = gm.${GroupMemberRepo.userId}"
        " where gm.${GroupMemberRepo.groupId} = ?"
        " and gm.${GroupMemberRepo.userId} != ?"
        " limit $limit;";
    Database? db = await SqliteService.to.db;
    if (db == null) {
      iPrint("computeTitle: database is null");
      return '';
    }

    try {
      List<Map<String, dynamic>> list = await db.rawQuery(sql, [
        gid,
        currentUid,
      ]);
      iPrint("computeTitle $gid, ${list.length} members found in local db");

      if (list.isNotEmpty) {
        final names = pickMemberNames(list);
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
        final rows = <Map<String, dynamic>>[];

        for (var item in IMBoyHttpResponse.payloadList(payload)) {
          await repo.save(item);
          // 与本地分支同一条约定：排除自己
          if (item[GroupMemberRepo.userId]?.toString() == currentUid) {
            continue;
          }
          rows.add(item);
        }

        final names = pickMemberNames(rows);
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

  /// 从群成员行里挑展示名，优先级：群内别名 → 好友备注 → 昵称 → 账号。
  ///
  /// 抽成静态纯函数是为了能脱离 SQLite 单例做契约测试 ——
  /// BUG#4 家族的坑就在于取名逻辑散落在本地/服务端两个分支里各写一遍。
  static List<String> pickMemberNames(List<Map<String, dynamic>> rows) {
    final names = <String>[];
    for (final row in rows) {
      for (final key in const ['alias', 'remark', 'nickname', 'account']) {
        final value = (row[key]?.toString() ?? '').trim();
        if (value.isNotEmpty) {
          names.add(value);
          break;
        }
      }
    }
    return names;
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
    // W07.c 收尾：门开启走签名游标循环，取满 offset+size 条后按本地
    // 视图切片返回（legacy 单页请求在游标协议下不可跳页，改由累计
    // 覆盖——无第一页伪全量）。
    if (_cursorGateEnabled) {
      final synced = await _pullAndSyncViaCursor(
        attr: normalizedAttr,
        want: offset + size,
      );
      return synced.length > offset ? synced.sublist(offset) : <GroupModel>[];
    }
    Map<String, dynamic>? payload = await GroupApi().page(
      page: page,
      size: size,
      attr: normalizedAttr,
    );
    if (payload == null) {
      return [];
    }
    for (var json in IMBoyHttpResponse.payloadList(payload)) {
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
      await gRepo.save(groupId, {GroupRepo.memberCount: g.memberCount + 1});
    }
    return {"isFirst": gm == null ? true : false};
  }

  /// 成员离开群组
  Future<void> memberLeave({
    required String groupId,
    required String userId,
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
      await gRepo.save(groupId, {GroupRepo.memberCount: g!.memberCount - 1});
    }
    // 本地成员落库后 fire：群头像拼图缓存（GroupAvatarMemberCache）按 gid
    // 即时失效，返回会话列表立刻反映成员变化。
    AppEventBus.fire(
      GroupMemberUpdateEvent(
        groupId: groupId,
        userId: userId,
        changeType: 'leave',
      ),
    );
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
