/// Tests for MessageRepo.queryCountBySenderInGroup (C2 Layer B).
///
/// Uses sqflite_common_ffi in-memory DB (existing project pattern,
/// see test/integration/db_multi_version_downgrade_test.dart).
///
/// Schema under test: msg_c2g(from_id INTEGER, conversation_uk3 TEXT,
/// created_at INTEGER, ...). See assets/migrations/upgrade.sql:911.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/repository/mention_frequency_repo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _uk3A = 'c2g:1:gid_A';
const _uk3B = 'c2g:1:gid_B';

Future<Database> openFixture() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE msg_c2g (
            auto_id INTEGER PRIMARY KEY AUTOINCREMENT,
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
            type TEXT DEFAULT 'C2G',
            action TEXT DEFAULT ''
          )
        ''');
      },
    ),
  );
  return db;
}

Future<void> seed(
  Database db, {
  required int id,
  required int fromId,
  required String uk3,
  required int createdAt,
}) async {
  await db.insert('msg_c2g', {
    'id': id,
    'from_id': fromId,
    'to_id': 999,
    'conversation_uk3': uk3,
    'created_at': createdAt,
    'payload': '{}',
    'status': 0,
    'is_author': 0,
    'type': 'C2G',
  });
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('MentionFrequencyRepo.queryWith', () {
    late Database db;

    setUp(() async {
      db = await openFixture();
    });

    tearDown(() async {
      await db.close();
    });

    test('empty table returns empty map', () async {
      final result = await MentionFrequencyRepo.queryWith(
        db,
        conversationUk3: _uk3A,
        sinceMs: 0,
      );
      expect(result, isEmpty);
    });

    test('single sender with N messages returns {uid: N}', () async {
      for (var i = 0; i < 3; i++) {
        await seed(db, id: 100 + i, fromId: 42, uk3: _uk3A, createdAt: 1000);
      }
      final result = await MentionFrequencyRepo.queryWith(
        db,
        conversationUk3: _uk3A,
        sinceMs: 0,
      );
      expect(result, {'42': 3});
    });

    test('multiple senders are grouped correctly', () async {
      await seed(db, id: 1, fromId: 10, uk3: _uk3A, createdAt: 1000);
      await seed(db, id: 2, fromId: 10, uk3: _uk3A, createdAt: 1100);
      await seed(db, id: 3, fromId: 20, uk3: _uk3A, createdAt: 1200);
      await seed(db, id: 4, fromId: 30, uk3: _uk3A, createdAt: 1300);
      await seed(db, id: 5, fromId: 30, uk3: _uk3A, createdAt: 1400);
      await seed(db, id: 6, fromId: 30, uk3: _uk3A, createdAt: 1500);

      final result = await MentionFrequencyRepo.queryWith(
        db,
        conversationUk3: _uk3A,
        sinceMs: 0,
      );
      expect(result, {'10': 2, '20': 1, '30': 3});
    });

    test('messages older than sinceMs are excluded', () async {
      await seed(db, id: 1, fromId: 10, uk3: _uk3A, createdAt: 500);
      await seed(db, id: 2, fromId: 10, uk3: _uk3A, createdAt: 1500);
      await seed(db, id: 3, fromId: 20, uk3: _uk3A, createdAt: 2000);

      final result = await MentionFrequencyRepo.queryWith(
        db,
        conversationUk3: _uk3A,
        sinceMs: 1000,
      );
      expect(result, {'10': 1, '20': 1}, reason: 'id=1 at 500ms is excluded');
    });

    test('messages in a different conversation are excluded', () async {
      await seed(db, id: 1, fromId: 10, uk3: _uk3A, createdAt: 1000);
      await seed(db, id: 2, fromId: 10, uk3: _uk3B, createdAt: 1000);
      await seed(db, id: 3, fromId: 20, uk3: _uk3A, createdAt: 1000);

      final result = await MentionFrequencyRepo.queryWith(
        db,
        conversationUk3: _uk3A,
        sinceMs: 0,
      );
      expect(result, {'10': 1, '20': 1});
    });

    test('sinceMs=0 counts all time (no lower bound effective)', () async {
      await seed(db, id: 1, fromId: 10, uk3: _uk3A, createdAt: 0);
      await seed(db, id: 2, fromId: 10, uk3: _uk3A, createdAt: 9999999);
      final result = await MentionFrequencyRepo.queryWith(
        db,
        conversationUk3: _uk3A,
        sinceMs: 0,
      );
      expect(result, {'10': 2});
    });

    test(
        'edge: message with created_at exactly equal to sinceMs is INCLUDED '
        '(boundary is inclusive)', () async {
      await seed(db, id: 1, fromId: 7, uk3: _uk3A, createdAt: 5000);
      final result = await MentionFrequencyRepo.queryWith(
        db,
        conversationUk3: _uk3A,
        sinceMs: 5000,
      );
      expect(result, {'7': 1});
    });
  });
}
