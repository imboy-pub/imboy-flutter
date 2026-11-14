import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:imboy/component/upload/resumable_attachment_uploader.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/modules/messaging/infrastructure/attachment_local_projection.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:imboy/service/migrations/upgrade_edges_v33.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_opener.dart';
import 'package:imboy/service/e2ee/attachment_open_registry.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

MessageModel location(int status) => MessageModel(
  'local-location',
  autoId: 0,
  type: 'C2C',
  fromId: '101',
  toId: '202',
  isAuthor: 1,
  createdAt: 1700000000000,
  conversationUk3: 'C2C_101_202',
  msgType: 'location',
  status: status,
  payload: {
    'title': 'test location',
    'latitude': '39.123456789',
    'longitude': '116.123456789',
  },
);

void main() {
  late Database db;
  late AttachmentUploadTaskRepo repo;
  late String originalEnvironment;
  late Uint8List encryptedBytes;
  late Map<String, dynamic> descriptor;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    UserRepoLocal.to.clearAuthTransitionFailureForTest();
    originalEnvironment = currentEnv;
    currentEnv = 'projection-test';
    envMap[currentEnv] = const _EndpointEnv('http://127.0.0.1:1');
    AttachmentOpenRegistry.resetForTest();
    SharedPreferences.setMockInitialValues({Keys.currentUid: '101'});
    await StorageService.init();
    await StorageService.to.setString(
      Keys.currentUser,
      '{"uid":"101","nickname":"sender","avatar":""}',
    );
    FlutterSecureStorage.setMockInitialValues({});
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    for (final sql in kUpgradeEdgesV33.single.sql.split(';')) {
      if (sql.trim().isNotEmpty) await db.execute(sql);
    }
    await db.execute(
      'CREATE TABLE msg_c2c (auto_id INTEGER PRIMARY KEY AUTOINCREMENT,'
      'id TEXT UNIQUE, type TEXT, from_id INTEGER, to_id INTEGER, payload TEXT,'
      'created_at INTEGER, is_author INTEGER, status INTEGER, conversation_uk3 TEXT,'
      'topic_id INTEGER, msg_type TEXT, action TEXT, e2ee TEXT, sender_did TEXT)',
    );
    await db.execute(
      'CREATE TABLE msg_c2c_fts (id TEXT,conversation_uk3 TEXT,text_content TEXT)',
    );
    SqliteService.setDbForTest(db);
    repo = AttachmentUploadTaskRepo();
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    if (db.isOpen) await db.close();
    envMap.remove('projection-test');
    currentEnv = originalEnvironment;
    AttachmentOpenRegistry.resetForTest();
  });

  Future<MessageModel> enqueue({
    bool encrypted = true,
    bool sealedAttachment = false,
    UploadKeyStore? readKeys,
    void Function(Message)? onEcho,
    void Function(String, String)? onRetry,
  }) async {
    var row = task();
    if (sealedAttachment) {
      final plain = Uint8List.fromList([1, 2, 3, 4]);
      final sealed = AttachmentEncryptor.seal(
        plaintext: plain,
        bindingHash: AttachmentOpener.bindingFor(
          messageId: 'local-location',
          chatType: 'C2C',
          fromUid: '101',
          toUid: '202',
        ),
        attachmentId: 'upload',
        objectKey: row.objectKey!,
        mime: row.mime,
        name: row.fileName,
        contentKey: AttachmentEncryptor.randomContentKey(),
        baseNonce: AttachmentEncryptor.randomBaseNonce(),
        chunkSize: 32,
      );
      encryptedBytes = sealed.ciphertext;
      descriptor = sealed.descriptor.toMap();
      row = AttachmentUploadTask.fromMap({
        ...row.toMap(),
        'cipher': 'AES-256-GCM',
        'key_ref': 'upload-key',
        'plain_size': plain.length,
        'plain_sha256': sha256.convert(plain).toString(),
        'ciphertext_sha256': sha256.convert(encryptedBytes).toString(),
      });
      await SecureUploadKeyStore().write('upload-key', {
        'descriptor': jsonEncode(descriptor),
      });
    }
    await repo.insert(row);
    final uploader = ResumableAttachmentUploader(
      repo: repo,
      keyStore: readKeys,
    );
    await uploader.recoverBusinessOutbox(
      '101',
      prepareMessage: (_, _) async => location(IMBoyMessageStatus.sending)
        ..payload = encrypted ? '' : location(10).payload
        ..e2ee = encrypted
            ? {
                'meta_version': 3,
                'devices': {
                  'peer-device': {'ciphertext': 'sealed'},
                },
              }
            : null
        ..senderDid = encrypted ? 'sender-device' : null,
      notifyRetry: onRetry ?? (_, _) {},
      notifyEcho: onEcho ?? (_) {},
    );
    return (await MessageRepo(tableName: 'msg_c2c').find('local-location'))!;
  }

  test(
    'location remains a supported card carrying the actual sent status',
    () async {
      final message = await location(IMBoyMessageStatus.sent).toTypeMessage();
      expect(message, isA<CustomMessage>());
      expect(message.status, MessageStatus.sent);
      expect(message.metadata?['unsupported'], isNot(true));
    },
  );

  test(
    'sealed DB row survives real template serialization, ACK and a new reader',
    () async {
      final queued = await enqueue();
      final sealed = jsonEncode(queued.e2ee);
      expect(queued.payload, '');
      final first = await queued.toTypeMessage();
      expect(first, isA<CustomMessage>());
      expect(first.status, MessageStatus.sending);
      expect(first.metadata?['title'], 'test location');
      final row = (await repo.findByAnchor(queued.id, '101')).single;
      final intent = jsonDecode(row.businessIntent!) as Map<String, dynamic>;
      expect(intent['local_projection_binding'], isA<String>());
      expect(row.businessIntent, isNot(contains('peer-device')));
      await repo.saveBusinessIntent(
        queued.id,
        '101',
        jsonEncode({...intent, 'state': 'committed'}),
      );
      await db.update(
        'msg_c2c',
        {'status': IMBoyMessageStatus.sent},
        where: 'id = ?',
        whereArgs: [queued.id],
      );
      final reread = (await MessageRepo(tableName: 'msg_c2c').find(queued.id))!;
      final after = await reread.toTypeMessage();
      expect(after, isA<CustomMessage>());
      expect(after.status, MessageStatus.sent);
      expect(after.metadata?['title'], 'test location');
      expect(after.metadata?['latitude'], '39.123456789');
      expect(reread.payload, '');
      expect(jsonEncode(reread.e2ee), sealed);
    },
  );

  test('atomic enqueue emits one visible card before retry, and never reinserts it', () async {
    await repo.insert(task());
    final order = <String>[];
    final echoes = <Message>[];
    final uploader = ResumableAttachmentUploader(repo: repo);
    Future<MessageModel> prepare(Map<String, dynamic> _, Message _) async =>
        location(IMBoyMessageStatus.sending)
          ..payload = ''
          ..e2ee = {
            'meta_version': 3,
            'devices': {
              'peer': {'ciphertext': 'sealed'},
            },
          };
    await uploader.recoverBusinessOutbox(
      '101',
      prepareMessage: prepare,
      notifyEcho: (m) {
        order.add('echo');
        echoes.add(m);
      },
      notifyRetry: (_, _) {
        order.add('retry');
      },
    );
    expect(order, ['echo', 'retry']);
    expect(echoes.single, isA<CustomMessage>());
    expect(echoes.single.status, MessageStatus.sending);
    await uploader.recoverBusinessOutbox(
      '101',
      prepareMessage: prepare,
      notifyEcho: (m) {
        echoes.add(m);
      },
      notifyRetry: (_, _) {},
    );
    expect(echoes, hasLength(1));
    expect(await db.query('msg_c2c'), hasLength(1));
  });

  for (final field in [
    'author_id',
    'peer_id',
    'chat_type',
    'conversation_uk3',
    'message_id',
    'attachment_kind',
    'expected_objects',
    'local_projection_binding',
  ]) {
    test('journal $field mismatch cannot restore plaintext', () async {
      final model = await enqueue();
      final row = (await repo.findByAnchor(model.id, '101')).single;
      final intent = jsonDecode(row.businessIntent!) as Map<String, dynamic>;
      await repo.saveBusinessIntent(
        model.id,
        '101',
        jsonEncode({...intent, field: 'wrong'}),
      );
      expect(await loadLocalAttachmentPayload(model), isNull);
    });
  }
  for (final field in [
    'e2ee',
    'conversation',
    'peer',
    'author',
    'type',
    'id',
    'action',
    'topic',
  ]) {
    test('sealed $field mismatch cannot restore plaintext', () async {
      final model = await enqueue();
      switch (field) {
        case 'e2ee':
          model.e2ee = {
            'meta_version': 3,
            'devices': {
              'peer': {'ciphertext': 'changed'},
            },
          };
        case 'conversation':
          model.conversationUk3 = 'different';
        case 'peer':
          model.toId = '303';
        case 'author':
          model.fromId = '303';
        case 'type':
          model.msgType = 'file';
        case 'id':
          model.id = 'different';
        case 'action':
          model.action = 'revoke';
        case 'topic':
          model.topicId = 42;
      }
      expect(await loadLocalAttachmentPayload(model), isNull);
    });
  }
  test('wrong owner and missing legacy binding remain closed', () async {
    final model = await enqueue();
    await StorageService.to.setString(Keys.currentUid, '303');
    expect(await loadLocalAttachmentPayload(model), isNull);
    await StorageService.to.setString(Keys.currentUid, '101');
    final row = (await repo.findByAnchor(model.id, '101')).single;
    final intent = jsonDecode(row.businessIntent!) as Map<String, dynamic>
      ..remove('local_projection_binding');
    await repo.saveBusinessIntent(model.id, '101', jsonEncode(intent));
    expect(await loadLocalAttachmentPayload(model), isNull);
  });
  test('template change with the same sealed bytes is rejected', () async {
    final model = await enqueue();
    final row = (await repo.findByAnchor(model.id, '101')).single;
    final intent = jsonDecode(row.businessIntent!) as Map<String, dynamic>;
    (intent['message_template']['metadata'] as Map)['title'] = 'wrong';
    await repo.saveBusinessIntent(model.id, '101', jsonEncode(intent));
    expect(await loadLocalAttachmentPayload(model), isNull);
  });
  test(
    'session changes during journal read cannot restore an old account',
    () async {
      final model = await enqueue();
      final rows = await repo.findByAnchor(model.id, '101');
      final delayed = _ReadRepo(rows, () async {
        await StorageService.to.setString(Keys.currentUid, '303');
      });
      expect(await loadLocalAttachmentPayload(model, repo: delayed), isNull);
    },
  );
  test(
    'enqueue reuses its verified template without a second secret read',
    () async {
      final keys = _ReadOnceKeys(SecureUploadKeyStore());
      final order = <String>[];
      final echoes = <Message>[];
      final model = await enqueue(
        sealedAttachment: true,
        readKeys: keys,
        onEcho: (m) {
          order.add('echo');
          echoes.add(m);
        },
        onRetry: (_, _) {
          order.add('retry');
        },
      );
      expect(keys.reads, 1);
      expect(order, ['echo', 'retry']);
      expect(echoes.single, isA<CustomMessage>());
      expect(echoes.single.metadata?['title'], 'test location');
      final wire = jsonEncode(model.e2ee);
      final row = (await repo.findByAnchor(model.id, '101')).single;
      final intent = jsonDecode(row.businessIntent!) as Map<String, dynamic>;
      await repo.saveBusinessIntent(
        model.id,
        '101',
        jsonEncode({...intent, 'state': 'committed'}),
      );
      await db.update(
        'msg_c2c',
        {'status': IMBoyMessageStatus.sent},
        where: 'id = ?',
        whereArgs: [model.id],
      );
      final reread = (await MessageRepo(tableName: 'msg_c2c').find(model.id))!;
      FlutterSecureStorage.setMockInitialValues({});
      final unavailable = await reread.toTypeMessage();
      expect(unavailable, isA<TextMessage>());
      expect(unavailable.metadata?['_e2ee_failed'], true);
      expect(unavailable.metadata?['title'], isNull);
      await SecureUploadKeyStore().write('upload-key', {
        'descriptor': jsonEncode(descriptor),
      });
      final recovered = await reread.toTypeMessage();
      expect(recovered, isA<CustomMessage>());
      expect(recovered.status, MessageStatus.sent);
      expect(recovered.metadata?['title'], 'test location');
      expect(reread.payload, '');
      expect(jsonEncode(reread.e2ee), wire);
    },
  );
  test(
    'archive read context preserves the bound sealed wire identity',
    () async {
      final model = await enqueue();
      model.e2ee = {...model.e2ee!, '_archive_conv_seq': 42};
      final payload = await loadLocalAttachmentPayload(model);
      expect(payload?['title'], 'test location');
    },
  );
  for (final changed in ['environment', 'endpoint']) {
    test('journal await rejects changed $changed', () async {
      final model = await enqueue();
      final rows = await repo.findByAnchor(model.id, '101');
      final delayed = _ReadRepo(rows, () async {
        if (changed == 'environment') {
          currentEnv = 'different-test-environment';
        } else {
          envMap[currentEnv] = const _EndpointEnv('http://127.0.0.1:2');
        }
      });
      expect(await loadLocalAttachmentPayload(model, repo: delayed), isNull);
    });
  }
  test(
    'encrypted attachment restores secure materials after committed ACK',
    () async {
      final model = await enqueue(sealedAttachment: true);
      final row = (await repo.findByAnchor(model.id, '101')).single;
      final intent = jsonDecode(row.businessIntent!) as Map<String, dynamic>;
      await repo.saveBusinessIntent(
        model.id,
        '101',
        jsonEncode({...intent, 'state': 'committed'}),
      );
      await db.update(
        'msg_c2c',
        {'status': IMBoyMessageStatus.sent},
        where: 'id = ?',
        whereArgs: [model.id],
      );
      final reread = (await MessageRepo(tableName: 'msg_c2c').find(model.id))!;
      final card = await reread.toTypeMessage();
      expect(card, isA<CustomMessage>());
      expect(card.status, MessageStatus.sent);
      expect(card.metadata?['attachment_descriptor'], descriptor);
      expect(
        AttachmentOpenRegistry.materialize('101/maps/test.jpg', encryptedBytes),
        Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(reread.payload, '');
    },
  );
  test('missing or changed secure descriptor fails closed', () async {
    final model = await enqueue(sealedAttachment: true);
    await SecureUploadKeyStore().write('upload-key', {
      'descriptor': jsonEncode({
        ...descriptor,
        'object_key': '101/maps/changed.jpg',
      }),
    });
    expect(await loadLocalAttachmentPayload(model), isNull);
    FlutterSecureStorage.setMockInitialValues({});
    expect(await loadLocalAttachmentPayload(model), isNull);
  });
  for (final change in ['account', 'environment', 'endpoint']) {
    test('secure material await rejects changed $change', () async {
      final model = await enqueue(sealedAttachment: true);
      final keys = _DelayedKeys(SecureUploadKeyStore(), () async {
        switch (change) {
          case 'account':
            await StorageService.to.setString(Keys.currentUid, '303');
          case 'environment':
            currentEnv = 'different-test-environment';
          case 'endpoint':
            envMap[currentEnv] = const _EndpointEnv('http://127.0.0.1:2');
        }
      });
      expect(await loadLocalAttachmentPayload(model, keyStore: keys), isNull);
    });
  }
  test(
    'same UID after session generation changes cannot reuse material',
    () async {
      final model = await enqueue(sealedAttachment: true);
      final generation = UserRepoLocal.to.sessionGeneration;
      final keys = _DelayedKeys(SecureUploadKeyStore(), () async {
        await UserRepoLocal.to.quitLogin();
        await StorageService.to.setString(Keys.currentUid, '101');
      });
      expect(await loadLocalAttachmentPayload(model, keyStore: keys), isNull);
      expect(UserRepoLocal.to.sessionGeneration, greaterThan(generation));
    },
  );
}

class _EndpointEnv implements Env {
  const _EndpointEnv(this.apiBaseUrl);
  @override
  final String apiBaseUrl;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DelayedKeys implements UploadKeyStore {
  _DelayedKeys(this.delegate, this.before);
  final UploadKeyStore delegate;
  final Future<void> Function() before;
  @override
  Future<Map<String, String>?> read(String ref) async {
    final value = await delegate.read(ref);
    await before();
    return value;
  }

  @override
  Future<void> write(String ref, Map<String, String> value) =>
      delegate.write(ref, value);
}

AttachmentUploadTask task() => AttachmentUploadTask(
  id: 'upload',
  userId: '101',
  scope: 'private',
  scopeRef: null,
  fileName: 'map.jpg',
  mime: 'image/jpeg',
  plainSize: 42,
  plainSha256: 'plain',
  objectKey: '101/maps/test.jpg',
  stage: AttachmentUploadStage.confirmed,
  cipher: null,
  bindingHash: null,
  keyRef: null,
  ciphertextSha256: null,
  anchorMsgId: 'local-location',
  lastError: null,
  createdAt: 1700000000000,
  updatedAt: 1700000000000,
  businessIntent: jsonEncode({
    'state': 'uploading',
    'message_id': 'local-location',
    'author_id': '101',
    'peer_id': '202',
    'chat_type': 'C2C',
    'conversation_uk3': 'C2C_101_202',
    'attachment_kind': 'location',
    'expected_objects': 1,
    'message_template': {
      'type': 'custom',
      'id': 'local-location',
      'authorId': '101',
      'createdAt': 1700000000000,
      'metadata': {
        'msg_type': 'location',
        'peer_id': '202',
        'title': 'test location',
        'latitude': '39.123456789',
        'longitude': '116.123456789',
      },
    },
  }),
);

class _ReadOnceKeys implements UploadKeyStore {
  _ReadOnceKeys(this.delegate);
  final UploadKeyStore delegate;
  int reads = 0;
  @override
  Future<Map<String, String>?> read(String ref) async =>
      ++reads == 1 ? delegate.read(ref) : null;
  @override
  Future<void> write(String ref, Map<String, String> material) =>
      delegate.write(ref, material);
}

class _ReadRepo extends AttachmentUploadTaskRepo {
  _ReadRepo(this.rows, this.before);
  final List<AttachmentUploadTask> rows;
  final Future<void> Function() before;
  @override
  Future<List<AttachmentUploadTask>> findByAnchor(
    String anchor,
    String user,
  ) async {
    await before();
    return rows;
  }
}
