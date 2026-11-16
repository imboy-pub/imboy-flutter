import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late MessageRetry retry;
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '100'});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await openFixtureDatabaseAtVersion(
      version: kInventoryCurrentDbVersion,
    );
    SqliteService.setDbForTest(db);
    retry = MessageRetry.instance;
    retry.clearRetryQueue();
    await retry.debugWaitForIdle();
  });
  tearDown(() async {
    retry.dispose();
    await retry.debugWaitForIdle();
    SqliteService.setDbForTest(null);
    await db.close();
  });

  for (final type in ['C2C', 'C2G']) {
    for (final deleteConversation in [false, true]) {
      final operation = deleteConversation
          ? 'deleteConversation'
          : 'clearMessages';
      test('$operation $type deletes FTS terms before rowid reuse', () async {
        final conversations = ConversationRepo();
        final conversation = await conversations.save(
          ConversationModel(
            id: 0,
            peerId: '200',
            avatar: '',
            title: 'Synthetic',
            subtitle: 'deletedsecret',
            type: type,
            msgType: 'text',
            lastTime: 1700000000000,
            lastMsgId: 'message-one',
            unreadNum: 0,
            payload: {
              'text': 'deletedsecret',
              'sys_prompt': 'deletedsecret',
              'burn_enabled': true,
              'burn_after_ms': 3000,
              'last_read_auto_id': 7,
              'member_generation_id': 'synthetic-generation',
              'authoritative': {
                'is_pinned': true,
                'last_msg': {'text': 'deletedsecret'},
              },
            },
          ),
        );
        final table = MessageRepo.getTableName(type);
        final messages = MessageRepo(tableName: table);
        MessageModel message(String id, String uk3, String text) =>
            MessageModel(
              id,
              autoId: 0,
              type: type,
              status: IMBoyMessageStatus.delivered,
              fromId: '200',
              toId: '100',
              payload: {'text': text},
              createdAt: 1700000000000,
              isAuthor: 0,
              conversationUk3: uk3,
              msgType: 'text',
            );
        Future<List<Map<String, Object?>>> matches(String word) => db.rawQuery(
          'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
          [word],
        );
        await messages.insert(
          message('message-one', conversation.uk3, 'deletedsecret'),
        );
        await messages.waitForFtsReindexForTest();
        final oldRowId = (await messages.find('message-one'))!.autoId;
        expect(await matches('deletedsecret'), hasLength(1));
        expect(
          await messages.update({
            'id': 'message-one',
            'payload': {'text': 'editedsecret'},
          }),
          1,
        );
        await messages.waitForFtsReindexForTest();
        expect(await matches('deletedsecret'), isEmpty);
        expect(await matches('editedsecret'), hasLength(1));
        retry.addToRetryQueue('message-one', type);
        expect(retry.getRetryInfo('message-one'), isNotNull);

        // A stale caller snapshot must not overwrite a setting changed later.
        await conversations.updateById(conversation.id, {
          ConversationRepo.payload: {
            ...?conversation.payload,
            'burn_after_ms': 9000,
          },
        });

        if (deleteConversation) {
          expect(await conversations.deleteConversation(conversation), 1);
          expect(await conversations.findById(conversation.id), isNull);
        } else {
          final cleared = await conversations.clearMessages(conversation);
          expect(cleared?.lastMsgId, '');
          expect(cleared?.subtitle, '');
          expect(cleared?.payload, {
            'burn_enabled': true,
            'burn_after_ms': 9000,
            'last_read_auto_id': 7,
            'member_generation_id': 'synthetic-generation',
            'authoritative': {'is_pinned': true},
          });
        }
        expect(retry.getRetryInfo('message-one'), isNull);
        expect(await messages.find('message-one'), isNull);
        expect(await matches('deletedsecret'), isEmpty);
        expect(await matches('editedsecret'), isEmpty);
        await messages.insert(
          message('message-two', conversation.uk3, 'newsecret'),
        );
        await messages.waitForFtsReindexForTest();
        expect(
          (await messages.find('message-two'))!.autoId,
          oldRowId,
          reason: 'SQLite reuses the deleted highest rowid',
        );
        expect(await matches('deletedsecret'), isEmpty);
        expect(await matches('editedsecret'), isEmpty);
        expect(await matches('newsecret'), hasLength(1));
      });
    }

    test(
      'failed $type conversation clear rolls back message and index together',
      () async {
        final conversations = ConversationRepo();
        final conversation = await conversations.save(
          ConversationModel(
            id: 0,
            peerId: '200',
            avatar: '',
            title: 'Synthetic',
            subtitle: 'keptsecret',
            type: type,
            msgType: 'text',
            lastTime: 1700000000000,
            lastMsgId: 'message-one',
            unreadNum: 0,
          ),
        );
        final table = MessageRepo.getTableName(type);
        final messages = MessageRepo(tableName: table);
        await messages.insert(
          MessageModel(
            'message-one',
            autoId: 0,
            type: type,
            status: IMBoyMessageStatus.delivered,
            fromId: '200',
            toId: '100',
            payload: {'text': 'keptsecret'},
            createdAt: 1700000000000,
            isAuthor: 0,
            conversationUk3: conversation.uk3,
            msgType: 'text',
          ),
        );
        await messages.waitForFtsReindexForTest();
        retry.addToRetryQueue('message-one', type);
        final pending = retry.getRetryInfo('message-one');
        expect(pending, isNotNull);
        await db.execute(
          "CREATE TRIGGER reject_clear BEFORE UPDATE ON conversation "
          "BEGIN SELECT RAISE(ABORT, 'synthetic clear failure'); END",
        );
        await expectLater(
          conversations.clearMessages(conversation),
          throwsA(isA<DatabaseException>()),
        );
        expect(await messages.find('message-one'), isNotNull);
        expect(retry.getRetryInfo('message-one'), same(pending));
        expect(
          (await conversations.findById(conversation.id))!.lastMsgId,
          'message-one',
        );
        expect(
          await db.rawQuery(
            'SELECT rowid FROM ${table}_fts WHERE ${table}_fts MATCH ?',
            ['keptsecret'],
          ),
          hasLength(1),
        );
      },
    );
  }
}
