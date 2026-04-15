/// 钉住 `group_member.mute_until` 列的持久化契约（in-memory SQLite）。
///
/// 本测试**不**走 `GroupMemberRepo`（依赖 `SqliteService.to` 单例），而是
/// 直接在 in-memory 数据库上复制 Repo 的核心写路径：
///   1. 建一张与 upgrade.sql v19 等价的最小表（含 mute_until INTEGER NULL）
///   2. 用 `GroupMemberModel.toJson()` 组装 insert map（这是 Repo 真实写入的数据形状）
///   3. 回查后用 `GroupMemberModel.fromJson(row)` 还原，断言 muteUntilMs
///
/// 契约：
///   - 字段类型 INTEGER NULL（SQLite 里毫秒时间戳落为 INTEGER，未禁言为 NULL）
///   - 插入 null → 回读 muteUntilMs == null
///   - 插入 int ms → 回读值相等
///   - 更新 mute_until（禁言 → 清禁言）走 UPDATE，字段能被显式置回 NULL
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/model/group_member_columns.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 与后端 `00000051_group_member_mute.sql` + 客户端 upgrade.sql v19 等价的
/// 最小 schema，仅保留本测试所需字段。
const String _groupMemberDDL = '''
  CREATE TABLE group_member (
    id INTEGER,
    group_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    nickname TEXT DEFAULT '',
    avatar TEXT DEFAULT '',
    sign TEXT DEFAULT '',
    account TEXT DEFAULT '',
    invite_code TEXT DEFAULT '',
    alias TEXT DEFAULT '',
    description TEXT DEFAULT '',
    role INTEGER DEFAULT 1,
    is_join INTEGER DEFAULT 1,
    join_mode TEXT DEFAULT '',
    status INTEGER DEFAULT 1,
    updated_at INTEGER DEFAULT 0,
    created_at INTEGER DEFAULT 0,
    mute_until INTEGER DEFAULT NULL,
    PRIMARY KEY (group_id, user_id)
  )
''';

Future<Database> _openMemoryDb() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 19),
  );
  await db.execute(_groupMemberDDL);
  return db;
}

GroupMemberModel _buildMember({int? muteUntilMs}) {
  return GroupMemberModel(
    id: null,
    groupId: 10,
    userId: 100,
    nickname: 'tester',
    avatar: '',
    sign: '',
    account: '',
    alias: '',
    createdAt: 1700000000000,
    muteUntilMs: muteUntilMs,
  );
}

void main() {
  group('group_member.mute_until 持久化契约', () {
    late Database db;

    setUp(() async {
      db = await _openMemoryDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('schema 包含 mute_until INTEGER NULL（默认 NULL）', () async {
      final cols = await db.rawQuery("PRAGMA table_info('group_member')");
      final muteCol = cols.firstWhere(
        (c) => c['name'] == 'mute_until',
        orElse: () => <String, Object?>{},
      );
      expect(muteCol.isNotEmpty, isTrue, reason: 'mute_until 列必须存在');
      expect(muteCol['type'], 'INTEGER');
      expect(muteCol['notnull'], 0, reason: 'mute_until 必须可为 NULL');
    });

    test('insert(muteUntilMs=null) → 回读 muteUntilMs 为 null', () async {
      final m = _buildMember(muteUntilMs: null);

      await db.insert(GroupMemberColumns.table, m.toJson());

      final rows = await db.query(
        GroupMemberColumns.table,
        where: '${GroupMemberColumns.groupId} = ? AND ${GroupMemberColumns.userId} = ?',
        whereArgs: [10, 100],
      );
      expect(rows, hasLength(1));
      expect(rows.single[GroupMemberColumns.muteUntil], isNull);

      final restored = GroupMemberModel.fromJson(rows.single);
      expect(restored.muteUntilMs, isNull);
      expect(restored.isMuted(nowMs: 1_700_000_000_001), isFalse);
    });

    test('insert(muteUntilMs=非空 int ms) → 回读值相等', () async {
      const until = 1_900_000_000_000;
      final m = _buildMember(muteUntilMs: until);

      await db.insert(GroupMemberColumns.table, m.toJson());

      final rows = await db.query(GroupMemberColumns.table);
      expect(rows.single[GroupMemberColumns.muteUntil], until);

      final restored = GroupMemberModel.fromJson(rows.single);
      expect(restored.muteUntilMs, until);
      expect(restored.isMuted(nowMs: until - 1), isTrue);
    });

    test('UPDATE mute_until：禁言 → 解禁（显式置 NULL）', () async {
      final m = _buildMember(muteUntilMs: 1_900_000_000_000);
      await db.insert(GroupMemberColumns.table, m.toJson());

      // 解禁：显式 UPDATE 置 NULL（Repo GREEN-3 需支持这条路径）
      final affected = await db.update(
        GroupMemberColumns.table,
        {GroupMemberColumns.muteUntil: null},
        where: '${GroupMemberColumns.groupId} = ? AND ${GroupMemberColumns.userId} = ?',
        whereArgs: [10, 100],
      );

      expect(affected, 1);
      final rows = await db.query(GroupMemberColumns.table);
      expect(rows.single[GroupMemberColumns.muteUntil], isNull);
      expect(GroupMemberModel.fromJson(rows.single).muteUntilMs, isNull);
    });
  });
}
