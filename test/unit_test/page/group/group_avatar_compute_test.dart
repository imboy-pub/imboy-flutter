import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';

/// 回归锁：群头像拼图数据源的确定性契约（计划 W2，2026-08-31）。
///
/// 原实现三个缺陷：①以 contact 为驱动表 LEFT JOIN group_member，非好友
/// 成员头像出不来（拼图缺格）；②无 ORDER BY，同一群不同时刻拼图排列
/// 漂移，观感像「换了头像」；③自己头像手动插首位 + 服务端回退可能重复。
///
/// SQL 方向本身要靠真机/集成验证（同 group_member_names_test 的取法），
/// 这里锁死 SQL 骨架与两个纯函数的输出契约。
void main() {
  group('GroupListService.memberAvatarSql SQL 契约', () {
    final sql = GroupListService.memberAvatarSql();

    test('驱动表是 group_member，contact 只做 LEFT JOIN 补头像', () {
      // group_member 必须是 from 的主表；contact 只能出现在 left join。
      expect(sql.contains('from group_member as gm'), isTrue);
      expect(sql.contains('left join contact as c'), isTrue);
      expect(
        sql.contains('from contact'),
        isFalse,
        reason: 'contact 驱动表会丢非好友成员（已修 bug 不得回退）',
      );
    });

    test('order by gm.user_id：拼图排列恒定', () {
      expect(
        sql.contains('order by gm.user_id'),
        isTrue,
        reason: '无确定性排序会导致同一群拼图漂移',
      );
    });

    test('is_join in (0, 1)：群主行 is_join=0 不被过滤掉', () {
      // 写入侧 _syncSelfMembershipShadow 对 owner 强制 is_join=0，
      // 过滤 = 1 会让群主头像从拼图消失。
      expect(sql.contains('is_join in (0, 1)'), isTrue);
      expect(sql.contains('is_join = 1'), isFalse);
    });

    test('or gm.user_id = ? 兜底自己行的 is_join 脏值', () {
      expect(sql.contains('or gm.user_id = ?'), isTrue);
    });

    test('头像列 coalesce：contact 优先、group_member 兜底', () {
      expect(
        sql.contains("coalesce(c.avatar, gm.avatar, '') as avatar"),
        isTrue,
        reason: 'group_member 自带 avatar，非好友成员不依赖 contact 也有头像',
      );
    });
  });

  group('GroupListService.rowsToAvatarList 本地行 → 列表', () {
    test('空头像保留占位，格数与成员数一致', () {
      final li = GroupListService.rowsToAvatarList([
        {'avatar': 'u1'},
        {'avatar': ''},
        {'avatar': 'u2'},
      ]);
      expect(li, ['u1', '', 'u2']);
    });

    test('null 头像列按空串占位', () {
      final li = GroupListService.rowsToAvatarList([
        {'avatar': null},
        {'avatar': 'u1'},
      ]);
      expect(li, ['', 'u1']);
    });

    test('全员空头像返回空列表，走默认群图而非灰格拼图', () {
      final li = GroupListService.rowsToAvatarList([
        {'avatar': ''},
        {'avatar': null},
      ]);
      expect(li, isEmpty);
    });

    test('行序即输出序（SQL 已 order by user_id，纯函数不再排序）', () {
      final li = GroupListService.rowsToAvatarList([
        {'avatar': 'c'},
        {'avatar': 'a'},
        {'avatar': 'b'},
      ]);
      expect(li, ['c', 'a', 'b']);
    });
  });

  group('GroupListService.serverRowsToAvatarList 服务端回退 → 列表', () {
    const selfUid = '100';
    const selfAvatar = 'me.png';

    List<Map<String, dynamic>> rows(List<(int, String)> pairs) => [
      for (final p in pairs)
        {GroupMemberRepo.userId: p.$1, GroupMemberRepo.avatar: p.$2},
    ];

    test('按 user_id 升序输出，与本地分支同一确定性顺序', () {
      final li = GroupListService.serverRowsToAvatarList(
        rows([(30, 'c'), (10, 'a'), (20, 'b')]),
        selfUid: '',
        selfAvatar: '',
      );
      expect(li, ['a', 'b', 'c']);
    });

    test('服务端未返回自己时用自己的头像补位（至少显示自己的兜底）', () {
      final li = GroupListService.serverRowsToAvatarList(
        rows([(200, 'a'), (300, 'b')]),
        selfUid: selfUid,
        selfAvatar: selfAvatar,
      );
      // selfUid=100 < 200 < 300，按 user_id 排序后自己在首位
      expect(li, [selfAvatar, 'a', 'b']);
    });

    test('服务端返回了自己时不重复插队', () {
      final li = GroupListService.serverRowsToAvatarList(
        rows([(100, 'server_me'), (200, 'a')]),
        selfUid: selfUid,
        selfAvatar: selfAvatar,
      );
      expect(li, ['server_me', 'a']);
    });

    test('空头像保留占位，格数稳定', () {
      final li = GroupListService.serverRowsToAvatarList(
        rows([(100, ''), (200, 'a')]),
        selfUid: '',
        selfAvatar: '',
      );
      expect(li, ['', 'a']);
    });

    test('全员空头像（含自己）返回空列表走默认群图', () {
      final li = GroupListService.serverRowsToAvatarList(
        rows([(100, '')]),
        selfUid: selfUid,
        selfAvatar: '',
      );
      expect(li, isEmpty);
    });

    test('user_id 非法的行跳过', () {
      final li = GroupListService.serverRowsToAvatarList(
        rows([(0, 'bad'), (200, 'a')]),
        selfUid: '',
        selfAvatar: '',
      );
      expect(li, ['a']);
    });
  });
}
