@TestOn('chrome')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/store/api/attachment_direct_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/upload/resumable_attachment_uploader.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/env_field.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/browser_sqlite_storage_bridge_web.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqflite.dart' as common;
import 'package:web/web.dart' as web;

import '../../env_test_pin.dart';

const _binding =
    'aa1122334455667788990011223344556677889900112233445566778899aabb';
const _id = '20000000-0000-4000-8000-000000000001';
const _missingId = '20000000-0000-4000-8000-000000000002';

// Only key plugin I/O and remote control/PUT are fixtures. No owner override,
// injected DB, custom schema, barrier callback or alternative state machine.
class _Keys implements UploadKeyStore {
  final values = <String, Map<String, String>>{};
  int writes = 0;
  @override
  Future<void> write(String ref, Map<String, String> material) async {
    writes++;
    values[ref] = Map.of(material);
  }

  @override
  Future<Map<String, String>?> read(String ref) async => values[ref];
}

class _EndpointChange implements Env, EnvField {
  @override
  String get apiBaseUrl => 'http://127.0.0.1:9801';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BeforePut implements Exception {}

class _Fixture {
  _Fixture(this.uid)
    : owner = AccountLocalTaskOwner.capture(),
      generation = UserRepoLocal.to.sessionGeneration;
  final AccountLocalTaskOwner owner;
  final int generation;
  final String uid;
  final repo = AttachmentUploadTaskRepo();
  final keys = _Keys();
  final events = <String>[];
  Uint8List? uploaded;
  bool stopAtGrant = true;
  String activeId = _id;
  Uint8List get bytes =>
      Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));
  String get anchor => 'synthetic-web-$activeId';
  String get objectKey => 'u$uid/web-material/$activeId';
  BrowserAttachmentMaterialStore store() =>
      BrowserAttachmentMaterialStore.forCurrentBrowserSession(repo);
  bool current() =>
      UserRepoLocal.to.currentUid == uid &&
      UserRepoLocal.to.isCurrentSession(generation) &&
      AccountLocalTaskOwner.capture() == owner &&
      !UserRepoLocal.to.isAuthTransitioning;

  ResumableAttachmentUploader uploader({
    BrowserAttachmentMaterialStore? bound,
    bool realPut = false,
    CancelToken? cancel,
    DirectSessionFn? control,
  }) => ResumableAttachmentUploader(
    repo: repo,
    keyStore: keys,
    process: false,
    browserMaterialStore: bound,
    directSessionFn: control ?? session,
    cancelToken: cancel,
    directSourcePutFn: realPut
        ? null
        : (url, source, length, headers, {cancelToken, onProgress}) async {
            events.add('PUT');
            uploaded = Uint8List.fromList(
              await source
                  .openRead(cancelToken: cancelToken)
                  .expand((chunk) => chunk)
                  .toList(),
            );
            expect(uploaded, hasLength(length));
            final checksum = base64Encode(sha256.convert(uploaded!).bytes);
            expect(headers['x-amz-checksum-sha256'], checksum);
          },
  );

  Future<String> start(ResumableAttachmentUploader uploader) => uploader.upload(
    idempotencyKey: activeId,
    userId: uid,
    bytes: bytes,
    fileName: 'browser.bin',
    mime: 'application/octet-stream',
    bindingHashHex: _binding,
    anchorMsgId: anchor,
    messageIntent: {
      'author_id': uid,
      'peer_id': '2002',
      'chat_type': 'c2c',
      'expected_objects': 1,
      'state': 'uploading',
      'message_template': {'id': anchor},
    },
  );

  Future<IMBoyHttpResponse> session(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final action = path.split('/').last;
    events.add(action);
    if (action == 'register') {
      expect(body!['client_upload_id'], activeId);
      return IMBoyHttpResponse.success({
        'state': 'DECLARED',
        'object_key': objectKey,
      });
    }
    if (action == 'status') {
      return IMBoyHttpResponse.success({
        'state': 'DECLARED',
        'object_key': objectKey,
      });
    }
    if (action == 'declare') {
      return IMBoyHttpResponse.success({'state': 'DECLARED'});
    }
    if (action == 'grant') {
      if (stopAtGrant) throw _BeforePut();
      final task = (await repo.find(activeId))!;
      final hash = task.ciphertextSha256!;
      final checksum = base64Encode(
        List.generate(
          32,
          (i) => int.parse(hash.substring(i * 2, i * 2 + 2), radix: 16),
        ),
      );
      return IMBoyHttpResponse.success({
        'state': 'GRANTED',
        'attempt_id': 1,
        'grant': {
          'transport': 's3_put',
          'method': 'PUT',
          'url': 'https://storage.example/synthetic-put',
          'required_headers': [
            ['Content-Type', 'application/octet-stream'],
            ['x-amz-checksum-sha256', checksum],
          ],
        },
      });
    }
    if (action == 'finalize') {
      return IMBoyHttpResponse.success({'state': 'CONFIRMED'});
    }
    throw StateError('unexpected control action $action');
  }

  MessageModel message() => MessageModel(
    anchor,
    autoId: 0,
    type: 'C2C',
    status: IMBoyMessageStatus.delivered,
    fromId: uid,
    toId: '2002',
    payload: {'text': 'synthetic local outbox contract'},
    isAuthor: 1,
    conversationUk3: 'C2C_${uid}_2002',
    msgType: 'text',
    createdAt: 1794355200000,
  );
}

Future<_Fixture> _open() async {
  pinLoopbackTestEnv();
  final uid = DateTime.now().microsecondsSinceEpoch.toString();
  final owner = AccountLocalTaskOwner(
    uid: uid,
    environment: currentEnv,
    endpoint: Env().apiBaseUrl,
  );
  // Synthetic inventory, not evidence that real login established ownership.
  SharedPreferences.setMockInitialValues({
    Keys.currentUid: uid,
    Keys.currentUser: jsonEncode({'uid': uid}),
    LoginAccountHistoryService.storageKey: jsonEncode({
      'version': 1,
      'accounts': [
        LoginAccountIdentity(
          uid: uid,
          environment: owner.environment,
          endpoint: owner.endpoint,
          aliases: {uid},
          storageOwnershipVerified: true,
        ).toJson(),
      ],
    }),
  });
  await prepareWebWriter();
  await StorageService.init();
  expect(UserRepoLocal.to.isAuthTransitioning, isFalse);
  final db = await SqliteService.to.db;
  expect(db, isNotNull);
  expect(common.databaseFactory, same(browserSqliteStorageBridge.factory));
  expect((await db!.query('attachment_upload_task')), isEmpty);
  return _Fixture(uid);
}

Future<void> _close(_Fixture fixture) async {
  final db = await SqliteService.to.db;
  // enqueueBusinessOutbox creates its own MessageRepo and FTS task. A fresh
  // MessageRepo's test wait would not join that task. Revoke this synthetic
  // UID first, then drain the captured real handle before close; pending FTS
  // continuations use the production UID guard and cannot reopen it afterward.
  await StorageService.to.setString(Keys.currentUid, '');
  if (db != null && db.isOpen) await db.rawQuery('SELECT 1');
  await browserSqliteStorageBridge.durableBarrier();
  await SqliteService.to.close();
  // Exact production account deletion, never a namespace/origin clear.
  await SqliteService.to.deleteDatabaseForUid(
    fixture.uid,
    environment: currentEnv,
  );
  expect(
    await common.databaseFactory.databaseExists(
      '${currentEnv}_${fixture.uid}.db',
    ),
    isFalse,
  );
}

const _slowOrigin = String.fromEnvironment('W09_CANCEL_ORIGIN');
const _slowNonce = String.fromEnvironment('W09_CANCEL_NONCE');

// Existing runner-owned slow PUT; control responses remain synthetic.
class _SlowPut {
  _SlowPut(this.fixture);
  final _Fixture fixture;
  final id = List.generate(
    16,
    (_) => Random.secure().nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Future<(int, String)> request(String path, {String method = 'GET'}) async {
    final controller = web.AbortController();
    Future<(int, String)> execute() async {
      final response = await web.window
          .fetch(
            '$_slowOrigin$path'.toJS,
            web.RequestInit(method: method, signal: controller.signal),
          )
          .toDart;
      return (response.status, (await response.text().toDart).toDart);
    }

    try {
      return await execute().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          controller.abort();
          throw TimeoutException('owned PUT fixture timeout');
        },
      );
    } catch (_) {
      controller.abort();
      throw StateError('owned PUT fixture request failed');
    }
  }

  Future<void> verify() async {
    final uri = Uri.tryParse(_slowOrigin);
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.host != '127.0.0.1' ||
        !uri.hasPort ||
        uri.path.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(_slowNonce)) {
      throw StateError('owned PUT fixture configuration missing');
    }
    final (status, body) = await request('/identity?nonce=$_slowNonce');
    final identity = jsonDecode(body) as Map;
    expect(status, 200);
    expect(identity['fixture'], 'w09-slow-put-v1');
    expect(identity['nonce'] == _slowNonce, isTrue);
  }

  Future<Map<String, dynamic>> events() async {
    final (status, body) = await request('/events?case=$id&nonce=$_slowNonce');
    expect(status, 200);
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> wait(String key) async {
    final until = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(until)) {
      final value = await events();
      if (value[key] == true) return value;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('owned PUT fixture checkpoint missing');
  }

  Future<void> release({bool allowMissing = false}) async {
    final (status, _) = await request(
      '/release?case=$id&nonce=$_slowNonce',
      method: 'POST',
    );
    expect(status == 204 || (allowMissing && status == 404), isTrue);
  }

  Future<IMBoyHttpResponse> control(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await fixture.session(path, body: body);
    if (!path.endsWith('/grant')) return response;
    final payload = IMBoyHttpResponse.payloadAsMap(response.payload);
    return IMBoyHttpResponse.success({
      ...payload,
      'grant': {
        ...Map<String, dynamic>.from(payload['grant'] as Map),
        'url': '$_slowOrigin/put?case=$id&nonce=$_slowNonce',
      },
    });
  }
}

Future<void> _assertNoCanceledOutbox(_Fixture f, common.Database db) async {
  expect(f.events, isNot(contains('finalize')));
  final task = (await f.repo.find(f.activeId))!;
  expect(task.userId, f.uid);
  expect(task.stage, isNot(AttachmentUploadStage.confirmed));
  final intent = jsonDecode(task.businessIntent!) as Map;
  expect(intent['state'], 'uploading');
  expect(
    await f.repo.enqueueBusinessOutbox(
      f.message(),
      userId: f.uid,
      isCurrent: f.current,
    ),
    isFalse,
  );
  expect(
    await f.repo.claimOutboxDispatch(f.anchor, f.uid, isCurrent: f.current),
    isFalse,
  );
  for (final table in ['msg_c2c', 'msg_c2g']) {
    expect(
      await db.query(table, where: 'id = ?', whereArgs: [f.anchor]),
      isEmpty,
    );
  }
  final rows = await db.query('attachment_upload_task');
  expect(rows, hasLength(1));
  expect(rows.single['user_id'].toString(), f.uid);
}

Future<bool> _cleanupStep(String phase, Future<void> Function() cleanup) async {
  try {
    await cleanup();
    return true;
  } catch (_) {
    // The framework retains this failure independently of the body's exception.
    // Raw transport errors may contain the fixture nonce; never report them.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('ATT02 cleanup $phase failed; details redacted'),
        stack: StackTrace.current,
        library: 'ATT02 test cleanup',
      ),
    );
    return false;
  }
}

Future<void> _cleanupSlowPut(
  _Fixture f,
  _SlowPut slow,
  CancelToken cancel,
  Future<Object>? pending,
) async {
  cancel.cancel('test cleanup');
  await _cleanupStep('release', () => slow.release(allowMissing: true));
  final operationTerminated =
      pending == null ||
      await _cleanupStep('pending', () async {
        await pending.timeout(const Duration(seconds: 8));
      });
  // A timeout does not cancel the Future: retain the DB if it is still live.
  if (operationTerminated) {
    await _cleanupStep('database', () => _close(f));
  }
}

Future<void> _cancelSlowPut(bool resume) async {
  final f = await _open();
  final db = (await SqliteService.to.db)!;
  final slow = _SlowPut(f);
  final cancel = CancelToken();
  Future<Object>? pending;
  try {
    await slow.verify();
    if (resume) {
      await expectLater(
        f.start(f.uploader(bound: f.store())),
        throwsA(isA<_BeforePut>()),
      );
      expect(
        (await f.repo.find(f.activeId))!.stage,
        AttachmentUploadStage.presigned,
      );
    }
    f.stopAtGrant = false;
    f.events.clear();
    final uploader = f.uploader(
      bound: f.store(),
      realPut: true,
      cancel: cancel,
      control: slow.control,
    );
    pending = (resume ? uploader.resumeAll(f.uid) : f.start(uploader))
        .then<Object>((value) => value, onError: (Object error) => error);
    await slow.wait('bodyEnded');
    cancel.cancel('synthetic user cancellation');
    expect(
      await pending.timeout(const Duration(seconds: 8)),
      anyOf(
        isA<StateError>(),
        isA<DirectUploadCancelled>(),
        isA<AccountLocalTaskCancelledException>(),
      ),
    );
    final closed = await slow.wait('closedBeforeResponse');
    expect(closed['responses'], 0);
    expect(closed['puts'], 1);
    await slow.release();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect((await slow.events())['puts'], 1);
    await _assertNoCanceledOutbox(f, db);
  } finally {
    await _cleanupSlowPut(f, slow, cancel, pending);
  }
}

Future<void> _completeSlowPut() async {
  final f = await _open();
  final db = (await SqliteService.to.db)!;
  final slow = _SlowPut(f);
  final cancel = CancelToken();
  Future<Object>? pending;
  try {
    await slow.verify();
    f.stopAtGrant = false;
    pending = f
        .start(
          f.uploader(
            bound: f.store(),
            realPut: true,
            cancel: cancel,
            control: slow.control,
          ),
        )
        .then<Object>((value) => value, onError: (Object error) => error);
    await slow.wait('bodyEnded');
    expect(await db.query('msg_c2c'), isEmpty);
    await slow.release();
    expect(await pending.timeout(const Duration(seconds: 8)), f.objectKey);
    expect(f.events.where((e) => e == 'finalize'), hasLength(1));
    expect(
      (await f.repo.find(f.activeId))!.stage,
      AttachmentUploadStage.confirmed,
    );
    for (var repeat = 0; repeat < 2; repeat++) {
      expect(
        await f.repo.enqueueBusinessOutbox(
          f.message(),
          userId: f.uid,
          isCurrent: f.current,
        ),
        isTrue,
      );
    }
    expect(
      await db.query('msg_c2c', where: 'id = ?', whereArgs: [f.anchor]),
      hasLength(1),
    );
    expect(
      jsonDecode((await f.repo.find(f.activeId))!.businessIntent!)['state'],
      'outbox_ready',
    );
  } finally {
    await _cleanupSlowPut(f, slow, cancel, pending);
  }
}

void main() {
  // ignore: avoid_print
  print('WEB_SQLITE_ORIGIN ${web.window.location.origin}');
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'cleanup failure preserves primary error and redacts diagnostics',
    (tester) async {
      final primary = StateError('synthetic primary failure');
      const sensitive = 'synthetic-fixture-nonce-never-report';
      bool? cleaned;
      Future<void> failingBody() async {
        try {
          throw primary;
        } finally {
          cleaned = await _cleanupStep('release', () async {
            throw StateError(sensitive);
          });
        }
      }

      await expectLater(failingBody(), throwsA(same(primary)));
      expect(cleaned, isFalse);
      final cleanupError = tester.takeException();
      expect(cleanupError, isA<StateError>());
      expect(cleanupError.toString(), contains('ATT02 cleanup release failed'));
      expect(cleanupError.toString(), isNot(contains(sensitive)));
      expect(tester.takeException(), isNull);
    },
  );
  for (final resume in [false, true]) {
    testWidgets(
      '${resume ? 'resume' : 'initial'} slow Fetch cancellation cannot commit real SQLite outbox',
      (tester) async {
        await tester.runAsync(() => _cancelSlowPut(resume));
      },
      timeout: const Timeout(Duration(seconds: 90)),
    );
  }
  testWidgets(
    'completed slow Fetch can commit one real SQLite outbox message',
    (tester) async {
      await tester.runAsync(_completeSlowPut);
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  testWidgets('real bridge bound Web materials and direct/outbox gates', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final f = await _open();
      try {
        // Even a no-op callback cannot masquerade as Web durability.
        final unbound = BrowserAttachmentMaterialStore(
          f.repo,
          durabilityBarrier: () async {},
        );
        await expectLater(
          f.start(f.uploader(bound: unbound)),
          throwsA(
            isA<BrowserMaterialException>().having(
              (e) => e.failure,
              'failure',
              BrowserMaterialFailure.durabilityUnavailable,
            ),
          ),
        );
        expect(await f.repo.find(_id), isNull);
        expect(f.keys.writes, 0);
        expect(f.events, isEmpty);

        final oldStore = f.store();
        await expectLater(
          f.start(f.uploader(bound: oldStore)),
          throwsA(isA<_BeforePut>()),
        );
        final before = (await f.repo.find(_id))!;
        final owner = AccountLocalTaskOwner.capture().storageDigest;
        final cached = await oldStore.read(before, owner, f.current);
        final keyBytes = jsonEncode(f.keys.values);
        final writeCount = f.keys.writes;
        expect(cached.kind, BrowserMaterialKind.upload);
        expect(cached.bytes, isNot(equals(f.bytes)));
        expect(before.id, _id);
        expect(before.anchorMsgId, f.anchor);
        expect(before.stage, AttachmentUploadStage.presigned);
        expect(
          await f.repo.enqueueBusinessOutbox(
            f.message(),
            userId: f.uid,
            isCurrent: f.current,
          ),
          isFalse,
        );
        expect(
          await f.repo.claimOutboxDispatch(
            f.anchor,
            f.uid,
            isCurrent: f.current,
          ),
          isFalse,
        );

        // Real transaction rollback. The barrier must reject, not deadlock.
        final db = (await SqliteService.to.db)!;
        await expectLater(
          db
              .transaction((tx) async {
                await tx.update(
                  'attachment_upload_task',
                  {'last_error': 'rollback'},
                  where: 'id = ?',
                  whereArgs: [_id],
                );
                await oldStore.ensureDurable();
              })
              .timeout(const Duration(seconds: 5)),
          throwsA(
            isA<BrowserMaterialException>().having(
              (e) => e.failure,
              'failure',
              BrowserMaterialFailure.storage,
            ),
          ),
        );
        expect((await f.repo.find(_id))!.lastError, before.lastError);
        await oldStore.ensureDurable();

        await SqliteService.to.close();
        await expectLater(
          oldStore.ensureDurable(),
          throwsA(
            isA<BrowserMaterialException>().having(
              (e) => e.failure,
              'failure',
              BrowserMaterialFailure.ownership,
            ),
          ),
        );
        final freshStore = f.store();
        await freshStore.ensureDurable();
        final reopened = (await f.repo.find(_id))!;
        final freshBytes = await freshStore.read(reopened, owner, f.current);
        expect(freshBytes.bytes, cached.bytes);
        expect(reopened.uploadPath, before.uploadPath);
        f.events.clear();
        f.stopAtGrant = false;
        expect(await f.uploader(bound: freshStore).resumeAll(f.uid), [
          f.objectKey,
        ]);
        expect(f.events.first, 'status');
        expect(f.events, contains('PUT'));
        expect(f.uploaded, cached.bytes);
        expect(jsonEncode(f.keys.values), keyBytes);
        expect(f.keys.writes, writeCount);
        final after = (await f.repo.find(_id))!;
        expect(after.stage, AttachmentUploadStage.confirmed);
        expect(after.id, before.id);
        expect(after.keyRef, before.keyRef);
        expect(after.objectKey, before.objectKey);
        expect(after.anchorMsgId, before.anchorMsgId);
        expect(after.ciphertextSha256, before.ciphertextSha256);
        expect(
          await f.repo.enqueueBusinessOutbox(
            f.message(),
            userId: f.uid,
            isCurrent: f.current,
          ),
          isTrue,
        );
        await freshStore.ensureDurable();
        expect(
          await f.repo.claimOutboxDispatch(
            f.anchor,
            f.uid,
            isCurrent: f.current,
          ),
          isTrue,
        );

        // Existing direct object + missing BLOB: status only, no fresh key/PUT.
        f.activeId = _missingId;
        f.stopAtGrant = true;
        await expectLater(
          f.start(f.uploader(bound: freshStore)),
          throwsA(isA<_BeforePut>()),
        );
        final missing = (await f.repo.find(_missingId))!;
        final keysBeforeMissing = jsonEncode(f.keys.values);
        await (await SqliteService.to.db)!.delete(
          BrowserAttachmentMaterialStore.tableName,
          where: 'task_id = ? AND user_id = ?',
          whereArgs: [_missingId, f.uid],
        );
        f.events.clear();
        f.stopAtGrant = false;
        expect(await f.uploader(bound: freshStore).resumeAll(f.uid), isEmpty);
        expect(f.events, ['status']);
        expect(
          (await f.repo.find(_missingId))!.stage,
          AttachmentUploadStage.abandoned,
        );
        expect(jsonEncode(f.keys.values), keysBeforeMissing);
        expect(missing.id, _missingId);
        expect(
          await f.repo.enqueueBusinessOutbox(
            f.message(),
            userId: f.uid,
            isCurrent: f.current,
          ),
          isFalse,
        );
        expect(
          await f.repo.claimOutboxDispatch(
            f.anchor,
            f.uid,
            isCurrent: f.current,
          ),
          isFalse,
        );

        final original = envMap[currentEnv]!;
        envMap[currentEnv] = _EndpointChange();
        try {
          await expectLater(
            freshStore.ensureDurable(),
            throwsA(
              isA<BrowserMaterialException>().having(
                (e) => e.failure,
                'failure',
                BrowserMaterialFailure.ownership,
              ),
            ),
          );
        } finally {
          envMap[currentEnv] = original;
        }
        await freshStore.ensureDurable();
      } catch (error, stack) {
        // ignore: avoid_print
        print('WEB_ATTACHMENT_MATERIALS_FAILURE $error\n$stack');
        rethrow;
      } finally {
        try {
          await _close(f);
        } catch (error, stack) {
          // ignore: avoid_print
          print('WEB_ATTACHMENT_MATERIALS_CLEANUP_FAILURE $error\n$stack');
          rethrow;
        }
      }
    });
  }, timeout: const Timeout(Duration(seconds: 90)));
}
