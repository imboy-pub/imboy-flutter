import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';

import '../../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// 只控制真实 SQLite 查询返回时的时钟/会话变化，不伪造查询结果或排序。
class _ObservedQueryDatabase implements Database {
  _ObservedQueryDatabase(this.delegate, this.onQueryCompleted);

  final Database delegate;
  final FutureOr<void> Function(String sql) onQueryCompleted;

  @override
  bool get isOpen => delegate.isOpen;

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final rows = await delegate.rawQuery(sql, arguments);
    await onQueryCompleted(sql);
    return rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('MessageFtsRepo.extractTextContent', () {
    test('text 消息提取 payload.text', () {
      expect(
        MessageFtsRepo.extractTextContent('text', {'text': '你好世界'}),
        '你好世界',
      );
    });

    test('quote 消息提取 payload.quote_text', () {
      expect(
        MessageFtsRepo.extractTextContent('quote', {'quote_text': '引用内容'}),
        '引用内容',
      );
    });

    test('location 消息拼接 title + address', () {
      expect(
        MessageFtsRepo.extractTextContent('location', {
          'title': '天安门',
          'address': '北京市东城区',
        }),
        '天安门 北京市东城区',
      );
    });

    test('location 仅 title', () {
      expect(
        MessageFtsRepo.extractTextContent('location', {'title': '故宫'}),
        '故宫',
      );
    });

    test('image 消息返回空', () {
      expect(
        MessageFtsRepo.extractTextContent('image', {'url': 'http://...'}),
        '',
      );
    });

    test('video 消息返回空', () {
      expect(
        MessageFtsRepo.extractTextContent('video', {'url': 'http://...'}),
        '',
      );
    });

    test('voice 消息返回空', () {
      expect(MessageFtsRepo.extractTextContent('voice', {'duration': 5}), '');
    });

    test('file 消息返回空', () {
      expect(
        MessageFtsRepo.extractTextContent('file', {'filename': 'doc.pdf'}),
        '',
      );
    });

    test('null msgType 返回空', () {
      expect(MessageFtsRepo.extractTextContent(null, {'text': 'hello'}), '');
    });

    test('空 text 返回空', () {
      expect(MessageFtsRepo.extractTextContent('text', {'text': '  '}), '');
    });

    test('text 内容去除前后空白', () {
      expect(
        MessageFtsRepo.extractTextContent('text', {'text': '  hello  '}),
        'hello',
      );
    });

    test('非字符串字段和解密失败占位不参与索引', () {
      expect(
        MessageFtsRepo.extractTextContent('text', {
          'text': {'ciphertext': 'secret'},
        }),
        '',
      );
      expect(
        MessageFtsRepo.extractTextContent('quote', {'quote_text': 42}),
        '',
      );
      expect(
        MessageFtsRepo.extractTextContent('location', {
          'title': ['secret'],
          'address': ' 地址 ',
        }),
        '地址',
      );
      expect(
        MessageFtsRepo.extractTextContent('text', {
          '_e2ee_failed': true,
          'text': 'placeholder',
        }),
        '',
      );
    });
  });

  group('FtsSearchResult', () {
    test('构造正确', () {
      final result = FtsSearchResult(
        id: 'msg1',
        conversationUk3: 'C2C_a_b',
        snippet: '搜索<b>关键词</b>',
        rank: -1.5,
      );
      expect(result.id, 'msg1');
      expect(result.conversationUk3, 'C2C_a_b');
      expect(result.snippet, '搜索<b>关键词</b>');
      expect(result.rank, -1.5);
    });
  });

  group('MessageFtsRepo 索引幂等（in-memory FTS5）', () {
    test('重复索引同 id 不产生双行，重索引后命中新文本', () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      SqliteService.setDbForTest(db);
      addTearDown(() async {
        SqliteService.setDbForTest(null);
        await db.close();
      });
      await db.execute(
        'CREATE VIRTUAL TABLE msg_c2c_fts USING fts5('
        'id, conversation_uk3, text_content)',
      );
      await db.execute(
        'CREATE TABLE msg_c2c(auto_id INTEGER PRIMARY KEY, id TEXT, '
        'conversation_uk3 TEXT, payload TEXT, msg_type TEXT, status INTEGER, '
        'is_author INTEGER, created_at INTEGER)',
      );
      await db.insert('msg_c2c', {
        'auto_id': 1,
        'id': 'm1',
        'conversation_uk3': 'c1',
        'payload': jsonEncode({'text': 'recovered plaintext hello'}),
        'msg_type': 'text',
        'status': 20,
        'is_author': 0,
        'created_at': 1000,
      });

      final repo = MessageFtsRepo();

      // 首次索引：占位文本（E2EE 失败行落库形态）
      await repo.indexC2cMessage(
        id: 'm1',
        conversationUk3: 'c1',
        textContent: '[encrypt placeholder]',
        rowid: 1,
      );
      // 幂等重复索引：占位行恢复明文后 update 重索引
      await repo.indexC2cMessage(
        id: 'm1',
        conversationUk3: 'c1',
        textContent: 'recovered plaintext hello',
        rowid: 1,
      );

      final rows = await db.query(
        'msg_c2c_fts',
        where: 'id = ?',
        whereArgs: ['m1'],
      );
      expect(rows, hasLength(1), reason: '重复索引不得产生双行');
      expect(rows.first['text_content'], 'recovered plaintext hello');

      // 明文关键词必须可搜（占位残留时搜不到）
      final hits = await repo.searchC2c(query: 'plaintext');
      expect(hits.map((h) => h.id), contains('m1'));
    });
  });

  for (final type in ['C2C', 'C2G']) {
    group('FTS $type current message visibility', () {
      late Database db;
      final table = type == 'C2C' ? 'msg_c2c' : 'msg_c2g';
      var now = 100000;

      setUp(() async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        db = await openFixtureDatabaseAtVersion(
          version: kInventoryCurrentDbVersion,
        );
        SqliteService.setDbForTest(db);
        now = 100000;
      });
      tearDown(() async {
        SqliteService.setDbForTest(null);
        await db.close();
      });

      Future<void> seed(
        String id,
        Map<String, dynamic> payload, {
        int isAuthor = 0,
        int createdAt = 1,
        int status = 20,
        String? rawPayload,
      }) async {
        final rowid = await db.insert(table, {
          'id': id,
          'type': type,
          'conversation_uk3': 'synthetic',
          'msg_type': 'text',
          'status': status,
          'is_author': isAuthor,
          'created_at': createdAt,
          'payload':
              rawPayload ?? jsonEncode({'text': 'searchword', ...payload}),
        });
        // Retain stale terms intentionally: lifecycle filtering must work even
        // when asynchronous deletion/reindexing has not run yet.
        await db.insert('${table}_fts', {
          'rowid': rowid,
          'id': id,
          'conversation_uk3': 'synthetic',
          'text_content': 'searchword',
        });
      }

      Future<List<FtsSearchResult>> search({int limit = 50}) {
        final repo = MessageFtsRepo(nowMs: () => now);
        return type == 'C2C'
            ? repo.searchC2c(
                query: 'searchword',
                limit: limit,
                throwOnError: true,
              )
            : repo.searchC2g(
                query: 'searchword',
                limit: limit,
                throwOnError: true,
              );
      }

      test(
        'deadline, unread, author and tombstone rules filter stale terms',
        () async {
          await seed('01-expired-read', {
            'burn': true,
            'burn_after_ms': 1000,
            'burn_read_at': 99000,
          });
          await seed('02-live-read', {
            'burn': true,
            'burn_after_ms': '1000',
            'burn_read_at': '99001',
          });
          await seed('03-unread-recipient', {
            'burn': true,
            'burn_after_ms': 1000,
          });
          await seed(
            '04-expired-author',
            {'burn': true, 'burn_after_ms': 1000},
            isAuthor: 1,
            createdAt: 99000,
          );
          await seed(
            '05-live-author',
            {'is_burn': true, 'expiry_time': 1000},
            isAuthor: 1,
            createdAt: 99001,
          );
          await seed('06-ordinary', {});
          await seed('07-tombstone', {'burn_deleted': true});
          await seed('08-revoked', {}, status: 30);
          await seed('09-undecrypted', {'_e2ee_failed': true});
          await seed('10-malformed', {}, rawPayload: '{broken');
          await seed('11-non-object', {}, rawPayload: '[]');

          final visible = await search();
          expect(
            visible.map((r) => r.id),
            unorderedEquals([
              '02-live-read',
              '03-unread-recipient',
              '05-live-author',
              '06-ordinary',
            ]),
          );
          final ranks = visible.map((r) => r.rank).toList();
          expect(ranks, orderedEquals([...ranks]..sort()));
          now = 100001;
          expect(
            (await search()).map((r) => r.id),
            unorderedEquals(['03-unread-recipient', '06-ordinary']),
          );
          expect(
            await db.rawQuery(
              'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
              ['searchword'],
            ),
            hasLength(11),
            reason: 'prove read-time filtering without index deletion',
          );
        },
      );

      test(
        'expired first batch cannot consume the visible result limit',
        () async {
          for (var i = 0; i < 65; i++) {
            await seed(i.toString().padLeft(3, '0'), {
              'burn': true,
              'burn_after_ms': 1000,
              'burn_read_at': 99000,
            });
          }
          await seed('999-live', {});
          expect((await search(limit: 1)).map((r) => r.id), ['999-live']);
        },
      );

      test(
        'an earlier batch expires while the next query is awaited',
        () async {
          await seed('000-expiring', {
            'burn': true,
            'burn_after_ms': 1000,
            'burn_read_at': 99001,
          });
          for (var i = 1; i < 64; i++) {
            await seed(i.toString().padLeft(3, '0'), {
              'burn': true,
              'burn_after_ms': 1000,
              'burn_read_at': 99000,
            });
          }
          await seed('100-live', {});
          await seed('101-live', {});
          var queries = 0;
          SqliteService.setDbForTest(
            _ObservedQueryDatabase(db, (sql) {
              if (sql.contains('JOIN $table AS message')) {
                queries++;
                if (queries == 2) now = 100001;
              }
            }),
          );

          expect((await search(limit: 2)).map((r) => r.id), [
            '100-live',
            '101-live',
          ]);
          expect(queries, greaterThanOrEqualTo(2));
        },
      );

      if (type == 'C2C') {
        test(
          'combined search discards earlier rows after an account switch',
          () async {
            await seed('old-account-result', {});
            var switched = false;
            SqliteService.setDbForTest(
              _ObservedQueryDatabase(db, (sql) async {
                if (sql.contains('JOIN msg_c2g AS message')) {
                  switched = true;
                  await StorageService.to.setString(Keys.currentUid, '200');
                }
              }),
            );

            final results = await MessageFtsRepo(nowMs: () => now)
                .searchAll(query: 'searchword', throwOnError: true);
            expect(switched, isTrue);
            expect(results, isEmpty);
          },
        );

        test('combined search rechecks C2C after awaiting C2G', () async {
          await seed('01-expiring', {
            'burn': true,
            'burn_after_ms': 1000,
            'burn_read_at': 99001,
          });
          await seed('02-live', {});
          final groupRowId = await db.insert('msg_c2g', {
            'id': '03-group',
            'conversation_uk3': 'synthetic',
            'msg_type': 'text',
            'status': 20,
            'is_author': 0,
            'created_at': 1,
            'payload': jsonEncode({'text': 'searchword'}),
          });
          await db.insert('msg_c2g_fts', {
            'rowid': groupRowId,
            'id': '03-group',
            'conversation_uk3': 'synthetic',
            'text_content': 'searchword',
          });
          var advanced = false;
          SqliteService.setDbForTest(
            _ObservedQueryDatabase(db, (sql) {
              if (sql.contains('JOIN msg_c2g AS message')) {
                advanced = true;
                now = 100001;
              }
            }),
          );

          final results = await MessageFtsRepo(nowMs: () => now)
              .searchAll(query: 'searchword', limit: 3, throwOnError: true);
          expect(advanced, isTrue);
          expect(
            results.map((result) => result.id),
            unorderedEquals(['02-live', '03-group']),
          );
        });
      }
    });
  }

  test(
    'an orphan FTS index cannot bypass missing message lifecycle data',
    () async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
      await StorageService.init();
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      SqliteService.setDbForTest(db);
      addTearDown(() async {
        SqliteService.setDbForTest(null);
        await db.close();
      });
      await db.execute(
        'CREATE VIRTUAL TABLE msg_c2c_fts USING fts5('
        'id, conversation_uk3, text_content)',
      );
      await db.insert('msg_c2c_fts', {
        'id': 'orphan',
        'conversation_uk3': 'synthetic',
        'text_content': 'searchword',
      });
      final repo = MessageFtsRepo();
      expect(await repo.searchC2c(query: 'searchword'), isEmpty);
      await expectLater(
        repo.searchC2c(query: 'searchword', throwOnError: true),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test(
    'nonpositive result limits are empty for individual and combined search',
    () async {
      final repo = MessageFtsRepo();
      for (final limit in [0, -1]) {
        expect(
          await repo.searchC2c(query: 'searchword', limit: limit),
          isEmpty,
        );
        expect(
          await repo.searchAll(query: 'searchword', limit: limit),
          isEmpty,
        );
      }
    },
  );
}
