import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

/// Mirrors the server's created_at >= cursor AND not-yet-ACKed predicate.
class _OfflineAdapter implements HttpClientAdapter {
  final acknowledged = <String>{};
  final cursors = <int>[];
  bool repaired = false;

  List<Map<String, dynamic>> get frames => [
    {
      'msg_id': 'cursor-poison',
      'type': 'S2C',
      'created_at': 1000,
      'from': '200',
      'to': '100',
      'action': repaired ? 'future-compatible-control' : 'c2c_del_everyone',
      'payload': {'old_msg_id': ''},
    },
    for (final entry in [
      ('cursor-good-first', 2000),
      ('cursor-good-later', 3000),
    ])
      {
        'msg_id': entry.$1,
        'type': 'S2C',
        'created_at': entry.$2,
        'from': '200',
        'to': '100',
        'action': 'future-compatible-control',
        'payload': <String, dynamic>{},
      },
  ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    late Map<String, dynamic> payload;
    if (options.path == API.msgOffline) {
      expect(options.queryParameters['did'], 'synthetic-cursor-device');
      final cursor = options.queryParameters['s2c_last_msg_at'] as int? ?? 0;
      cursors.add(cursor);
      final pending = frames
          .where(
            (frame) =>
                (frame['created_at'] as int) >= cursor &&
                !acknowledged.contains(frame['msg_id']),
          )
          .toList();
      final page = pending.take(2).toList();
      payload = {
        's2c': {
          'list': page,
          'has_more': pending.length > page.length,
          if (page.isNotEmpty) 'next_last_msg_at': page.last['created_at'],
        },
      };
    } else if (options.path == API.msgOfflineAck) {
      final data = options.data is Map
          ? options.data as Map
          : jsonDecode(options.data as String) as Map;
      expect(data['did'], 'synthetic-cursor-device');
      expect(data['type'], 'S2C');
      acknowledged.addAll((data['msg_ids'] as List).cast<String>());
      payload = {};
    } else {
      throw StateError('unexpected synthetic endpoint: ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode({'code': 0, 'payload': payload}),
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

  test('poison frame preserves durable cursor while later pages ACK; restart retries it', () async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '100',
      Keys.offlineCursorS2c: 500,
    });
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(
      version: kInventoryCurrentDbVersion,
    );
    SqliteService.setDbForTest(db);
    final originalDevice = init.deviceId;
    final originalFeatures = AppFeatureRegistry.snapshot;
    init.deviceId = 'synthetic-cursor-device';
    AppFeatureRegistry.replaceSnapshotForTest({
      ...originalFeatures,
      'e2ee': false,
    });
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    FlutterSecureStorage.setMockInitialValues({
      'secure_token':
          '${encode({'alg': 'none'})}.${encode({'exp': 4102444800, 'uid': 100})}.test',
    });
    final adapter = _OfflineAdapter();
    HttpClient.adapterForTest = adapter;
    init.serviceContainer.put(HttpClient());
    var service = MessageOfflineService.instance;
    try {
      expect(
        await service.requestPull(source: 'synthetic-poison', force: true),
        isFalse,
      );
      expect(adapter.cursors, [500, 2000]);
      expect(adapter.acknowledged, {'cursor-good-first', 'cursor-good-later'});
      expect(service.getPullStats()['last_result'], 'partial');
      expect(
        MessageOfflineService.readStoredCursor(Keys.offlineCursorS2c),
        500,
      );

      service.onDispose();
      service = MessageOfflineService.instance;
      adapter.repaired = true;
      expect(
        await service.requestPull(source: 'synthetic-restart', force: true),
        isTrue,
      );
      expect(adapter.cursors, [500, 2000, 500]);
      expect(adapter.acknowledged, {
        'cursor-poison',
        'cursor-good-first',
        'cursor-good-later',
      });
      expect(service.getPullStats()['last_result'], 'success');
      expect(
        MessageOfflineService.readStoredCursor(Keys.offlineCursorS2c),
        1000,
      );
    } finally {
      service.onDispose();
      AckManager.to.dispose();
      HttpClient.adapterForTest = null;
      init.serviceContainer.clear();
      AppFeatureRegistry.replaceSnapshotForTest(originalFeatures);
      init.deviceId = originalDevice;
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });
  group('S2C replay isolation', () {
    late Database db;
    late ProviderContainer container;
    late MessageRepo messageRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
      await StorageService.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      db = await openFixtureDatabaseAtVersion(
        version: kInventoryCurrentDbVersion,
      );
      SqliteService.setDbForTest(db);
      container = ProviderContainer();
      MessageRepo.setProviderContainer(container);
      messageRepo = MessageRepo(tableName: MessageRepo.c2cTable);
    });
    tearDown(() async {
      await messageRepo.waitForFtsReindexForTest();
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    });
    test('S2C poison frame does not hide committed or later successful ACKs', () async {
      final handled = <String>[];
      final messages = <Map<String, dynamic>>[
        {
          'id': 'ordinary-before-poison',
          'type': 'C2C',
          'from': '995012',
          'to': '995011',
          'msg_type': 'text',
          'payload': {'text': 'synthetic committed message'},
          'created_at': 1700000000000,
        },
        for (final id in ['s2c-good-before', 's2c-poison', 's2c-good-after'])
          {'id': id, 'type': 'S2C', 'action': 'synthetic-action'},
      ];
      final acknowledgements = await messageRepo.batchInsertOfflineMessages(
        messages,
        onS2CMessage: (message) async {
          final id = message['id'] as String;
          handled.add(id);
          if (id == 's2c-poison') {
            throw const FormatException('synthetic poison');
          }
        },
      );
      expect(handled, ['s2c-good-before', 's2c-poison', 's2c-good-after']);
      expect(acknowledgements, [
        'ordinary-before-poison',
        's2c-good-before',
        's2c-good-after',
      ]);
      expect(await messageRepo.find('ordinary-before-poison'), isNotNull);
      // Failed control messages remain unacknowledged so the server can retry.
      expect(acknowledgements, isNot(contains('s2c-poison')));
    });

    test('S2C isolation still rejects a changed account', () async {
      final handled = <String>[];
      try {
        await expectLater(
          messageRepo.batchInsertOfflineMessages(
            [
              {'id': 's2c-switch-account', 'type': 'S2C'},
              {'id': 's2c-must-not-run', 'type': 'S2C'},
            ],
            onS2CMessage: (message) async {
              handled.add(message['id'] as String);
              await StorageService.to.setString(Keys.currentUid, '995013');
              throw const FormatException('synthetic handler failure');
            },
          ),
          throwsStateError,
        );
        expect(handled, ['s2c-switch-account']);
      } finally {
        await StorageService.to.setString(Keys.currentUid, '995011');
      }
    });
  });
}
