import 'dart:convert';

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
import 'offline_cursor_recovery_support.dart';

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
    final adapter = OfflineFixtureAdapter();
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

  // ====================================================================
  // FL-04:LOCAL:01~:06 本机负例组（ScriptedPullAdapter 合成离线服务）
  // ====================================================================

  test(':01 batch committed but ACK response lost: retry yields one object per msg_id', () async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '100',
      Keys.offlineCursorC2c: 1500,
    });
    await StorageService.init();
    final db = await fl04OpenDb();
    SqliteService.setDbForTest(db);
    final originalDevice = init.deviceId;
    final originalFeatures = AppFeatureRegistry.snapshot;
    init.deviceId = 'synthetic-cursor-device';
    AppFeatureRegistry.replaceSnapshotForTest({
      ...originalFeatures,
      'e2ee': false,
    });
    await fl04InstallToken(100);
    final container = ProviderContainer();
    MessageRepo.setProviderContainer(container);
    final adapter = ScriptedPullAdapter(
      frames: [
        fl04C2cFrame('ackloss-1', 2000),
        fl04C2cFrame('ackloss-2', 3000),
      ],
      sectionKey: 'c2c',
      ackFailures: 1,
    );
    HttpClient.adapterForTest = adapter;
    init.serviceContainer.put(HttpClient());
    final service = MessageOfflineService.instance;
    try {
      // 第一拉：批写已提交，ACK 请求连接丢失 → 整轮失败，游标不推进。
      expect(
        await service.requestPull(source: 'fl04-ackloss', force: true),
        isFalse,
      );
      expect(adapter.ackBodies, isEmpty);
      expect(
        MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c),
        1500,
      );

      // 重试：服务端按 did 谓词重发同帧 → msg_id 幂等去重，业务对象仍各一。
      expect(
        await service.requestPull(source: 'fl04-ackloss-retry', force: true),
        isTrue,
      );
      expect(
        adapter.ackBodies.last['msg_ids'],
        containsAll(<String>['ackloss-1', 'ackloss-2']),
      );
      expect(
        MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c),
        3000,
      );
      final counts = <String, int>{};
      for (final id in ['ackloss-1', 'ackloss-2']) {
        final rows = await db.rawQuery(
          'SELECT COUNT(*) AS c FROM ${MessageRepo.c2cTable} WHERE id = ?',
          [id],
        );
        counts[id] = rows.single['c'] as int;
      }
      expect(counts, {'ackloss-1': 1, 'ackloss-2': 1});
    } finally {
      service.onDispose();
      AckManager.to.dispose();
      HttpClient.adapterForTest = null;
      init.serviceContainer.clear();
      AppFeatureRegistry.replaceSnapshotForTest(originalFeatures);
      init.deviceId = originalDevice;
      await MessageRepo(tableName: MessageRepo.c2cTable)
          .waitForFtsReindexForTest();
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });

  test(
    ':02 out-of-order batch persists both; authoritative order, single effect',
    () async {
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '100',
        Keys.offlineCursorS2c: 500,
      });
      await StorageService.init();
      final db = await fl04OpenDb();
      SqliteService.setDbForTest(db);
      final originalDevice = init.deviceId;
      final originalFeatures = AppFeatureRegistry.snapshot;
      init.deviceId = 'synthetic-cursor-device';
      AppFeatureRegistry.replaceSnapshotForTest({
        ...originalFeatures,
        'e2ee': false,
      });
      await fl04InstallToken(100);
      final container = ProviderContainer();
      MessageRepo.setProviderContainer(container);
      // 批内乱序：102（created_at=3000）先到，101（created_at=2000）迟到同批。
      final adapter = ScriptedPullAdapter(
        frames: [
          fl04C2cFrame('disorder-102', 3000),
          fl04C2cFrame('disorder-101', 2000),
        ],
        sectionKey: 'c2c',
      );
      HttpClient.adapterForTest = adapter;
      init.serviceContainer.put(HttpClient());
      final service = MessageOfflineService.instance;
      try {
        expect(
          await service.requestPull(source: 'fl04-disorder', force: true),
          isTrue,
        );
        expect(
          adapter.acknowledged,
          containsAll(<String>['disorder-101', 'disorder-102']),
        );
        final ordered = await db.rawQuery(
          'SELECT id FROM ${MessageRepo.c2cTable} '
          'WHERE id IN (?, ?) ORDER BY created_at ASC, id ASC',
          ['disorder-101', 'disorder-102'],
        );
        // 权威顺序按 created_at，而非到达序；两条各落库一次。
        expect(ordered.map((r) => r['id']), ['disorder-101', 'disorder-102']);
        for (final id in ['disorder-101', 'disorder-102']) {
          final rows = await db.rawQuery(
            'SELECT COUNT(*) AS c FROM ${MessageRepo.c2cTable} WHERE id = ?',
            [id],
          );
          expect(rows.single['c'], 1, reason: '$id 落库恰好一份');
        }
        expect(
          MessageOfflineService.readStoredCursor(Keys.offlineCursorC2c),
          3000,
        );
      } finally {
        service.onDispose();
        AckManager.to.dispose();
        HttpClient.adapterForTest = null;
        init.serviceContainer.clear();
        AppFeatureRegistry.replaceSnapshotForTest(originalFeatures);
        init.deviceId = originalDevice;
        await MessageRepo(tableName: MessageRepo.c2cTable)
            .waitForFtsReindexForTest();
        container.dispose();
        SqliteService.setDbForTest(null);
        await db.close();
      }
    },
  );

  test(':02 poison page defers cursor; later page ACKs; repair never duplicates 102', () async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '100',
      Keys.offlineCursorS2c: 500,
    });
    await StorageService.init();
    final db = await fl04OpenDb();
    SqliteService.setDbForTest(db);
    final originalDevice = init.deviceId;
    final originalFeatures = AppFeatureRegistry.snapshot;
    init.deviceId = 'synthetic-cursor-device';
    AppFeatureRegistry.replaceSnapshotForTest({
      ...originalFeatures,
      'e2ee': false,
    });
    await fl04InstallToken(100);
    final container = ProviderContainer();
    MessageRepo.setProviderContainer(container);
    final adapter = ScriptedPullAdapter(
      frames: [
        fl04S2cFrame('late-101-poison', 2000),
        fl04S2cFrame('late-102-good', 3000),
      ],
      sectionKey: 's2c',
      pageSize: 2,
      poisonIds: {'late-101-poison'},
    );
    HttpClient.adapterForTest = adapter;
    init.serviceContainer.put(HttpClient());
    var service = MessageOfflineService.instance;
    try {
      // 第一拉：101 页毒丸不入 ACK、游标停在 500；102 页照常 ACK。
      expect(
        await service.requestPull(source: 'fl04-late', force: true),
        isFalse,
      );
      expect(adapter.acknowledged, {'late-102-good'});
      expect(adapter.deliveredCounts['late-102-good'], 1);
      expect(
        MessageOfflineService.readStoredCursor(Keys.offlineCursorS2c),
        500,
      );

      // 断线重连（服务重建）后 101 补齐；102 不再重复产生业务效果。
      service.onDispose();
      service = MessageOfflineService.instance;
      adapter.repaired = true;
      expect(
        await service.requestPull(source: 'fl04-late-repair', force: true),
        isTrue,
      );
      expect(adapter.acknowledged, {'late-101-poison', 'late-102-good'});
      // 102 恰送达一次（不重复产生业务效果）；101 在断线期间被服务端重发
      // （未 ACK 即保留 pending），但首次投递被隔离、仅修复后那一帧生效。
      expect(adapter.deliveredCounts['late-102-good'], 1);
      expect(adapter.deliveredCounts['late-101-poison'], 2);
      expect(
        MessageOfflineService.readStoredCursor(Keys.offlineCursorS2c),
        2000,
      );
    } finally {
      service.onDispose();
      AckManager.to.dispose();
      HttpClient.adapterForTest = null;
      init.serviceContainer.clear();
      AppFeatureRegistry.replaceSnapshotForTest(originalFeatures);
      init.deviceId = originalDevice;
      await MessageRepo(tableName: MessageRepo.c2cTable)
          .waitForFtsReindexForTest();
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });
}
