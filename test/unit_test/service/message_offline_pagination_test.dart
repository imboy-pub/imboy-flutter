import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _PagedAdapter implements HttpClientAdapter {
  final acknowledged = <String>{};
  final cursors = <int>[];
  bool stall = false;
  bool c2gMode = false;
  final groupCursors = <String?>[];
  String? rejectAckId;
  void Function()? onTwentiethAck;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == API.msgOfflineAck) {
      final ids = (options.data['msg_ids'] as List).cast<String>();
      if (rejectAckId != null && ids.contains(rejectAckId)) {
        rejectAckId = null;
        return response({'code': 1, 'payload': <String, dynamic>{}});
      }
      acknowledged.addAll(ids);
      if (acknowledged.length == 20) onTwentiethAck?.call();
      return response({'code': 0, 'payload': <String, dynamic>{}});
    }
    if (options.path != API.msgOffline) throw StateError('Unexpected request');
    return offlinePage(options);
  }

  ResponseBody offlinePage(RequestOptions options) {
    if (c2gMode) return groupPage(options);
    final cursor =
        int.tryParse('${options.queryParameters['c2c_last_msg_at']}') ?? 0;
    cursors.add(cursor);
    final page = cursor == 0 ? 1 : cursor - 1750000000000 + 1;
    final section = {
      'list': stall || page > 23
          ? <Map<String, dynamic>>[]
          : [
              {
                'msg_id': '${116837000000000100 + page}',
                'from': '995012',
                'to': '995011',
                'msg_type': 'text',
                'payload': {'text': ''},
                'created_at': 1750000000000 + page,
              },
            ],
      'has_more': stall || page < 23,
      if (!stall) 'next_last_msg_at': 1750000000000 + page,
    };
    return response({
      'code': 0,
      'payload': {'c2c': section},
    });
  }

  ResponseBody groupPage(RequestOptions options) {
    final token = options.queryParameters['c2g_cursor'] as String?;
    groupCursors.add(token);
    final page = token == null ? 1 : int.parse(token.substring(1)) + 1;
    return response({
      'code': 0,
      'payload': {
        'c2g': {
          'list': page > 23
              ? <Map<String, dynamic>>[]
              : [
                  {
                    'msg_id': '${116837000000000100 + page}',
                    'from': '995012',
                    'to': '995013',
                    'msg_type': 'text',
                    'payload': {'text': ''},
                    'created_at': 1750000000000,
                    'conv_seq': page,
                  },
                ],
          'has_more': page < 23,
          'next_last_msg_at': 1750000000000,
          'next_cursor': 'g${page > 23 ? 23 : page}',
        },
      },
    });
  }

  ResponseBody response(Map<String, dynamic> value) => ResponseBody.fromString(
    jsonEncode(value),
    200,
    headers: {
      'content-type': ['application/json'],
    },
  );
  @override
  void close({bool force = false}) {}
}

String _encode(Object value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late ProviderContainer container;
  late _PagedAdapter adapter;
  late MessageOfflineService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    FlutterSecureStorage.setMockInitialValues({
      'secure_token':
          '${_encode({'alg': 'none'})}.${_encode({'exp': 4102444800, 'uid': 995011})}.test',
    });
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await openFixtureDatabaseAtVersion(version: 32);
    SqliteService.setDbForTest(db);
    container = ProviderContainer();
    MessageRepo.setProviderContainer(container);
    AppFeatureRegistry.replaceSnapshotForTest({'e2ee': false});
    adapter = _PagedAdapter();
    HttpClient.adapterForTest = adapter;
    serviceContainer.put(HttpClient());
    service = MessageOfflineService.instance;
  });

  tearDown(() async {
    service.onDispose();
    container.dispose();
    SqliteService.setDbForTest(null);
    await db.close();
    HttpClient.adapterForTest = null;
    serviceContainer.clear();
    await AppFeatureRegistry.clear();
  });

  testWidgets(
    'one pull event drains more than 20 pages without another signal',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(builder: AppLoading.init(), home: const SizedBox()),
      );
      await tester.runAsync(() async {
        expect(
          await service.requestPull(source: 'pagination_test', force: true),
          isTrue,
        );
        for (var i = 0; i < 150 && adapter.acknowledged.length < 23; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(adapter.acknowledged, hasLength(23));
        expect(await db.query('msg_c2c'), hasLength(23));
        expect((await db.query('conversation')).single['unread_num'], 23);
        expect(
          adapter.cursors,
          orderedEquals([0, ...List.generate(22, (i) => 1750000000001 + i)]),
        );
        expect(
          MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c),
          1750000000023,
        );
      });
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'C2G composite cursor drains tied timestamps beyond20 pages and resumes',
    (tester) async {
      adapter.c2gMode = true;
      service.onDispose();
      await StorageService.to.remove(Keys.currentUid);
      service = MessageOfflineService.instance;
      await StorageService.to.setString(Keys.currentUid, '995011');
      await tester.pumpWidget(
        MaterialApp(builder: AppLoading.init(), home: const SizedBox()),
      );
      await tester.runAsync(() async {
        expect(
          await service.requestPull(source: 'c2g_cursor', force: true),
          isTrue,
        );
        for (var i = 0; i < 150 && adapter.acknowledged.length < 23; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(adapter.acknowledged, hasLength(23));
        expect(await db.query('msg_c2g'), hasLength(23));
        expect((await db.query('conversation')).single['unread_num'], 23);
        expect(
          adapter.groupCursors,
          orderedEquals([null, ...List.generate(22, (i) => 'g${i + 1}')]),
        );
        final key = '${Keys.offlineCursorC2gPage}_${currentEnv}_995011';
        expect(StorageService.to.getString(key), 'g23');
        expect(
          StorageService.to.getString(
            '${Keys.offlineCursorC2gPage}_${currentEnv}_995014',
          ),
          isEmpty,
        );
        service.onDispose();
        service = MessageOfflineService.instance;
        expect(
          await service.requestPull(source: 'restart_cursor', force: true),
          isTrue,
        );
        expect(adapter.groupCursors.last, 'g23');
        expect((await db.query('conversation')).single['unread_num'], 23);
      });
    },
  );

  testWidgets('C2G failed ACK does not publish a composite cursor', (
    tester,
  ) async {
    adapter.c2gMode = true;
    adapter.rejectAckId = '116837000000000103';
    await tester.pumpWidget(
      MaterialApp(builder: AppLoading.init(), home: const SizedBox()),
    );
    await tester.runAsync(() async {
      expect(
        await service.requestPull(source: 'c2g_failed_ack', force: true),
        isFalse,
      );
      final key = '${Keys.offlineCursorC2gPage}_${currentEnv}_995011';
      expect(StorageService.to.getString(key), isEmpty);
      expect(adapter.acknowledged, hasLength(2));
      expect(await db.query('msg_c2g'), hasLength(3));
      expect(
        await service.requestPull(source: 'c2g_retry', force: true),
        isTrue,
      );
      for (var i = 0; i < 150 && adapter.acknowledged.length < 23; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(adapter.acknowledged, hasLength(23));
      expect(await db.query('msg_c2g'), hasLength(23));
      expect((await db.query('conversation')).single['unread_num'], 23);
      expect(StorageService.to.getString(key), 'g23');
      expect(
        adapter.groupCursors.where((cursor) => cursor == null),
        hasLength(2),
      );
    });
  });

  testWidgets('disposed service does not launch a continuation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(builder: AppLoading.init(), home: const SizedBox()),
    );
    adapter.onTwentiethAck = service.onDispose;
    await tester.runAsync(() async {
      expect(
        await service.requestPull(source: 'disposed_pagination', force: true),
        isTrue,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(adapter.acknowledged, hasLength(20));
      expect(adapter.cursors, hasLength(20));
    });
    await tester.pumpAndSettle();
  });

  testWidgets('has_more without cursor progress fails instead of looping', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(builder: AppLoading.init(), home: const SizedBox()),
    );
    adapter.stall = true;
    await tester.runAsync(() async {
      expect(
        await service.requestPull(source: 'stalled_pagination', force: true),
        isFalse,
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(adapter.cursors, hasLength(20));
      expect(adapter.acknowledged, isEmpty);
      expect(service.getPullStats()['succeeded_total'], 0);
      expect(service.getPullStats()['failed_total'], 1);
      expect(MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c), 0);
    });
    await tester.pumpAndSettle();
  });
  testWidgets(
    'ACK failure retains cursor and retry deduplicates before draining',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(builder: AppLoading.init(), home: const SizedBox()),
      );
      adapter.rejectAckId = '116837000000000103';
      await tester.runAsync(() async {
        expect(
          await service.requestPull(source: 'ack_failure', force: true),
          isFalse,
        );
        expect(
          MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c),
          0,
        );
        expect(adapter.acknowledged, hasLength(2));
        expect(await db.query('msg_c2c'), hasLength(3));
        expect(service.getPullStats()['succeeded_total'], 0);
        expect(
          await service.requestPull(source: 'ack_recovery', force: true),
          isTrue,
        );
        for (var i = 0; i < 150 && adapter.acknowledged.length < 23; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(adapter.cursors[3], 0);
        expect(adapter.acknowledged, hasLength(23));
        expect(await db.query('msg_c2c'), hasLength(23));
        expect((await db.query('conversation')).single['unread_num'], 23);
        expect(
          MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c),
          1750000000023,
        );
        expect(service.getPullStats()['failed_total'], 1);
      });
      await tester.pumpAndSettle();
    },
  );
}
