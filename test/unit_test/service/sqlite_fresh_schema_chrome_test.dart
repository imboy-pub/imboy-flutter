@TestOn('chrome')
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/schema_contract.dart';
import 'package:imboy/service/server_ack_receipts.dart';
import 'package:imboy/service/sqflite_init.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/channel_inbox_preference_repo_sqlite.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqflite.dart' as common;
import 'package:web/web.dart' as web;

import '../../env_test_pin.dart';

// Independent inventory: released v36 golden has these 25 application tables;
// registered v39 adds local channel preferences, and production creation adds
// schema metadata. v38 trigger changes remain an unregistered draft.
const _tables = {
  'attachment_upload_task',
  'channel',
  'channel_admin',
  'channel_message',
  'channel_message_outbox',
  'channel_publish_outbox',
  'channel_subscription',
  'contact',
  'conversation',
  'group',
  'group_member',
  'group_notice',
  'moment_notify',
  'msg_c2c',
  'msg_c2c_fts',
  'msg_c2g',
  'msg_c2g_fts',
  'msg_c2s',
  'msg_s2c',
  'new_friend',
  'user_collect',
  'user_denylist',
  'user_device',
  'user_group',
  'user_tag',
  'channel_inbox_preference',
  '_imboy_schema_meta',
};

Future<List<Map<String, Object?>>> _objects(common.Database db) => db.rawQuery(
  "SELECT type, name, tbl_name, sql FROM sqlite_master "
  "WHERE name NOT LIKE 'sqlite_%' ORDER BY type, name",
);

Future<void> _verifyProductionSchema(common.Database db) async {
  expect(await db.getVersion(), 39);
  final objects = await _objects(db);
  final tables = {
    for (final row in objects)
      if (row['type'] == 'table') row['name'] as String,
  };
  for (final prefix in ['msg_c2c_fts', 'msg_c2g_fts']) {
    for (final suffix in ['data', 'idx', 'docsize', 'config']) {
      tables.remove('${prefix}_$suffix');
    }
  }
  // ignore: avoid_print
  print(
    'WEB_SQLITE_SCHEMA_ORACLE version=${await db.getVersion()} '
    'tables=${tables.toList()..sort()}',
  );
  expect(tables, _tables);
  final indexes = {
    for (final row in objects)
      if (row['type'] == 'index') row['name'] as String,
  };
  expect(
    indexes,
    containsAll([
      'idx_contact_user_id_peer_id',
      'uk_cv_Type_From_To',
      'idx_msg_c2c_conversation_conv_seq',
      'idx_msg_c2g_conversation_conv_seq',
      'idx_attachment_upload_task_user_stage',
    ]),
  );
  expect(
    objects.where((row) => row['type'] == 'trigger'),
    isEmpty,
    reason: 'Fresh v39 must not silently activate the unregistered v38 draft',
  );
  final idColumn = (await db.rawQuery('PRAGMA table_info(msg_c2c)'))
      .singleWhere((row) => row['name'] == 'id');
  expect(idColumn['type'], 'TEXT');
  expect(await SchemaContract.verifyInvariants(db, version: 39), isEmpty);
  final meta = await ImboySchemaMeta.readAll(db);
  expect(meta['schema_version'], '39');
  expect(meta['migration_state'], 'ok');
  expect(meta['last_migration_id'], 'baseline_create_v39');
  expect(meta['schema_hash'], matches(RegExp(r'^[0-9a-f]{64}$')));
  expect(
    (await db.rawQuery('PRAGMA application_id')).single.values.single,
    0x494D424F,
  );
  expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
  expect(
    (await db.rawQuery('PRAGMA recursive_triggers')).single.values.single,
    1,
  );
  expect((await db.rawQuery('PRAGMA quick_check')).single.values.single, 'ok');
  expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
}

void main() {
  // ignore: avoid_print
  print('WEB_SQLITE_ORIGIN ${web.window.location.origin}');
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('large SQLite identities reconcile a held group attachment', (
    tester,
  ) async {
    await tester.runAsync(() async {
      pinLoopbackTestEnv();
      final uid =
          (BigInt.parse('100000000000000000') +
                  BigInt.from(DateTime.now().microsecondsSinceEpoch))
              .toString();
      const peer = '123456837222926337';
      const anchor = 'synthetic-large-group-anchor';
      SharedPreferences.setMockInitialValues({Keys.currentUid: uid});
      await prepareWebWriter();
      await StorageService.init();
      initSqfliteFactory();
      final path = '${currentEnv}_$uid.db';
      expect(await common.databaseFactory.databaseExists(path), isFalse);
      try {
        final db = (await SqliteService.to.db)!;
        await db.insert('msg_c2g', {
          'id': anchor,
          'type': 'C2G',
          'from_id': uid,
          'to_id': peer,
          'is_author': 1,
          'status': IMBoyMessageStatus.outcomeUnknown,
          'conversation_uk3': 'c2g-$uid-$peer',
        });
        await db.insert('conversation', {
          'user_id': uid,
          'peer_id': peer,
          'type': 'C2G',
          'last_msg_id': anchor,
          'last_msg_status': IMBoyMessageStatus.outcomeUnknown,
        });
        final repo = AttachmentUploadTaskRepo();
        await repo.insert(
          AttachmentUploadTask(
            id: 'large-attachment',
            userId: uid,
            scope: 'private',
            scopeRef: null,
            fileName: 'synthetic.txt',
            mime: 'text/plain',
            plainSize: 1,
            plainSha256: 'synthetic',
            objectKey: 'synthetic',
            businessIntent: jsonEncode({
              'author_id': uid,
              'chat_type': 'c2g',
              'state': 'commit_unknown',
            }),
            stage: AttachmentUploadStage.confirmed,
            cipher: null,
            bindingHash: null,
            keyRef: null,
            ciphertextSha256: null,
            anchorMsgId: anchor,
            lastError: null,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
        expect(
          await repo.reconcileOutboxCommitted(
            anchor,
            uid,
            isCurrent: () => true,
          ),
          isTrue,
        );
        expect(
          (await db.query('msg_c2g')).single['status'],
          IMBoyMessageStatus.sent,
        );
        expect(
          (await db.query('conversation')).single['last_msg_status'],
          IMBoyMessageStatus.sent,
        );
        final autoId = await db.insert('msg_c2g', {
          'id': 'synthetic-large-ack',
          'type': 'C2G',
          'from_id': uid,
          'to_id': peer,
          'is_author': 1,
          'status': IMBoyMessageStatus.outcomeUnknown,
          'conversation_uk3': 'c2g-$uid-$peer',
        });
        await db.execute(
          'CREATE TABLE message_send_attempt '
          '(user_id TEXT, anchor TEXT, token TEXT)',
        );
        await db.insert('message_send_attempt', {
          'user_id': uid,
          'anchor': 'synthetic-large-ack',
          'token': 'synthetic',
        });
        Future<bool> ack(String expectedPeer) => ServerAckReceipts.persist(
          db: db,
          ackId: 'synthetic-large-ack',
          ackType: 'C2G_SERVER_ACK',
          ownerUid: uid,
          expectedAutoId: autoId,
          expectedPeerId: expectedPeer,
          isCurrent: () => true,
        );
        expect(await ack('123456837222926336'), isFalse);
        expect(await ack(peer), isTrue);
        expect(
          (await db.query(
            'msg_c2g',
            where: 'id = ?',
            whereArgs: ['synthetic-large-ack'],
          )).single['status'],
          IMBoyMessageStatus.sent,
        );
      } finally {
        await SqliteService.to.close();
        await StorageService.to.setString(Keys.currentUid, '');
        await SqliteService.to.deleteDatabaseForUid(
          uid,
          environment: currentEnv,
        );
      }
    });
  });
  testWidgets(
    'production Web fresh schema and app rows survive same-context close/reopen',
    (tester) async {
      expect(kIsWeb, isTrue);
      expect(isEncryptionSupported, isFalse);
      // Keep the production factory and its default relative WASM URL. Flutter's
      // suite iframe serves this file beside the tracked WASM symlink.
      expect(
        Uri.base.resolve('sqlite3.wasm').path,
        endsWith('/unit_test/service/sqlite3.wasm'),
      );
      await tester.runAsync(() async {
        pinLoopbackTestEnv();
        final uid = DateTime.now().microsecondsSinceEpoch.toString();
        SharedPreferences.setMockInitialValues({
          Keys.currentUid: uid,
          Keys.currentUser:
              '{"uid":"$uid","nickname":"Synthetic schema owner"}',
        });
        await prepareWebWriter();
        await StorageService.init();
        initSqfliteFactory();
        final path = '${currentEnv}_$uid.db';
        expect(
          await common.databaseFactory.databaseExists(path),
          isFalse,
          reason:
              'Fresh means a new physical account path, never an injected DB',
        );
        final messages = MessageRepo(tableName: MessageRepo.c2cTable);
        final messageId = 'synthetic-fresh-$uid';
        try {
          // The sole creator is the real SqliteService production callback chain.
          final first = await SqliteService.to.db;
          expect(first, isNotNull);
          final db = first!;
          await _verifyProductionSchema(db);
          final schema = await _objects(db);
          await ContactRepo().insert(
            ContactModel(peerId: '2002', nickname: 'Synthetic schema peer'),
          );
          final prototype = ConversationModel(
            id: 0,
            peerId: '2002',
            avatar: '',
            title: 'Synthetic schema chat',
            subtitle: '',
            type: 'C2C',
            msgType: 'text',
            unreadNum: 1,
          );
          final conversationId = await ConversationRepo().insert(prototype);
          final conversation = (await ConversationRepo().findById(
            conversationId,
          ))!;
          await messages.save(
            MessageModel(
              messageId,
              autoId: 0,
              type: 'C2C',
              status: IMBoyMessageStatus.delivered,
              fromId: '2002',
              toId: uid,
              payload: {'text': 'synthetic schema message'},
              isAuthor: 0,
              conversationUk3: conversation.uk3,
              msgType: 'text',
              createdAt: 1794355200000,
            ),
          );
          await messages.waitForFtsReindexForTest();
          expect(
            (await messages.find(messageId))!.payloadMap['text'],
            'synthetic schema message',
          );
          await db.insert('channel', {
            'id': 901,
            'name': 'Synthetic personal channel',
            'creator_id': uid,
            'created_at': 1,
            'updated_at': 1,
            'scope': 'personal',
            'is_subscribed': 1,
          });
          await db.insert('channel_subscription', {
            'channel_id': 901,
            'subscribed_at': 1,
            'unread_count': 3,
          });
          final preferences = ChannelInboxPreferenceRepo();
          final scope = preferences.captureScope();
          expect(await preferences.setHidden(scope, '901', true), isTrue);
          expect(await preferences.hiddenIds(scope), {'901'});

          await SqliteService.to.close();
          expect(db.isOpen, isFalse);
          expect(await common.databaseFactory.databaseExists(path), isTrue);
          final reopened = await SqliteService.to.db;
          expect(reopened, isNotNull);
          expect(reopened, isNot(same(db)));
          await _verifyProductionSchema(reopened!);
          expect(await _objects(reopened), schema);
          // Raw row read rules out a repository cache being the only oracle.
          expect(
            (await reopened.query(
              'msg_c2c',
              columns: ['id', 'status'],
              where: 'id = ?',
              whereArgs: [messageId],
            )).single,
            {'id': messageId, 'status': IMBoyMessageStatus.delivered},
          );
          expect((await messages.find(messageId))!.id, messageId);
          expect(
            (await ContactRepo().findByUid('2002', autoFetch: false))!.nickname,
            'Synthetic schema peer',
          );
          expect(
            (await ConversationRepo().findById(conversationId))!.uk3,
            conversation.uk3,
          );
          expect(await preferences.hiddenIds(scope), {'901'});
          expect(
            (await reopened.query(
              'channel_subscription',
              columns: ['unread_count'],
            )).single['unread_count'],
            3,
          );
        } catch (error, stack) {
          // ignore: avoid_print
          print('WEB_SQLITE_SCHEMA_FAILURE $error\n$stack');
          rethrow;
        } finally {
          await messages.waitForFtsReindexForTest();
          try {
            await SqliteService.to.close();
          } finally {
            await StorageService.to.setString(Keys.currentUid, '');
            // Delete only the fresh path created by this test; no namespace reset.
            await SqliteService.to.deleteDatabaseForUid(
              uid,
              environment: currentEnv,
            );
          }
        }
      });
    },
  );
}
