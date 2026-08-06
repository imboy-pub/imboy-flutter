/// Schema migration v23 → v24（透明 AI 徽章数据源）：contact 表新增
/// `account_type` 列（0=真人 1=AI 助手 2=官方机器人，服务端只读投影）。
///
/// SQL duplicated from assets/migrations/upgrade.sql per the project
/// pattern (same trade-off as the v17/v18 tests).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// V23 时点的 contact 表（baseline v16 起未变）。
const String _v23ContactDDL = '''
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
    CONSTRAINT uk_FromTo UNIQUE (user_id, peer_id)
  )
''';

/// V24 upgrade — must match assets/migrations/upgrade.sql "VERSION: 24" block.
const String _v24Upgrade =
    'ALTER TABLE contact ADD COLUMN account_type INTEGER NOT NULL DEFAULT 0';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('v23 → v24 contact.account_type migration', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);
      await db.execute(_v23ContactDDL);
      // v23 时点已有的老好友行（迁移后应默认 0=真人）
      await db.insert('contact', {
        'user_id': 1,
        'peer_id': 100,
        'nickname': 'old-friend',
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('迁移后新增 account_type 列且老行默认 0', () async {
      await db.execute(_v24Upgrade);

      final columns = await db.rawQuery('PRAGMA table_info(contact)');
      final names = columns.map((c) => c['name']).toList();
      expect(names, contains('account_type'));

      final rows = await db.query('contact', where: 'peer_id = 100');
      expect(rows.single['account_type'], 0);
    });

    test('迁移后可写入并读回 AI/官方账号类型', () async {
      await db.execute(_v24Upgrade);

      await db.insert('contact', {
        'user_id': 1,
        'peer_id': 200,
        'nickname': 'ai-bot',
        'account_type': 1,
      });
      await db.insert('contact', {
        'user_id': 1,
        'peer_id': 300,
        'nickname': 'official-bot',
        'account_type': 2,
      });

      final ai = await db.query('contact', where: 'peer_id = 200');
      final official = await db.query('contact', where: 'peer_id = 300');
      expect(ai.single['account_type'], 1);
      expect(official.single['account_type'], 2);
    });
  });
}
