@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/web_writer_http_adapter.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/browser_sqlite_storage_bridge_web.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

class OfflineAdapter implements HttpClientAdapter {
  final paths = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    paths.add(path);
    if (path == API.msgOfflineAck) {
      return ResponseBody.fromString(
        '{"code":0,"payload":{}}',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      );
    }
    if (path != API.msgOffline) {
      throw StateError('unexpected request $path');
    }
    return ResponseBody.fromString(
      '{"code":0,"payload":{"s2c":{"list":[{"msg_id":"synthetic-offline-role","action":"group_member_role","from":"1","to":"995011","payload":{"gid":9007199254740993,"user_id":9007199254740995,"role":3,"updated_at":42}}],"has_more":false,"next_last_msg_at":1}}}',
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'raw offline group role updates exact member and dispatches event',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(builder: AppLoading.init(), home: const SizedBox()),
      );
      await tester.runAsync(() async {
        await prepareWebWriter();
        expect(isWebWriterReady, isTrue);
        SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
        await StorageService.init();
        String encode(Object v) =>
            base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
        FlutterSecureStorage.setMockInitialValues({
          'secure_token':
              '${encode({'alg': 'none'})}.${encode({'exp': 4102444800, 'uid': 995011})}.test',
        });
        // Keep the admitted bridge's process-global handler. Opening a legacy
        // Web factory here replaces it and correctly poisons the writer gate.
        final factory = browserSqliteStorageBridge.factory;
        final databaseName = SqliteService.databaseNameForUid('995011');
        await factory.deleteDatabase(databaseName);
        final db = await factory.openDatabase(databaseName);
        SqliteService.setDbForTest(db);
        await db.execute(
          'CREATE TABLE group_member (id INTEGER PRIMARY KEY, group_id INTEGER, user_id INTEGER, role INTEGER, updated_at INTEGER)',
        );
        await db.insert('group_member', {
          'id': '1',
          'group_id': '9007199254740993',
          'user_id': '9007199254740995',
          'role': 1,
          'updated_at': 0,
        });
        expect(isWebWriterReady, isTrue);
        final container = ProviderContainer();
        MessageRepo.setProviderContainer(container);
        AppFeatureRegistry.replaceSnapshotForTest({'e2ee': false});
        final adapter = OfflineAdapter();
        final client = HttpClient(retryEnabled: false);
        // Synthetic wire bytes exercise the real decoder and offline handler.
        // Keep Web request/session and writer guards around this local adapter;
        // the production control router otherwise dispatches real Fetch.
        client.dio.httpClientAdapter = adapter;
        guardWebWriterDio(client.dio);
        serviceContainer.put(client);
        final service = MessageOfflineService.instance;
        final events = <GroupMemberRoleEvent>[];
        final sub = AppEventBus.on<GroupMemberRoleEvent>().listen(events.add);
        try {
          final ok = await service.requestPull(
            source: 'synthetic_offline',
            force: true,
          );
          expect(isWebWriterReady, isTrue);
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(ok, isTrue);
          final rows = await db.rawQuery(
            'SELECT role, updated_at FROM group_member WHERE group_id = ? AND user_id = ?',
            ['9007199254740993', '9007199254740995'],
          );
          expect(rows.single['role'], 3);
          expect(events.single.gid, '9007199254740993');
          expect(events.single.userId, '9007199254740995');
          expect(adapter.paths, contains(API.msgOfflineAck));
        } finally {
          await sub.cancel();
          service.onDispose();
          container.dispose();
          SqliteService.setDbForTest(null);
          await db.close();
          await factory.deleteDatabase(databaseName);
          client.dio.close(force: true);
          serviceContainer.clear();
          await AppFeatureRegistry.clear();
        }
      });
    },
    skip: const String.fromEnvironment('SQLITE_WASM_URL').isEmpty,
  );
}
