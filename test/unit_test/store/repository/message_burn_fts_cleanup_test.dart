// 范围删除（deleteByUid / deleteByConversationId）的 FTS 索引同步清理。
//
// 风险线（wave2 burn 残留线索）：v37 基线（当前注册版本，本地 SQLite FTS
// 活路径）的 FTS5 表是 contentless 且无删除触发器，v38 触发器有意未注册；
// 修复前 deleteByUid（删联系人，contact_setting_provider.dart:79）与
// deleteByConversationId（退群清空，group_detail_service.dart:154）直接删
// 消息行、不清索引，已删消息正文仍可经 FTS 搜到——对阅后即焚消息即正文
// 泄露。修复后两条路径在删行**之前**按同一 WHERE 批量清索引，且清索引 +
// 删行整体置于 MessageRepo._ftsReindexLock 内，与 _reindexFts 延迟任务互斥，
// 同时消除「入库→延迟索引窗口内被删除，索引写入已删消息」的窄竞态。
//
// setup 与 message_fts_transaction_test.dart 同构：生产真源 schema 的
// fixture 库（version 37，contentless FTS、无触发器），repo 写入 +
// waitForFtsReindexForTest 等待延迟重索引。
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/message_fts_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  for (final type in ['C2C', 'C2G']) {
    test(
      'deleteByUid $type clears FTS terms without touching other uids',
      () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final db = await openFixtureDatabaseAtVersion(
          version: kInventoryCurrentDbVersion,
        );
        SqliteService.setDbForTest(db);
        final table = type == 'C2C'
            ? MessageRepo.c2cTable
            : MessageRepo.c2gTable;
        final repo = MessageRepo(tableName: table);
        final fts = MessageFtsRepo();
        Future<int> matches(String word) async => (await db.rawQuery(
          'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          [word],
        )).length;
        try {
          await repo.insert(
            MessageModel(
              '116837000000000201',
              autoId: 1,
              type: type,
              status: IMBoyMessageStatus.delivered,
              fromId: 200,
              toId: 100,
              payload: {'text': 'uidsecreta'},
              createdAt: 1700000000000,
              isAuthor: 0,
              conversationUk3: 'synthetic',
              msgType: 'text',
            ),
          );
          await repo.insert(
            MessageModel(
              '116837000000000202',
              autoId: 2,
              type: type,
              status: IMBoyMessageStatus.delivered,
              fromId: 300,
              toId: 100,
              payload: {'text': 'uidsecretb'},
              createdAt: 1700000000001,
              isAuthor: 0,
              conversationUk3: 'synthetic',
              msgType: 'text',
            ),
          );
          await repo.waitForFtsReindexForTest();
          expect(await matches('uidsecreta'), 1);
          expect(await matches('uidsecretb'), 1);

          expect(await repo.deleteByUid('200'), 1);
          await repo.waitForFtsReindexForTest();

          // 行已出库；被删 uid 的词条无残留
          expect(await repo.find('116837000000000201'), isNull);
          expect(await matches('uidsecreta'), 0);
          // 范围正确性：其他 uid 的消息与索引不受影响
          expect(await repo.find('116837000000000202'), isNotNull);
          expect(await matches('uidsecretb'), 1);
          // 搜索入口：已删消息不再命中，存活消息仍可搜到
          final gone = type == 'C2C'
              ? await fts.searchC2c(
                  query: 'uidsecreta',
                  conversationUk3: 'synthetic',
                )
              : await fts.searchC2g(
                  query: 'uidsecreta',
                  conversationUk3: 'synthetic',
                );
          expect(gone, isEmpty);
          final kept = type == 'C2C'
              ? await fts.searchC2c(
                  query: 'uidsecretb',
                  conversationUk3: 'synthetic',
                )
              : await fts.searchC2g(
                  query: 'uidsecretb',
                  conversationUk3: 'synthetic',
                );
          expect(kept.map((r) => r.id), ['116837000000000202']);
        } finally {
          await repo.waitForFtsReindexForTest();
          SqliteService.setDbForTest(null);
          await db.close();
        }
      },
    );

    test(
      'deleteByConversationId $type clears FTS terms for the whole conversation',
      () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final db = await openFixtureDatabaseAtVersion(
          version: kInventoryCurrentDbVersion,
        );
        SqliteService.setDbForTest(db);
        final table = type == 'C2C'
            ? MessageRepo.c2cTable
            : MessageRepo.c2gTable;
        final repo = MessageRepo(tableName: table);
        final fts = MessageFtsRepo();
        Future<int> matches(String word) async => (await db.rawQuery(
          'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          [word],
        )).length;
        try {
          // 同会话两条，其一为阅后即焚 payload（退群清空场景下 burn 消息
          // 同样必须索引同步清空）
          await repo.insert(
            MessageModel(
              '116837000000000203',
              autoId: 1,
              type: type,
              status: IMBoyMessageStatus.seen,
              fromId: 200,
              toId: 100,
              payload: {
                'text': 'convsecretc',
                'burn': true,
                'burn_after_ms': 60000,
                'burn_read_at': 1700000001000,
              },
              createdAt: 1700000000000,
              isAuthor: 0,
              conversationUk3: 'synthetic',
              msgType: 'text',
            ),
          );
          await repo.insert(
            MessageModel(
              '116837000000000204',
              autoId: 2,
              type: type,
              status: IMBoyMessageStatus.delivered,
              fromId: 200,
              toId: 100,
              payload: {'text': 'convsecretd'},
              createdAt: 1700000000001,
              isAuthor: 0,
              conversationUk3: 'synthetic',
              msgType: 'text',
            ),
          );
          await repo.insert(
            MessageModel(
              '116837000000000205',
              autoId: 3,
              type: type,
              status: IMBoyMessageStatus.delivered,
              fromId: 200,
              toId: 100,
              payload: {'text': 'convsecrete'},
              createdAt: 1700000000002,
              isAuthor: 0,
              conversationUk3: 'synthetic-keep',
              msgType: 'text',
            ),
          );
          await repo.waitForFtsReindexForTest();
          expect(await matches('convsecretc'), 1);
          expect(await matches('convsecretd'), 1);
          expect(await matches('convsecrete'), 1);

          expect(await repo.deleteByConversationId('synthetic'), 2);
          await repo.waitForFtsReindexForTest();

          expect(await repo.find('116837000000000203'), isNull);
          expect(await repo.find('116837000000000204'), isNull);
          // 含 burn 消息在内，被清会话的词条零残留
          expect(await matches('convsecretc'), 0);
          expect(await matches('convsecretd'), 0);
          // 其他会话不受影响
          expect(await repo.find('116837000000000205'), isNotNull);
          expect(await matches('convsecrete'), 1);
          final results = type == 'C2C'
              ? await fts.searchC2c(
                  query: 'convsecretc',
                  conversationUk3: 'synthetic',
                )
              : await fts.searchC2g(
                  query: 'convsecretc',
                  conversationUk3: 'synthetic',
                );
          expect(results, isEmpty);
        } finally {
          await repo.waitForFtsReindexForTest();
          SqliteService.setDbForTest(null);
          await db.close();
        }
      },
    );

    test(
      'late reindex after $type range delete does not resurrect FTS entry',
      () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final db = await openFixtureDatabaseAtVersion(
          version: kInventoryCurrentDbVersion,
        );
        SqliteService.setDbForTest(db);
        final table = type == 'C2C'
            ? MessageRepo.c2cTable
            : MessageRepo.c2gTable;
        final repo = MessageRepo(tableName: table);
        Future<int> matches(String word) async => (await db.rawQuery(
          'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          [word],
        )).length;
        try {
          // 不等待延迟重索引，立即范围删除：入库→延迟索引窗口与删除交错
          // （重索引任务先于或后于删除执行都必须收敛为零索引——修复前
          // 「删除先拿锁」时序会把已删消息写回索引，此处为竞态不变量断言）
          await repo.insert(
            MessageModel(
              '116837000000000206',
              autoId: 1,
              type: type,
              status: IMBoyMessageStatus.delivered,
              fromId: 200,
              toId: 100,
              payload: {'text': 'racelatesecret'},
              createdAt: 1700000000000,
              isAuthor: 0,
              conversationUk3: 'synthetic',
              msgType: 'text',
            ),
          );
          expect(await repo.deleteByUid('200'), 1);
          await repo.waitForFtsReindexForTest();

          expect(await repo.find('116837000000000206'), isNull);
          expect(await matches('racelatesecret'), 0);

          // 行已删：对同 id 的迟到 update 不命中任何行，也不得让索引复活
          expect(
            await repo.update({
              MessageRepo.id: '116837000000000206',
              MessageRepo.payload: {'text': 'resurrectsecret'},
            }),
            0,
          );
          await repo.waitForFtsReindexForTest();
          expect(await matches('resurrectsecret'), 0);
        } finally {
          await repo.waitForFtsReindexForTest();
          SqliteService.setDbForTest(null);
          await db.close();
        }
      },
    );

    test(
      'burn message removed by $type deleteByUid is unrecoverable via searchAll',
      () async {
        SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
        await StorageService.init();
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
        final db = await openFixtureDatabaseAtVersion(
          version: kInventoryCurrentDbVersion,
        );
        SqliteService.setDbForTest(db);
        final table = type == 'C2C'
            ? MessageRepo.c2cTable
            : MessageRepo.c2gTable;
        final repo = MessageRepo(tableName: table);
        final fts = MessageFtsRepo();
        Future<int> matches(String word) async => (await db.rawQuery(
          'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          [word],
        )).length;
        try {
          // payload 键与 ChatBurnService.isBurnPayload / burnAfterMsFromPayload /
          // burnReadAtMsFromPayload 读取的现网形态一致
          await repo.insert(
            MessageModel(
              '116837000000000207',
              autoId: 1,
              type: type,
              status: IMBoyMessageStatus.seen,
              fromId: 200,
              toId: 100,
              payload: {
                'text': 'burnrangeword',
                'burn': true,
                'burn_after_ms': 60000,
                'burn_read_at': 1700000001000,
              },
              createdAt: 1700000000000,
              isAuthor: 0,
              conversationUk3: 'synthetic',
              msgType: 'text',
            ),
          );
          await repo.waitForFtsReindexForTest();
          expect(await matches('burnrangeword'), 1);

          expect(await repo.deleteByUid('200'), 1);
          await repo.waitForFtsReindexForTest();

          expect(await repo.find('116837000000000207'), isNull);
          expect(await matches('burnrangeword'), 0);
          // 全局搜索入口（C2C + C2G 合并）也不得返回已销毁正文
          final results = await fts.searchAll(
            query: 'burnrangeword',
            conversationUk3: 'synthetic',
          );
          expect(results, isEmpty);
        } finally {
          await repo.waitForFtsReindexForTest();
          SqliteService.setDbForTest(null);
          await db.close();
        }
      },
    );
  }
}
