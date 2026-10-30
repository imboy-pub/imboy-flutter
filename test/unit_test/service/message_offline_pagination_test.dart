import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
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
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _PagedAdapter implements HttpClientAdapter {
  final acknowledged = <String>{};
  final cursors = <int>[];
  bool stall = false;
  bool c2gMode = false;
  final groupCursors = <String?>[];
  String? rejectAckId;
  void Function()? onTwentiethAck;
  Completer<void>? finalAckObserved;
  Completer<void>? releaseFinalAck;
  Future<void> Function()? afterAck;
  void Function()? afterPull;

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
      await afterAck?.call();
      if (acknowledged.length == 20) onTwentiethAck?.call();
      if (acknowledged.length == 23 && finalAckObserved != null) {
        finalAckObserved!.complete();
        await releaseFinalAck!.future;
      }
      return response({'code': 0, 'payload': <String, dynamic>{}});
    }
    if (options.path != API.msgOffline) throw StateError('Unexpected request');
    final result = offlinePage(options);
    afterPull?.call();
    return result;
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

// requestPull completes one bounded cycle. Its continuation must finish ACK
// processing and cursor persistence before assertions or disposal are safe.
Future<void> _waitForPullIdle(MessageOfflineService service) async {
  final elapsed = Stopwatch()..start();
  while (elapsed.elapsed < const Duration(seconds: 10)) {
    final stats = service.getPullStats();
    if (stats['in_flight'] == false && stats['pending_pull_request'] == false) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw TimeoutException(
    'Offline pull did not finish: ${service.getPullStats()}',
  );
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
    // v35 起消息四表含 conv_seq/accepted_at（R07 phase1）；C2G 离线路径
    // 在服务端提供 conv_seq 时写入该列，fixture 必须对齐当前库版本，
    // 否则 INSERT 报 no such column（SqfliteFfiException）。
    db = await openFixtureDatabaseAtVersion(
      version: kInventoryCurrentDbVersion,
    );
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

  void registerSessionTest() {
    testWidgets('session change after ACK prevents cursor advancement', (
      tester,
    ) async {
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      await tester.pumpWidget(
        MaterialApp(builder: AppLoading.init(), home: const SizedBox()),
      );
      await tester.runAsync(() async {
        final originalStorage = FlutterSecureStoragePlatform.instance;
        adapter.afterAck = () async {
          FlutterSecureStoragePlatform.instance =
              MethodChannelFlutterSecureStorage();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
                if (call.method == 'write' &&
                    (call.arguments as Map)['key'] == 'secure_token') {
                  throw PlatformException(code: 'synthetic-login-stop');
                }
                return null;
              });
          await expectLater(
            UserRepoLocal.to.loginAfter('synthetic-session', {
              'uid': '995013',
              'token': 'synthetic-token',
              'refreshtoken': 'synthetic-refresh',
            }),
            throwsA(isA<PlatformException>()),
          );
        };
        try {
          expect(
            await service.requestPull(source: 'session_test', force: true),
            isFalse,
          );
          expect(adapter.acknowledged, hasLength(1));
          expect(adapter.cursors, [0]);
          expect(
            MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c),
            0,
          );
          expect(await db.query('msg_c2c'), hasLength(1));
        } finally {
          FlutterSecureStoragePlatform.instance = originalStorage;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        }
      });
    });
  }

  testWidgets('HTTP guard rejects source change before request dispatch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(builder: AppLoading.init(), home: const SizedBox()),
    );
    await tester.runAsync(() async {
      final client = HttpClient.client;
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            client.dio.options.baseUrl = 'http://127.0.0.1:1';
            handler.next(options);
          },
        ),
      );
      expect(
        await service.requestPull(source: 'guard_test', force: true),
        isFalse,
      );
      expect(adapter.cursors, isEmpty);
      expect(adapter.acknowledged, isEmpty);
      expect(await db.query('msg_c2c'), isEmpty);
    });
  });
  testWidgets('changed HTTP source stops before persistence and ACK', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(builder: AppLoading.init(), home: const SizedBox()),
    );
    await tester.runAsync(() async {
      final client = HttpClient.client;
      adapter.afterPull = () {
        client.dio.options.baseUrl = 'http://127.0.0.1:1';
      };
      expect(
        await service.requestPull(source: 'source_test', force: true),
        isFalse,
      );
      expect(adapter.cursors, [0]);
      expect(adapter.acknowledged, isEmpty);
      expect(await db.query('msg_c2c'), isEmpty);
      expect(MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c), 0);
    });
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
        await _waitForPullIdle(service);
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
        // Construct barriers in the real-async zone used by the HTTP adapter.
        adapter.finalAckObserved = Completer<void>();
        adapter.releaseFinalAck = Completer<void>();
        expect(
          await service.requestPull(source: 'c2g_cursor', force: true),
          isTrue,
        );
        final key = '${Keys.offlineCursorC2gPage}_${currentEnv}_995011';
        try {
          await adapter.finalAckObserved!.future.timeout(
            const Duration(seconds: 10),
          );
          // Reproduce the former race deterministically: all 23 ACKs are
          // observed, but the last response has not reached cursor persistence.
          expect(adapter.acknowledged, hasLength(23));
          expect(service.getPullStats()['in_flight'], isTrue);
          expect(StorageService.to.getString(key), 'g20');
        } finally {
          adapter.releaseFinalAck!.complete();
        }
        await _waitForPullIdle(service);
        expect(adapter.acknowledged, hasLength(23));
        expect(await db.query('msg_c2g'), hasLength(23));
        expect((await db.query('conversation')).single['unread_num'], 23);
        expect(
          adapter.groupCursors,
          orderedEquals([null, ...List.generate(22, (i) => 'g${i + 1}')]),
        );
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
      await _waitForPullIdle(service);
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
        await _waitForPullIdle(service);
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
  registerSessionTest();
}
