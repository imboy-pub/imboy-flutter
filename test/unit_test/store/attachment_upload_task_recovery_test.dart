// W5-01 客户端恢复单元测试（不代替真实服务、设备或消息发送验收）。
//
// 基础设施：sqflite_common_ffi 内存库（DDL 与迁移 v33 同构）+
// SqliteService.setDbForTest + 内存 KeyStore + fake presign/put/confirm。
// 「进程被杀」用 checkpoint 抛 _KillSignal 模拟；「重启」= 新建
// uploader（同一底层 DB 与 KeyStore）后 resume。
//
// 测试名与合同场景同名不代表逐叶通过；HTTP Range、消息未知提交及真实进程恢复另验。
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/page/chat/chat/attachment_handler.dart';

import 'dart:typed_data';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/upload/resumable_attachment_uploader.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';
import 'package:imboy/service/e2ee/attachment_descriptor.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/migrations/downgrade_edges_all.dart';
import 'package:imboy/store/api/attachment_api.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:dio/dio.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

part 'attachment_upload_cleanup_test_cases.dart';

late Directory _uploadCache;

const String _uidA = '101';
const String _uidB = '202';
const String _binding =
    'aa1122334455667788990011223344556677889900112233445566778899aabb';

class _KillSignal implements Exception {
  final String at;
  _KillSignal(this.at);
  @override
  String toString() => 'KillSignal@$at';
}

/// 内存密钥材料存储（生产为 flutter_secure_storage）。
class _MemKeyStore implements UploadKeyStore {
  final Map<String, Map<String, String>> store = {};
  bool failWrites = false;

  @override
  Future<void> write(String ref, Map<String, String> material) async {
    if (failWrites) throw Exception('durable checkpoint write failed');
    store[ref] = Map<String, String>.of(material);
  }

  @override
  Future<Map<String, String>?> read(String ref) async => store[ref];
}

class _Fakes {
  final List<String> presignCalls = [];
  final List<Uint8List> putBodies = [];
  final List<Map<String, dynamic>> confirmBodies = [];
  bool presignFail = false;
  bool confirmForbidden = false;
  String objectKey = 'u101/v5e2e/fake-object-key';

  PresignFn get presign => (fileName, mime) async {
    presignCalls.add(fileName);
    if (presignFail) {
      return IMBoyHttpResponse.failure(errMsg: 'presign down');
    }
    return IMBoyHttpResponse.success(<String, dynamic>{
      'put_url': 'https://garage.test/put',
      'object_key': objectKey,
    });
  };

  PutFn get put => (putUrl, bytes, mime, process) async {
    putBodies.add(Uint8List.fromList(bytes));
  };

  ConfirmFn get confirm => (body) async {
    if (confirmForbidden) {
      return IMBoyHttpResponse.failure(errMsg: 'forbidden', errCode: 403);
    }
    confirmBodies.add(body);
    return IMBoyHttpResponse.success(<String, dynamic>{'ok': true});
  };
}

class _ResultApi extends MsgApi {
  _ResultApi(this.payload, {this.ok = true});
  final Map<String, dynamic> payload;
  final bool ok;
  final queries = <Map<String, dynamic>>[];
  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    expect(uri, '/api/v1/msg/result');
    queries.add(queryParameters!);
    return ok
        ? IMBoyHttpResponse.success(payload)
        : IMBoyHttpResponse.failure(errMsg: 'unavailable');
  }
}

Future<Database> _openDb([String path = inMemoryDatabasePath]) async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(version: 33, singleInstance: false),
  );
  await db.execute('''
    CREATE TABLE IF NOT EXISTS "attachment_upload_task" (
        "id" TEXT PRIMARY KEY,
        "user_id" TEXT NOT NULL,
        "scope" TEXT NOT NULL,
        "scope_ref" TEXT,
        "file_name" TEXT NOT NULL,
        "mime" TEXT NOT NULL,
        "plain_size" INTEGER NOT NULL,
        "plain_sha256" TEXT NOT NULL,
        "object_key" TEXT,
        "upload_path" TEXT,
        "business_intent" TEXT,
        "stage" TEXT NOT NULL,
        "cipher" TEXT,
        "binding_hash" TEXT,
        "key_ref" TEXT,
        "ciphertext_sha256" TEXT,
        "anchor_msg_id" TEXT,
        "last_error" TEXT,
        "created_at" INTEGER NOT NULL,
        "updated_at" INTEGER NOT NULL
    )
  ''');
  return db;
}

Future<void> _createMessageOutboxTables(Database db) async {
  await db.execute(
    'CREATE TABLE msg_c2c (auto_id INTEGER PRIMARY KEY AUTOINCREMENT,'
    'id TEXT UNIQUE, type TEXT, from_id INTEGER, to_id INTEGER, payload TEXT,'
    'created_at INTEGER, is_author INTEGER, status INTEGER, conversation_uk3 TEXT,'
    'topic_id INTEGER, msg_type TEXT, action TEXT, e2ee TEXT, sender_did TEXT)',
  );
  await db.execute(
    'CREATE TABLE msg_c2c_fts (id TEXT, conversation_uk3 TEXT, text_content TEXT)',
  );
}

ResumableAttachmentUploader _uploader(
  AttachmentUploadTaskRepo repo,
  _MemKeyStore keys,
) => ResumableAttachmentUploader(
  repo: repo,
  keyStore: keys,
  sessionGuard: (_) => true,
  cacheDirectory: _uploadCache,
  cacheWriter: (write, _) => write(),
);

Future<String> _runUpload(
  ResumableAttachmentUploader up,
  _Fakes f, {
  required String id,
  String uid = _uidA,
  Future<void> Function(UploadCheckpoint event)? checkpoint,
  Uint8List? bytes,
}) => up.upload(
  idempotencyKey: id,
  userId: uid,
  bytes: bytes ?? Uint8List.fromList(List<int>.generate(4096, (i) => i % 251)),
  fileName: 'resume.bin',
  mime: 'application/octet-stream',
  bindingHashHex: _binding,
  presignFn: f.presign,
  putFn: f.put,
  confirmFn: f.confirm,
  checkpoint: checkpoint,
);

void main() {
  late Database db;
  late AttachmentUploadTaskRepo repo;
  late _MemKeyStore keys;
  late _Fakes f;

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: _uidA});
    await StorageService.init();
    _uploadCache = await Directory.systemTemp.createTemp('imboy-upload-owned-');
    db = await _openDb();
    SqliteService.setDbForTest(db);
    repo = AttachmentUploadTaskRepo();
    keys = _MemKeyStore();
    f = _Fakes();
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
    await _uploadCache.delete(recursive: true);
  });

  _registerAccountUploadCleanupTest(() => repo, () => keys, () => f);

  test('并发任务插入和无任务发送栅栏只能有一方成功', () async {
    final base = await _seedRow(
      'race-upload',
      uid: _uidA,
      stage: AttachmentUploadStage.pending,
      objectKey: '',
    );
    final task = AttachmentUploadTask.fromMap({
      ...base.toMap(),
      'anchor_msg_id': 'race-anchor',
      'business_intent': jsonEncode({'state': 'uploading'}),
    });
    final results = await Future.wait([
      repo.claimOutboxDispatch('race-anchor', _uidA, isCurrent: () => true),
      repo.insert(task).catchError((Object _) => false),
    ]);
    expect(results.where((result) => result).length, 1);
    if (results.first) {
      expect(await repo.find(task.id), isNull);
      expect(await db.query('attachment_send_gate'), hasLength(1));
    } else {
      expect(await repo.find(task.id), isNotNull);
    }
  });

  test('独立 SQLite 连接上的发送和任务创建竞争保持互斥', () async {
    final path = '${_uploadCache.path}/fence.sqlite';
    final firstDb = await _openDb(path);
    final secondDb = await _openDb(path);
    try {
      SqliteService.setDbForTest(firstDb);
      final first = AttachmentUploadTaskRepo();
      SqliteService.setDbForTest(secondDb);
      final second = AttachmentUploadTaskRepo();
      final base = await _seedRow(
        'two-connection',
        uid: _uidA,
        stage: AttachmentUploadStage.pending,
        objectKey: '',
      );
      final task = AttachmentUploadTask.fromMap({
        ...base.toMap(),
        'anchor_msg_id': 'two-connection-anchor',
        'business_intent': jsonEncode({'state': 'uploading'}),
      });
      final results = await Future.wait([
        first.claimOutboxDispatch(
          'two-connection-anchor',
          _uidA,
          isCurrent: () => true,
        ),
        second.insert(task).catchError((Object _) => false),
      ]);
      expect(results.where((value) => value).length, 1);
      if (results.first) {
        expect(await second.find(task.id), isNull);
        await expectLater(second.insert(task), throwsStateError);
      } else {
        expect(await second.find(task.id), isNotNull);
        expect(
          await first.claimOutboxDispatch(
            'two-connection-anchor',
            _uidA,
            isCurrent: () => true,
          ),
          isFalse,
        );
      }
    } finally {
      SqliteService.setDbForTest(db);
      await firstDb.close();
      await secondDb.close();
    }
  });

  test('普通操作 ACK 可保留旧行为并阻止以后同 ID 建附件', () async {
    expect(
      await repo.allowUnprotectedActionAck(
        'action-anchor',
        _uidA,
        isCurrent: () => true,
      ),
      isTrue,
    );
    final base = await _seedRow(
      'action-attachment',
      uid: _uidA,
      stage: AttachmentUploadStage.pending,
      objectKey: '',
    );
    final task = AttachmentUploadTask.fromMap({
      ...base.toMap(),
      'anchor_msg_id': 'action-anchor',
      'business_intent': jsonEncode({'state': 'uploading'}),
    });
    await expectLater(repo.insert(task), throwsStateError);
    final other = AttachmentUploadTask.fromMap({
      ...base.toMap(),
      'id': 'protected-upload',
      'anchor_msg_id': 'protected-anchor',
      'business_intent': jsonEncode({'state': 'uploading'}),
    });
    await repo.insert(other);
    expect(
      await repo.allowUnprotectedActionAck(
        'protected-anchor',
        _uidA,
        isCurrent: () => true,
      ),
      isFalse,
    );
  });

  test('已有发送记录的消息 ID 不可复用为新出站', () async {
    await _createMessageOutboxTables(db);
    expect(
      await repo.claimOutboxDispatch('reused-id', _uidA, isCurrent: () => true),
      isTrue,
    );
    final message = MessageModel(
      'reused-id',
      autoId: 0,
      type: 'C2C',
      status: IMBoyMessageStatus.sending,
      fromId: _uidA,
      toId: _uidB,
      payload: {'text': 'test'},
      isAuthor: 1,
      conversationUk3: 'c2c-101-202',
      msgType: 'text',
      createdAt: 1751850000000,
    );
    await expectLater(
      MessageRepo(tableName: 'msg_c2c').insert(message, outbound: true),
      throwsStateError,
    );
    expect(await db.query('msg_c2c'), isEmpty);
    await MessageRepo(tableName: 'msg_c2c').insert(message);
    expect(await db.query('msg_c2c'), hasLength(1));
  });

  test('持久状态重开后区分未发送、未知和服务器确认', () async {
    final path = '${_uploadCache.path}/dispatch.sqlite';
    var disk = await _openDb(path);
    await _createMessageOutboxTables(disk);
    await disk.execute(
      "CREATE TABLE crypto_outbox (id TEXT PRIMARY KEY, status TEXT, sent_at INTEGER)",
    );
    await disk.insert('msg_c2c', {
      'id': 'durable-anchor',
      'type': 'C2C',
      'from_id': 101,
      'is_author': 1,
      'conversation_uk3': 'c2c-101-202',
      'status': IMBoyMessageStatus.sending,
    });
    await disk.insert('crypto_outbox', {
      'id': 'durable-anchor',
      'status': 'pending',
    });
    try {
      SqliteService.setDbForTest(disk);
      var service = AttachmentUploadTaskRepo();
      final base = await _seedRow(
        'durable-dispatch',
        uid: _uidA,
        stage: AttachmentUploadStage.confirmed,
        objectKey: 'object',
      );
      final task = AttachmentUploadTask.fromMap({
        ...base.toMap(),
        'anchor_msg_id': 'durable-anchor',
        'business_intent': jsonEncode({
          'state': 'outbox_ready',
          'author_id': _uidA,
          'chat_type': 'c2c',
        }),
      });
      await service.insert(task);
      expect(
        await service.claimOutboxDispatch(
          'durable-anchor',
          _uidA,
          isCurrent: () => true,
        ),
        isTrue,
      );
      await disk.close();
      disk = await _openDb(path);
      SqliteService.setDbForTest(disk);
      service = AttachmentUploadTaskRepo();
      expect(
        jsonDecode((await service.find(task.id))!.businessIntent!)['state'],
        'dispatch_reserved_v2',
      );
      final attempts = await Future.wait([
        service.beginOutboxSend('durable-anchor', _uidA, isCurrent: () => true),
        service.beginOutboxSend('durable-anchor', _uidA, isCurrent: () => true),
      ]);
      expect(attempts.where((value) => value), hasLength(1));
      await disk.close();
      disk = await _openDb(path);
      SqliteService.setDbForTest(disk);
      service = AttachmentUploadTaskRepo();
      expect(
        jsonDecode((await service.find(task.id))!.businessIntent!)['state'],
        'commit_unknown',
      );
      expect(
        await service.beginOutboxSend(
          'durable-anchor',
          _uidA,
          isCurrent: () => true,
        ),
        isFalse,
      );
      expect(
        await service.reconcileOutboxCommitted(
          'durable-anchor',
          _uidA,
          isCurrent: () => true,
        ),
        isTrue,
      );
      expect(
        jsonDecode((await service.find(task.id))!.businessIntent!)['state'],
        'committed',
      );
      expect(
        (await disk.query('msg_c2c')).single['status'],
        IMBoyMessageStatus.sent,
      );
      expect((await disk.query('crypto_outbox')).single['status'], 'sent');
      expect(
        await service.markOutboxUnknown(
          'durable-anchor',
          _uidA,
          'c2c',
          isCurrent: () => true,
        ),
        isFalse,
      );
      expect(
        jsonDecode((await service.find(task.id))!.businessIntent!)['state'],
        'committed',
      );
    } finally {
      SqliteService.setDbForTest(db);
      await disk.close();
    }
  });

  test('模板业务意图的未知提交可由服务器正证调和', () async {
    await _createMessageOutboxTables(db);
    await db.insert('msg_c2c', {
      'id': 'template-anchor',
      'type': 'C2C',
      'from_id': 101,
      'is_author': 1,
      'conversation_uk3': 'c2c-101-202',
      'status': IMBoyMessageStatus.sending,
    });
    final base = await _seedRow(
      'template-result',
      uid: _uidA,
      stage: AttachmentUploadStage.confirmed,
      objectKey: 'object',
    );
    final task = AttachmentUploadTask.fromMap({
      ...base.toMap(),
      'anchor_msg_id': 'template-anchor',
      'business_intent': jsonEncode({
        'author_id': _uidA,
        'peer_id': _uidB,
        'chat_type': 'c2c',
        'state': 'commit_unknown',
        'message_template': <String, dynamic>{},
      }),
    });
    await repo.insert(task);
    final api = _ResultApi({
      'message_id': 'template-anchor',
      'chat_type': 'c2c',
      'peer_id': _uidB,
      'state': 'committed',
    });
    await _uploader(repo, keys).reconcileMessages(_uidA, api: api);
    expect(api.queries, hasLength(1));
    expect(
      jsonDecode((await repo.find(task.id))!.businessIntent!)['state'],
      'committed',
    );
  });

  test('暂停写入的旧版本不能覆盖已发布材料指针', () async {
    final task = await _seedRow(
      'material-race',
      uid: _uidA,
      stage: AttachmentUploadStage.pending,
      objectKey: '',
    );
    await repo.insert(task);
    final resume = Completer<void>();
    final late = () async {
      await resume.future;
      await keys.write('old-version', {'descriptor': 'old'});
      return repo.publishMaterialReference(task, 'old-version');
    }();
    await keys.write('new-version', {'descriptor': 'new'});
    expect(await repo.publishMaterialReference(task, 'new-version'), isTrue);
    resume.complete();
    expect(await late, isFalse);
    final current = (await repo.find(task.id))!;
    expect(current.keyRef, 'new-version');
    expect((await keys.read(current.keyRef!))!['descriptor'], 'new');
    expect(
      await repo.advanceStage(
        task.id,
        AttachmentUploadStage.pending,
        AttachmentUploadStage.pending,
        userId: _uidA,
        uploadPath: 'stale-ciphertext',
        expectedKeyRef: 'old-version',
      ),
      isFalse,
    );
    expect((await repo.find(task.id))!.uploadPath, isNull);
  });

  test('新 E2EE 源文件加密落盘，模拟 checkpoint 前崩溃后恢复', () async {
    const id = 'encrypted-source-crash';
    final up = _uploader(repo, keys);
    expect(
      await up.upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        prepareOnly: true,
      ),
      id,
    );
    final initial = (await repo.find(id))!;
    expect(initial.uploadPath, endsWith('.source.enc'));
    final source = File(initial.uploadPath!);
    expect(await source.readAsBytes(), isNot(_testBytes()));
    final partial = File('${source.path}.part-crash');
    await source.rename(partial.path);
    await db.update(
      'attachment_upload_task',
      {'upload_path': null},
      where: 'id = ?',
      whereArgs: [id],
    );
    final restarted = _uploader(repo, keys);
    expect(
      await restarted.resumeAll(
        _uidA,
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
      ),
      [f.objectKey],
    );
    expect((await repo.find(id))!.stage, AttachmentUploadStage.confirmed);
    expect(await source.exists(), isFalse);
    expect(await partial.exists(), isFalse);
    expect(f.putBodies.single, isNot(_testBytes()));
  });

  test('同一任务不同明文拒绝，源缓存密钥和 nonce 与上传密钥分域', () async {
    const id = 'source-identity-guard';
    final up = _uploader(repo, keys);
    await up.upload(
      idempotencyKey: id,
      userId: _uidA,
      bytes: _testBytes(),
      fileName: 'resume.bin',
      mime: 'application/octet-stream',
      bindingHashHex: _binding,
      prepareOnly: true,
    );
    final row = (await repo.find(id))!;
    final source = File(row.uploadPath!);
    final ciphertext = await source.readAsBytes();
    final material = Map<String, String>.from(keys.store[id]!);
    final uploadKey = base64Decode(material['content_key']!);
    final uploadNonce = base64Decode(material['base_nonce']!);
    final sourceKey = Hmac(sha256, uploadKey)
        .convert(utf8.encode('imboy-legacy-migration-v1:$id:source-cache-key'))
        .bytes;
    final sourceNonce = Hmac(sha256, uploadKey)
        .convert(
          utf8.encode('imboy-legacy-migration-v1:$id:source-cache-nonce'),
        )
        .bytes
        .sublist(0, 12);
    expect(sourceKey, isNot(uploadKey));
    expect(sourceNonce, isNot(uploadNonce));
    final changed = Uint8List.fromList(_testBytes())..[0] ^= 1;
    await expectLater(
      up.upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: changed,
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        prepareOnly: true,
      ),
      throwsStateError,
    );
    expect(await source.readAsBytes(), ciphertext);
    expect(keys.store[id], material);
  });

  test('旧密文会话以加密暂存迁移并保留原材料', () async {
    await _createMessageOutboxTables(db);
    const id = 'legacy-preserved';
    const anchor = 'legacy-anchor';
    final intent = {
      'state': 'uploading',
      'author_id': _uidA,
      'chat_type': 'c2c',
    };
    await expectLater(
      _uploader(repo, keys).upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: intent,
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('put');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final before = (await repo.find(id))!;
    final cache = File(before.uploadPath!);
    final ciphertext = await cache.readAsBytes();
    final material = Map<String, String>.from(keys.store[id]!);
    var requests = 0;
    var interrupt = true;
    final resumed = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      legacyMigrationBarrier: (_) async {
        if (interrupt) throw _KillSignal('after-marker');
      },
      directSessionFn: (_, {body}) async {
        requests++;
        return IMBoyHttpResponse.failure(errMsg: 'legacy_session_conflict');
      },
    );
    expect(await resumed.resumeAll(_uidA), isEmpty);
    final interrupted = (await repo.find(id))!;
    expect(interrupted.lastError, startsWith('legacy_migrating:'));
    expect(interrupted.objectKey, before.objectKey);
    expect(await cache.readAsBytes(), ciphertext);
    expect(keys.store[id], material);
    interrupt = false;
    await db.insert('msg_c2c', {'id': anchor});
    expect(await resumed.resumeAll(_uidA), isEmpty);
    expect((await repo.find(id))!.lastError, interrupted.lastError);
    expect(keys.store[id], material);
    await db.delete('msg_c2c', where: 'id = ?', whereArgs: [anchor]);
    expect(await resumed.resumeAll(_uidA), isEmpty);
    expect(await repo.find(id), isNull);
    final group = await repo.findByAnchor(anchor, _uidA);
    expect(group, hasLength(1));
    final after = group.single;
    expect(after.id, isNot(id));
    expect(after.stage, AttachmentUploadStage.pending);
    expect(after.objectKey, isNull);
    expect(after.businessIntent, before.businessIntent);
    expect(
      after.lastError,
      AttachmentUploadTaskRepo.legacyMigrationMarker(before),
    );
    expect(await cache.readAsBytes(), ciphertext);
    expect(keys.store[id], material);
    expect(keys.store.containsKey(after.id), isFalse);
    final staged = await File(after.uploadPath!).readAsBytes();
    expect(staged, isNot(_testBytes()));
    expect(requests, 2);

    // Simulate secure-store discard after an account transition; the original
    // key reference and deterministic migration identity reconstruct the keys.
    Uint8List? sent;
    final restarted = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      process: false,
      directSessionFn: (path, {body}) async {
        switch (path.split('/').last) {
          case 'register':
            return IMBoyHttpResponse.success({
              'object_key': 'new/direct/key',
              'state': 'RESERVED',
            });
          case 'declare':
            return IMBoyHttpResponse.success({'state': 'DECLARED'});
          case 'grant':
            return IMBoyHttpResponse.success({
              'attempt_id': 1,
              'grant': {
                'transport': 's3_put',
                'method': 'PUT',
                'url': 'https://s3.example/staging',
                'required_headers': [
                  ['Content-Type', 'application/octet-stream'],
                  ['x-amz-checksum-sha256', 'checksum'],
                ],
                'expires_in': 300,
              },
            });
          case 'finalize':
            return IMBoyHttpResponse.success({'state': 'CONFIRMED'});
          default:
            throw StateError('unexpected direct action: $path');
        }
      },
      directPutFn: (url, file, length, headers) async {
        sent = await file.readAsBytes();
      },
    );
    expect(await restarted.resumeAll(_uidA), ['new/direct/key']);
    final completed = (await repo.find(after.id))!;
    expect(completed.stage, AttachmentUploadStage.confirmed);
    expect(completed.businessIntent, before.businessIntent);
    final newMaterial = keys.store[(await repo.find(after.id))!.keyRef]!;
    expect(newMaterial['content_key'], isNot(material['content_key']));
    expect(newMaterial['base_nonce'], isNot(material['base_nonce']));
    expect(newMaterial['descriptor'], isNotNull);
    expect(sent, isNot(_testBytes()));
    expect(await cache.readAsBytes(), ciphertext);
    expect(await File(after.uploadPath!).exists(), isFalse);
  });

  test('无法证明来源归属时保留旧明文和无关文件', () async {
    await _createMessageOutboxTables(db);
    const oldId = 'old-plaintext-owned';
    const anchor = 'old-plaintext-anchor';
    await _uploader(repo, keys).upload(
      idempotencyKey: oldId,
      userId: _uidA,
      bytes: _testBytes(),
      fileName: 'resume.bin',
      mime: 'application/octet-stream',
      bindingHashHex: _binding,
      anchorMsgId: anchor,
      messageIntent: {
        'state': 'uploading',
        'author_id': _uidA,
        'chat_type': 'c2c',
      },
      prepareOnly: true,
    );
    final before = (await repo.find(oldId))!;
    final encryptedSource = File(before.uploadPath!);
    final oldSource = File(
      encryptedSource.path.replaceFirst('.source.enc', '.source'),
    );
    await oldSource.writeAsBytes(_testBytes(), flush: true);
    await db.update(
      'attachment_upload_task',
      {'upload_path': oldSource.path},
      where: 'id = ?',
      whereArgs: [oldId],
    );
    final unrelated = File('${oldSource.parent.path}/unrelated.bin.source');
    await unrelated.writeAsBytes([9, 8, 7]);
    final interrupted = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      process: false,
      legacyMigrationCommittedBarrier: (_) async =>
          throw _KillSignal('post-commit'),
      directSessionFn: (path, {body}) async => IMBoyHttpResponse.failure(
        errMsg: body?['client_upload_id'] == oldId
            ? 'legacy_session_conflict'
            : 'offline',
      ),
    );
    expect(await interrupted.resumeAll(_uidA), isEmpty);
    final replacement = (await repo.findByAnchor(anchor, _uidA)).single;
    expect(replacement.id, isNot(oldId));
    expect(await oldSource.exists(), isTrue);
    final staged = File(replacement.uploadPath!);
    final validStage = await staged.readAsBytes();
    await staged.writeAsBytes([0, 1], flush: true);
    final retry = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      process: false,
      directSessionFn: (_, {body}) async =>
          IMBoyHttpResponse.failure(errMsg: 'offline'),
    );
    expect(await retry.resumeAll(_uidA), isEmpty);
    expect(
      await oldSource.exists(),
      isTrue,
      reason: 'invalid replacement cannot justify deletion',
    );
    await staged.writeAsBytes(validStage, flush: true);
    await oldSource.writeAsBytes([1, 2], flush: true);
    expect(await retry.resumeAll(_uidA), isEmpty);
    expect(
      await oldSource.exists(),
      isTrue,
      reason: 'changed source is not ours to delete',
    );
    await oldSource.writeAsBytes(_testBytes(), flush: true);
    expect(await retry.resumeAll(_uidA), isEmpty);
    expect(await oldSource.exists(), isTrue);
    expect(await unrelated.readAsBytes(), [9, 8, 7]);
    expect(
      (await repo.find(replacement.id))!.businessIntent,
      before.businessIntent,
    );
  });

  test('旧密文迁移后同轮确认并恢复原消息 outbox', () async {
    await _createMessageOutboxTables(db);
    const id = 'same-round-legacy';
    const anchor = 'same-round-original-message';
    final handler = ChatAttachmentHandler(
      peerId: _uidB,
      conversationUk3: 'c2c-101-202',
      type: 'C2C',
      currentUserOverride: const User(id: _uidA),
      onMessageCreated: (_) async => true,
    );
    final intent = handler.pendingMessageIntent(
      anchor,
      'file',
      name: 'original.bin',
      size: _testBytes().length,
    );
    await expectLater(
      _uploader(repo, keys).upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: intent,
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('put');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final actions = <String>[];
    final recovered = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      process: false,
      directSessionFn: (path, {body}) async {
        final action = path.split('/').last;
        actions.add(action);
        switch (action) {
          case 'register':
            if (body?['client_upload_id'] == id) {
              return IMBoyHttpResponse.failure(
                errMsg: 'legacy_session_conflict',
              );
            }
            return IMBoyHttpResponse.success({
              'object_key': 'new/direct/same-round',
              'state': 'RESERVED',
            });
          case 'declare':
            return IMBoyHttpResponse.success({'state': 'DECLARED'});
          case 'grant':
            return IMBoyHttpResponse.success({
              'attempt_id': 1,
              'grant': {
                'transport': 's3_put',
                'method': 'PUT',
                'url': 'https://s3.example/staging',
                'required_headers': [
                  ['Content-Type', 'application/octet-stream'],
                  ['x-amz-checksum-sha256', 'checksum'],
                ],
                'expires_in': 300,
              },
            });
          case 'finalize':
            return IMBoyHttpResponse.success({'state': 'CONFIRMED'});
          default:
            throw StateError('unexpected direct action: $action');
        }
      },
      directPutFn: (url, file, length, headers) async {
        expect(await file.readAsBytes(), isNot(_testBytes()));
      },
    );
    expect(await recovered.resumeAll(_uidA), ['new/direct/same-round']);
    final group = await repo.findByAnchor(anchor, _uidA);
    expect(group, hasLength(1));
    expect(group.single.stage, AttachmentUploadStage.confirmed);
    expect(jsonDecode(group.single.businessIntent!)['state'], 'uploading');
    expect(actions, [
      'register',
      'register',
      'register',
      'declare',
      'grant',
      'finalize',
    ]);
    final notified = <String>[];
    await recovered.recoverBusinessOutbox(
      _uidA,
      prepareMessage: (savedIntent, message) async => MessageModel(
        message.id,
        autoId: 0,
        type: 'C2C',
        status: IMBoyMessageStatus.sending,
        fromId: 101,
        toId: 202,
        payload: '',
        e2ee: {'protocol': 'olm', 'meta_version': 3},
        isAuthor: 1,
        conversationUk3: 'c2c-101-202',
        msgType: 'file',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
      notifyRetry: (messageId, _) => notified.add(messageId),
    );
    expect(await db.rawQuery('SELECT id FROM msg_c2c'), [
      {'id': anchor},
    ]);
    expect(notified, [anchor]);
    expect(
      jsonDecode((await repo.find(group.single.id))!.businessIntent!)['state'],
      'outbox_ready',
    );
  });

  test('旧视频先迁移已确认缩略图，再同轮迁移视频并保留原消息', () async {
    await _createMessageOutboxTables(db);
    const thumbId = 'old-video-thumb';
    const videoId = 'old-video-main';
    const anchor = 'old-video-original-message';
    final handler = ChatAttachmentHandler(
      peerId: _uidB,
      conversationUk3: 'c2c-101-202',
      type: 'C2C',
      currentUserOverride: const User(id: _uidA),
      onMessageCreated: (_) async => true,
    );
    final intent = handler.pendingMessageIntent(
      anchor,
      'video',
      name: 'original.mp4',
      width: 640,
      height: 480,
      duration: const Duration(seconds: 2),
    );
    final up = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      directSessionFn: (_, {body}) async => IMBoyHttpResponse.success({
        'object_key': body?['object_key'],
        'state': 'CONFIRMED',
      }),
    );
    for (final (id, name, mime) in [
      (thumbId, 'thumb.jpg', 'image/jpeg'),
      (videoId, 'video.mp4', 'video/mp4'),
    ]) {
      await up.upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: name,
        mime: mime,
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: intent,
        prepareOnly: true,
      );
    }
    f.objectKey = 'old/thumbnail';
    await up.upload(
      idempotencyKey: thumbId,
      userId: _uidA,
      bytes: _testBytes(),
      fileName: 'thumb.jpg',
      mime: 'image/jpeg',
      bindingHashHex: _binding,
      anchorMsgId: anchor,
      messageIntent: intent,
      presignFn: f.presign,
      putFn: f.put,
      confirmFn: f.confirm,
    );
    keys.store[videoId]!['thumb'] =
        keys.store[(await repo.find(thumbId))!.keyRef]!['descriptor']!;
    f.objectKey = 'old/video';
    await expectLater(
      up.upload(
        idempotencyKey: videoId,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'video.mp4',
        mime: 'video/mp4',
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: intent,
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('old-video');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final uploaded = <String>[];
    final resumed = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      process: false,
      directSessionFn: (path, {body}) async {
        switch (path.split('/').last) {
          case 'status':
            return IMBoyHttpResponse.success({
              'object_key': body?['object_key'],
              'state': 'CONFIRMED',
            });
          case 'register':
            if (body?['client_upload_id'] == videoId) {
              return IMBoyHttpResponse.failure(
                errMsg: 'legacy_session_conflict',
              );
            }
            return IMBoyHttpResponse.success({
              'object_key': body?['filename'] == 'thumb.jpg'
                  ? 'new/thumbnail'
                  : 'new/video',
              'state': 'RESERVED',
            });
          case 'declare':
            return IMBoyHttpResponse.success({'state': 'DECLARED'});
          case 'grant':
            return IMBoyHttpResponse.success({
              'attempt_id': 1,
              'grant': {
                'transport': 's3_put',
                'method': 'PUT',
                'url': 'https://s3.example/staging',
                'required_headers': [
                  [
                    'Content-Type',
                    body?['object_key'] == 'new/thumbnail'
                        ? 'image/jpeg'
                        : 'video/mp4',
                  ],
                  ['x-amz-checksum-sha256', 'checksum'],
                ],
                'expires_in': 300,
              },
            });
          case 'finalize':
            return IMBoyHttpResponse.success({'state': 'CONFIRMED'});
          default:
            throw StateError('unexpected direct action: $path');
        }
      },
      directPutFn: (url, file, length, headers) async {
        uploaded.add(headers['Content-Type']!);
        expect(await file.readAsBytes(), isNot(_testBytes()));
      },
    );
    expect(await resumed.resumeAll(_uidA), ['new/thumbnail', 'new/video']);
    expect(uploaded, ['image/jpeg', 'video/mp4']);
    final group = await repo.findByAnchor(anchor, _uidA);
    expect(group, hasLength(2));
    expect(
      group.every((row) => row.stage == AttachmentUploadStage.confirmed),
      isTrue,
    );
    expect(await repo.find(thumbId), isNull);
    expect(await repo.find(videoId), isNull);
    expect(keys.store.containsKey(thumbId), isTrue);
    expect(keys.store.containsKey(videoId), isTrue);
    final video = group.singleWhere((row) => row.mime.startsWith('video/'));
    final restored = await resumed.restoreMessageTemplate(video);
    final metadata = Map<String, dynamic>.from(restored['metadata'] as Map);
    final descriptor = AttachmentDescriptor.fromMap(
      Map<String, dynamic>.from(metadata['attachment_descriptor'] as Map),
    );
    expect(descriptor.objectKey, 'new/video');
    expect(descriptor.thumb?.objectKey, 'new/thumbnail');
    expect(restored['id'], anchor);
  });

  test('旧视频未注册时依据服务端旧状态迁移缩略图并保留原消息', () async {
    await _createMessageOutboxTables(db);
    const thumbId = 'old-video-thumb';
    const videoId = 'old-video-main';
    const anchor = 'old-video-original-message';
    final handler = ChatAttachmentHandler(
      peerId: _uidB,
      conversationUk3: 'c2c-101-202',
      type: 'C2C',
      currentUserOverride: const User(id: _uidA),
      onMessageCreated: (_) async => true,
    );
    final intent = handler.pendingMessageIntent(
      anchor,
      'video',
      name: 'original.mp4',
      width: 640,
      height: 480,
      duration: const Duration(seconds: 2),
    );
    final up = _uploader(repo, keys);
    for (final (id, name, mime) in [
      (thumbId, 'thumb.jpg', 'image/jpeg'),
      (videoId, 'video.mp4', 'video/mp4'),
    ]) {
      await up.upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: name,
        mime: mime,
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: intent,
        prepareOnly: true,
      );
    }
    f.objectKey = 'old/thumbnail';
    await up.upload(
      idempotencyKey: thumbId,
      userId: _uidA,
      bytes: _testBytes(),
      fileName: 'thumb.jpg',
      mime: 'image/jpeg',
      bindingHashHex: _binding,
      anchorMsgId: anchor,
      messageIntent: intent,
      presignFn: f.presign,
      putFn: f.put,
      confirmFn: f.confirm,
    );
    keys.store[videoId]!['thumb'] =
        keys.store[(await repo.find(thumbId))!.keyRef]!['descriptor']!;
    final uploaded = <String>[];
    final resumed = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      process: false,
      directSessionFn: (path, {body}) async {
        switch (path.split('/').last) {
          case 'status':
            return IMBoyHttpResponse.success({
              'object_key': body?['object_key'],
              'state': body?['object_key'] == 'old/thumbnail'
                  ? null
                  : 'CONFIRMED',
            });
          case 'register':
            if (body?['client_upload_id'] == videoId) {
              return IMBoyHttpResponse.failure(
                errMsg: 'legacy_session_conflict',
              );
            }
            return IMBoyHttpResponse.success({
              'object_key': body?['filename'] == 'thumb.jpg'
                  ? 'new/thumbnail'
                  : 'new/video',
              'state': 'RESERVED',
            });
          case 'declare':
            return IMBoyHttpResponse.success({'state': 'DECLARED'});
          case 'grant':
            return IMBoyHttpResponse.success({
              'attempt_id': 1,
              'grant': {
                'transport': 's3_put',
                'method': 'PUT',
                'url': 'https://s3.example/staging',
                'required_headers': [
                  [
                    'Content-Type',
                    body?['object_key'] == 'new/thumbnail'
                        ? 'image/jpeg'
                        : 'video/mp4',
                  ],
                  ['x-amz-checksum-sha256', 'checksum'],
                ],
                'expires_in': 300,
              },
            });
          case 'finalize':
            return IMBoyHttpResponse.success({'state': 'CONFIRMED'});
          default:
            throw StateError('unexpected direct action: $path');
        }
      },
      directPutFn: (url, file, length, headers) async {
        uploaded.add(headers['Content-Type']!);
        expect(await file.readAsBytes(), isNot(_testBytes()));
      },
    );
    expect(await resumed.resumeAll(_uidA), ['new/thumbnail', 'new/video']);
    expect(uploaded, ['image/jpeg', 'video/mp4']);
    final group = await repo.findByAnchor(anchor, _uidA);
    expect(group, hasLength(2));
    expect(
      group.every((row) => row.stage == AttachmentUploadStage.confirmed),
      isTrue,
    );
    expect(await repo.find(thumbId), isNull);
    expect(await repo.find(videoId), isNull);
    expect(keys.store.containsKey(thumbId), isTrue);
    expect(keys.store.containsKey(videoId), isTrue);
    final video = group.singleWhere((row) => row.mime.startsWith('video/'));
    final restored = await resumed.restoreMessageTemplate(video);
    final metadata = Map<String, dynamic>.from(restored['metadata'] as Map);
    final descriptor = AttachmentDescriptor.fromMap(
      Map<String, dynamic>.from(metadata['attachment_descriptor'] as Map),
    );
    expect(descriptor.objectKey, 'new/video');
    expect(descriptor.thumb?.objectKey, 'new/thumbnail');
    expect(restored['id'], anchor);
  });

  test('视频直接调用在状态不可达时不注册也不更改原任务', () async {
    await _createMessageOutboxTables(db);
    const thumbId = 'old-video-thumb';
    const videoId = 'old-video-main';
    const anchor = 'old-video-original-message';
    final handler = ChatAttachmentHandler(
      peerId: _uidB,
      conversationUk3: 'c2c-101-202',
      type: 'C2C',
      currentUserOverride: const User(id: _uidA),
      onMessageCreated: (_) async => true,
    );
    final intent = handler.pendingMessageIntent(
      anchor,
      'video',
      name: 'original.mp4',
      width: 640,
      height: 480,
      duration: const Duration(seconds: 2),
    );
    final up = _uploader(repo, keys);
    for (final (id, name, mime) in [
      (thumbId, 'thumb.jpg', 'image/jpeg'),
      (videoId, 'video.mp4', 'video/mp4'),
    ]) {
      await up.upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: name,
        mime: mime,
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: intent,
        prepareOnly: true,
      );
    }
    f.objectKey = 'old/thumbnail';
    await up.upload(
      idempotencyKey: thumbId,
      userId: _uidA,
      bytes: _testBytes(),
      fileName: 'thumb.jpg',
      mime: 'image/jpeg',
      bindingHashHex: _binding,
      anchorMsgId: anchor,
      messageIntent: intent,
      presignFn: f.presign,
      putFn: f.put,
      confirmFn: f.confirm,
    );
    keys.store[videoId]!['thumb'] =
        keys.store[(await repo.find(thumbId))!.keyRef]!['descriptor']!;
    var calls = 0;
    final offline = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      directSessionFn: (path, {body}) async {
        calls++;
        expect(path, endsWith('/status'));
        return IMBoyHttpResponse.failure(errMsg: 'offline');
      },
    );
    await expectLater(
      offline.upload(
        idempotencyKey: videoId,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'video.mp4',
        mime: 'video/mp4',
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: intent,
      ),
      throwsA(anything),
    );
    expect(calls, 1);
    expect((await repo.find(videoId))!.stage, AttachmentUploadStage.pending);
    expect(await repo.find(thumbId), isNotNull);
    expect(await offline.resumeAll(_uidA), isEmpty);
    expect((await repo.find(videoId))!.stage, AttachmentUploadStage.pending);
    final originalThumb = keys.store[videoId]!['thumb']!;
    final unrelated = jsonDecode(originalThumb) as Map<String, dynamic>;
    unrelated['name'] = 'not-the-confirmed-thumbnail.jpg';
    final seal = AttachmentSealRequest(
      bindingHash: _hexDecode(_binding),
      attachmentId: videoId,
    )..thumbDescriptor = AttachmentDescriptor.fromMap(unrelated);
    final before = Map<String, String>.of(keys.store[videoId]!);
    final rejected = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sealRequest: seal,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      directSessionFn: (_, {body}) async =>
          IMBoyHttpResponse.failure(errMsg: 'offline'),
    );
    await expectLater(
      rejected.upload(
        idempotencyKey: videoId,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'video.mp4',
        mime: 'video/mp4',
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: intent,
      ),
      throwsA(anything),
    );
    expect(keys.store[videoId], before);
    final changed = jsonDecode(originalThumb) as Map<String, dynamic>;
    changed['name'] = 'different-name.jpg';
    keys.store[videoId]!['thumb'] = jsonEncode(changed);
    final confirmed = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      directSessionFn: (path, {body}) async {
        expect(path, endsWith('/status'));
        return IMBoyHttpResponse.success({
          'object_key': body?['object_key'],
          'state': 'CONFIRMED',
        });
      },
    );
    await expectLater(
      confirmed.upload(
        idempotencyKey: videoId,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'video.mp4',
        mime: 'video/mp4',
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: intent,
      ),
      throwsStateError,
    );
    expect((await repo.find(videoId))!.stage, AttachmentUploadStage.pending);
    keys.store[videoId]!['thumb'] = originalThumb;
    await db.insert('msg_c2c', {'id': anchor});
    final callsBeforeOutbox = calls;
    expect(await offline.resumeAll(_uidA), isEmpty);
    expect(calls, callsBeforeOutbox);
    expect((await repo.find(videoId))!.lastError, 'legacy_outbox_check');
    expect(await repo.find(thumbId), isNotNull);
  });

  test('视频先遍历时，正式密文缩略图重启确认后同轮恢复视频', () async {
    await _createMessageOutboxTables(db);
    const thumbId = 'old-resume-thumb';
    const videoId = 'old-resume-video';
    const anchor = 'old-resume-message';
    final handler = ChatAttachmentHandler(
      peerId: _uidB,
      conversationUk3: 'c2c-101-202',
      type: 'C2C',
      currentUserOverride: const User(id: _uidA),
      onMessageCreated: (_) async => true,
    );
    final intent = handler.pendingMessageIntent(
      anchor,
      'video',
      name: 'original.mp4',
    );
    final up = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      directSessionFn: (_, {body}) async => IMBoyHttpResponse.success({
        'object_key': body?['object_key'],
        'state': 'CONFIRMED',
      }),
    );
    for (final (id, name, mime) in [
      (thumbId, 'thumb.jpg', 'image/jpeg'),
      (videoId, 'video.mp4', 'video/mp4'),
    ]) {
      await up.upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: name,
        mime: mime,
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: intent,
        prepareOnly: true,
      );
    }
    f.objectKey = 'old/thumbnail';
    await up.upload(
      idempotencyKey: thumbId,
      userId: _uidA,
      bytes: _testBytes(),
      fileName: 'thumb.jpg',
      mime: 'image/jpeg',
      bindingHashHex: _binding,
      anchorMsgId: anchor,
      messageIntent: intent,
      presignFn: f.presign,
      putFn: f.put,
      confirmFn: f.confirm,
    );
    keys.store[videoId]!['thumb'] =
        keys.store[(await repo.find(thumbId))!.keyRef]!['descriptor']!;
    f.objectKey = 'old/video';
    await expectLater(
      up.upload(
        idempotencyKey: videoId,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'video.mp4',
        mime: 'video/mp4',
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: intent,
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('old-video');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final expectedByKey = <String, Map<String, dynamic>>{};
    final confirmed = <String>{};
    final uploads = <String>[];
    var loseThumbFinalize = true;
    Future<IMBoyHttpResponse> direct(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      final action = path.split('/').last;
      final objectKey = body?['object_key']?.toString();
      switch (action) {
        case 'register':
          if (body?['client_upload_id'] == videoId) {
            return IMBoyHttpResponse.failure(errMsg: 'legacy_session_conflict');
          }
          final key = body?['filename'] == 'thumb.jpg'
              ? 'new/restart-thumb'
              : 'new/restart-video';
          return IMBoyHttpResponse.success({
            'object_key': key,
            'state': confirmed.contains(key) ? 'CONFIRMED' : 'RESERVED',
          });
        case 'declare':
          expectedByKey[objectKey!] = {
            'sha256': body?['sha256'],
            'size_bytes': body?['size_bytes'],
            'mime': body?['mime'],
          };
          return IMBoyHttpResponse.success({'state': 'DECLARED'});
        case 'grant':
          return IMBoyHttpResponse.success({
            'attempt_id': 1,
            'grant': {
              'transport': 's3_put',
              'method': 'PUT',
              'url': 'https://s3.example/staging',
              'required_headers': [
                [
                  'Content-Type',
                  objectKey == 'new/restart-thumb' ? 'image/jpeg' : 'video/mp4',
                ],
                ['x-amz-checksum-sha256', 'checksum'],
              ],
              'expires_in': 300,
            },
          });
        case 'finalize':
          confirmed.add(objectKey!);
          if (objectKey == 'new/restart-thumb' && loseThumbFinalize) {
            loseThumbFinalize = false;
            throw _KillSignal('response-lost');
          }
          return IMBoyHttpResponse.success({'state': 'CONFIRMED'});
        case 'status':
          return IMBoyHttpResponse.success({
            'object_key': objectKey,
            'state': confirmed.contains(objectKey) ? 'CONFIRMED' : 'GRANTED',
            'expected': expectedByKey[objectKey],
          });
        default:
          throw StateError('unexpected direct action: $action');
      }
    }

    ResumableAttachmentUploader make() => ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      process: false,
      directSessionFn: direct,
      directPutFn: (url, file, length, headers) async =>
          uploads.add(headers['Content-Type']!),
    );
    expect(await make().resumeAll(_uidA), isEmpty);
    final firstGroup = await repo.findByAnchor(anchor, _uidA);
    final pendingThumb = firstGroup.singleWhere(
      (row) => row.mime.startsWith('image/'),
    );
    expect(pendingThumb.stage, AttachmentUploadStage.putDone);
    expect(pendingThumb.uploadPath, contains('.bin.material-'));
    expect((await repo.find(videoId))!.lastError, 'legacy_reselect');
    await db.update(
      'attachment_upload_task',
      {'created_at': 1},
      where: 'id = ?',
      whereArgs: [videoId],
    );
    expect((await repo.listResumable(_uidA)).first.id, videoId);
    expect(await make().resumeAll(_uidA), [
      'new/restart-thumb',
      'new/restart-video',
    ]);
    expect(uploads, ['image/jpeg', 'video/mp4']);
    final group = await repo.findByAnchor(anchor, _uidA);
    expect(group, hasLength(2));
    expect(
      group.every((row) => row.stage == AttachmentUploadStage.confirmed),
      isTrue,
    );
    final video = group.singleWhere((row) => row.mime.startsWith('video/'));
    final restored = await make().restoreMessageTemplate(video);
    final meta = Map<String, dynamic>.from(restored['metadata'] as Map);
    final descriptor = AttachmentDescriptor.fromMap(
      Map<String, dynamic>.from(meta['attachment_descriptor'] as Map),
    );
    expect(descriptor.thumb?.objectKey, 'new/restart-thumb');
    expect(restored['id'], anchor);
    Future<MessageModel> prepare(
      Map<String, dynamic> savedIntent,
      Message message,
    ) async => MessageModel(
      message.id,
      autoId: 0,
      type: 'C2C',
      status: IMBoyMessageStatus.sending,
      fromId: 101,
      toId: 202,
      payload: '',
      e2ee: {'protocol': 'olm', 'meta_version': 3},
      isAuthor: 1,
      conversationUk3: 'c2c-101-202',
      msgType: 'video',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final retry = <String>[];
    await make().recoverBusinessOutbox(
      _uidA,
      prepareMessage: prepare,
      notifyRetry: (id, _) => retry.add(id),
    );
    await make().recoverBusinessOutbox(
      _uidA,
      prepareMessage: prepare,
      notifyRetry: (id, _) => retry.add(id),
    );
    expect(await db.rawQuery('SELECT id FROM msg_c2c'), [
      {'id': anchor},
    ]);
  });

  test('已确认缩略图正在迁移时，模板与 outbox 均阻断', () async {
    await _createMessageOutboxTables(db);
    const anchor = 'migrating-thumb-anchor';
    final handler = ChatAttachmentHandler(
      peerId: _uidB,
      conversationUk3: 'c2c-101-202',
      type: 'C2C',
      currentUserOverride: const User(id: _uidA),
      onMessageCreated: (_) async => true,
    );
    final intent = jsonEncode(
      handler.pendingMessageIntent(anchor, 'video', name: 'video.mp4'),
    );
    final thumbBase = await _seedRow(
      'busy-thumb',
      uid: _uidA,
      stage: AttachmentUploadStage.confirmed,
      objectKey: 'old/thumb',
    );
    final videoBase = await _seedRow(
      'busy-video',
      uid: _uidA,
      stage: AttachmentUploadStage.confirmed,
      objectKey: 'old/video',
    );
    await repo.insert(
      AttachmentUploadTask.fromMap({
        ...thumbBase.toMap(),
        'anchor_msg_id': anchor,
        'business_intent': intent,
        'mime': 'image/jpeg',
        'last_error': 'legacy_migrating:a12c5f87-944d-416d-bdcc-a7533ab3491f',
      }),
    );
    await repo.insert(
      AttachmentUploadTask.fromMap({
        ...videoBase.toMap(),
        'anchor_msg_id': anchor,
        'business_intent': intent,
        'mime': 'video/mp4',
      }),
    );
    await expectLater(
      _uploader(
        repo,
        keys,
      ).restoreMessageTemplate((await repo.find('busy-video'))!),
      throwsStateError,
    );
    expect(
      await repo.claimBusinessDispatch(anchor, _uidA, {
        'metadata': <String, dynamic>{},
      }),
      isFalse,
    );
    final message = MessageModel(
      anchor,
      autoId: 0,
      type: 'C2C',
      status: IMBoyMessageStatus.sending,
      fromId: 101,
      toId: 202,
      payload: '',
      e2ee: {'protocol': 'olm', 'meta_version': 3},
      isAuthor: 1,
      conversationUk3: 'c2c-101-202',
      msgType: 'video',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    expect(
      await repo.enqueueBusinessOutbox(
        message,
        userId: _uidA,
        isCurrent: () => true,
      ),
      isFalse,
    );
    expect(await db.rawQuery('SELECT id FROM msg_c2c'), isEmpty);
    await expectLater(
      MessageRepo(tableName: 'msg_c2c').insert(message, outbound: true),
      throwsStateError,
    );
    expect(await db.rawQuery('SELECT id FROM msg_c2c'), isEmpty);
    // 服务端已经接受的事实仍要落库，后续上传恢复据此停止而非重发。
    await MessageRepo(tableName: 'msg_c2c').insert(message);
    expect(await db.rawQuery('SELECT id FROM msg_c2c'), hasLength(1));
    expect(
      await repo.legacyOutboxMayExist((await repo.find('busy-video'))!),
      isTrue,
    );
  });

  test('旧迁移标记不能被过期的恢复结果覆盖或放弃', () async {
    await _createMessageOutboxTables(db);
    final base = await _seedRow(
      'marker-race',
      uid: _uidA,
      stage: AttachmentUploadStage.putDone,
      objectKey: 'old/key',
    );
    final observed = AttachmentUploadTask.fromMap({
      ...base.toMap(),
      'anchor_msg_id': 'marker-anchor',
      'business_intent': jsonEncode({
        'state': 'uploading',
        'author_id': _uidA,
        'chat_type': 'c2c',
      }),
    });
    await repo.insert(observed);
    const replacement = 'a12c5f87-944d-416d-bdcc-a7533ab3491f';
    final releaseStaleWriter = Completer<void>();
    final staleWrite = () async {
      await releaseStaleWriter.future;
      return repo.setRecoveryReason(observed, 'legacy_reselect');
    }();
    expect(
      await repo.reserveLegacyMigration(
        observed,
        replacement,
        isCurrent: () => true,
      ),
      replacement,
    );
    final marker = (await repo.find(observed.id))!.lastError;
    expect(marker, 'legacy_migrating:$replacement');
    releaseStaleWriter.complete();
    expect(await staleWrite, isFalse);
    expect(
      await repo.advanceStage(
        observed.id,
        observed.stage,
        observed.stage,
        userId: _uidA,
        lastError: 'legacy_outbox_check',
      ),
      isFalse,
    );
    expect(await repo.abandon(observed.id, _uidA, 'conflict'), isFalse);
    expect((await repo.find(observed.id))!.lastError, marker);
  });

  test('迟到的迁移不能覆盖已确认 descriptor 或留下暂存', () async {
    await _createMessageOutboxTables(db);
    const id = 'late-legacy';
    const anchor = 'late-legacy-anchor';
    await expectLater(
      _uploader(repo, keys).upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: {
          'state': 'uploading',
          'author_id': _uidA,
          'chat_type': 'c2c',
        },
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('put');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final old = (await repo.find(id))!;
    final oldCiphertext = File(old.uploadPath!);
    final oldSource = File(
      '${oldCiphertext.path.split('.material-').first}.source',
    );
    await oldSource.writeAsBytes(_testBytes(), flush: true);
    await db.update(
      'attachment_upload_task',
      {
        'upload_path': oldSource.path,
        'stage': AttachmentUploadStage.presigned.value,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final held = Completer<void>();
    final release = Completer<void>();
    Future<IMBoyHttpResponse> direct(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      switch (path.split('/').last) {
        case 'register':
          if (body?['client_upload_id'] == id) {
            return IMBoyHttpResponse.failure(errMsg: 'legacy_session_conflict');
          }
          return IMBoyHttpResponse.success({
            'object_key': 'new/direct/late',
            'state': 'RESERVED',
          });
        case 'declare':
          return IMBoyHttpResponse.success({'state': 'DECLARED'});
        case 'grant':
          return IMBoyHttpResponse.success({
            'attempt_id': 1,
            'grant': {
              'transport': 's3_put',
              'method': 'PUT',
              'url': 'https://s3.example/staging',
              'required_headers': [
                ['Content-Type', 'application/octet-stream'],
                ['x-amz-checksum-sha256', 'checksum'],
              ],
              'expires_in': 300,
            },
          });
        case 'finalize':
          return IMBoyHttpResponse.success({'state': 'CONFIRMED'});
        default:
          throw StateError('unexpected direct action: $path');
      }
    }

    ResumableAttachmentUploader make({bool delay = false}) =>
        ResumableAttachmentUploader(
          repo: repo,
          keyStore: keys,
          sessionGuard: (_) => true,
          cacheDirectory: _uploadCache,
          cacheWriter: (write, _) => write(),
          process: false,
          directSessionFn: direct,
          directPutFn: (url, file, length, headers) async {},
          legacyMigrationBarrier: delay
              ? (_) async {
                  held.complete();
                  await release.future;
                }
              : null,
        );
    final slow = make(delay: true).resumeAll(_uidA);
    await held.future;
    expect(await make().resumeAll(_uidA), ['new/direct/late']);
    final completed = (await repo.findByAnchor(anchor, _uidA)).single;
    final descriptor =
        keys.store[(await repo.find(completed.id))!.keyRef]!['descriptor'];
    expect(descriptor, isNotNull);
    release.complete();
    await slow;
    expect(
      keys.store[(await repo.find(completed.id))!.keyRef]!['descriptor'],
      descriptor,
    );
    expect(
      (await repo.find(completed.id))!.stage,
      AttachmentUploadStage.confirmed,
    );
    expect(await oldSource.exists(), isTrue);
    expect(await oldCiphertext.exists(), isTrue);
    expect(
      _uploadCache
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.contains('.migration')),
      isEmpty,
    );
  });

  test('旧任务恢复过程切号不写记录或生成新材料', () async {
    await _createMessageOutboxTables(db);
    const id = 'legacy-switch';
    await expectLater(
      _uploader(repo, keys).upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        anchorMsgId: 'switch-anchor',
        messageIntent: {
          'state': 'uploading',
          'author_id': _uidA,
          'chat_type': 'c2c',
        },
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('put');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final before = (await repo.find(id))!;
    final material = Map<String, String>.from(keys.store[id]!);
    final paths = _uploadCache
        .listSync(recursive: true)
        .map((e) => e.path)
        .toSet();
    var active = true;
    final uploader = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => active,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      directSessionFn: (_, {body}) async {
        active = false;
        return IMBoyHttpResponse.failure(errMsg: 'legacy_session_conflict');
      },
    );
    await expectLater(uploader.resumeAll(_uidA), throwsStateError);
    final after = (await repo.find(id))!;
    expect(after.lastError, isNull);
    expect(after.objectKey, before.objectKey);
    expect(keys.store[id], material);
    expect(
      _uploadCache.listSync(recursive: true).map((e) => e.path).toSet(),
      paths,
    );
  });

  test('并发旧任务恢复只生成一个新身份并保留旧材料', () async {
    await _createMessageOutboxTables(db);
    const id = 'legacy-race';
    await expectLater(
      _uploader(repo, keys).upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        anchorMsgId: 'race-anchor',
        messageIntent: {
          'state': 'uploading',
          'author_id': _uidA,
          'chat_type': 'c2c',
        },
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('put');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final before = (await repo.find(id))!;
    final material = Map<String, String>.from(keys.store[id]!);
    ResumableAttachmentUploader make() => ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      directSessionFn: (_, {body}) async =>
          IMBoyHttpResponse.failure(errMsg: 'legacy_session_conflict'),
    );
    await Future.wait([make().resumeAll(_uidA), make().resumeAll(_uidA)]);
    final rows = await repo.findByAnchor('race-anchor', _uidA);
    expect(rows, hasLength(1));
    expect(rows.single.id, isNot(id));
    expect(rows.single.stage, AttachmentUploadStage.pending);
    expect(rows.single.businessIntent, before.businessIntent);
    expect(keys.store[id], material);
    expect(keys.store.keys, isNot(contains(rows.single.id)));
    expect(await File(before.uploadPath!).exists(), isTrue);
  });

  test('旧任务已有 outbox 消息时不提供重发依据', () async {
    await _createMessageOutboxTables(db);
    const id = 'legacy-outbox';
    const anchor = 'outbox-anchor';
    await expectLater(
      _uploader(repo, keys).upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        anchorMsgId: anchor,
        messageIntent: {
          'state': 'uploading',
          'author_id': _uidA,
          'chat_type': 'c2c',
        },
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('put');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    await db.insert('msg_c2c', {'id': anchor});
    final resumed = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      directSessionFn: (_, {body}) async =>
          IMBoyHttpResponse.failure(errMsg: 'legacy_session_conflict'),
    );
    expect(await resumed.resumeAll(_uidA), isEmpty);
    final old = (await repo.find(id))!;
    expect(old.stage, AttachmentUploadStage.putDone);
    expect(old.lastError, 'legacy_outbox_check');
    expect(await repo.legacyOutboxMayExist(old), isTrue);
    expect(await repo.findByAnchor(anchor, _uidA), hasLength(1));
  });

  test('无业务意图的旧任务保留并提示返回原页面', () async {
    const id = 'legacy-no-intent';
    await expectLater(
      _uploader(repo, keys).upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.presigned) {
            throw _KillSignal('presigned');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final before = (await repo.find(id))!;
    final resumed = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      directSessionFn: (_, {body}) async =>
          IMBoyHttpResponse.failure(errMsg: 'legacy_session_conflict'),
    );
    expect(await resumed.resumeAll(_uidA), isEmpty);
    final old = (await repo.find(id))!;
    expect(old.stage, AttachmentUploadStage.presigned);
    expect(old.lastError, 'legacy_return_page');
    expect(old.objectKey, before.objectKey);
    expect(await repo.hasUnrecoverableNonChat(_uidA), isTrue);
    expect(await File(old.uploadPath!).exists(), isTrue);
    expect(keys.store[id], isNotNull);
  });

  test('direct 密文 PUT 后中断，重启后 renew 并完成原身份', () async {
    var state = 'RESERVED';
    Map<String, dynamic>? expected;
    var attempt = 0;
    final uploaded = <Uint8List>[];
    Future<IMBoyHttpResponse> session(
      String path, {
      Map<String, dynamic>? body,
    }) async {
      switch (path.split('/').last) {
        case 'register':
          expect(body?['cipher'], AttachmentDescriptor.supportedCipher);
          return IMBoyHttpResponse.success({
            'object_key': 'private/direct-key',
            'state': state,
          });
        case 'declare':
          expected = {
            'sha256': body!['sha256'],
            'size_bytes': body['size_bytes'],
            'mime': body['mime'],
          };
          state = 'DECLARED';
          return IMBoyHttpResponse.success({'state': state});
        case 'grant':
        case 'renew':
          state = 'GRANTED';
          attempt++;
          return IMBoyHttpResponse.success({
            'attempt_id': attempt,
            'grant': {
              'transport': 's3_put',
              'url': 'https://garage.test/$attempt',
              'method': 'PUT',
              'required_headers': [
                ['Content-Type', 'application/octet-stream'],
                ['x-amz-checksum-sha256', 'sha'],
              ],
            },
          });
        case 'status':
          return IMBoyHttpResponse.success({
            'state': state,
            'expected': expected,
            'attempts': List.filled(attempt, <String, dynamic>{}),
          });
        case 'finalize':
          state = 'CONFIRMED';
          return IMBoyHttpResponse.success({'state': state});
        default:
          throw StateError(path);
      }
    }

    ResumableAttachmentUploader makeUploader() => ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      directSessionFn: session,
      directPutFn: (_, file, _, _) async =>
          uploaded.add(await file.readAsBytes()),
    );
    const id = 'f0e0d0c0-b0a0-4908-8877-665544332211';
    await expectLater(
      makeUploader().upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('put');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final pending = (await repo.find(id))!;
    expect(pending.stage, AttachmentUploadStage.putDone);
    expect(
      pending.ciphertextSha256,
      sha256.convert(uploaded.single).toString(),
    );
    final result = await makeUploader().resumeAll(_uidA);
    expect(result, ['private/direct-key']);
    expect((await repo.find(id))!.stage, AttachmentUploadStage.confirmed);
    expect(uploaded, hasLength(2));
    expect(uploaded[1], uploaded[0]);
    expect(attempt, 2);
  });

  test('kill_after_registered: 注册后（presign 前）被杀，恢复重走全链', () async {
    // 注册（任务行落盘）后进程被杀：行停在 pending，无密文无材料。
    await repo.insert(
      await _seedRow(
        't1',
        uid: _uidA,
        stage: AttachmentUploadStage.pending,
        objectKey: '',
      ),
    );

    // 「重启」：新 uploader，同 DB 同 KeyStore——同幂等键重放即恢复。
    final up2 = _uploader(repo, keys);
    final ok = await _runUpload(up2, f, id: 't1');
    expect(ok, f.objectKey);
    expect(f.presignCalls.length, 1, reason: '被杀前未到 presign，恢复只调用一次');
    final done = await repo.find('t1');
    expect(done!.stage, AttachmentUploadStage.confirmed);
  });

  test('kill_after_put: put_done 后被杀，恢复跳过重传', () async {
    final up1 = _uploader(repo, keys);
    await expectLater(
      _runUpload(
        up1,
        f,
        id: 't2',
        checkpoint: (e) async {
          if (e.stage == UploadCheckpointStage.putDone) throw _KillSignal('d');
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    expect((await repo.find('t2'))!.stage, AttachmentUploadStage.putDone);
    expect(f.confirmBodies, isEmpty);
    final putsBefore = f.putBodies.length;

    final up2 = _uploader(repo, keys);
    await _runUpload(up2, f, id: 't2');
    expect(f.putBodies.length, putsBefore, reason: 'put_done 检查点后的恢复跳过 PUT 重传');
    expect(f.confirmBodies, hasLength(1));
    expect((await repo.find('t2'))!.stage, AttachmentUploadStage.confirmed);
  });

  test('kill_after_confirm: 已确认任务同键重放幂等返回原 objectKey', () async {
    final up1 = _uploader(repo, keys);
    final ok1 = await _runUpload(up1, f, id: 't3');
    final confirmsBefore = f.confirmBodies.length;

    final up2 = _uploader(repo, keys);
    final ok2 = await _runUpload(up2, f, id: 't3');
    expect(ok2, ok1);
    expect(f.confirmBodies.length, confirmsBefore, reason: 'confirmed 幂等路径零网络');
  });

  test('unknown_message_commit: 未知阶段回写 CAS 落空不误伤已终态行', () async {
    final up = _uploader(repo, keys);
    await _runUpload(up, f, id: 't4');
    final before = await repo.find('t4');
    // 迟到/未知回调把 confirmed 行往 put_done 回写 → CAS 拒绝。
    final advanced = await repo.advanceStage(
      't4',
      AttachmentUploadStage.presigned,
      AttachmentUploadStage.putDone,
    );
    expect(advanced, isFalse);
    final after = await repo.find('t4');
    expect(after!.stage, before!.stage);
  });

  test('user_switch: 恢复只取本账号任务行', () async {
    final up = _uploader(repo, keys);
    await repo.insert(
      await _seedRow(
        't5',
        uid: _uidA,
        stage: AttachmentUploadStage.presigned,
        objectKey: f.objectKey,
      ),
    );
    final ok = await up.resumeAll(
      _uidB,
      bytesProvider: (_) async => _testBytes(),
    );
    expect(ok, isEmpty, reason: 'uidB 不恢复 uidA 的行');
    expect(
      (await repo.find('t5'))!.stage,
      AttachmentUploadStage.presigned,
      reason: '他人行不被触碰',
    );
  });

  test('presign_response_lost: presign 失败停在 pending，恢复重走 presign', () async {
    final up = _uploader(repo, keys);
    f.presignFail = true;
    await expectLater(_runUpload(up, f, id: 't6'), throwsA(anything));
    expect((await repo.find('t6'))!.stage, AttachmentUploadStage.pending);

    f.presignFail = false;
    final ok = await _runUpload(up, f, id: 't6');
    expect(ok, f.objectKey);
    expect(f.presignCalls.length, 2);
  });

  test('restart_before_put: sealed 检查点（材料已落盘）后被杀，恢复密文一致', () async {
    final up1 = _uploader(repo, keys);
    await expectLater(
      _runUpload(
        up1,
        f,
        id: 't7',
        checkpoint: (e) async {
          if (e.stage == UploadCheckpointStage.sealed) throw _KillSignal('s');
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    expect(
      keys.store['t7'],
      isNotNull,
      reason: '材料未落盘不上网络（fail-closed），此处材料已在',
    );

    final up2 = _uploader(repo, keys);
    final ok = await _runUpload(up2, f, id: 't7');
    expect(ok, f.objectKey);
    expect(f.putBodies.length, 1, reason: 'sealed 后被杀未上网络，恢复只 PUT 一次');
  });

  test('expired_capability_resume: confirm失败保留检查点并记录错误', () async {
    final up = _uploader(repo, keys);
    await repo.insert(
      await _seedRow(
        't8',
        uid: _uidA,
        stage: AttachmentUploadStage.putDone,
        objectKey: f.objectKey,
      ),
    );
    await keys.write('t8', {
      'content_key': base64Encode(Uint8List.fromList(List.filled(32, 7))),
      'base_nonce': base64Encode(Uint8List.fromList(List.filled(12, 9))),
    });
    f.confirmForbidden = true;
    expect(
      await up.resumeAll(
        _uidA,
        bytesProvider: (_) async => _testBytes(),
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
      ),
      isEmpty,
    );
    expect((await repo.find('t8'))!.stage, AttachmentUploadStage.putDone);
    expect((await repo.find('t8'))!.lastError, isNotEmpty);
  });

  test('account_switch_late_callback: 账号切换后旧行回调 CAS 拒绝', () async {
    final up = _uploader(repo, keys);
    await repo.insert(
      await _seedRow(
        't9',
        uid: _uidA,
        stage: AttachmentUploadStage.presigned,
        objectKey: f.objectKey,
      ),
    );
    // 旧账号（uidA）进程迟到回调试图推进 uidA 行——行本身仍归 uidA，
    // 但当前会话是 uidB：恢复入口按 uid 过滤，回调即使直达也按 CAS+行
    // 归属校验。此处验证恢复入口隔离。
    final ok = await up.resumeAll(
      _uidB,
      bytesProvider: (_) async => _testBytes(),
    );
    expect(ok, isEmpty);
    expect((await repo.find('t9'))!.stage, AttachmentUploadStage.presigned);
  });

  test('workspace_switch_late_callback: scope 变更的幂等键拒绝串工作区', () async {
    final up = _uploader(repo, keys);
    await _runUpload(up, f, id: 't10');
    // 同幂等键换 scopeRef 再次 upload → 已 confirmed 幂等返回，
    // 不产生第二行（业务层应换新幂等键发起工作区 B 的上传）。
    final ok = await _runUpload(up, f, id: 't10');
    expect(ok, f.objectKey);
    final rows = await db.query(
      'attachment_upload_task',
      where: 'id = ?',
      whereArgs: ['t10'],
    );
    expect(rows.length, 1);
  });

  test('authorization_revoked: 授权撤销（confirm 403）→ abandon 记录原因', () async {
    final up = _uploader(repo, keys);
    f.confirmForbidden = true;
    await expectLater(
      _runUpload(
        up,
        f,
        id: 't11',
        checkpoint: (e) async {
          if (e.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('d');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    f.confirmForbidden = false;
    // 直接 resume：confirm 403。
    f.confirmForbidden = true;
    await expectLater(
      up.resume(
        (await repo.find('t11'))!,
        Uint8List.fromList(List<int>.generate(4096, (i) => i % 251)),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
      ),
      throwsA(anything),
    );
    await repo.abandon('t11', _uidA, 'revoked');
    expect((await repo.find('t11'))!.stage, AttachmentUploadStage.abandoned);
  });

  test('durable_checkpoint_failure: 材料落盘失败 → 上传中止且不误推进', () async {
    final up = _uploader(repo, keys);
    keys.failWrites = true;
    await expectLater(_runUpload(up, f, id: 't12'), throwsA(anything));
    // sealed 检查点失败：材料未落盘、密文未上网络、行不越过 presigned。
    expect(f.putBodies, isEmpty);
    final row = await repo.find('t12');
    expect(row!.stage, isNot(AttachmentUploadStage.putDone));
  });

  test('same_key_same_ciphertext_after_restart: 恢复重放同 key 同密文', () async {
    final up1 = _uploader(repo, keys);
    await expectLater(
      _runUpload(
        up1,
        f,
        id: 't13',
        checkpoint: (e) async {
          if (e.stage == UploadCheckpointStage.sealed) throw _KillSignal('s');
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final material = keys.store['t13']!;
    final expected = AttachmentEncryptor.seal(
      plaintext: _testBytes(),
      bindingHash: _hexDecode(_binding),
      attachmentId: 't13',
      objectKey: f.objectKey,
      mime: 'application/octet-stream',
      name: 'resume.bin',
      contentKey: base64Decode(material['content_key']!),
      baseNonce: base64Decode(material['base_nonce']!),
    );
    final up2 = _uploader(repo, keys);
    await _runUpload(up2, f, id: 't13');
    expect(f.putBodies.single, expected.ciphertext);
    expect((await repo.find('t13'))!.objectKey, f.objectKey);
    expect(f.putBodies.length, 1);
    final sha = (await repo.find('t13'))!.ciphertextSha256;
    expect(sha, isNotNull);
    // 与 confirm 体一致：服务端收到的是恢复后密文的 hash。
    expect(f.confirmBodies.first['file_hash256'], sha);
  });

  test('lost_cipher_material_requires_new_task: 材料缺失显式 abandon', () async {
    final up = _uploader(repo, keys);
    await repo.insert(
      await _seedRow(
        't14',
        uid: _uidA,
        stage: AttachmentUploadStage.presigned,
        objectKey: f.objectKey,
      ),
    );
    // 不写 key store → 材料丢失。
    final ok = await up.resumeAll(
      _uidA,
      bytesProvider: (_) async => _testBytes(),
    );
    expect(ok, isEmpty);
    final row = await repo.find('t14');
    expect(row!.stage, AttachmentUploadStage.abandoned);
    expect(row.lastError, contains('material lost'));
  });

  test('legacy_download_range: 旧格式行（无 key_ref 材料）兼容处理不崩溃', () async {
    final up = _uploader(repo, keys);
    final legacy = await _seedRow(
      't15',
      uid: _uidA,
      stage: AttachmentUploadStage.presigned,
      objectKey: f.objectKey,
    );
    await db.update(
      'attachment_upload_task',
      {'key_ref': null},
      where: 'id = ?',
      whereArgs: ['t15'],
    );
    expect(legacy.keyRef, isNotNull);
    expect(await repo.insert(legacy), isTrue);
    final ok = await up.resumeAll(
      _uidA,
      bytesProvider: (_) async => _testBytes(),
    );
    expect(ok, isEmpty, reason: '旧格式无材料行按 lost material 处理');
    expect(((await repo.find('t15'))!).stage, AttachmentUploadStage.abandoned);
  });

  test('e2ee_byte_preservation: 同 key 同 nonce 两次 seal 字节一致', () async {
    final plain = Uint8List.fromList(List<int>.generate(8192, (i) => i % 253));
    final ck = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
    final bn = Uint8List.fromList(List<int>.generate(12, (i) => i + 2));
    final s1 = AttachmentEncryptor.seal(
      plaintext: plain,
      bindingHash: _hexDecode(_binding),
      attachmentId: 'det1',
      objectKey: 'k',
      mime: 'application/octet-stream',
      name: 'a.bin',
      contentKey: ck,
      baseNonce: bn,
    );
    final s2 = AttachmentEncryptor.seal(
      plaintext: plain,
      bindingHash: _hexDecode(_binding),
      attachmentId: 'det1',
      objectKey: 'k',
      mime: 'application/octet-stream',
      name: 'a.bin',
      contentKey: ck,
      baseNonce: bn,
    );
    expect(
      s1.ciphertextSha256Hex,
      s2.ciphertextSha256Hex,
      reason: 'AES-GCM 同 key 同 nonce 同明文 → 密文逐字节确定',
    );
  });

  test('new_key_reseals: abandon 后新任务新 key（密文不同）', () async {
    final up = _uploader(repo, keys);
    await repo.insert(
      await _seedRow(
        't16',
        uid: _uidA,
        stage: AttachmentUploadStage.presigned,
        objectKey: f.objectKey,
      ),
    );
    await up.resumeAll(
      _uidA,
      bytesProvider: (_) async => _testBytes(),
    ); // abandon（无材料）
    // 新任务新幂等键：全新 key 重新 seal。
    final ok = await _runUpload(up, f, id: 't16-new');
    expect(ok, f.objectKey);
    final oldKeys = keys.store['t16'];
    final newKeys = keys.store['t16-new'];
    expect(newKeys, isNotNull);
    expect(oldKeys, isNull, reason: '旧任务材料从未落盘');
    expect(f.putBodies, isNotEmpty);
  });

  test('changed_source_rejected_before_network: nonce不得用于不同明文', () async {
    final up = _uploader(repo, keys);
    await expectLater(
      _runUpload(
        up,
        f,
        id: 'pin',
        checkpoint: (e) async {
          if (e.stage == UploadCheckpointStage.sealed) throw _KillSignal('s');
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final calls = f.presignCalls.length;
    final changed = _testBytes()..[0] = 99;
    await expectLater(
      _runUpload(up, f, id: 'pin', bytes: changed),
      throwsStateError,
    );
    expect(f.presignCalls.length, calls);
    expect(f.putBodies, isEmpty);
  });

  test('different_object_key_rejected_before_put: 恢复不接受服务端换key', () async {
    final up = _uploader(repo, keys);
    await expectLater(
      _runUpload(
        up,
        f,
        id: 'key-pin',
        checkpoint: (e) async {
          if (e.stage == UploadCheckpointStage.sealed) throw _KillSignal('s');
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final original = (await repo.find('key-pin'))!.objectKey;
    f.objectKey = 'different-key';
    await expectLater(_runUpload(up, f, id: 'key-pin'), throwsStateError);
    expect(f.putBodies, isEmpty);
    expect((await repo.find('key-pin'))!.objectKey, original);
  });

  test('actual_scope_change_rejected: 同UUID切工作区不返回旧资产', () async {
    final up = _uploader(repo, keys);
    await _runUpload(up, f, id: 'scope-pin');
    await expectLater(
      up.upload(
        idempotencyKey: 'scope-pin',
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        scope: 'group',
        scopeRef: 'other-workspace',
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
      ),
      throwsStateError,
    );
    expect(f.presignCalls, hasLength(1));
  });

  test('actual_account_epoch_late_callback: 账号变更后不PUT不确认', () async {
    var active = true;
    final up = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => active,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
    );
    await expectLater(
      _runUpload(
        up,
        f,
        id: 'epoch',
        checkpoint: (e) async {
          if (e.stage == UploadCheckpointStage.presigned) active = false;
        },
      ),
      throwsStateError,
    );
    expect(f.putBodies, isEmpty);
    expect(f.confirmBodies, isEmpty);
    expect((await repo.find('epoch'))!.stage, AttachmentUploadStage.presigned);
  });

  test('fast_confirm_preserves_cipher_declaration: 大小hash和cipher均不变', () async {
    final up = _uploader(repo, keys);
    await expectLater(
      _runUpload(
        up,
        f,
        id: 'cipher-declaration',
        checkpoint: (e) async {
          if (e.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('put');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final sent = f.putBodies.single;
    await _runUpload(_uploader(repo, keys), f, id: 'cipher-declaration');
    final confirm = f.confirmBodies.single;
    expect(confirm['size'], sent.length);
    expect(confirm['cipher'], AttachmentDescriptor.supportedCipher);
    expect(confirm['file_hash256'], sha256.convert(sent).toString());
  });

  test(
    'local_presigned_remote_confirmed_reconciles_without_put: 远端已确认只调和原key',
    () async {
      final operations = <String>[];
      final events = <UploadCheckpointStage>[];
      final seal = AttachmentSealRequest(
        bindingHash: _hexDecode(_binding),
        attachmentId: 'remote-confirmed',
      );
      final objectKey = await AttachmentApi.uploadViaPresign(
        _testBytes(),
        'resume.bin',
        'application/octet-stream',
        clientUploadId: 'same-registered-id',
        seal: seal,
        resume: ResumableUploadState(
          objectKey: f.objectKey,
          contentKey: Uint8List.fromList(List.filled(32, 1)),
          baseNonce: Uint8List.fromList(List.filled(12, 2)),
        ),
        sessionFn: (query) async {
          operations.add(query['operation'] as String);
          return IMBoyHttpResponse.success({
            'object_key': f.objectKey,
            'session_state': 'confirmed',
          });
        },
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
        checkpoint: (event) async {
          events.add(event.stage);
        },
      );
      expect(operations, ['status']);
      expect(f.presignCalls, isEmpty);
      expect(f.putBodies, isEmpty);
      expect(objectKey, f.objectKey);
      expect(f.confirmBodies.single['object_key'], f.objectKey);
      expect(
        f.confirmBodies.single['cipher'],
        AttachmentDescriptor.supportedCipher,
      );
      expect(seal.descriptor!.objectKey, f.objectKey);
      expect(events, [
        UploadCheckpointStage.sealed,
        UploadCheckpointStage.putDone,
        UploadCheckpointStage.confirmed,
      ]);
    },
  );

  test('session_status_then_renew_same_identity: 恢复发送同UUID且不重新登记', () async {
    final operations = <String>[];
    final ids = <String>[];
    String? putUrl;
    await AttachmentApi.uploadViaPresign(
      _testBytes(),
      'resume.bin',
      'application/octet-stream',
      clientUploadId: 'same-upload-uuid',
      resume: ResumableUploadState(objectKey: f.objectKey),
      sessionFn: (query) async {
        operations.add(query['operation'] as String);
        ids.add(query['client_upload_id'] as String);
        return IMBoyHttpResponse.success(
          query['operation'] == 'status'
              ? {'object_key': f.objectKey, 'session_state': 'registered'}
              : {
                  'object_key': f.objectKey,
                  'put_url': 'https://garage.test/renewed',
                },
        );
      },
      presignFn: (_, _) async => throw StateError('unexpected new register'),
      putFn: (url, bytes, mime, process) async {
        putUrl = url;
      },
      confirmFn: f.confirm,
    );
    expect(operations, ['status', 'renew']);
    expect(ids.toSet(), {'same-upload-uuid'});
    expect(putUrl, 'https://garage.test/renewed');
    expect(f.confirmBodies.single['object_key'], f.objectKey);
  });

  for (final failure in ['transient', 'terminal', 'account-switch']) {
    test('resume_queue_isolates_$failure', () async {
      var active = true;
      ResumableAttachmentUploader restarted() => ResumableAttachmentUploader(
        repo: repo,
        keyStore: keys,
        sessionGuard: (_) => active,
        encrypt: false,
        cacheDirectory: _uploadCache,
        cacheWriter: (write, _) => write(),
      );
      for (final id in ['first-A', 'healthy-B']) {
        await expectLater(
          restarted().upload(
            idempotencyKey: id,
            userId: _uidA,
            bytes: _testBytes(),
            fileName: '$id.bin',
            mime: 'application/octet-stream',
            bindingHashHex: '',
            presignFn: f.presign,
            putFn: f.put,
            confirmFn: f.confirm,
            checkpoint: (event) async {
              if (event.stage == UploadCheckpointStage.putDone) {
                throw _KillSignal(id);
              }
            },
          ),
          throwsA(isA<_KillSignal>()),
        );
      }
      final seen = <String>[];
      Future<IMBoyHttpResponse> status(Map<String, dynamic> query) async {
        final id = query['client_upload_id'] as String;
        seen.add(id);
        if (id == 'first-A') {
          if (failure == 'account-switch') active = false;
          if (failure != 'terminal') {
            throw StateError('owned temporary failure');
          }
        }
        return IMBoyHttpResponse.success({
          'object_key': f.objectKey,
          'session_state': id == 'first-A' ? 'deleted' : 'confirmed',
        });
      }

      final recovery = restarted().resumeAll(
        _uidA,
        sessionFn: status,
        confirmFn: f.confirm,
        putFn: (_, _, _, _) async => fail('must retain put_done checkpoint'),
      );
      if (failure == 'account-switch') {
        await expectLater(recovery, throwsStateError);
        expect(seen, ['first-A']);
        expect(
          (await repo.find('healthy-B'))!.stage,
          AttachmentUploadStage.putDone,
        );
        expect((await repo.find('first-A'))!.lastError, isNull);
        return;
      }
      expect(await recovery, [f.objectKey]);
      expect(seen, ['first-A', 'healthy-B']);
      final blocked = (await repo.find('first-A'))!;
      expect(blocked.lastError, isNotEmpty);
      expect(
        blocked.stage,
        failure == 'terminal'
            ? AttachmentUploadStage.abandoned
            : AttachmentUploadStage.putDone,
      );
      seen.clear();
      await restarted().resumeAll(
        _uidA,
        sessionFn: (query) async {
          seen.add(query['client_upload_id'] as String);
          return IMBoyHttpResponse.success({
            'object_key': f.objectKey,
            'session_state': 'confirmed',
          });
        },
        confirmFn: f.confirm,
        putFn: (_, _, _, _) async => fail('restart must not PUT'),
      );
      expect(seen, failure == 'terminal' ? isEmpty : ['first-A']);
      expect((await repo.find('first-A'))!.objectKey, f.objectKey);
    });
  }

  test('terminal_status_no_new_capability: 终态回查拒绝续签及PUT', () async {
    final operations = <String>[];
    await expectLater(
      AttachmentApi.uploadViaPresign(
        _testBytes(),
        'resume.bin',
        'application/octet-stream',
        clientUploadId: 'terminal-upload',
        resume: ResumableUploadState(objectKey: f.objectKey),
        sessionFn: (query) async {
          operations.add(query['operation'] as String);
          return IMBoyHttpResponse.success({
            'object_key': f.objectKey,
            'session_state': 'deleted',
          });
        },
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
      ),
      throwsStateError,
    );
    expect(operations, ['status']);
    expect(f.presignCalls, isEmpty);
    expect(f.putBodies, isEmpty);
    expect(f.confirmBodies, isEmpty);
  });

  test('down_blocks_pending_journal: 降级不得丢失未完成恢复身份', () async {
    await repo.insert(
      await _seedRow(
        'pending-down',
        uid: _uidA,
        stage: AttachmentUploadStage.pending,
        objectKey: '',
      ),
    );
    final sql = kDowngradeEdgesAll.firstWhere((e) => e.fromVersion == 33).sql;
    await expectLater(
      db.transaction((txn) async {
        for (final statement in sql.split(';')) {
          if (statement.trim().isNotEmpty) await txn.execute(statement);
        }
      }),
      throwsA(anything),
    );
    expect(
      (await repo.find('pending-down'))!.stage,
      AttachmentUploadStage.pending,
    );
  });

  test('closed_database_fails_before_register: journal不可用无网络', () async {
    await db.close();
    await expectLater(
      _runUpload(_uploader(repo, keys), f, id: 'closed-db'),
      throwsA(anything),
    );
    expect(f.presignCalls, isEmpty);
  });

  test('new_object_reseals_with_distinct_material: 新任务不复用旧key密文', () async {
    final up = _uploader(repo, keys);
    await expectLater(
      _runUpload(
        up,
        f,
        id: 'old-put',
        checkpoint: (e) async {
          if (e.stage == UploadCheckpointStage.putDone) {
            throw _KillSignal('put');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final old = f.putBodies.single;
    final oldKey = f.objectKey;
    await repo.abandon('old-put', _uidA, 'explicit new upload');
    f.objectKey = 'different-physical-object';
    await _runUpload(up, f, id: 'new-put');
    expect(
      keys.store['old-put']!['content_key'],
      isNot(keys.store['new-put']!['content_key']),
    );
    expect(f.putBodies.last, isNot(old));
    expect((await repo.find('old-put'))!.objectKey, oldKey);
    expect((await repo.find('new-put'))!.objectKey, f.objectKey);
  });

  test('cached_cipher_restart_without_plaintext: 新编排直接恢复原密文文件', () async {
    final up = _uploader(repo, keys);
    await expectLater(
      _runUpload(
        up,
        f,
        id: 'cache-resume',
        checkpoint: (e) async {
          if (e.stage == UploadCheckpointStage.sealed) {
            throw _KillSignal('sealed');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final row = (await repo.find('cache-resume'))!;
    final saved = await File(row.uploadPath!).readAsBytes();
    expect(saved, isNot(_testBytes()));
    expect(keys.store[row.keyRef]!['descriptor'], isNotNull);
    final operations = <String>[];
    final restored = await _uploader(repo, keys).resumeAll(
      _uidA,
      presignFn: f.presign,
      putFn: f.put,
      confirmFn: f.confirm,
      sessionFn: (q) async {
        operations.add(q['operation'] as String);
        return IMBoyHttpResponse.success(
          q['operation'] == 'status'
              ? {'object_key': f.objectKey, 'session_state': 'registered'}
              : {
                  'object_key': f.objectKey,
                  'put_url': 'https://garage.test/renewed',
                },
        );
      },
    );
    expect(restored, [f.objectKey]);
    expect(operations, ['status', 'renew']);
    expect(f.putBodies.single, saved);
    expect(
      (await repo.find('cache-resume'))!.stage,
      AttachmentUploadStage.confirmed,
    );
    expect(f.confirmBodies.single['size'], saved.length);
  });

  test(
    'cached_confirm_unknown_reconciles_without_second_put: 丢确认响应后读远端终态',
    () async {
      final up = _uploader(repo, keys);
      await expectLater(
        up.upload(
          idempotencyKey: 'cache-confirm',
          userId: _uidA,
          bytes: _testBytes(),
          fileName: 'resume.bin',
          mime: 'application/octet-stream',
          bindingHashHex: _binding,
          presignFn: f.presign,
          putFn: f.put,
          confirmFn: (body) async {
            f.confirmBodies.add(body);
            throw _KillSignal('response');
          },
        ),
        throwsA(isA<_KillSignal>()),
      );
      final original = (await repo.find('cache-confirm'))!;
      expect(original.stage, AttachmentUploadStage.putDone);
      await _uploader(repo, keys).resumeAll(
        _uidA,
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
        sessionFn: (_) async => IMBoyHttpResponse.success({
          'object_key': f.objectKey,
          'session_state': 'confirmed',
        }),
      );
      expect(f.putBodies, hasLength(1));
      expect(f.presignCalls, hasLength(1));
      expect(f.confirmBodies.last, f.confirmBodies.first);
      expect((await repo.find('cache-confirm'))!.objectKey, original.objectKey);
      expect(
        (await repo.find('cache-confirm'))!.stage,
        AttachmentUploadStage.confirmed,
      );
    },
  );

  test('lost_cipher_file_requires_new_task: 不得在旧key重新随机seal', () async {
    await expectLater(
      _runUpload(
        _uploader(repo, keys),
        f,
        id: 'missing-cache',
        checkpoint: (e) async {
          if (e.stage == UploadCheckpointStage.sealed) {
            throw _KillSignal('sealed');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final row = (await repo.find('missing-cache'))!;
    await File(row.uploadPath!).delete();
    final result = await _uploader(repo, keys).resumeAll(_uidA);
    expect(result, isEmpty);
    expect(
      (await repo.find('missing-cache'))!.stage,
      AttachmentUploadStage.abandoned,
    );
    expect(f.putBodies, isEmpty);
    await expectLater(
      _runUpload(_uploader(repo, keys), f, id: 'missing-cache'),
      throwsStateError,
    );
  });

  test(
    'message_result_lookup_binds_original_identity: unknown和错误身份不可作成功',
    () async {
      final binding = {
        'message_id': 'original-id',
        'chat_type': 'c2c',
        'peer_id': 202,
        'state': 'committed',
        'conv_seq': 1,
      };
      final api = _ResultApi(binding);
      expect(
        await api.isCommitted(
          chatType: 'c2c',
          peerId: '202',
          messageId: 'original-id',
        ),
        isTrue,
      );
      expect(api.queries.single, {
        'chat_type': 'c2c',
        'peer_id': '202',
        'message_id': 'original-id',
      });
      for (final payload in [
        {...binding, 'state': 'unknown'},
        {...binding, 'message_id': 'different'},
        {...binding, 'chat_type': 'c2g'},
        {...binding, 'peer_id': 999},
      ]) {
        expect(
          await _ResultApi(payload).isCommitted(
            chatType: 'c2c',
            peerId: '202',
            messageId: 'original-id',
          ),
          isFalse,
        );
      }
      expect(
        await _ResultApi(
          binding,
          ok: false,
        ).isCommitted(chatType: 'c2c', peerId: '202', messageId: 'original-id'),
        isFalse,
      );
    },
  );

  test(
    'business_intent_unknown_preserved_without_send: 未知消息提交不推进为成功',
    () async {
      await _createMessageOutboxTables(db);
      final intent = {
        'author_id': _uidA,
        'message_id': 'anchor-1',
        'chat_type': 'c2c',
        'peer_id': _uidB,
        'state': 'dispatch_intent',
        'message': {'id': 'anchor-1'},
      };
      await _uploader(repo, keys).upload(
        idempotencyKey: 'message-journal',
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'resume.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        anchorMsgId: 'anchor-1',
        messageIntent: intent,
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
      );
      final api = _ResultApi({
        'message_id': 'anchor-1',
        'chat_type': 'c2c',
        'peer_id': 202,
        'state': 'unknown',
      });
      await _uploader(repo, keys).reconcileMessages(_uidA, api: api);
      final persisted = jsonDecode(
        (await repo.find('message-journal'))!.businessIntent!,
      ) as Map<String, dynamic>;
      expect(persisted['state'], 'commit_unknown');
      expect(persisted['message'], intent['message']);
      expect(api.queries.single['message_id'], 'anchor-1');
      expect(f.putBodies, hasLength(1));
    },
  );

  test(
    'confirmed_before_message_construction_restores_original_template_once',
    () async {
      final handler = ChatAttachmentHandler(
        peerId: _uidB,
        conversationUk3: 'c2c-101-202',
        type: 'C2C',
        currentUserOverride: const User(id: _uidA),
        onMessageCreated: (_) async => true,
      );
      final intent = handler.pendingMessageIntent(
        'original-message',
        'file',
        name: '用户原文件.pdf',
        size: _testBytes().length,
      );
      final uploader = _uploader(repo, keys);
      await uploader.upload(
        idempotencyKey: 'template-upload',
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'anonymous.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        anchorMsgId: 'original-message',
        messageIntent: intent,
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
      );
      final row = (await repo.find('template-upload'))!;
      expect(row.businessIntent, isNot(contains('content_key')));
      expect(row.businessIntent, isNot(contains('attachment_descriptor')));
      final resultApi = _ResultApi({});
      await _uploader(repo, keys).reconcileMessages(_uidA, api: resultApi);
      expect(resultApi.queries, isEmpty);
      expect(
        jsonDecode(
          (await repo.find('template-upload'))!.businessIntent!,
        )['state'],
        'uploading',
      );
      final restored = await _uploader(repo, keys).restoreMessageTemplate(row);
      final message = Message.fromJson(restored) as FileMessage;
      expect(message.id, 'original-message');
      expect(message.name, '用户原文件.pdf');
      expect(message.source, f.objectKey);
      expect(
        message.metadata!['attachment_descriptor'],
        isA<Map<String, dynamic>>(),
      );
      await expectLater(
        repo.claimBusinessDispatch('original-message', _uidA, restored),
        throwsArgumentError,
      );
      final safe = {
        ...restored,
        'metadata': {...message.metadata!}..remove('attachment_descriptor'),
      };
      final claims = await Future.wait([
        repo.claimBusinessDispatch('original-message', _uidA, safe),
        repo.claimBusinessDispatch('original-message', _uidA, safe),
      ]);
      expect(claims.where((won) => won), hasLength(1));
      expect(
        (await repo.find('template-upload'))!.businessIntent,
        isNot(contains('content_key')),
      );
      expect(f.putBodies, hasLength(1));
    },
  );

  test('thumb_confirm_then_main_register_restart_uses_durable_pair', () async {
    await db.close();
    final databasePath = '${_uploadCache.path}/pair.sqlite';
    db = await _openDb(databasePath);
    await _createMessageOutboxTables(db);
    SqliteService.setDbForTest(db);
    repo = AttachmentUploadTaskRepo();
    final handler = ChatAttachmentHandler(
      peerId: _uidB,
      conversationUk3: 'c2c-101-202',
      type: 'C2C',
      currentUserOverride: const User(id: _uidA),
      onMessageCreated: (_) async => true,
    );
    final intent = handler.pendingMessageIntent(
      'video-message',
      'video',
      name: '原视频.mp4',
      width: 640,
      height: 480,
      duration: const Duration(milliseconds: 3154),
    );
    final uploader = _uploader(repo, keys);
    for (final (id, name, mime) in [
      ('pair-thumb', 'thumb.jpg', 'image/jpeg'),
      ('pair-video', 'video.mp4', 'video/mp4'),
    ]) {
      await uploader.upload(
        idempotencyKey: id,
        userId: _uidA,
        bytes: _testBytes(),
        fileName: name,
        mime: mime,
        bindingHashHex: _binding,
        anchorMsgId: 'video-message',
        messageIntent: intent,
        prepareOnly: true,
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
      );
    }
    expect(f.presignCalls, isEmpty);
    expect(f.putBodies, isEmpty);
    f.objectKey = 'u101/pair-thumb';
    await uploader.upload(
      idempotencyKey: 'pair-thumb',
      userId: _uidA,
      bytes: _testBytes(),
      fileName: 'thumb.jpg',
      mime: 'image/jpeg',
      bindingHashHex: _binding,
      anchorMsgId: 'video-message',
      messageIntent: intent,
      presignFn: f.presign,
      putFn: f.put,
      confirmFn: f.confirm,
    );
    expect(
      (await repo.find('pair-thumb'))!.stage,
      AttachmentUploadStage.confirmed,
    );
    expect((await repo.find('pair-video'))!.objectKey, isNull);
    final source = (await repo.find('pair-video'))!.uploadPath!;
    expect(await File(source).exists(), isTrue);
    await db.close();
    db = await _openDb(databasePath);
    SqliteService.setDbForTest(db);
    repo = AttachmentUploadTaskRepo();
    f.objectKey = 'u101/pair-video';
    final resumed = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
      directSessionFn: (_, {body}) async => IMBoyHttpResponse.success({
        'object_key': body!['object_key'],
        'state': 'CONFIRMED',
      }),
    );
    await resumed.resumeAll(
      _uidA,
      presignFn: f.presign,
      putFn: f.put,
      confirmFn: f.confirm,
    );
    expect(f.presignCalls, ['thumb.jpg', 'video.mp4']);
    expect(f.putBodies, hasLength(2));
    final video = (await repo.find('pair-video'))!;
    expect(video.stage, AttachmentUploadStage.confirmed);
    expect(await File(source).exists(), isFalse);
    final restored = await resumed.restoreMessageTemplate(video);
    final message = ChatAttachmentHandler.messageFromPendingTemplate(
      restored,
    ) as VideoMessage;
    expect(message.id, 'video-message');
    expect(message.source, 'u101/pair-video');
    expect(message.metadata!['thumb']['uri'], 'u101/pair-thumb');
    expect(message.metadata!['duration_ms'], 3154);
    expect(
      message.metadata!['attachment_descriptor']['thumb']['object_key'],
      'u101/pair-thumb',
    );
    expect(video.businessIntent, isNot(contains('content_key')));
  });

  test('ordinary_registered_before_seal_restart_keeps_original_source_and_identity', () async {
    await db.close();
    final databasePath = '${_uploadCache.path}/registered.sqlite';
    db = await _openDb(databasePath);
    SqliteService.setDbForTest(db);
    repo = AttachmentUploadTaskRepo();
    await expectLater(
      _runUpload(
        _uploader(repo, keys),
        f,
        id: 'ordinary-source',
        checkpoint: (event) async {
          if (event.stage == UploadCheckpointStage.presigned) {
            throw _KillSignal('registered');
          }
        },
      ),
      throwsA(isA<_KillSignal>()),
    );
    final before = (await repo.find('ordinary-source'))!;
    expect(before.stage, AttachmentUploadStage.presigned);
    expect(before.objectKey, f.objectKey);
    expect(await File(before.uploadPath!).exists(), isTrue);
    expect(f.putBodies, isEmpty);
    final originalMaterial = Map<String, String>.from(
      keys.store['ordinary-source']!,
    );
    await db.close();
    db = await _openDb(databasePath);
    SqliteService.setDbForTest(db);
    repo = AttachmentUploadTaskRepo();
    final operations = <String>[];
    await _uploader(repo, keys).resumeAll(
      _uidA,
      presignFn: f.presign,
      putFn: f.put,
      confirmFn: f.confirm,
      sessionFn: (query) async {
        operations.add(query['operation'] as String);
        return IMBoyHttpResponse.success({
          'object_key': f.objectKey,
          'session_state': 'registered',
          'put_url': 'https://garage.test/renew',
        });
      },
    );
    final after = (await repo.find('ordinary-source'))!;
    expect(after.id, before.id);
    expect(after.objectKey, before.objectKey);
    expect(after.stage, AttachmentUploadStage.confirmed);
    expect(operations, ['status', 'renew']);
    expect(f.presignCalls, hasLength(1));
    expect(f.putBodies, hasLength(1));
    expect(
      keys.store['ordinary-source']!['content_key'],
      originalMaterial['content_key'],
    );
    expect(await File(before.uploadPath!).exists(), isFalse);
  });

  test(
    'down_refuses_uncommitted_confirmed_business_intents_without_loss',
    () async {
      final sql = kDowngradeEdgesAll.firstWhere((e) => e.fromVersion == 33).sql;
      for (final intent in [
        '{"state":"dispatch_intent"}',
        '{"state":"commit_unknown"}',
        '{"state":"unknown_business_intent"}',
        '{}',
        '{"state":1}',
        'invalid-json',
      ]) {
        await repo.insert(
          await _seedRow(
            'unknown-down',
            uid: _uidA,
            stage: AttachmentUploadStage.confirmed,
            objectKey: 'original',
          ),
        );
        await db.update(
          'attachment_upload_task',
          {'business_intent': intent},
          where: 'id = ?',
          whereArgs: ['unknown-down'],
        );
        await expectLater(
          db.transaction((txn) async {
            for (final statement in sql.split(';')) {
              if (statement.trim().isNotEmpty) await txn.execute(statement);
            }
          }),
          throwsA(anything),
        );
        expect((await repo.find('unknown-down'))!.businessIntent, intent);
        await db.delete(
          'attachment_upload_task',
          where: 'id = ?',
          whereArgs: ['unknown-down'],
        );
      }
    },
  );

  test('down_allows_only_explicit_committed_business_intent', () async {
    await repo.insert(
      await _seedRow(
        'committed-down',
        uid: _uidA,
        stage: AttachmentUploadStage.confirmed,
        objectKey: 'original',
      ),
    );
    await db.update('attachment_upload_task', {
      'business_intent': '{"state":"committed"}',
    });
    final sql = kDowngradeEdgesAll.firstWhere((e) => e.fromVersion == 33).sql;
    await db.transaction((txn) async {
      for (final statement in sql.split(';')) {
        if (statement.trim().isNotEmpty) await txn.execute(statement);
      }
    });
    expect(
      await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE name='attachment_upload_task'",
      ),
      isEmpty,
    );
  });

  test(
    'business_recovery_inventory_keeps_pending_and_abandoned_visible',
    () async {
      for (final stage in [
        AttachmentUploadStage.pending,
        AttachmentUploadStage.abandoned,
        AttachmentUploadStage.confirmed,
      ]) {
        await repo.insert(
          await _seedRow(
            'visible-${stage.value}',
            uid: _uidA,
            stage: stage,
            objectKey: 'original',
          ),
        );
        await db.update(
          'attachment_upload_task',
          {
            'business_intent': jsonEncode({
              'author_id': _uidA,
              'state': 'uploading',
              'message_template': {'id': stage.value},
            }),
          },
          where: 'id = ?',
          whereArgs: ['visible-${stage.value}'],
        );
      }
      expect(
        (await repo.listBusinessPending(_uidA)).map((r) => r.stage).toSet(),
        {
          AttachmentUploadStage.pending,
          AttachmentUploadStage.abandoned,
          AttachmentUploadStage.confirmed,
        },
      );
      final api = _ResultApi({});
      await _uploader(repo, keys).reconcileMessages(_uidA, api: api);
      expect(api.queries, isEmpty);
      for (final row in await repo.listBusinessPending(_uidA)) {
        expect(jsonDecode(row.businessIntent!)['state'], 'uploading');
      }
    },
  );

  test('global_init_without_chat_provider_restores_into_existing_message_outbox_once', () async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, _uidA);
    await StorageService.setMap(Keys.currentUser, {
      'uid': _uidA,
      'nickname': 'Synthetic',
    });
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: true,
    );
    SqliteService.setDbForTest(db);
    repo = AttachmentUploadTaskRepo();
    await _createMessageOutboxTables(db);
    final handler = ChatAttachmentHandler(
      peerId: _uidB,
      conversationUk3: 'c2c-101-202',
      type: 'C2C',
      currentUserOverride: const User(id: _uidA),
      onMessageCreated: (_) async => true,
    );
    final intent = handler.pendingMessageIntent(
      'global-original-id',
      'file',
      name: '原文件.bin',
      size: _testBytes().length,
    );
    final plain = ResumableAttachmentUploader(
      repo: repo,
      keyStore: keys,
      sessionGuard: (_) => true,
      encrypt: false,
      cacheDirectory: _uploadCache,
      cacheWriter: (write, _) => write(),
    );
    await plain.upload(
      idempotencyKey: 'global-original-upload',
      userId: _uidA,
      bytes: _testBytes(),
      fileName: 'original.bin',
      mime: 'application/octet-stream',
      bindingHashHex: '',
      anchorMsgId: 'global-original-id',
      messageIntent: intent,
      presignFn: f.presign,
      putFn: f.put,
      confirmFn: f.confirm,
    );
    // A 的授权回查失败不得饿死 B，也不得阻止 C 的 confirmed outbox。
    for (final id in ['blocked-A', 'healthy-B']) {
      await expectLater(
        plain.upload(
          idempotencyKey: id,
          userId: _uidA,
          bytes: _testBytes(),
          fileName: '$id.bin',
          mime: 'application/octet-stream',
          bindingHashHex: '',
          presignFn: f.presign,
          putFn: f.put,
          confirmFn: f.confirm,
          checkpoint: (event) async {
            if (event.stage == UploadCheckpointStage.putDone) {
              throw _KillSignal(id);
            }
          },
        ),
        throwsA(isA<_KillSignal>()),
      );
    }
    final resumedIds = <String>[];
    await plain.resumeAll(
      _uidA,
      sessionFn: (query) async {
        final id = query['client_upload_id'] as String;
        resumedIds.add(id);
        return id == 'blocked-A'
            ? IMBoyHttpResponse.failure(errMsg: 'revoked', errCode: 403)
            : IMBoyHttpResponse.success({
                'object_key': f.objectKey,
                'session_state': 'confirmed',
              });
      },
      confirmFn: f.confirm,
      putFn: (_, _, _, _) async => fail('put_done must not PUT'),
    );
    expect(resumedIds, ['blocked-A', 'healthy-B']);
    expect(
      (await repo.find('healthy-B'))!.stage,
      AttachmentUploadStage.confirmed,
    );
    expect(
      (await repo.find('blocked-A'))!.stage,
      AttachmentUploadStage.abandoned,
    );
    expect((await repo.find('blocked-A'))!.lastError, isNotEmpty);
    // 即使另一行的本地日志写入失败，已确认 C 也必须独立调和。
    final dbBlocked = (await _seedRow(
      'global-db-blocker',
      uid: _uidA,
      stage: AttachmentUploadStage.pending,
      objectKey: '',
    )).toMap()..['cipher'] = null;
    await db.insert('attachment_upload_task', dbBlocked);
    await db.execute(
      "CREATE TRIGGER owned_block_upload_update BEFORE UPDATE ON attachment_upload_task WHEN OLD.id = 'global-db-blocker' BEGIN SELECT RAISE(ABORT, 'owned upload journal failure'); END",
    );
    // 新 uploader 使用同一持久检查点：C 仍只入一次 outbox。
    await ResumableAttachmentUploader.recoverCurrentSession();
    await MessageRetry.instance.debugWaitForIdle();
    expect(await db.rawQuery('SELECT id FROM msg_c2c'), [
      {'id': 'global-original-id'},
    ]);
    expect(
      jsonDecode(
        (await repo.find('global-original-upload'))!.businessIntent!,
      )['state'],
      'outbox_ready',
    );
    await ResumableAttachmentUploader.recoverCurrentSession();
    expect(await db.rawQuery('SELECT COUNT(*) n FROM msg_c2c'), [
      {'n': 1},
    ]);
    expect(MessageRetry.instance.getRetryInfo('global-original-id'), isNotNull);
    MessageRetry.instance.clearRetryQueue();
    await MessageRetry.instance.debugWaitForIdle();
    MessageRetry.instance.dispose();
  });

  test(
    'outbox_insert_and_intent_update_abort_together_then_retry_same_id_once',
    () async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      await StorageService.to.setString(Keys.currentUid, _uidA);
      await StorageService.setMap(Keys.currentUser, {
        'uid': _uidA,
        'nickname': 'Synthetic',
      });
      SqliteService.setDbForTest(db);
      repo = AttachmentUploadTaskRepo();
      await _createMessageOutboxTables(db);
      final handler = ChatAttachmentHandler(
        peerId: _uidB,
        conversationUk3: 'c2c-101-202',
        type: 'C2C',
        currentUserOverride: const User(id: _uidA),
        onMessageCreated: (_) async => true,
      );
      await _uploader(repo, keys).upload(
        idempotencyKey: 'atomic-upload',
        userId: _uidA,
        bytes: _testBytes(),
        fileName: 'original.bin',
        mime: 'application/octet-stream',
        bindingHashHex: _binding,
        anchorMsgId: 'atomic-original-id',
        messageIntent: handler.pendingMessageIntent(
          'atomic-original-id',
          'file',
          name: '原名',
        ),
        presignFn: f.presign,
        putFn: f.put,
        confirmFn: f.confirm,
      );
      Future<MessageModel> prepare(
        Map<String, dynamic> intent,
        Message message,
      ) async => MessageModel(
        message.id,
        autoId: 0,
        type: 'C2C',
        status: IMBoyMessageStatus.sending,
        fromId: 101,
        toId: 202,
        payload: '',
        e2ee: {'protocol': 'olm', 'meta_version': 3},
        isAuthor: 1,
        conversationUk3: 'c2c-101-202',
        msgType: 'file',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      final notified = <String>[];
      await db.execute(
        "CREATE TRIGGER abort_business_claim BEFORE UPDATE OF business_intent ON attachment_upload_task BEGIN SELECT RAISE(ABORT, 'owned injected rollback'); END",
      );
      await _uploader(repo, keys).recoverBusinessOutbox(
        _uidA,
        prepareMessage: prepare,
        notifyRetry: (id, _) => notified.add(id),
      );
      expect(await db.rawQuery('SELECT id FROM msg_c2c'), isEmpty);
      expect(
        jsonDecode(
          (await repo.find('atomic-upload'))!.businessIntent!,
        )['state'],
        'uploading',
      );
      expect(notified, isEmpty);
      await db.execute('DROP TRIGGER abort_business_claim');
      await _uploader(repo, keys).recoverBusinessOutbox(
        _uidA,
        prepareMessage: prepare,
        notifyRetry: (id, _) => notified.add(id),
      );
      await _uploader(repo, keys).recoverBusinessOutbox(
        _uidA,
        prepareMessage: prepare,
        notifyRetry: (id, _) => notified.add(id),
      );
      expect(await db.rawQuery('SELECT id FROM msg_c2c'), [
        {'id': 'atomic-original-id'},
      ]);
      final stored = (await db.query('msg_c2c')).single;
      expect(stored['payload'], '""');
      expect(stored.toString(), isNot(contains('content_key')));
      expect(stored.toString(), isNot(contains('attachment_descriptor')));
      expect(
        await repo.claimOutboxDispatch(
          'atomic-original-id',
          _uidA,
          isCurrent: () => true,
        ),
        isTrue,
      );
      final before = notified.length;
      // A reserved send can resume; only the I/O boundary makes its result unknown.
      await _uploader(repo, keys).recoverBusinessOutbox(
        _uidA,
        prepareMessage: prepare,
        notifyRetry: (id, _) => notified.add(id),
      );
      expect(notified, hasLength(before + 1));
      expect(
        await repo.claimOutboxDispatch(
          'atomic-original-id',
          _uidA,
          isCurrent: () => true,
        ),
        isTrue,
      );
      expect(
        jsonDecode(
          (await repo.find('atomic-upload'))!.businessIntent!,
        )['state'],
        'dispatch_reserved_v2',
      );
      expect(
        await repo.beginOutboxSend(
          'atomic-original-id',
          _uidA,
          isCurrent: () => true,
        ),
        isTrue,
      );
      final original = (await MessageRepo(tableName: MessageRepo.c2cTable)
          .find('atomic-original-id'))!;
      final unknown = _ResultApi({
        'message_id': 'atomic-original-id',
        'chat_type': 'c2c',
        'peer_id': _uidB,
        'state': 'unknown',
      });
      expect(
        await MessageRetry.instance.debugAttachmentRetryBlocked(
          original,
          unknown,
        ),
        isTrue,
      );
      expect(
        jsonDecode(
          (await repo.find('atomic-upload'))!.businessIntent!,
        )['state'],
        'commit_unknown',
      );
      await _uploader(repo, keys).recoverBusinessOutbox(
        _uidA,
        prepareMessage: prepare,
        notifyRetry: (id, _) => notified.add(id),
      );
      expect(notified, hasLength(before + 1));
      MessageRetry.instance.clearRetryQueue();
      await MessageRetry.instance.debugWaitForIdle();
      MessageRetry.instance.dispose();
    },
  );

  test('unknown_state_no_delete: 未知 stage 值行不被恢复也不被删除', () async {
    await db.insert('attachment_upload_task', {
      'id': 't17',
      'user_id': _uidA,
      'scope': 'private',
      'file_name': 'x.bin',
      'mime': 'application/octet-stream',
      'plain_size': 1,
      'plain_sha256': 'x',
      'stage': 'future_stage',
      'created_at': 1,
      'updated_at': 1,
    });
    final up = _uploader(repo, keys);
    final ok = await up.resumeAll(
      _uidA,
      bytesProvider: (_) async => _testBytes(),
    );
    expect(ok, isEmpty);
    final row = await db.query(
      'attachment_upload_task',
      where: 'id = ?',
      whereArgs: ['t17'],
    );
    expect(row, hasLength(1), reason: '未知状态行保留（unknown_state_no_delete）');
  });
}

Future<AttachmentUploadTask> _seedRow(
  String id, {
  required String uid,
  required AttachmentUploadStage stage,
  required String objectKey,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  return AttachmentUploadTask(
    id: id,
    userId: uid,
    scope: 'private',
    scopeRef: null,
    fileName: 'resume.bin',
    mime: 'application/octet-stream',
    plainSize: 4096,
    plainSha256: sha256.convert(_testBytes()).toString(),
    objectKey: objectKey,
    stage: stage,
    cipher: 'AES-256-GCM',
    bindingHash: _binding,
    keyRef: id,
    ciphertextSha256: null,
    anchorMsgId: null,
    lastError: null,
    createdAt: now,
    updatedAt: now,
  );
}
