@TestOn('chrome')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrintSynchronously;
import 'package:material_ui/material_ui.dart';
import 'package:imboy/component/http/http_client.dart' as app_http;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/web_shell/web_attachment_input.dart';
import 'package:imboy/page/web_shell/web_group_composer_gate.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/browser_sqlite_storage_bridge_web.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/repository/attachment_upload_task_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;
import 'package:web/web.dart' as web;

import '../env_test_pin.dart';

final class _NoNetwork implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    throw StateError('Unexpected product HTTP');
  }

  @override
  void close({bool force = false}) {}
}

// The delegated query completes in the real database before its result is held.
final class _HeldQueryDb implements Database {
  _HeldQueryDb(this.delegate, this.whereToHold);
  final Database delegate;
  final String whereToHold;
  final entered = Completer<void>.sync();
  final release = Completer<void>.sync();
  final returned = Completer<void>.sync();
  bool armed = false;
  @override
  bool get isOpen => delegate.isOpen;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    debugPrintSynchronously(
      'RACE_PROXY query start table=$table where=$where armed=$armed target=$whereToHold',
    );
    final result = await delegate.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    debugPrintSynchronously(
      'RACE_PROXY query returned table=$table where=$where rows=${result.length}',
    );
    if (armed &&
        table == AttachmentUploadTaskRepo.tableName &&
        where == whereToHold &&
        !entered.isCompleted) {
      debugPrintSynchronously('RACE_PROXY query gated where=$where');
      entered.complete();
      await release.future;
      returned.complete();
      debugPrintSynchronously('RACE_PROXY query released where=$where');
    }
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'unexpected gated database operation: ${invocation.memberName}',
  );
}

// Synthetic discovery-only row. Real writer, ownership inventory and VFS barrier;
// no upload, server success, alternative DB, lease override or custom storage seam.
Future<String> _openPending({
  String state = 'uploading',
  bool includeOtherPending = false,
}) async {
  pinLoopbackTestEnv();
  final uid = DateTime.now().microsecondsSinceEpoch.toString();
  final owner = AccountLocalTaskOwner(
    uid: uid,
    environment: currentEnv,
    endpoint: Env().apiBaseUrl,
  );
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
  final repo = AttachmentUploadTaskRepo();
  const id = '30000000-0000-4000-8000-000000000001';
  final now = DateTime.now().millisecondsSinceEpoch;
  if (includeOtherPending) {
    const otherId = '30000000-0000-4000-8000-000000000002';
    expect(
      await repo.insert(
        AttachmentUploadTask(
          id: otherId,
          userId: uid,
          scope: 'group',
          scopeRef: '990001',
          fileName: 'other-pending.bin',
          mime: 'application/octet-stream',
          plainSize: 2,
          plainSha256: '11' * 32,
          objectKey: null,
          uploadPath: BrowserUploadMaterial.pending(
            owner.storageDigest,
            otherId,
          ),
          businessIntent: jsonEncode({
            'author_id': uid,
            'peer_id': '990001',
            'chat_type': 'c2g',
            'state': 'uploading',
            'expected_objects': 1,
          }),
          stage: AttachmentUploadStage.pending,
          cipher: null,
          bindingHash: null,
          keyRef: null,
          ciphertextSha256: null,
          anchorMsgId: 'other-anchor',
          lastError: null,
          createdAt: now - 1,
          updatedAt: now - 1,
        ),
      ),
      isTrue,
    );
  }
  expect(
    await repo.insert(
      AttachmentUploadTask(
        id: id,
        userId: uid,
        scope: 'group',
        scopeRef: '990001',
        fileName: 'pending.bin',
        mime: 'application/octet-stream',
        plainSize: 3,
        plainSha256: '00' * 32,
        objectKey: null,
        uploadPath: BrowserUploadMaterial.pending(owner.storageDigest, id),
        businessIntent: jsonEncode({
          'author_id': uid,
          'peer_id': '990001',
          'chat_type': 'c2g',
          'state': state,
          'expected_objects': includeOtherPending ? 2 : 1,
        }),
        stage: state == 'uploading'
            ? AttachmentUploadStage.pending
            : AttachmentUploadStage.confirmed,
        cipher: null,
        bindingHash: null,
        keyRef: null,
        ciphertextSha256: null,
        anchorMsgId: 'pending-anchor',
        lastError: null,
        createdAt: now,
        updatedAt: now,
      ),
    ),
    isTrue,
  );
  if (includeOtherPending) {
    const secondId = '30000000-0000-4000-8000-000000000003';
    expect(
      await repo.insert(
        AttachmentUploadTask(
          id: secondId,
          userId: uid,
          scope: 'group',
          scopeRef: '990001',
          fileName: 'pending-part-two.bin',
          mime: 'application/octet-stream',
          plainSize: 2,
          plainSha256: '22' * 32,
          objectKey: null,
          uploadPath: BrowserUploadMaterial.pending(
            owner.storageDigest,
            secondId,
          ),
          businessIntent: jsonEncode({
            'author_id': uid,
            'peer_id': '990001',
            'chat_type': 'c2g',
            'state': state,
            'expected_objects': 2,
          }),
          stage: AttachmentUploadStage.confirmed,
          cipher: null,
          bindingHash: null,
          keyRef: null,
          ciphertextSha256: null,
          anchorMsgId: 'pending-anchor',
          lastError: null,
          createdAt: now,
          updatedAt: now,
        ),
      ),
      isTrue,
    );
  }
  await BrowserAttachmentMaterialStore.forCurrentBrowserSession(repo)
      .ensureDurable();
  return uid;
}

Future<void> _close(String uid) async {
  await StorageService.to.setString(Keys.currentUid, '');
  await browserSqliteStorageBridge.durableBarrier();
  await SqliteService.to.close();
  await SqliteService.to.deleteDatabaseForUid(uid, environment: currentEnv);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'group permission ready discovers original pending before new selection',
    (tester) async {
      final uid = (await tester.runAsync(_openPending))!;
      final focus = FocusNode();
      final region = GlobalKey();
      var allowed = false;
      late StateSetter update;
      final pick = find.byKey(const ValueKey('web-attachment-file'));
      Future<void> pumpUntilPending() async {
        for (
          var i = 0;
          i < 50 && find.textContaining('pending.bin').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
      }

      try {
        await tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return WebGroupSendScope(
                      allowed: allowed,
                      capture: () =>
                          () => allowed,
                      child: Container(
                        key: region,
                        child: WebAttachmentInput(
                          key: const ValueKey('restore-composer'),
                          selection: const ChatSelection(
                            peerId: '990001',
                            chatType: 'C2G',
                          ),
                          currentUserId: uid,
                          isCurrent: () => true,
                          inputFocus: focus,
                          regionKey: region,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        expect(tester.widget<IconButton>(pick).onPressed, isNull);
        expect(find.textContaining('pending.bin'), findsNothing);
        update(() => allowed = true);
        await tester.pump();
        await pumpUntilPending();
        expect(find.textContaining('pending.bin'), findsOneWidget);
        expect(tester.widget<IconButton>(pick).onPressed, isNull);
        expect(find.widgetWithText(TextButton, t.common.retry), findsOneWidget);
        // Revocation cancels this view. A new ready boundary must query again.
        update(() => allowed = false);
        await tester.pump();
        expect(find.textContaining('pending.bin'), findsNothing);
        update(() => allowed = true);
        await tester.pump();
        await pumpUntilPending();
        expect(find.textContaining('pending.bin'), findsOneWidget);
        expect(tester.widget<IconButton>(pick).onPressed, isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        focus.dispose();
        await tester.runAsync(() => _close(uid));
      }
    },
  );
  for (final state in [
    'dispatch_intent',
    'commit_unknown',
    'unknown_business_intent',
  ]) {
    testWidgets('restores $state without offering upload retry', (
      tester,
    ) async {
      final uid = (await tester.runAsync(
        () => _openPending(state: state, includeOtherPending: true),
      ))!;
      final focus = FocusNode();
      final region = GlobalKey();
      final pick = find.byKey(const ValueKey('web-attachment-file'));
      final oldAdapter = app_http.HttpClient.adapterForTest;
      final noNetwork = _NoNetwork();
      app_http.HttpClient.adapterForTest = noNetwork;
      var peer = '990001';
      var currentUser = uid;
      late StateSetter update;
      Future<T?> checkedDb<T>(
        String step,
        Future<T> Function() operation,
      ) async {
        debugPrintSynchronously('DIAGNOSTIC $state db:$step start');
        try {
          return await tester.runAsync(
            () => operation().timeout(const Duration(seconds: 5)),
          );
        } finally {
          debugPrintSynchronously('DIAGNOSTIC $state db:$step end');
        }
      }

      Future<void> waitForLocalCheck(String step) async {
        debugPrintSynchronously('DIAGNOSTIC $state local:$step waiting');
        for (var i = 0; i < 200; i++) {
          final button = find.widgetWithText(
            TextButton,
            t.common.legacyUploadCheckLocal,
          );
          if (button.evaluate().isNotEmpty &&
              tester.widget<TextButton>(button).onPressed != null) {
            debugPrintSynchronously('DIAGNOSTIC $state local:$step ready');
            return;
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        fail('local check did not finish: $step');
      }

      try {
        await tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return WebGroupSendScope(
                      allowed: true,
                      capture: () =>
                          () => true,
                      child: Container(
                        key: region,
                        child: WebAttachmentInput(
                          selection: ChatSelection(
                            peerId: peer,
                            chatType: 'C2G',
                          ),
                          currentUserId: currentUser,
                          isCurrent: () => true,
                          inputFocus: focus,
                          regionKey: region,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        for (
          var i = 0;
          i < 100 && find.textContaining('pending.bin').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        debugPrint(
          'DIAGNOSTIC state=$state file=${find.textContaining('pending.bin').evaluate().length} hint=${find.text(t.common.legacyUploadOutboxCheck).evaluate().length} pickEnabled=${tester.widget<IconButton>(pick).onPressed != null}',
        );
        expect(find.textContaining('pending.bin'), findsOneWidget);
        expect(find.text(t.common.legacyUploadOutboxCheck), findsOneWidget);
        expect(tester.widget<IconButton>(pick).onPressed, isNull);
        expect(find.widgetWithText(TextButton, t.common.retry), findsNothing);
        expect(
          find.widgetWithText(TextButton, t.common.buttonSend),
          findsNothing,
        );
        await waitForLocalCheck('initial');
        final before = await checkedDb(
          'before',
          () => AttachmentUploadTaskRepo().findByAnchor('pending-anchor', uid),
        );
        expect(before, hasLength(2));
        expect(
          before!.every(
            (row) => (jsonDecode(row.businessIntent!) as Map)['state'] == state,
          ),
          isTrue,
        );
        expect(
          find.widgetWithText(TextButton, t.common.legacyUploadCheckLocal),
          findsOneWidget,
        );
        await tester.tap(
          find.widgetWithText(TextButton, t.common.legacyUploadCheckLocal),
        );
        await tester.pump();
        await waitForLocalCheck('unknown');
        final unchanged = await checkedDb(
          'unchanged',
          () => AttachmentUploadTaskRepo().findByAnchor('pending-anchor', uid),
        );
        expect(unchanged, hasLength(2));
        expect(
          unchanged!.every(
            (row) => (jsonDecode(row.businessIntent!) as Map)['state'] == state,
          ),
          isTrue,
        );
        final other = await checkedDb(
          'other',
          () => AttachmentUploadTaskRepo().findByAnchor('other-anchor', uid),
        );
        expect(other, hasLength(1));
        expect(
          (jsonDecode(other!.single.businessIntent!) as Map)['state'],
          'uploading',
        );
        expect(find.textContaining('other-pending.bin'), findsNothing);
        expect(tester.widget<IconButton>(pick).onPressed, isNull);
        update(() => peer = '990002');
        await tester.pump();
        for (
          var i = 0;
          i < 100 && tester.widget<IconButton>(pick).onPressed == null;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(find.textContaining('pending.bin'), findsNothing);
        expect(tester.widget<IconButton>(pick).onPressed, isNotNull);
        update(() => peer = '990001');
        await tester.pump();
        for (
          var i = 0;
          i < 100 && find.textContaining('pending.bin').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        expect(find.textContaining('pending.bin'), findsOneWidget);
        // Synthetic local reconciliation: no backend response is claimed.
        final committed = {
          ...jsonDecode(unchanged.first.businessIntent!) as Map,
          'state': 'committed',
        };
        await checkedDb('partial-update', () async {
          final db = await SqliteService.to.db;
          return db!.update(
            AttachmentUploadTaskRepo.tableName,
            {'business_intent': jsonEncode(committed)},
            where: 'id = ?',
            whereArgs: [unchanged.first.id],
          );
        });
        await tester.tap(
          find.widgetWithText(TextButton, t.common.legacyUploadCheckLocal),
        );
        await tester.pump();
        await waitForLocalCheck('partial');
        expect(find.text(t.common.legacyUploadOutboxCheck), findsOneWidget);
        expect(tester.widget<IconButton>(pick).onPressed, isNull);
        await checkedDb('delete-one', () async {
          final db = await SqliteService.to.db;
          return db!.delete(
            AttachmentUploadTaskRepo.tableName,
            where: 'id = ?',
            whereArgs: [unchanged.last.id],
          );
        });
        await tester.tap(
          find.widgetWithText(TextButton, t.common.legacyUploadCheckLocal),
        );
        await tester.pump();
        await waitForLocalCheck('missing');
        expect(find.text(t.common.legacyUploadOutboxCheck), findsOneWidget);
        expect(tester.widget<IconButton>(pick).onPressed, isNull);
        expect(
          await checkedDb(
            'reinsert',
            () => AttachmentUploadTaskRepo().insert(unchanged.last),
          ),
          isTrue,
        );
        expect(
          await checkedDb(
            'commit-all',
            () => AttachmentUploadTaskRepo().saveBusinessIntent(
              'pending-anchor',
              uid,
              jsonEncode(committed),
            ),
          ),
          2,
        );
        await tester.tap(
          find.widgetWithText(TextButton, t.common.legacyUploadCheckLocal),
        );
        await tester.pump();
        debugPrintSynchronously('DIAGNOSTIC $state local:committed waiting');
        for (
          var i = 0;
          i < 100 &&
              find.textContaining('other-pending.bin').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        debugPrintSynchronously('DIAGNOSTIC $state local:committed result');
        expect(find.textContaining('other-pending.bin'), findsOneWidget);
        expect(tester.widget<IconButton>(pick).onPressed, isNull);
        update(() => currentUser = 'another-account');
        await tester.pump();
        expect(find.textContaining('pending.bin'), findsNothing);
        expect(tester.widget<IconButton>(pick).onPressed, isNull);
        expect(noNetwork.calls, 0);
      } catch (error, stack) {
        debugPrint('DIAGNOSTIC failure state=$state: $error\n$stack');
        rethrow;
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        app_http.HttpClient.adapterForTest = oldAdapter;
        focus.dispose();
        await checkedDb('cleanup', () async {
          await _close(uid);
          return true;
        });
      }
    });
  }

  for (final gate in [
    'anchor_msg_id = ? AND user_id = ?',
    'user_id = ? AND business_intent IS NOT NULL',
  ]) {
    for (final switchAccount in [false, true]) {
      testWidgets(
        'late $gate cannot affect changed ${switchAccount ? 'synthetic UID' : 'conversation B'}',
        (tester) async {
          final uid = (await tester.runAsync(
            () => _openPending(state: 'commit_unknown'),
          ))!;
          final focus = FocusNode();
          final region = GlobalKey();
          final oldAdapter = app_http.HttpClient.adapterForTest;
          final noNetwork = _NoNetwork();
          app_http.HttpClient.adapterForTest = noNetwork;
          var peer = '990001';
          var widgetUid = uid;
          late StateSetter update;
          Database? realDb;
          _HeldQueryDb? held;
          Future<void>? operation;
          Object? firstError;
          StackTrace? firstStack;
          bool environmentUntrusted = false;
          void checkFrameworkError(String step) {
            final error = tester.takeException();
            if (error != null) {
              debugPrintSynchronously('RACE_ERROR $gate $step: $error');
              Error.throwWithStackTrace(error as Object, StackTrace.current);
            }
          }

          Future<void> pumpUntil(bool Function() condition, String step) async {
            for (var i = 0; i < 200 && !condition(); i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 10)),
              );
              await tester.pump();
            }
            expect(condition(), isTrue, reason: step);
          }

          Future<String> snapshot() async {
            final tables = await realDb!.rawQuery(
              "SELECT name, sql FROM sqlite_master WHERE type = 'table' ORDER BY name",
            );
            final result = <String, Object?>{'schema': tables};
            for (final entry in tables) {
              final name = entry['name']! as String;
              if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(name)) {
                throw StateError('Unexpected synthetic database table name');
              }
              final rows = await realDb!.query(name);
              result[name] = rows.map(jsonEncode).toList()..sort();
            }
            return jsonEncode(result);
          }

          final button = find.widgetWithText(
            TextButton,
            t.common.legacyUploadCheckLocal,
          );
          final pick = find.byKey(const ValueKey('web-attachment-file'));
          try {
            debugPrintSynchronously('RACE_PHASE $gate widget start');
            await tester.pumpWidget(
              TranslationProvider(
                child: MaterialApp(
                  home: Scaffold(
                    body: StatefulBuilder(
                      builder: (context, setState) {
                        update = setState;
                        return WebGroupSendScope(
                          allowed: true,
                          capture: () =>
                              () => true,
                          child: Container(
                            key: region,
                            child: WebAttachmentInput(
                              selection: ChatSelection(
                                peerId: peer,
                                chatType: 'C2G',
                              ),
                              currentUserId: widgetUid,
                              isCurrent: () => true,
                              inputFocus: focus,
                              regionKey: region,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
            checkFrameworkError('initial-pump');
            await pumpUntil(
              () =>
                  button.evaluate().isNotEmpty &&
                  tester.widget<TextButton>(button).onPressed != null,
              'A initial restore',
            );
            final before = await tester.runAsync(() async {
              realDb = await SqliteService.to.db;
              final repo = AttachmentUploadTaskRepo();
              final rows = await repo.findByAnchor('pending-anchor', uid);
              expect(rows, hasLength(1));
              final committed = {
                ...jsonDecode(rows.single.businessIntent!) as Map,
                'state': 'committed',
              };
              expect(
                await repo.saveBusinessIntent(
                  'pending-anchor',
                  uid,
                  jsonEncode(committed),
                ),
                1,
              );
              return snapshot();
            });
            debugPrintSynchronously('RACE_PHASE $gate snapshot prepared');
            checkFrameworkError('before-hold');
            final onPressed = tester.widget<TextButton>(button).onPressed!;
            debugPrintSynchronously(
              'RACE_DIAGNOSTIC $gate ${switchAccount ? 'synthetic UID' : 'B'} start',
            );
            await tester.runAsync(() async {
              held = _HeldQueryDb(realDb!, gate)..armed = true;
              SqliteService.setDbForTest(held);
              final bound = await SqliteService.to.db;
              debugPrintSynchronously(
                'RACE_PHASE $gate bound-proxy=${identical(bound, held)}',
              );
              expect(
                identical(bound, held),
                isTrue,
                reason: 'gated database must be current',
              );
              operation = Function.apply(onPressed, const []) as Future<void>;
              final outcome = await Future.any([
                held!.entered.future.then((_) => 'entered'),
                operation!.then((_) => 'completed-before-query'),
              ]).timeout(const Duration(seconds: 5));
              debugPrintSynchronously(
                'RACE_PHASE $gate action-outcome=$outcome',
              );
              if (outcome != 'entered') {
                throw StateError(
                  'local-check operation completed before targeted SQLite query',
                );
              }
            });
            debugPrintSynchronously('RACE_PHASE $gate held');
            checkFrameworkError('held');
            // The first query has returned its real result into the held proxy.
            // B's initialization must use the original DB, not the proxy.
            SqliteService.setDbForTest(realDb);
            if (switchAccount) {
              await tester.runAsync(
                () => StorageService.to.setString(
                  Keys.currentUid,
                  'race-other-user',
                ),
              );
              update(() => widgetUid = 'race-previous-view');
              await tester.pump();
              expect(find.textContaining('pending.bin'), findsNothing);
              expect(tester.widget<IconButton>(pick).onPressed, isNull);
            } else {
              update(() => peer = '990002');
              await tester.pump();
              await pumpUntil(
                () => tester.widget<IconButton>(pick).onPressed != null,
                'B initialized and can pick',
              );
              final box =
                  region.currentContext!.findRenderObject()! as RenderBox;
              final point = box.localToGlobal(const Offset(2, 2));
              final transfer = web.DataTransfer();
              transfer.items.add(
                web.File(
                  <web.BlobPart>[
                    Uint8List.fromList([4, 7, 11, 19]).toJS,
                  ].toJS,
                  'b-sentinel.bin',
                ),
              );
              final event = web.DragEvent(
                'drop',
                web.DragEventInit(
                  cancelable: true,
                  clientX: point.dx.toInt(),
                  clientY: point.dy.toInt(),
                  dataTransfer: transfer,
                ),
              );
              await tester.runAsync(() async {
                web.document.dispatchEvent(event);
              });
              await pumpUntil(
                () =>
                    find.textContaining('b-sentinel.bin').evaluate().isNotEmpty,
                'B sentinel selected',
              );
              expect(event.defaultPrevented, isTrue);
              expect(tester.widget<IconButton>(pick).onPressed, isNotNull);
            }
            debugPrintSynchronously('RACE_PHASE $gate changed-context');
            checkFrameworkError('changed-context');
            await tester.runAsync(() async {
              held!.release.complete();
              await operation!.timeout(const Duration(seconds: 5));
              expect(held!.returned.isCompleted, isTrue);
            });
            await tester.pump();
            checkFrameworkError('after-operation');
            if (switchAccount) {
              expect(find.textContaining('pending.bin'), findsNothing);
              expect(tester.widget<IconButton>(pick).onPressed, isNull);
            } else {
              expect(find.textContaining('b-sentinel.bin'), findsOneWidget);
              expect(tester.widget<IconButton>(pick).onPressed, isNotNull);
            }
            expect(await tester.runAsync(snapshot), before);
            expect(noNetwork.calls, 0);
            debugPrintSynchronously(
              'RACE_DIAGNOSTIC $gate ${switchAccount ? 'synthetic UID' : 'B'} done',
            );
          } catch (error, stack) {
            debugPrintSynchronously('RACE_ERROR $gate body: $error\n$stack');
            firstError = error;
            firstStack = stack;
          } finally {
            Future<bool> cleanupStep(
              String step,
              FutureOr<void> Function() action,
            ) async {
              debugPrintSynchronously('RACE_PHASE $gate cleanup $step start');
              try {
                await action();
                debugPrintSynchronously('RACE_PHASE $gate cleanup $step done');
                return true;
              } catch (error, stack) {
                firstError ??= error;
                firstStack ??= stack;
                environmentUntrusted = true;
                debugPrintSynchronously(
                  'RACE_ERROR $gate cleanup $step: $error\n$stack',
                );
                if (error is TimeoutException) {
                  debugPrintSynchronously(
                    'RACE_ENV_UNTRUSTED $gate $step timed out; underlying Future may still run',
                  );
                }
                return false;
              }
            }

            final gateDb = held;
            final released = await cleanupStep('release-gate', () {
              if (gateDb != null && !gateDb.release.isCompleted) {
                gateDb.release.complete();
              }
            });
            var operationSettled = held == null && operation == null;
            if (operation != null) {
              operationSettled = await cleanupStep('wait-operation', () async {
                final completed = await tester.runAsync(() async {
                  await operation!.timeout(const Duration(seconds: 5));
                  return true;
                });
                checkFrameworkError('cleanup-operation');
                if (completed != true) {
                  throw StateError('operation completion unknown');
                }
              });
            }
            if (!released || !operationSettled) environmentUntrusted = true;
            final unmounted = await cleanupStep('unmount', () async {
              await tester.pumpWidget(const SizedBox.shrink());
              checkFrameworkError('cleanup-unmount');
            });
            await cleanupStep('restore-adapter', () {
              app_http.HttpClient.adapterForTest = oldAdapter;
            });
            await cleanupStep('dispose-focus', focus.dispose);
            var uidRestored = false;
            await cleanupStep('restore-uid', () async {
              if (switchAccount) {
                final stored = await tester.runAsync(
                  () => StorageService.to
                      .setString(Keys.currentUid, uid)
                      .timeout(const Duration(seconds: 10)),
                );
                checkFrameworkError('cleanup-uid');
                if (stored != true) {
                  throw StateError('synthetic uid restore failed');
                }
              }
              uidRestored = StorageService.to.getString(Keys.currentUid) == uid;
              if (!uidRestored) {
                throw StateError('synthetic uid identity mismatch');
              }
            });
            var dbRestored = false;
            if (uidRestored && operationSettled && realDb != null) {
              dbRestored = await cleanupStep('restore-db', () {
                SqliteService.setDbForTest(realDb);
              });
            }
            var databaseDeleted = false;
            var deletionStarted = false;
            if (dbRestored && unmounted && !environmentUntrusted) {
              final uidCleared = await cleanupStep('clear-uid', () async {
                final cleared = await tester.runAsync(
                  () => StorageService.to
                      .setString(Keys.currentUid, '')
                      .timeout(const Duration(seconds: 10)),
                );
                checkFrameworkError('cleanup-clear-uid');
                if (cleared != true) {
                  throw StateError('synthetic uid clear failed');
                }
              });
              var barrierOk = false;
              if (uidCleared) {
                barrierOk = await cleanupStep('barrier', () async {
                  await tester.runAsync(
                    () => browserSqliteStorageBridge.durableBarrier().timeout(
                      const Duration(seconds: 10),
                    ),
                  );
                  checkFrameworkError('cleanup-barrier');
                });
              }
              var closed = false;
              if (barrierOk) {
                closed = await cleanupStep('close-db', () async {
                  await tester.runAsync(
                    () => SqliteService.to.close().timeout(
                      const Duration(seconds: 10),
                    ),
                  );
                  checkFrameworkError('cleanup-close-db');
                });
              }
              if (closed && !environmentUntrusted) {
                deletionStarted = true;
                databaseDeleted = await cleanupStep('delete-test-db', () async {
                  await tester.runAsync(
                    () => SqliteService.to
                        .deleteDatabaseForUid(uid, environment: currentEnv)
                        .timeout(const Duration(seconds: 10)),
                  );
                  checkFrameworkError('cleanup-delete-db');
                });
              }
            }
            if (!databaseDeleted) {
              environmentUntrusted = true;
              final detail = deletionStarted
                  ? 'test database deletion result UNKNOWN'
                  : 'test database deletion not started; state unverified';
              firstError ??= StateError(detail);
              firstStack ??= StackTrace.current;
              debugPrintSynchronously(
                'RACE_ENV_UNTRUSTED $gate $detail; inspect outstanding work',
              );
            }
            if (environmentUntrusted) {
              debugPrintSynchronously(
                'RACE_ENV_UNTRUSTED $gate cleanup incomplete; timeout does not cancel a Future',
              );
            }
          }
          if (firstError != null) {
            Error.throwWithStackTrace(firstError!, firstStack!);
          }
        },
      );
    }
  }
}
