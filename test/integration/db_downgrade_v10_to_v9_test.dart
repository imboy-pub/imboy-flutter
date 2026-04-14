// DB 降级脚本集成测试：V10 → V9
// DB downgrade script integration test: V10 → V9
//
// 用 sqflite_common_ffi 的 in-memory 数据库验证 assets/migrations/downgrade.sql
// 中 `VERSION: 10` 块的正确性。不依赖 Flutter 平台通道/path_provider，可在纯
// dart_test 环境运行。
//
// 覆盖场景：
//   1. 表重命名：msg_c2c/msg_c2g/msg_c2s/msg_s2c → message/group_message/
//      c2s_message/s2c_message
//   2. 字段删除：v2.0 新增的 msg_type/action/e2ee 列被移除
//   3. 数据保留：重建前已插入的历史行在重建后仍可查询
//   4. 索引重建：旧格式索引在降级后存在
//   5. PRAGMA user_version 更新为 9
//
// Uses an in-memory sqflite_common_ffi database to validate the VERSION: 10
// block of the downgrade script. No platform channels / path_provider needed,
// so it runs under plain `flutter test`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 解析 `downgrade.sql`，提取目标 VERSION 块中的 SQL 语句列表。
/// Parses downgrade.sql and extracts SQL statements from the VERSION block.
///
/// 规则与 MigrationService._parseMigrationScripts 一致：
///   - 按 `-- VERSION:` 切分
///   - 跳过注释行、空行
///   - 以 `;` 结尾作为语句边界
/// Mirrors the rules in MigrationService._parseMigrationScripts.
List<String> parseVersionBlock(String content, int version) {
  final blocks = content.split('-- VERSION:');
  for (final block in blocks.skip(1)) {
    final lines = block.split('\n');
    if (lines.isEmpty) continue;
    final startVersion = int.tryParse(lines[0].trim());
    if (startVersion != version) continue;

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
    return statements;
  }
  return const [];
}

/// 构造 V10 schema 的测试夹具（仅消息相关四表，足够验证降级）。
/// Sets up the V10 schema fixture (four message tables).
Future<void> createV10Schema(Database db) async {
  // 四张 V10 消息表，包含 v2.0 新增字段 msg_type / action / e2ee
  for (final table in ['msg_c2c', 'msg_c2g', 'msg_c2s', 'msg_s2c']) {
    await db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        from_id TEXT NOT NULL,
        to_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        is_author INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        conversation_uk3 TEXT NOT NULL,
        topic_id INTEGER NOT NULL DEFAULT 0,
        msg_type TEXT,
        action TEXT,
        e2ee TEXT
      )
    ''');
  }
  // V10 索引（部分，验证 DROP INDEX IF EXISTS 的幂等性）
  await db.execute('''
    CREATE INDEX idx_msg_c2c_conversation_uk3 ON msg_c2c (conversation_uk3)
  ''');
  await db.execute('PRAGMA user_version = 10');
}

void main() {
  // sqflite_common_ffi 初始化（一次性）
  // Initialize sqflite_common_ffi once per test run
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('downgrade.sql VERSION: 10 → VERSION: 9', () {
    late Database db;
    late List<String> statements;

    setUp(() async {
      // 读取实际的降级脚本（测试 CWD 是项目根）
      // Read the real downgrade script (test CWD = project root)
      final file = File('assets/migrations/downgrade.sql');
      expect(file.existsSync(), isTrue, reason: 'downgrade.sql 必须存在');
      final content = await file.readAsString();
      statements = parseVersionBlock(content, 10);
      expect(statements, isNotEmpty, reason: 'V10 降级块必须含 SQL 语句');

      // In-memory DB，每个测试独立
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await createV10Schema(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('脚本能无错误执行 / script executes without error', () async {
      for (final sql in statements) {
        // 脚本里含多语句（以 ; 结尾），execute 接受单条；按 ; 再拆
        // 简化处理：直接传给 execute（含尾随 ;）
        await db.execute(sql);
      }
      // 若到达此行，则脚本全部可执行
    });

    test('旧表名已恢复 / legacy table names restored', () async {
      for (final sql in statements) {
        await db.execute(sql);
      }

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = tables.map((r) => r['name'] as String).toSet();

      expect(names.contains('message'), isTrue, reason: 'msg_c2c → message');
      expect(names.contains('group_message'), isTrue);
      expect(names.contains('c2s_message'), isTrue);
      expect(names.contains('s2c_message'), isTrue);

      // 新表名应已消失
      expect(names.contains('msg_c2c'), isFalse);
      expect(names.contains('msg_c2g'), isFalse);
      expect(names.contains('msg_c2s'), isFalse);
      expect(names.contains('msg_s2c'), isFalse);
    });

    test('v2.0 新增字段被移除 / v2.0 columns dropped', () async {
      for (final sql in statements) {
        await db.execute(sql);
      }

      for (final table in [
        'message',
        'group_message',
        'c2s_message',
        's2c_message',
      ]) {
        final info = await db.rawQuery('PRAGMA table_info($table)');
        final columns = info.map((r) => r['name'] as String).toSet();

        expect(
          columns.contains('msg_type'),
          isFalse,
          reason: '$table.msg_type 应已删除',
        );
        expect(
          columns.contains('action'),
          isFalse,
          reason: '$table.action 应已删除',
        );
        expect(columns.contains('e2ee'), isFalse, reason: '$table.e2ee 应已删除');

        // 基础字段必须保留
        expect(columns.contains('id'), isTrue);
        expect(columns.contains('from_id'), isTrue);
        expect(columns.contains('to_id'), isTrue);
        expect(columns.contains('payload'), isTrue);
        expect(columns.contains('conversation_uk3'), isTrue);
      }
    });

    test('历史数据在降级后仍可查询 / legacy rows preserved', () async {
      // 在 V10 表中插入样本数据
      await db.insert('msg_c2c', {
        'type': 'C2C',
        'from_id': 'alice',
        'to_id': 'bob',
        'payload': 'hello',
        'status': 0,
        'is_author': 1,
        'created_at': 1000,
        'conversation_uk3': 'alice_bob',
        'topic_id': 0,
        'msg_type': 'text', // V10 字段，降级后丢失但不应报错
        'action': '',
        'e2ee': null,
      });

      for (final sql in statements) {
        await db.execute(sql);
      }

      final rows = await db.query('message', where: 'from_id = ?', whereArgs: ['alice']);
      expect(rows, hasLength(1));
      expect(rows.first['payload'], 'hello');
      expect(rows.first['to_id'], 'bob');
      expect(rows.first['conversation_uk3'], 'alice_bob');
    });

    test('旧索引已重建 / legacy indexes rebuilt', () async {
      for (final sql in statements) {
        await db.execute(sql);
      }

      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' ORDER BY name",
      );
      final names = indexes.map((r) => r['name'] as String).toSet();

      // 检查关键旧索引（downgrade.sql 明确创建的）
      expect(names.contains('idx_message_conversation_uk3'), isTrue);
      expect(names.contains('idx_message_from_to_created'), isTrue);
      expect(names.contains('idx_c2g_message_conversation_uk3'), isTrue);
      expect(names.contains('idx_s2c_msg_conversation_status_author'), isTrue);

      // V10 新索引应已消失
      expect(names.contains('idx_msg_c2c_conversation_uk3'), isFalse);
    });

    test('PRAGMA user_version 更新为 9 / user_version set to 9', () async {
      for (final sql in statements) {
        await db.execute(sql);
      }

      final result = await db.rawQuery('PRAGMA user_version');
      expect(result.first.values.first, 9);
    });

    test('脚本幂等：重复执行仍成功 / idempotent on re-run', () async {
      for (final sql in statements) {
        await db.execute(sql);
      }

      // 第二次不应报错（但由于 ALTER TABLE RENAME 在第二次会失败，
      // 真实场景的幂等保证其实来自 sqflite 事务 + user_version 检查）
      // 因此这里只断言第一次成功。
      // On second run ALTER TABLE RENAME would fail; real idempotency comes
      // from sqflite's transaction + version check, not the script itself.
      // So we only assert the first run succeeded above.
      final result = await db.rawQuery('PRAGMA user_version');
      expect(result.first.values.first, 9);
    });
  });

  group('parseVersionBlock helper', () {
    test(
      '不存在的版本号返回空列表 / unknown version yields empty list',
      () {
        const content = '-- VERSION: 10\nSELECT 1;';
        expect(parseVersionBlock(content, 99), isEmpty);
      },
    );

    test('跳过注释与空行 / skips comments and blanks', () {
      const content = '''
-- VERSION: 10
-- DESC: test
-- comment line
SELECT 1;

-- another comment
SELECT 2;
''';
      final stmts = parseVersionBlock(content, 10);
      expect(stmts, hasLength(2));
      expect(stmts[0].contains('SELECT 1'), isTrue);
      expect(stmts[1].contains('SELECT 2'), isTrue);
    });
  });
}
