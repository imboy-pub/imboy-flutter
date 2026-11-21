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
import 'package:imboy/config/env.dart' show envMap;
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_read_repo.dart';
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

/// 可编程离线服务（FL-04:LOCAL:01~:06 负例组）：按
/// 「服务端 created_at >= cursor AND 未按设备 ACK」谓词出页；
/// ACK 可注入失败（响应丢失/连接断）；毒帧行为与主例同构（repaired 修复）。
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter({
    required this.frames,
    required this.sectionKey,
    this.pageSize = 2,
    this.poisonIds = const {},
    this.ackFailures = 0,
    this.alwaysHasMore = false,
  });

  final List<Map<String, dynamic>> frames;
  final String sectionKey; // 'c2c' | 'c2g' | 's2c'
  final int pageSize;
  final Set<String> poisonIds;
  int ackFailures;

  /// 病态服务模式：无论谓词结果恒回 has_more=true（无进展分页负例）。
  final bool alwaysHasMore;

  final acknowledged = <String>{};
  final cursors = <int>[];
  final ackBodies = <Map<String, dynamic>>[];
  final deliveredCounts = <String, int>{};
  final queryLog = <Map<String, dynamic>>[];
  bool repaired = false;

  /// 每次出页前回调（切账号/断线注入点）。
  void Function()? beforePage;

  Map<String, dynamic> _servedFrame(Map<String, dynamic> frame) {
    final id = frame['msg_id'] as String;
    final poison = poisonIds.contains(id) && !repaired;
    return {
      ...frame,
      'action': poison ? 'c2c_del_everyone' : 'future-compatible-control',
      'payload': {'old_msg_id': ''},
    };
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    late Map<String, dynamic> payload;
    if (options.path == API.msgOffline) {
      beforePage?.call();
      final query = Map<String, dynamic>.from(options.queryParameters);
      queryLog.add(query);
      final cursor = query['${sectionKey}_last_msg_at'] as int? ?? 0;
      cursors.add(cursor);
      final pending = frames
          .where(
            (frame) =>
                (frame['created_at'] as int) >= cursor &&
                !acknowledged.contains(frame['msg_id']),
          )
          .toList();
      final page = pending.take(pageSize).map(_servedFrame).toList();
      for (final frame in page) {
        final id = frame['msg_id'] as String;
        deliveredCounts[id] = (deliveredCounts[id] ?? 0) + 1;
      }
      payload = {
        sectionKey: {
          'list': page,
          'has_more': alwaysHasMore || pending.length > page.length,
          if (page.isNotEmpty)
            'next_last_msg_at': page
                .map((f) => f['created_at'] as int)
                .reduce((a, b) => a > b ? a : b),
          if (sectionKey == 'c2g')
            'next_cursor': 'tok-${cursors.length}-${page.length}',
        },
      };
    } else if (options.path == API.msgOfflineAck) {
      if (ackFailures > 0) {
        ackFailures--;
        throw DioException(
          requestOptions: options,
          error: StateError('synthetic ack connection lost'),
        );
      }
      final data = options.data is Map
          ? options.data as Map
          : jsonDecode(options.data as String) as Map;
      ackBodies.add(Map<String, dynamic>.from(data));
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

Map<String, dynamic> _fl04C2cFrame(String id, int createdAt) => {
  'msg_id': id,
  'type': 'C2C',
  'created_at': createdAt,
  'from': '200',
  'to': '100',
  'msg_type': 'text',
  'payload': {'text': 'frame-$id'},
};

Map<String, dynamic> _fl04S2cFrame(String id, int createdAt) => {
  'msg_id': id,
  'type': 'S2C',
  'created_at': createdAt,
  'from': '200',
  'to': '100',
};

Future<Database> _fl04OpenDb() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  return openFixtureDatabaseAtVersion(version: kInventoryCurrentDbVersion);
}

Future<void> _fl04InstallToken(int uid) async {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  FlutterSecureStorage.setMockInitialValues({
    'secure_token':
        '${encode({'alg': 'none'})}.${encode({'exp': 4102444800, 'uid': uid})}.test',
  });
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

  // ====================================================================
  // FL-04:LOCAL:01~:06 本机负例组（_ScriptedAdapter 合成离线服务）
  // ====================================================================

  test(':01 batch committed but ACK response lost: retry yields one object per msg_id', () async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '100',
      Keys.offlineCursorC2c: 1500,
    });
    await StorageService.init();
    final db = await _fl04OpenDb();
    SqliteService.setDbForTest(db);
    final originalDevice = init.deviceId;
    final originalFeatures = AppFeatureRegistry.snapshot;
    init.deviceId = 'synthetic-cursor-device';
    AppFeatureRegistry.replaceSnapshotForTest({
      ...originalFeatures,
      'e2ee': false,
    });
    await _fl04InstallToken(100);
    final container = ProviderContainer();
    MessageRepo.setProviderContainer(container);
    final adapter = _ScriptedAdapter(
      frames: [
        _fl04C2cFrame('ackloss-1', 2000),
        _fl04C2cFrame('ackloss-2', 3000),
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
      final db = await _fl04OpenDb();
      SqliteService.setDbForTest(db);
      final originalDevice = init.deviceId;
      final originalFeatures = AppFeatureRegistry.snapshot;
      init.deviceId = 'synthetic-cursor-device';
      AppFeatureRegistry.replaceSnapshotForTest({
        ...originalFeatures,
        'e2ee': false,
      });
      await _fl04InstallToken(100);
      final container = ProviderContainer();
      MessageRepo.setProviderContainer(container);
      // 批内乱序：102（created_at=3000）先到，101（created_at=2000）迟到同批。
      final adapter = _ScriptedAdapter(
        frames: [
          _fl04C2cFrame('disorder-102', 3000),
          _fl04C2cFrame('disorder-101', 2000),
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
    final db = await _fl04OpenDb();
    SqliteService.setDbForTest(db);
    final originalDevice = init.deviceId;
    final originalFeatures = AppFeatureRegistry.snapshot;
    init.deviceId = 'synthetic-cursor-device';
    AppFeatureRegistry.replaceSnapshotForTest({
      ...originalFeatures,
      'e2ee': false,
    });
    await _fl04InstallToken(100);
    final container = ProviderContainer();
    MessageRepo.setProviderContainer(container);
    final adapter = _ScriptedAdapter(
      frames: [
        _fl04S2cFrame('late-101-poison', 2000),
        _fl04S2cFrame('late-102-good', 3000),
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

  test(
    ':03 progress-less pagination (same timestamp / empty page) fails bounded',
    () async {
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '100',
        Keys.offlineCursorS2c: 500,
      });
      await StorageService.init();
      final db = await _fl04OpenDb();
      SqliteService.setDbForTest(db);
      final originalDevice = init.deviceId;
      final originalFeatures = AppFeatureRegistry.snapshot;
      init.deviceId = 'synthetic-cursor-device';
      AppFeatureRegistry.replaceSnapshotForTest({
        ...originalFeatures,
        'e2ee': false,
      });
      await _fl04InstallToken(100);
      final container = ProviderContainer();
      MessageRepo.setProviderContainer(container);
      final adapter = _ScriptedAdapter(
        // 同时间戳帧：next_last_msg_at 恒等于请求游标 → 无进展。
        frames: [_fl04S2cFrame('stuck-frame', 500)],
        sectionKey: 's2c',
        pageSize: 2,
        alwaysHasMore: true,
      );
      HttpClient.adapterForTest = adapter;
      init.serviceContainer.put(HttpClient());
      final service = MessageOfflineService.instance;
      try {
        expect(
          await service.requestPull(source: 'fl04-stuck', force: true),
          isFalse,
        );
        // 有界失败：第 1 页确认带来进展不触发；第 2 页空页无进展 → StateError
        // 终止，不无限拉取（< _maxPullCount=20），游标不误推进。
        expect(adapter.queryLog.length, 2);
        expect(
          MessageOfflineService.readStoredCursor(Keys.offlineCursorS2c),
          500,
        );
        expect(service.getPullStats()['last_result'], 'failed_exception');
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

  test(
    ':04 c2g page cursor is scoped by env+uid; switch never leaks across scope',
    () async {
      final originalEnv = init.currentEnv;
      // 同一 loopback 端点注册为两个环境键：切换只影响游标作用域，不影响端点。
      envMap['devA'] = envMap['dev']!;
      envMap['devB'] = envMap['dev']!;
      init.currentEnv = 'devA';
      SharedPreferences.setMockInitialValues({Keys.currentUid: '105'});
      await StorageService.init();
      final db = await _fl04OpenDb();
      SqliteService.setDbForTest(db);
      final originalDevice = init.deviceId;
      final originalFeatures = AppFeatureRegistry.snapshot;
      init.deviceId = 'synthetic-cursor-device';
      AppFeatureRegistry.replaceSnapshotForTest({
        ...originalFeatures,
        'e2ee': false,
      });
      await _fl04InstallToken(105);
      final container = ProviderContainer();
      MessageRepo.setProviderContainer(container);
      final adapter = _ScriptedAdapter(
        frames: [_fl04C2cFrame('c2g-scope-a', 2000)],
        sectionKey: 'c2g',
        pageSize: 2,
      );
      HttpClient.adapterForTest = adapter;
      init.serviceContainer.put(HttpClient());
      var service = MessageOfflineService.instance;
      try {
        expect(
          await service.requestPull(source: 'fl04-c2g-a', force: true),
          isTrue,
        );
        // 环境 A 持久化了自己的分页游标（键含 env+uid）。
        final scopedKeys = StorageService.to
            .getKeys()
            .where((k) => k.startsWith(Keys.offlineCursorC2gPage))
            .toList();
        expect(scopedKeys, hasLength(1));
        expect(scopedKeys.single, contains('devA'));
        expect(scopedKeys.single, contains('105'));

        // 切环境后重建服务：新作用域键下无游标 → 不携带旧 token 重放。
        service.onDispose();
        init.currentEnv = 'devB';
        service = MessageOfflineService.instance;
        expect(
          await service.requestPull(source: 'fl04-c2g-b', force: true),
          isTrue,
        );
        final lastQuery = adapter.queryLog.last;
        expect(lastQuery.containsKey('c2g_cursor'), isFalse);
        // 环境 B 的键与 A 分离；A 的游标未被 B 读取或改写。
        final keys = StorageService.to
            .getKeys()
            .where((k) => k.startsWith(Keys.offlineCursorC2gPage))
            .toList();
        expect(keys, hasLength(2));
        expect(keys.where((k) => k.contains('devA')), hasLength(1));
        expect(keys.where((k) => k.contains('devB')), hasLength(1));
      } finally {
        service.onDispose();
        AckManager.to.dispose();
        HttpClient.adapterForTest = null;
        init.serviceContainer.clear();
        AppFeatureRegistry.replaceSnapshotForTest(originalFeatures);
        init.deviceId = originalDevice;
        init.currentEnv = originalEnv;
        await MessageRepo(tableName: MessageRepo.c2cTable)
            .waitForFtsReindexForTest();
        container.dispose();
        SqliteService.setDbForTest(null);
        await db.close();
      }
    },
  );

  test(':04 account switch mid-pull aborts; no cursor cross-use for the new account', () async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '106',
      Keys.offlineCursorS2c: 500,
    });
    await StorageService.init();
    final db = await _fl04OpenDb();
    SqliteService.setDbForTest(db);
    final originalDevice = init.deviceId;
    final originalFeatures = AppFeatureRegistry.snapshot;
    init.deviceId = 'synthetic-cursor-device';
    AppFeatureRegistry.replaceSnapshotForTest({
      ...originalFeatures,
      'e2ee': false,
    });
    await _fl04InstallToken(106);
    final container = ProviderContainer();
    MessageRepo.setProviderContainer(container);
    final frames = [
      _fl04S2cFrame('switch-page-1', 2000),
      _fl04S2cFrame('switch-page-2', 3000),
    ];
    final adapter =
        _ScriptedAdapter(frames: frames, sectionKey: 's2c', pageSize: 1)
          ..beforePage = () {
            // 第 2 页拉取时刻切账号（模拟登录态被替换）。
            StorageService.to.setString(Keys.currentUid, '206');
          };
    HttpClient.adapterForTest = adapter;
    init.serviceContainer.put(HttpClient());
    final service = MessageOfflineService.instance;
    try {
      expect(
        await service.requestPull(source: 'fl04-switch', force: true),
        isFalse,
      );
      // 旧账号游标不被推进，也不为 206 生成任何键。
      expect(
        MessageOfflineService.readStoredCursor(Keys.offlineCursorS2c),
        500,
      );
      expect(
        StorageService.to.getKeys().where((k) => k.contains('206')),
        isEmpty,
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

  test(':05 delivered and read stay distinct; late duplicate read never rolls back', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    final db = await _fl04OpenDb();
    SqliteService.setDbForTest(db);
    final container = ProviderContainer();
    MessageRepo.setProviderContainer(container);
    final messageRepo = MessageRepo(tableName: MessageRepo.c2cTable);
    try {
      // B 端离线补齐：三条送达（delivered=20）消息落库。
      final messages = <Map<String, dynamic>>[
        for (final id in ['read-m1', 'read-m2'])
          {
            'id': id,
            'type': 'C2C',
            'from': '995012',
            'to': '995011',
            'msg_type': 'text',
            'payload': {'text': 'delivered-$id'},
            'created_at': 1700000000000,
          },
        {
          // 另一会话（peer 995013）的消息：已读同步不得误伤。
          'id': 'read-m3-foreign',
          'type': 'C2C',
          'from': '995013',
          'to': '995011',
          'msg_type': 'text',
          'payload': {'text': 'foreign'},
          'created_at': 1700000000000,
        },
      ];
      await messageRepo.batchInsertOfflineMessages(messages);
      for (final id in ['read-m1', 'read-m2', 'read-m3-foreign']) {
        await db.update(
          MessageRepo.c2cTable,
          {'status': IMBoyMessageStatus.delivered},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      final conversationRepo = ConversationRepo();
      // 离线批量写入会自动为消息落库会话行（未读数=2）；直接复用该行，
      // 与真实 B 端「先离线补齐、后应用已读同步」路径一致。
      final conv = await conversationRepo.findByPeerId('C2C', '995012');
      expect(conv, isNotNull, reason: '离线补齐应已建会话');
      expect(conv!.unreadNum, 2);

      // A 端已读 → B 端离线补齐：apply 只推进本会话消息。
      final first = await MessageReadRepo.apply(db, conv, [
        'read-m1',
        'read-m3-foreign',
      ]);
      expect(first.msgIds, ['read-m1']);
      // 送达不伪装已读：m2 仍 delivered；他conversation消息不动。
      Future<int> statusOf(String id) async {
        final rows = await db.rawQuery(
          'SELECT status FROM ${MessageRepo.c2cTable} WHERE id = ?',
          [id],
        );
        return rows.single['status'] as int;
      }

      expect(await statusOf('read-m1'), IMBoyMessageStatus.seen);
      expect(await statusOf('read-m2'), IMBoyMessageStatus.delivered);
      expect(await statusOf('read-m3-foreign'), IMBoyMessageStatus.delivered);
      expect(first.unreadNum, 1);

      // 迟到重复的旧已读请求：已读位不回滚、未读不为负。
      final replay = await MessageReadRepo.apply(db, conv, ['read-m1']);
      expect(replay.msgIds, ['read-m1']);
      expect(await statusOf('read-m1'), IMBoyMessageStatus.seen);
      expect(replay.unreadNum, 1);

      // 已读不伪装同步完成：m2 未读时未读数>0；全部已读才归零。
      final done = await MessageReadRepo.apply(db, conv, ['read-m2']);
      expect(done.unreadNum, 0);
      expect(await statusOf('read-m2'), IMBoyMessageStatus.seen);
    } finally {
      await messageRepo.waitForFtsReindexForTest();
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });

  test(':06 dense native receive: multi-page with interleaved poisons stays stable', () async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '100',
      Keys.offlineCursorS2c: 500,
    });
    await StorageService.init();
    final db = await _fl04OpenDb();
    SqliteService.setDbForTest(db);
    final originalDevice = init.deviceId;
    final originalFeatures = AppFeatureRegistry.snapshot;
    init.deviceId = 'synthetic-cursor-device';
    AppFeatureRegistry.replaceSnapshotForTest({
      ...originalFeatures,
      'e2ee': false,
    });
    await _fl04InstallToken(100);
    final container = ProviderContainer();
    MessageRepo.setProviderContainer(container);
    final adapter = _ScriptedAdapter(
      frames: [
        _fl04S2cFrame('dense-p1-a', 1000),
        _fl04S2cFrame('dense-p1-b', 1100),
        _fl04S2cFrame('dense-p2-poison', 1200),
        _fl04S2cFrame('dense-p2-b', 1300),
        _fl04S2cFrame('dense-p3-a', 1400),
        _fl04S2cFrame('dense-p3-poison', 1500),
        _fl04S2cFrame('dense-p4-a', 1600),
        _fl04S2cFrame('dense-p4-b', 1700),
      ],
      sectionKey: 's2c',
      pageSize: 2,
      poisonIds: {'dense-p2-poison', 'dense-p3-poison'},
    );
    HttpClient.adapterForTest = adapter;
    init.serviceContainer.put(HttpClient());
    var service = MessageOfflineService.instance;
    try {
      expect(
        await service.requestPull(source: 'fl04-dense', force: true),
        isFalse,
      );
      // 毒丸帧保留 pending；全部正常帧恰好送达一次。
      expect(
        adapter.acknowledged,
        containsAll(<String>[
          'dense-p1-a',
          'dense-p1-b',
          'dense-p2-b',
          'dense-p3-a',
          'dense-p4-a',
          'dense-p4-b',
        ]),
      );
      expect(adapter.acknowledged.contains('dense-p2-poison'), isFalse);
      for (final id in [
        'dense-p1-a',
        'dense-p1-b',
        'dense-p2-b',
        'dense-p3-a',
        'dense-p4-a',
        'dense-p4-b',
      ]) {
        expect(adapter.deliveredCounts[id], 1);
      }
      expect(
        MessageOfflineService.readStoredCursor(Keys.offlineCursorS2c),
        500,
      );

      service.onDispose();
      service = MessageOfflineService.instance;
      adapter.repaired = true;
      expect(
        await service.requestPull(source: 'fl04-dense-repair', force: true),
        isTrue,
      );
      // 全帧恰一次业务效果；总请求数有界（≤ 每轮 20 页）。
      expect(adapter.acknowledged.length, 8);
      expect(adapter.queryLog.length, lessThan(20));
      expect(
        MessageOfflineService.readStoredCursor(Keys.offlineCursorS2c),
        1500,
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
