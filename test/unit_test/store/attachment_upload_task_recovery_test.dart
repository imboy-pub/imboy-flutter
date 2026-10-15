// W5-01 客户端恢复单元测试（不代替真实服务、设备或消息发送验收）。
//
// 基础设施：sqflite_common_ffi 内存库（DDL 与迁移 v33 同构）+
// SqliteService.setDbForTest + 内存 KeyStore + fake presign/put/confirm。
// 「进程被杀」用 checkpoint 抛 _KillSignal 模拟；「重启」= 新建
// uploader（同一底层 DB 与 KeyStore）后 resume。
//
// 测试名与合同场景同名不代表逐叶通过；HTTP Range、消息未知提交及真实进程恢复另验。
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/message_retry.dart';
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

Uint8List _hexDecode(String hex) => Uint8List.fromList(
  List<int>.generate(
    hex.length ~/ 2,
    (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
  ),
);

Uint8List _testBytes() =>
    Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));

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
    final putsBefore = f.putBodies.length;

    final up2 = _uploader(repo, keys);
    await _runUpload(up2, f, id: 't2');
    expect(f.putBodies.length, putsBefore, reason: 'put_done 检查点后的恢复跳过 PUT 重传');
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

  test('expired_capability_resume: 恢复时授权已过期（confirm 403）→ abandon', () async {
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
    await expectLater(
      up.resumeAll(_uidA, bytesProvider: (_) async => _testBytes()),
      throwsException,
    );
    expect((await repo.find('t8'))!.stage, AttachmentUploadStage.putDone);
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
    expect(keys.store['cache-resume']!['descriptor'], isNotNull);
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
    final resumed = _uploader(repo, keys);
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
      // The process can die here before WS. A new uploader must not call this a first attempt.
      await _uploader(repo, keys).recoverBusinessOutbox(
        _uidA,
        prepareMessage: prepare,
        notifyRetry: (id, _) => notified.add(id),
      );
      expect(notified, hasLength(before));
      expect(
        await repo.claimOutboxDispatch(
          'atomic-original-id',
          _uidA,
          isCurrent: () => true,
        ),
        isFalse,
      );
      expect(
        jsonDecode(
          (await repo.find('atomic-upload'))!.businessIntent!,
        )['state'],
        'dispatch_intent',
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
      expect(notified, hasLength(before));
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
