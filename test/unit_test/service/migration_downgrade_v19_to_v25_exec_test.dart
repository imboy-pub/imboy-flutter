// v19~v25 降级块的真实执行集成测试（ffi in-memory DB）
// Real execution of v19–v25 downgrade chain on in-memory SQLite
//
// 解析层测试（migration_downgrade_v19_to_v25_test.dart）只守护"块存在"。
// 本测试用 sqflite_common_ffi 真实执行完整 v25→v18 降级链，验证：
//   - 重建表 DDL 语法正确（列清单/INSERT/索引）
//   - 数据在删列/重建后保留（content 行不丢）
//   - 每步 PRAGMA user_version 归位到目标版本
// 这是 A-21 缺口修复的关键正确性验证——只写脚本不真跑，语法错会在
// 生产降级时才炸。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/embedded_schema_scripts.dart';
import 'package:imboy/service/migration_script.dart';
import 'package:imboy/service/migration_script_planner.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 构造 v25 完整 schema（含 v18~v25 全部新列/新表），与升级脚本对齐。
/// 只建本测试涉及的 5 张表：group_member / moment_notify / user_collect /
/// channel_message / msg_c2c（contact 的 account_type 在 v24 单独覆盖）。
Future<void> createV25Schema(Database db) async {
  // group_member 含 mute_until（v19 新增）
  await db.execute('''
    CREATE TABLE group_member (
      id INTEGER PRIMARY KEY,
      group_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      nickname TEXT DEFAULT '',
      avatar TEXT DEFAULT '',
      sign TEXT DEFAULT '',
      account TEXT DEFAULT '',
      invite_code TEXT DEFAULT '',
      alias TEXT DEFAULT '',
      description TEXT DEFAULT '',
      role INTEGER DEFAULT 0,
      is_join INTEGER DEFAULT 0,
      join_mode TEXT,
      status INTEGER NOT NULL DEFAULT 1,
      updated_at INTEGER DEFAULT 0,
      created_at INTEGER NOT NULL,
      mute_until INTEGER DEFAULT NULL
    )
  ''');
  await db.execute(
    'CREATE UNIQUE INDEX uk_Gid_Uid ON group_member (group_id, user_id)',
  );
  await db.execute(
    'CREATE INDEX idx_group_member_mute_until ON group_member (group_id, user_id) WHERE mute_until IS NOT NULL',
  );

  // moment_notify（v20/v21 新增）
  await db.execute('''
    CREATE TABLE moment_notify (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      action TEXT NOT NULL,
      moment_id TEXT NOT NULL,
      from_uid TEXT NOT NULL,
      comment_id TEXT,
      is_read INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )
  ''');
  await db.execute(
    'CREATE UNIQUE INDEX uq_moment_notify_dedup ON moment_notify(user_id, action, moment_id, from_uid, COALESCE(comment_id, \'\'))',
  );
  await db.execute(
    'CREATE INDEX idx_moment_notify_user_read ON moment_notify(user_id, is_read, created_at DESC)',
  );

  // user_collect（v22 后：kind_id TEXT）
  await db.execute('''
    CREATE TABLE user_collect (
      auto_id INTEGER PRIMARY KEY,
      user_id INTEGER NOT NULL,
      kind INTEGER NOT NULL DEFAULT 0,
      kind_id TEXT NOT NULL DEFAULT '',
      source TEXT NOT NULL DEFAULT '',
      remark TEXT NOT NULL DEFAULT '',
      tag TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT 0,
      info TEXT DEFAULT ''
    )
  ''');
  await db.execute(
    'CREATE UNIQUE INDEX i_Uid_KindId ON user_collect (user_id, kind_id)',
  );

  // channel_message 含 my_reactions（v23 新增）
  await db.execute('''
    CREATE TABLE channel_message (
      id INTEGER PRIMARY KEY,
      channel_id INTEGER NOT NULL,
      author_id INTEGER,
      author_name TEXT,
      author_avatar TEXT,
      content TEXT,
      msg_type TEXT NOT NULL,
      payload TEXT,
      created_at INTEGER NOT NULL,
      is_pinned INTEGER DEFAULT 0,
      view_count INTEGER DEFAULT 0,
      reaction_summary TEXT,
      my_reactions TEXT
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_channel_msg_channel_id ON channel_message(channel_id)',
  );

  // contact 含 account_type（v24 新增）——v24 降级块会重建它
  await db.execute('''
    CREATE TABLE contact (
      auto_id INTEGER PRIMARY KEY,
      user_id INTEGER NOT NULL,
      peer_id INTEGER NOT NULL,
      nickname TEXT NOT NULL DEFAULT '',
      avatar TEXT NOT NULL DEFAULT '',
      gender INTEGER NOT NULL DEFAULT 0,
      account TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL DEFAULT '',
      remark TEXT DEFAULT '',
      tag TEXT DEFAULT '',
      region TEXT DEFAULT '',
      sign TEXT NOT NULL DEFAULT '',
      source TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL DEFAULT 0,
      is_friend INTEGER NOT NULL DEFAULT 0,
      is_from INTEGER NOT NULL DEFAULT 0,
      category_id INTEGER NOT NULL DEFAULT 0,
      last_seen_at INTEGER,
      account_type INTEGER NOT NULL DEFAULT 0
    )
  ''');
  await db.execute(
    'CREATE UNIQUE INDEX uk_FromTo ON contact (user_id, peer_id)',
  );

  // msg_c2c 含 sender_did（v25 新增）
  await db.execute('''
    CREATE TABLE msg_c2c (
      auto_id INTEGER PRIMARY KEY,
      id INTEGER NOT NULL,
      msg_type TEXT,
      from_id INTEGER,
      to_id INTEGER,
      conversation_uk3 TEXT,
      e2ee TEXT,
      payload TEXT,
      created_at INTEGER,
      topic_id INTEGER,
      status INTEGER,
      is_author INTEGER,
      type TEXT DEFAULT 'C2C',
      action TEXT DEFAULT '',
      sender_did TEXT
    )
  ''');
  await db.execute('CREATE UNIQUE INDEX uk_MsgId ON msg_c2c (id)');

  await db.execute('PRAGMA user_version = 25');
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> runPlan(Database db, List<MigrationScript> plan) async {
    for (final script in plan) {
      for (final sql in script.sqlStatements) {
        await db.execute(sql);
      }
    }
  }

  Future<Map<int, MigrationScript>> loadDowngradeScripts() async {
    await MigrationService.to.init();
    return MigrationService.to.debugDowngradeScripts;
  }

  group('v25→v18 真实降级链', () {
    test('planner 规划降序且逐块执行成功、数据保留', () async {
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      addTearDown(() => db.close());
      await createV25Schema(db);

      // 插入各表样本数据
      await db.insert('group_member', {
        'id': 1,
        'group_id': 10,
        'user_id': 20,
        'nickname': 'member1',
        'status': 1,
        'created_at': 1000,
        'mute_until': 9999999999999,
      });
      await db.insert('moment_notify', {
        'user_id': '1',
        'action': 'moment_like',
        'moment_id': '100',
        'from_uid': '2',
        'comment_id': null,
        'is_read': 0,
        'created_at': 1000,
      });
      await db.insert('user_collect', {
        'auto_id': 1,
        'user_id': 1,
        'kind': 1,
        'kind_id': 'abc123',
        'created_at': 1000,
      });
      await db.insert('channel_message', {
        'id': 1,
        'channel_id': 5,
        'content': 'hello',
        'msg_type': 'channel_text',
        'created_at': 1000,
        'my_reactions': '["\u{1F44D}"]',
      });
      await db.insert('msg_c2c', {
        'auto_id': 1,
        'id': 1,
        'from_id': 100,
        'to_id': 200,
        'payload': 'msg1',
        'created_at': 1000,
        'sender_did': 'device-1',
      });

      final scripts = await loadDowngradeScripts();
      final plan = MigrationScriptPlanner.plan(
        scripts: scripts,
        fromVersion: 25,
        toVersion: 18,
      );
      // 降序：25 → 24 → ... → 19
      expect(plan.map((s) => s.version).toList(), [25, 24, 23, 22, 21, 20, 19]);

      await runPlan(db, plan);

      // 降级后 user_version = 18
      final ver = await db.rawQuery('PRAGMA user_version');
      expect(int.parse('${ver.first.values.first}'), 18);

      // group_member：mute_until 列已移除，数据保留
      final gmCols = await db.rawQuery('PRAGMA table_info(group_member)');
      expect(gmCols.map((c) => c['name']), isNot(contains('mute_until')));
      final gm = await db.query('group_member');
      expect(gm, hasLength(1));
      expect(gm.first['nickname'], 'member1');

      // moment_notify：表已删除
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='moment_notify'",
      );
      expect(tables, isEmpty);

      // user_collect：kind_id 已回退为 INTEGER 列，数据保留
      final ucCols = await db.rawQuery('PRAGMA table_info(user_collect)');
      final kindId = ucCols.firstWhere((c) => c['name'] == 'kind_id');
      expect(kindId['type'], 'INTEGER');
      final uc = await db.query('user_collect');
      expect(uc, hasLength(1));
      expect(uc.first['kind_id'], isA<int>());

      // channel_message：my_reactions 列移除，content 保留
      final cmCols = await db.rawQuery('PRAGMA table_info(channel_message)');
      expect(cmCols.map((c) => c['name']), isNot(contains('my_reactions')));
      final cm = await db.query('channel_message');
      expect(cm.first['content'], 'hello');

      // msg_c2c：sender_did 列移除，payload 保留
      final mcCols = await db.rawQuery('PRAGMA table_info(msg_c2c)');
      expect(mcCols.map((c) => c['name']), isNot(contains('sender_did')));
      final mc = await db.query('msg_c2c');
      expect(mc.first['payload'], 'msg1');
    });
  });
}
