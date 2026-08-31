/// 群头像 SQL 行为测试（计划 W2 验收标准 2/3 的自动化闭环）。
///
/// 与 db_v17_conversation_mention_unread_test 同一模式：内存 FFI 库 +
/// 精简 DDL + 真跑 `GroupListService.memberAvatarSql()`。
/// SQL 字符串契约（group_avatar_compute_test.dart）锁「SQL 长什么样」，
/// 本文件锁「SQL 跑出来是什么结果」——缺格修复（非好友成员）、群主
/// is_join=0 不丢、user_id 排序稳定、coalesce 优先级、limit 截断。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/page/group/group_list/group_list_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  Future<void> seedGroupMember(
    int gid,
    int uid,
    String avatar, {
    int? isJoin,
  }) async {
    await db.insert('group_member', {
      'id': null,
      'group_id': gid,
      'user_id': uid,
      'avatar': avatar,
      'is_join': isJoin,
      'nickname': 'u$uid',
      'role': 1,
      'status': 1,
    });
  }

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) async {
          await d.execute('''
          CREATE TABLE contact (
            auto_id INTEGER PRIMARY KEY,
            user_id INTEGER NOT NULL,
            peer_id INTEGER NOT NULL,
            avatar TEXT NOT NULL DEFAULT '',
            is_friend INTEGER NOT NULL DEFAULT 0
          )
        ''');
          await d.execute('''
          CREATE TABLE group_member (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            group_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            avatar TEXT NOT NULL DEFAULT '',
            nickname TEXT NOT NULL DEFAULT '',
            role INTEGER NOT NULL DEFAULT 1,
            is_join INTEGER DEFAULT 0,
            status INTEGER NOT NULL DEFAULT 1
          )
        ''');
        },
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<String>> runSql(String gid, String selfUid) async {
    final rows = await db.rawQuery(GroupListService.memberAvatarSql(), [
      gid,
      selfUid,
    ]);
    return GroupListService.rowsToAvatarList(rows);
  }

  test('群主行 is_join=0 仍在拼图（=1 过滤会丢群主，W2 实证场景）', () async {
    const gid = 100;
    await seedGroupMember(gid, 6, 'owner.png', isJoin: 0); // 群主
    await seedGroupMember(gid, 7, 'm7.png', isJoin: 1);

    final li = await runSql(gid.toString(), '999');
    expect(li, contains('owner.png'), reason: '群主 is_join=0 必须出现');
    expect(li, ['owner.png', 'm7.png']); // user_id 升序：6 < 7
  });

  test('非好友成员（无 contact 行）头像出现——contact 驱动表缺格 bug 的行为锁', () async {
    const gid = 101;
    await db.insert('contact', {
      'user_id': 1,
      'peer_id': 10,
      'avatar': 'friend.png',
      'is_friend': 1,
    });
    await seedGroupMember(gid, 10, 'friend.png', isJoin: 1);
    await seedGroupMember(gid, 20, 'stranger.png', isJoin: 1); // 非好友

    final li = await runSql(gid.toString(), '999');
    expect(li, contains('stranger.png'), reason: '非好友成员不得缺格');
  });

  test('coalesce：contact.avatar 优先，group_member 兜底，双空出空串占位', () async {
    const gid = 102;
    await db.insert('contact', {
      'user_id': 1,
      'peer_id': 10,
      'avatar': 'newer.png',
      'is_friend': 1,
    });
    await seedGroupMember(gid, 10, 'older.png', isJoin: 1); // contact 更新
    await seedGroupMember(gid, 11, 'gm_only.png', isJoin: 1); // 无 contact
    await seedGroupMember(gid, 12, '', isJoin: 1); // 双空

    final li = await runSql(gid.toString(), '999');
    expect(li, ['newer.png', 'gm_only.png', '']);
  });

  test('order by user_id：插入乱序、查询多次，输出恒定升序', () async {
    const gid = 103;
    await seedGroupMember(gid, 300, 'c.png', isJoin: 1);
    await seedGroupMember(gid, 100, 'a.png', isJoin: 1);
    await seedGroupMember(gid, 200, 'b.png', isJoin: 1);

    final first = await runSql(gid.toString(), '999');
    final second = await runSql(gid.toString(), '999');
    expect(first, ['a.png', 'b.png', 'c.png']);
    expect(second, first, reason: '同一群两次查询排列必须一致');
  });

  test('limit 9：12 名成员取 user_id 最小的 9 个', () async {
    const gid = 104;
    for (int uid = 1; uid <= 12; uid++) {
      await seedGroupMember(gid, uid, 'u$uid.png', isJoin: 1);
    }
    final li = await runSql(gid.toString(), '999');
    expect(li.length, 9);
    expect(li.first, 'u1.png');
    expect(li.last, 'u9.png');
  });

  test('自己行 is_join 脏值（NULL）仍被 or user_id 兜底查出', () async {
    const gid = 105;
    await db.insert('group_member', {
      'id': null,
      'group_id': gid,
      'user_id': 42,
      'avatar': 'self.png',
      'is_join': null, // 脏值
      'nickname': 'self',
      'role': 1,
      'status': 1,
    });
    final li = await runSql(gid.toString(), '42');
    expect(li, ['self.png'], reason: 'or gm.user_id = ? 兜底自己行');
  });

  test('其他群成员不串场（group_id 过滤）', () async {
    await seedGroupMember(200, 1, 'other.png', isJoin: 1);
    await seedGroupMember(201, 2, 'mine.png', isJoin: 1);
    final li = await runSql('201', '999');
    expect(li, ['mine.png']);
  });
}
