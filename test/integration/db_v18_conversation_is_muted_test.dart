/// Schema migration v17 ↔ v18 for C7-α L0 (local DND): add `is_muted`
/// column to `conversation` to let the user silence per-group notifications.
///
/// SQL duplicated from assets/migrations/{upgrade,downgrade}.sql per the
/// project pattern (same trade-off as the v17 test).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// V17 baseline: conversation table (v17 = v16 + mention_unread).
/// Mirrors the state after the v17 ALTER TABLE.
const String _v17ConversationDDL = '''
  CREATE TABLE conversation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    peer_id INTEGER,
    avatar TEXT,
    title TEXT,
    subtitle TEXT,
    region TEXT,
    sign TEXT,
    unread_num INTEGER,
    "type" TEXT,
    msg_type TEXT,
    is_show INTEGER,
    last_time INTEGER,
    last_msg_id INTEGER,
    last_msg_status INTEGER,
    payload TEXT,
    mention_unread INTEGER NOT NULL DEFAULT 0
  )
''';

/// V18 upgrade — must match assets/migrations/upgrade.sql "VERSION: 18" block.
const String _v18Upgrade =
    'ALTER TABLE conversation ADD COLUMN is_muted INTEGER NOT NULL DEFAULT 0';

/// V18 → V17 downgrade — must match assets/migrations/downgrade.sql.
/// SQLite < 3.35 no DROP COLUMN, rebuild-table mode. Preserves mention_unread.
const List<String> _v18DowngradeStmts = [
  '''CREATE TABLE conversation_v17 (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    peer_id INTEGER,
    avatar TEXT,
    title TEXT,
    subtitle TEXT,
    region TEXT,
    sign TEXT,
    unread_num INTEGER,
    "type" TEXT,
    msg_type TEXT,
    is_show INTEGER,
    last_time INTEGER,
    last_msg_id INTEGER,
    last_msg_status INTEGER,
    payload TEXT,
    mention_unread INTEGER NOT NULL DEFAULT 0
  )''',
  '''INSERT INTO conversation_v17
    (id, user_id, peer_id, avatar, title, subtitle, region, sign,
     unread_num, "type", msg_type, is_show, last_time,
     last_msg_id, last_msg_status, payload, mention_unread)
    SELECT
      id, user_id, peer_id, avatar, title, subtitle, region, sign,
      unread_num, "type", msg_type, is_show, last_time,
      last_msg_id, last_msg_status, payload, mention_unread
    FROM conversation''',
  'DROP TABLE conversation',
  'ALTER TABLE conversation_v17 RENAME TO conversation',
];

Future<List<Map<String, Object?>>> tableInfo(Database db, String table) =>
    db.rawQuery('PRAGMA table_info($table)');

bool hasColumn(List<Map<String, Object?>> info, String name) =>
    info.any((r) => r['name'] == name);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('migration asset files contain the v18 blocks', () {
    test('upgrade.sql declares VERSION: 18 and is_muted column', () {
      final content = File('assets/migrations/upgrade.sql').readAsStringSync();
      expect(content.contains('-- VERSION: 18'), isTrue,
          reason: 'upgrade.sql must have the v18 block');
      expect(content.contains('is_muted'), isTrue,
          reason: 'upgrade.sql v18 must add is_muted column');
      expect(content.contains('PRAGMA user_version = 18'), isTrue,
          reason: 'upgrade.sql must bump user_version to 18');
    });

    test('downgrade.sql declares VERSION: 18 block', () {
      final content = File('assets/migrations/downgrade.sql').readAsStringSync();
      expect(content.contains('-- VERSION: 18'), isTrue,
          reason: 'downgrade.sql must have the v18 → v17 block');
    });
  });

  group('v17 → v18 upgrade: conversation.is_muted (C7-α-1)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute(_v17ConversationDDL);
    });

    tearDown(() async => db.close());

    test('v17 baseline has mention_unread but NO is_muted column', () async {
      final info = await tableInfo(db, 'conversation');
      expect(hasColumn(info, 'mention_unread'), isTrue,
          reason: 'sanity: v17 baseline includes mention_unread from C7-β-1');
      expect(hasColumn(info, 'is_muted'), isFalse);
    });

    test('applying v18 upgrade adds is_muted column (default 0)', () async {
      await db.insert('conversation', {
        'user_id': 1,
        'peer_id': 42,
        'type': 'C2G',
        'unread_num': 3,
        'mention_unread': 1,
      });

      await db.execute(_v18Upgrade);

      final info = await tableInfo(db, 'conversation');
      expect(hasColumn(info, 'is_muted'), isTrue);
      expect(hasColumn(info, 'mention_unread'), isTrue,
          reason: 'v18 upgrade must preserve v17 column');

      final rows = await db.rawQuery(
          'SELECT is_muted, mention_unread, unread_num FROM conversation');
      expect(rows, hasLength(1));
      expect(rows.first['is_muted'], 0,
          reason: 'existing row must get default 0');
      expect(rows.first['mention_unread'], 1, reason: 'v17 data preserved');
      expect(rows.first['unread_num'], 3);
    });

    test('v18 table accepts explicit is_muted writes', () async {
      await db.execute(_v18Upgrade);

      await db.insert('conversation', {
        'user_id': 1,
        'peer_id': 42,
        'type': 'C2G',
        'unread_num': 5,
        'mention_unread': 2,
        'is_muted': 1,
      });

      final rows = await db.rawQuery(
          'SELECT is_muted, mention_unread FROM conversation');
      expect(rows.first['is_muted'], 1);
      expect(rows.first['mention_unread'], 2);
    });
  });

  group('v18 → v17 downgrade (C7-α-1)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute(_v17ConversationDDL);
      await db.execute(_v18Upgrade);
    });

    tearDown(() async => db.close());

    test('after downgrade: is_muted column is gone; mention_unread preserved',
        () async {
      await db.insert('conversation', {
        'user_id': 1,
        'peer_id': 42,
        'type': 'C2G',
        'unread_num': 5,
        'mention_unread': 3,
        'is_muted': 1,
      });

      for (final stmt in _v18DowngradeStmts) {
        await db.execute(stmt);
      }

      final info = await tableInfo(db, 'conversation');
      expect(hasColumn(info, 'is_muted'), isFalse);
      expect(hasColumn(info, 'mention_unread'), isTrue,
          reason: 'v17 column must survive v18 downgrade');
      expect(hasColumn(info, 'unread_num'), isTrue);
    });

    test('downgrade preserves non-is_muted data (incl. mention_unread)',
        () async {
      await db.insert('conversation', {
        'user_id': 9,
        'peer_id': 123,
        'title': 'Test Group',
        'type': 'C2G',
        'unread_num': 4,
        'mention_unread': 2,
        'is_muted': 1,
      });

      for (final stmt in _v18DowngradeStmts) {
        await db.execute(stmt);
      }

      final rows = await db.rawQuery(
          'SELECT user_id, peer_id, title, unread_num, mention_unread FROM conversation');
      expect(rows, hasLength(1));
      expect(rows.first['user_id'], 9);
      expect(rows.first['peer_id'], 123);
      expect(rows.first['title'], 'Test Group');
      expect(rows.first['unread_num'], 4);
      expect(rows.first['mention_unread'], 2);
    });
  });
}
