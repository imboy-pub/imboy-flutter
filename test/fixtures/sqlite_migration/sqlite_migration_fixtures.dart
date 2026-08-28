// SQLite 迁移测试 fixture 生成器（WP0，无 PII）
// SQLite migration test fixture builder (WP0, PII-free).
//
// 设计原则：fixture 不手工维护 SQL 副本，而是**从生产真源**
// （kBaselineSchemaSql / kUpgradeScriptSql）在 sqflite_common_ffi
// in-memory 库上真实执行构建任意版本 schema。这样 fixture 永远不会
// 与生产迁移脚本漂移；新增版本块后 fixture 自动覆盖。
//
// 两条构建路径与生产一致：
//   - version >= 16：执行 kBaselineSchemaSql（= SqliteService._onCreate
//     加密平台建库路径）→ user_version=16 → 执行 (16, version] 升级块。
//   - version <= 15：v9 legacy mini schema（旧表名形态，受支持的最老
//     升级起点）→ 执行 (9, version] 升级块。v15 为历史跳号，无块。
//
// 已知现状复刻（非认可）：生产 MigrationService.migrate 通过字符串匹配
// 吞掉所有 "duplicate column" 错误（v11/v12 块对 v10 已加列的重复 ALTER
// 依赖此行为幂等）。fixture 的 upgrade 执行器复刻同一行为，保证 fixture
// 构建结果与生产迁移结果一致；WP2 收紧生产吞错时必须同步收紧此处。
library;

import 'package:imboy/service/embedded_schema_scripts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 解析 `-- VERSION:` 分块脚本（规则与 MigrationService._parseMigrationScripts
/// 一致：按 '-- VERSION:' 切分、首行取版本号、跳过注释/空行、行尾 ';'
/// 作为语句边界、末尾残句补收）。
///
/// 返回 {起始版本号: 语句列表}。VERSION:9 空占位块映射为空列表。
Map<int, List<String>> parseMigrationVersionBlocks(String content) {
  final blocks = <int, List<String>>{};
  for (final block in content.split('-- VERSION:').skip(1)) {
    final lines = block.split('\n');
    if (lines.isEmpty) continue;
    final version = int.tryParse(lines[0].trim());
    if (version == null) continue;

    final statements = <String>[];
    final current = StringBuffer();
    for (final line in lines.skip(1)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('--')) continue;
      current.write(line);
      current.write('\n');
      if (trimmed.endsWith(';')) {
        statements.add(current.toString().trim());
        current.clear();
      }
    }
    if (current.isNotEmpty) statements.add(current.toString().trim());
    blocks[version] = statements;
  }
  return blocks;
}

/// 执行 baseline 建库脚本，语义与 SqliteService._onCreate 加密平台路径
/// 一致：按 ';' 切分、过滤空/注释语句、跳过 sqlite_ 内部对象、
/// 忽略 "already exists"（幂等）。
///
/// 与生产的已知偏差（WP0 计划外发现 #1）：baseline 内含 fts5 影子表的
/// 显式 DDL（'msg_c2c_fts_data' 等）。影子表由 CREATE VIRTUAL TABLE
/// 自动创建，新版 SQLite（含 sqflite_common_ffi）对显式 DDL 报
/// "object name reserved for internal use" 而生产 SQLCipher 打包的
/// 老版本容忍。两种情况下最终 schema 等价（影子表均由 fts5 接管），
/// 故此处跳过该类错误；该偏差已登记进基线报告，待后续 WP 评估
/// 是否从 baseline SQL 移除影子表 DDL。
Future<void> applyBaselineSchema(Database db) async {
  final statements = kBaselineSchemaSql
      .split(';')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && !s.startsWith('--'))
      .toList();

  for (final sql in statements) {
    if (sql.toLowerCase().contains('sqlite_')) continue;
    try {
      await db.execute(sql);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('already exists')) continue;
      if (msg.contains('reserved for internal use')) continue;
      rethrow;
    }
  }
}

/// v9 legacy 最小 schema：旧表名消息四表（无 type/msg_type/action/e2ee 列）
/// + upgrade VERSION:16 重建所涉及的 4 张旧形态表。
///
/// 列清单从 upgrade.sql VERSION:10（ALTER 基础列）与 VERSION:16
/// （INSERT … SELECT 引用列）反推；旧形态 user_id 等为 TEXT
/// （v16 重建时 CAST AS INTEGER），故此处统一宽松 TEXT。
Future<void> applyV9LegacySchema(Database db) async {
  // ---- 旧表名消息四表（v10 块在其上 ADD COLUMN + RENAME）----
  // 列名对齐升级链真实形态：主键是 auto_id（v14 块索引
  // idx_msg_*_unread_count 引用 auto_id；baseline msg_c2c 同为
  // auto_id 主键 + id 业务列）。downgrade VERSION:10 重建的 message
  // 用 id 主键是降级产物形态，与升级起点不同——勿混用。
  const legacyMsgBase = '''
      auto_id INTEGER PRIMARY KEY AUTOINCREMENT,
      id INTEGER NOT NULL DEFAULT 0,
      from_id TEXT NOT NULL,
      to_id TEXT NOT NULL,
      payload TEXT NOT NULL,
      status INTEGER NOT NULL DEFAULT 0,
      is_author INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      conversation_uk3 TEXT NOT NULL,
      topic_id INTEGER NOT NULL DEFAULT 0
  ''';
  for (final table in [
    'message',
    'group_message',
    'c2s_message',
    's2c_message',
  ]) {
    await db.execute('CREATE TABLE $table ($legacyMsgBase)');
  }

  // ---- v16 块重建涉及的旧形态表（INSERT ... SELECT 的数据源）----
  await db.execute('''
    CREATE TABLE contact (
      auto_id INTEGER PRIMARY KEY,
      user_id TEXT, peer_id TEXT,
      nickname TEXT DEFAULT '', avatar TEXT DEFAULT '',
      gender TEXT DEFAULT '0', account TEXT DEFAULT '',
      status TEXT DEFAULT '', remark TEXT DEFAULT '',
      tag TEXT DEFAULT '', region TEXT DEFAULT '',
      sign TEXT DEFAULT '', source TEXT DEFAULT '',
      updated_at TEXT DEFAULT '0',
      is_friend TEXT DEFAULT '0', is_from TEXT DEFAULT '0',
      category_id TEXT DEFAULT '0'
    )
  ''');
  await db.execute('''
    CREATE TABLE new_friend (
      auto_id INTEGER PRIMARY KEY,
      uid TEXT, from_id TEXT, to_id TEXT,
      nickname TEXT DEFAULT '', avatar TEXT DEFAULT '',
      msg TEXT DEFAULT '', status TEXT DEFAULT '',
      payload TEXT DEFAULT '',
      updated_at TEXT DEFAULT '0', created_at TEXT DEFAULT '0'
    )
  ''');
  await db.execute('''
    CREATE TABLE user_denylist (
      auto_id INTEGER PRIMARY KEY,
      user_id TEXT, denied_user_id TEXT,
      nickname TEXT DEFAULT '', avatar TEXT DEFAULT '',
      gender TEXT DEFAULT '0', account TEXT DEFAULT '',
      region TEXT DEFAULT '', sign TEXT DEFAULT '',
      source TEXT DEFAULT '', remark TEXT DEFAULT '',
      created_at TEXT DEFAULT '0'
    )
  ''');
  await db.execute('''
    CREATE TABLE user_device (
      auto_id INTEGER PRIMARY KEY,
      user_id TEXT,
      device_id TEXT, device_name TEXT, device_type TEXT,
      last_active_at TEXT, device_vsn TEXT
    )
  ''');

  // ---- 升级链 INSERT…SELECT 数据引用的其余存量表（v22 user_collect
  // 重建、v16/17 user_tag/group_notice/group_member/user_group/
  // conversation 重建的数据源）。列名与对应重建块的 SELECT 清单对齐，
  // 类型宽松（旧库形态，重建时统一 CAST 收紧）。
  await db.execute('''
    CREATE TABLE user_collect (
      auto_id INTEGER PRIMARY KEY,
      user_id TEXT, kind TEXT DEFAULT '0',
      kind_id TEXT DEFAULT '', source TEXT DEFAULT '',
      remark TEXT DEFAULT '', tag TEXT DEFAULT '',
      updated_at TEXT DEFAULT '0', created_at TEXT DEFAULT '0',
      info TEXT DEFAULT ''
    )
  ''');
  await db.execute('''
    CREATE TABLE user_tag (
      auto_id INTEGER PRIMARY KEY,
      user_id TEXT, tag_id TEXT,
      scene TEXT, name TEXT, subtitle TEXT,
      referer_time TEXT, updated_at TEXT, created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE group_notice (
      id TEXT, group_id TEXT, user_id TEXT, edit_user_id TEXT,
      body TEXT, status TEXT,
      expired_at TEXT, updated_at TEXT, created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE group_member (
      id TEXT, group_id TEXT, user_id TEXT,
      nickname TEXT, avatar TEXT, sign TEXT, account TEXT,
      invite_code TEXT, alias TEXT, description TEXT,
      role TEXT, is_join TEXT, join_mode TEXT,
      status TEXT, updated_at TEXT, created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE user_group (
      id TEXT, user_id TEXT, group_id TEXT,
      remark TEXT, setting TEXT, status TEXT,
      updated_at TEXT, created_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE conversation (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT, peer_id TEXT,
      avatar TEXT, title TEXT, subtitle TEXT, region TEXT, sign TEXT,
      unread_num TEXT,
      "type" TEXT, msg_type TEXT,
      is_show TEXT, last_time TEXT,
      last_msg_id TEXT, last_msg_status TEXT, payload TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE "group" (
      id TEXT, type TEXT, join_limit TEXT, content_limit TEXT, user_id_sum TEXT,
      owner_uid TEXT, creator_uid TEXT,
      member_max TEXT, member_count TEXT,
      introduction TEXT, avatar TEXT, title TEXT, status TEXT,
      updated_at TEXT, created_at TEXT, pinned_msg TEXT
    )
  ''');

  await db.execute('PRAGMA user_version = 9');
}

/// 按 planner 语义执行 (fromVersion, toVersion] 区间的升级块（升序）。
///
/// duplicate-column 吞错是现状复刻（见库文档注释）。
Future<void> upgradeFixtureToVersion(
  Database db,
  int fromVersion,
  int toVersion,
) async {
  assert(toVersion > fromVersion, 'fixture upgrade requires to > from');
  final blocks = parseMigrationVersionBlocks(kUpgradeScriptSql);

  for (var v = fromVersion + 1; v <= toVersion; v++) {
    final statements = blocks[v];
    if (statements == null) continue; // 跳号版本（v15）无块，合法
    for (final sql in statements) {
      try {
        await db.execute(sql);
      } catch (e) {
        if (!e.toString().toLowerCase().contains('duplicate column')) rethrow;
      }
    }
  }
  await db.execute('PRAGMA user_version = $toVersion');
}

/// 构建指定版本的 fixture 数据库（in-memory，或传入 path 建文件库）。
///
/// [version] 必须是受支持起点/终点之一（见 migration_inventory.dart）。
/// [withSyntheticRows] 为 true 时插入无 PII 合成种子行（synthetic-* 前缀，
/// 固定值，可安全出现在任何日志/报告/fixture 快照中）。
///
/// 注意：ffi 工厂对 in-memory 路径按路径做**单例复用**——同进程内两次
/// `openDatabase(inMemoryDatabasePath)` 会拿到同一个 Database 对象，导致
/// 多个 fixture 相互污染。因此这里强制 singleInstance: false，保证每次
/// 调用都是独立、干净的数据库。
Future<Database> openFixtureDatabaseAtVersion({
  required int version,
  bool withSyntheticRows = false,
  String? path,
}) async {
  final db = await databaseFactory.openDatabase(
    path ?? inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );

  if (version >= 16) {
    await applyBaselineSchema(db);
    await db.execute('PRAGMA user_version = 16');
    if (version > 16) {
      await upgradeFixtureToVersion(db, 16, version);
    }
  } else {
    // v9..v15：legacy 起点后逐级升（v15 无块自然跳过）
    await applyV9LegacySchema(db);
    if (version > 9) {
      await upgradeFixtureToVersion(db, 9, version);
    }
  }

  if (withSyntheticRows) {
    await seedSyntheticRows(db, version);
  }
  return db;
}

/// 无 PII 合成种子行（固定合成值，不含任何真实账号/消息/手机号）。
///
/// 只覆盖迁移矩阵关心的三类关键业务对象：
/// conversation（会话）、msg_c2c（C2C 消息，空合成 payload）、
/// channel（频道，v13+ 存在；v31 形态为三字段访问模型）。
Future<void> seedSyntheticRows(Database db, int version) async {
  final uk3 = 'synthetic-conv-001';
  final now = 1700000000000; // 固定合成时间戳（非真实数据）

  // conversation（v16+ baseline 含此表；v9 legacy mini 未建，跳过）
  // 唯一键为 (type, user_id, peer_id)——uk3 是 msg 表的列，conversation 无。
  final hasConversation = await _tableExists(db, 'conversation');
  if (hasConversation) {
    await db.insert('conversation', {
      'type': 'C2C',
      'user_id': 990001,
      'peer_id': 990002,
      'is_show': 1,
      'last_time': now,
    });
  }

  // msg_c2c（v10+ 新表名；v9 为 message 旧表名，此处不种）
  if (version >= 10) {
    await db.insert('msg_c2c', {
      'id': 990000000001,
      'msg_type': 'text',
      'from_id': 990001,
      'to_id': 990002,
      'conversation_uk3': uk3,
      'payload': '{"synthetic":true}',
      'created_at': now,
      'topic_id': 0,
      'status': 1,
      'is_author': 1,
      'type': 'C2C',
    });
  }

  // channel（v13+ 存在；v30+ 有 has_purchased，v31 有访问模型三字段）
  final hasChannel = await _tableExists(db, 'channel');
  if (hasChannel) {
    // channel.id 声明类型随版本演进（v13 建的 TEXT UUID → v17 起重建为
    // INTEGER；baseline v16 直接 INTEGER）——按实际列类型选择合成值。
    final idColType = await _columnType(db, 'channel', 'id');
    final row = <String, Object?>{
      'id': idColType.toUpperCase().contains('INT')
          ? 990100
          : 'synthetic-channel-990100',
      'name': 'synthetic-channel-001',
      'creator_id': 990001,
      'created_at': now,
      'updated_at': now,
    };
    final cols = await _columnNames(db, 'channel');
    if (cols.contains('type')) row['type'] = 0;
    if (cols.contains('has_purchased')) row['has_purchased'] = 0;
    if (cols.contains('visibility')) row['visibility'] = 'public';
    if (cols.contains('access_type')) row['access_type'] = 0;
    if (cols.contains('join_policy')) row['join_policy'] = 'open';
    await db.insert('channel', row);
  }
}

Future<bool> _tableExists(Database db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
    [table],
  );
  return rows.isNotEmpty;
}

Future<Set<String>> _columnNames(Database db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return rows.map((r) => r['name'] as String).toSet();
}

Future<String> _columnType(Database db, String table, String column) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  for (final r in rows) {
    if (r['name'] == column) return (r['type'] ?? '') as String;
  }
  return '';
}
