/// Schema migration v16 ↔ v17 for C7-β: add `mention_unread` column to
/// the `conversation` table to support standalone @ mention counting.
///
/// These tests duplicate the v17 SQL snippets from
/// assets/migrations/{upgrade,downgrade}.sql. The duplication is a known
/// trade-off: keep the tests as a fast feedback loop without loading the
/// entire migration engine. Keep in sync by hand.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// V16 baseline: conversation table WITHOUT mention_unread.
/// Mirrors upgrade.sql:833-850 (CREATE TABLE conversation_new).
const String _v16ConversationDDL = '''
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
    payload TEXT
  )
''';

/// V17 upgrade: add the new column. Must be kept in sync with
/// assets/migrations/upgrade.sql "VERSION: 17" block.
const String _v17Upgrade =
    'ALTER TABLE conversation ADD COLUMN mention_unread INTEGER NOT NULL DEFAULT 0';

/// V17 downgrade: rebuild table without mention_unread.
/// Must be kept in sync with assets/migrations/downgrade.sql "VERSION: 17" block.
const List<String> _v17DowngradeStmts = [
  '''CREATE TABLE conversation_v16 (
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
    payload TEXT
  )''',
  '''INSERT INTO conversation_v16
    (id, user_id, peer_id, avatar, title, subtitle, region, sign,
     unread_num, "type", msg_type, is_show, last_time,
     last_msg_id, last_msg_status, payload)
    SELECT
      id, user_id, peer_id, avatar, title, subtitle, region, sign,
      unread_num, "type", msg_type, is_show, last_time,
      last_msg_id, last_msg_status, payload
    FROM conversation''',
  'DROP TABLE conversation',
  'ALTER TABLE conversation_v16 RENAME TO conversation',
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

  group('migration asset files contain the v17 blocks', () {
    test('upgrade.sql declares VERSION: 17 and mention_unread column', () {
      final content = File('assets/migrations/upgrade.sql').readAsStringSync();
      expect(content.contains('-- VERSION: 17'), isTrue,
          reason: 'upgrade.sql must have the v17 block');
      expect(content.contains('mention_unread'), isTrue,
          reason: 'upgrade.sql v17 must add mention_unread column');
      expect(content.contains('PRAGMA user_version = 17'), isTrue,
          reason: 'upgrade.sql must bump user_version to 17');
    });

    test('downgrade.sql declares VERSION: 17 block', () {
      final content = File('assets/migrations/downgrade.sql').readAsStringSync();
      expect(content.contains('-- VERSION: 17'), isTrue,
          reason: 'downgrade.sql must have the v17 → v16 block');
    });
  });

  group('v16 → v17 upgrade: conversation.mention_unread (C7-β)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute(_v16ConversationDDL);
    });

    tearDown(() async => db.close());

    test('v16 baseline has NO mention_unread column', () async {
      final info = await tableInfo(db, 'conversation');
      expect(hasColumn(info, 'mention_unread'), isFalse);
      expect(hasColumn(info, 'unread_num'), isTrue,
          reason: 'sanity: v16 keeps unread_num');
    });

    test('applying v17 upgrade adds mention_unread column (default 0)',
        () async {
      // seed v16 row
      await db.insert('conversation', {
        'user_id': 1,
        'peer_id': 42,
        'type': 'C2G',
        'unread_num': 3,
      });

      await db.execute(_v17Upgrade);

      final info = await tableInfo(db, 'conversation');
      expect(hasColumn(info, 'mention_unread'), isTrue);

      final rows = await db.rawQuery(
          'SELECT mention_unread, unread_num FROM conversation');
      expect(rows, hasLength(1));
      expect(rows.first['mention_unread'], 0,
          reason: 'existing v16 row must get default 0');
      expect(rows.first['unread_num'], 3);
    });

    test('v17 table accepts explicit mention_unread writes', () async {
      await db.execute(_v17Upgrade);

      await db.insert('conversation', {
        'user_id': 1,
        'peer_id': 42,
        'type': 'C2G',
        'unread_num': 5,
        'mention_unread': 2,
      });

      final rows = await db
          .rawQuery('SELECT mention_unread, unread_num FROM conversation');
      expect(rows.first['mention_unread'], 2);
      expect(rows.first['unread_num'], 5);
    });
  });

  group('v17 → v16 downgrade (C7-β)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute(_v16ConversationDDL);
      await db.execute(_v17Upgrade);
    });

    tearDown(() async => db.close());

    test('after downgrade: mention_unread column is gone', () async {
      await db.insert('conversation', {
        'user_id': 1,
        'peer_id': 42,
        'type': 'C2G',
        'unread_num': 5,
        'mention_unread': 7,
      });

      for (final stmt in _v17DowngradeStmts) {
        await db.execute(stmt);
      }

      final info = await tableInfo(db, 'conversation');
      expect(hasColumn(info, 'mention_unread'), isFalse);
      expect(hasColumn(info, 'unread_num'), isTrue,
          reason: 'other columns must be preserved');
    });

    test('downgrade preserves non-mention_unread data', () async {
      await db.insert('conversation', {
        'user_id': 9,
        'peer_id': 123,
        'title': 'Test Group',
        'type': 'C2G',
        'unread_num': 4,
        'mention_unread': 2,
      });

      for (final stmt in _v17DowngradeStmts) {
        await db.execute(stmt);
      }

      final rows = await db.rawQuery(
          'SELECT user_id, peer_id, title, unread_num FROM conversation');
      expect(rows, hasLength(1));
      expect(rows.first['user_id'], 9);
      expect(rows.first['peer_id'], 123);
      expect(rows.first['title'], 'Test Group');
      expect(rows.first['unread_num'], 4);
    });
  });
}
