/// 钉住 v21 `uq_moment_notify_dedup` 唯一索引的 NULL 折叠语义（in-memory SQLite）。
///
/// 背景（v20 → v21 修复）：
///   - v20 唯一索引直接使用 `comment_id` 列，SQLite "NULL != NULL" 语义使
///     `moment_like`（comment_id=NULL）重复 S2C 推送被允许插入，客户端通知
///     中心出现重复项。`ConflictAlgorithm.ignore` 对含 NULL 列组无效。
///   - v21 修复：`COALESCE(comment_id, '')` 将 NULL 折叠为空串参与唯一约束。
///
/// 本测试：
///   1. 复制 upgrade.sql v21 的最小等价 schema（不依赖 SqliteService 单例）
///   2. 模拟重复 S2C 推送场景，断言第二条 insert 被唯一索引拦截返回 0
///   3. 穿插正向 case（不同 moment_id / from_uid / action）确保索引未过紧
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 与 upgrade.sql v21 等价的最小 schema（moment_notify 表 + v21 唯一索引）。
const String _momentNotifyDDL = '''
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
''';

const String _dedupIndexDDL = '''
  CREATE UNIQUE INDEX uq_moment_notify_dedup
    ON moment_notify(
      user_id,
      action,
      moment_id,
      from_uid,
      COALESCE(comment_id, '')
    )
''';

/// 反例索引（v20，直接用 comment_id 不做 COALESCE）——
/// 仅用于对照测试，证明修复前的语义漏洞。
const String _v20DedupIndexDDL = '''
  CREATE UNIQUE INDEX uq_moment_notify_dedup_v20
    ON moment_notify(user_id, action, moment_id, from_uid, comment_id)
''';

Future<Database> _openDb({bool useV20Index = false}) async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 21),
  );
  await db.execute(_momentNotifyDDL);
  await db.execute(useV20Index ? _v20DedupIndexDDL : _dedupIndexDDL);
  return db;
}

Future<int> _countRows(Database db) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM moment_notify');
  final v = rows.first['c'];
  return v is int ? v : (v as num).toInt();
}

Map<String, dynamic> _row({
  String userId = '1000',
  String action = 'moment_like',
  String momentId = 'mo-1',
  String fromUid = '2000',
  String? commentId,
  int createdAt = 1_700_000_000_000,
}) {
  return {
    'user_id': userId,
    'action': action,
    'moment_id': momentId,
    'from_uid': fromUid,
    'comment_id': commentId,
    'is_read': 0,
    'created_at': createdAt,
  };
}

void main() {
  group('v21 uq_moment_notify_dedup — NULL 折叠语义', () {
    test('moment_like 重复推送（comment_id=NULL）→ 第二次被唯一索引拦截', () async {
      final db = await _openDb();
      try {
        final r1 = await db.insert(
          'moment_notify',
          _row(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        final r2 = await db.insert(
          'moment_notify',
          _row(), // 四元组完全相同，comment_id 仍为 NULL
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        expect(r1, greaterThan(0), reason: '首次插入应成功');
        expect(r2, 0, reason: 'NULL 折叠后重复 → ConflictAlgorithm.ignore 返回 0');

        final count = await _countRows(db);
        expect(count, 1, reason: '重复项未落库');
      } finally {
        await db.close();
      }
    });

    test('moment_comment 重复推送（comment_id 相同非 NULL）→ 第二次被拦截', () async {
      final db = await _openDb();
      try {
        final r1 = await db.insert(
          'moment_notify',
          _row(action: 'moment_comment', commentId: 'c-1'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        final r2 = await db.insert(
          'moment_notify',
          _row(action: 'moment_comment', commentId: 'c-1'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        expect(r1, greaterThan(0));
        expect(r2, 0);
      } finally {
        await db.close();
      }
    });

    test('moment_like + moment_comment 同 moment_id → action 字段区分，各自落库',
        () async {
      final db = await _openDb();
      try {
        await db.insert(
          'moment_notify',
          _row(action: 'moment_like'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await db.insert(
          'moment_notify',
          _row(action: 'moment_comment', commentId: 'c-1'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        final count = await _countRows(db);
        expect(count, 2, reason: 'action 不同互不冲突');
      } finally {
        await db.close();
      }
    });

    test('不同 from_uid 的 moment_like（同 moment_id）可共存', () async {
      final db = await _openDb();
      try {
        await db.insert(
          'moment_notify',
          _row(fromUid: '2000'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await db.insert(
          'moment_notify',
          _row(fromUid: '2001'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        final count = await _countRows(db);
        expect(count, 2);
      } finally {
        await db.close();
      }
    });

    test('不同 moment_id 的 moment_like → 各自落库', () async {
      final db = await _openDb();
      try {
        await db.insert(
          'moment_notify',
          _row(momentId: 'mo-1'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await db.insert(
          'moment_notify',
          _row(momentId: 'mo-2'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        final count = await _countRows(db);
        expect(count, 2);
      } finally {
        await db.close();
      }
    });

    test('不同 user_id → 两端用户互不干扰', () async {
      final db = await _openDb();
      try {
        await db.insert(
          'moment_notify',
          _row(userId: '1000'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await db.insert(
          'moment_notify',
          _row(userId: '1001'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        final count = await _countRows(db);
        expect(count, 2);
      } finally {
        await db.close();
      }
    });

    test('moment_like + moment_comment（comment_id=""）→ 两者冲突', () async {
      // 潜在陷阱：若后端错传 comment_id=""（空串）给 moment_like，或客户端
      // 解析路径未归一化，v21 索引会把两行视为同一条（都折叠到 ''）。
      // 这里断言这种情况确实冲突 → 客户端解析层必须保证：
      //   - moment_like  → comment_id = NULL
      //   - moment_comment → comment_id != NULL && comment_id != ''
      final db = await _openDb();
      try {
        await db.insert(
          'moment_notify',
          _row(action: 'moment_like'), // comment_id=NULL → COALESCE '' → ''
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        final r2 = await db.insert(
          'moment_notify',
          _row(action: 'moment_like', commentId: ''), // 显式空串也折叠到 ''
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        expect(r2, 0, reason: 'NULL 与 "" 在 COALESCE 下等价 → 重复');
      } finally {
        await db.close();
      }
    });
  });

  group('v20 反例 — 证明 NULL 语义漏洞真实存在', () {
    test('v20 索引允许 moment_like 重复（NULL != NULL）— 这是被修复的 bug', () async {
      final db = await _openDb(useV20Index: true);
      try {
        final r1 = await db.insert(
          'moment_notify',
          _row(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        final r2 = await db.insert(
          'moment_notify',
          _row(), // 四元组完全相同，但 comment_id=NULL
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        expect(r1, greaterThan(0));
        expect(r2, greaterThan(0), reason: 'v20 bug 保留：NULL != NULL 允许重复');

        final count = await _countRows(db);
        expect(count, 2, reason: 'v20 漏洞：两条完全相同的 moment_like 都落库');
      } finally {
        await db.close();
      }
    });
  });
}
