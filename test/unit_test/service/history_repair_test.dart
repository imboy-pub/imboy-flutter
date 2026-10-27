import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/config/env.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _RepairApi extends MsgApi {
  int safeHead = 20;
  bool blocked = true;
  int? failAfter;
  int? nextSeq;
  int step = 10;
  bool emitRows = true;
  Map<String, dynamic>? malformed;
  final afterCalls = <int>[];

  @override
  Future<Map<String, dynamic>?> history({
    required String chatType,
    required String peerId,
    int afterSeq = 0,
    int limit = 50,
    String did = '',
  }) async => {
    'messages': <dynamic>[],
    'next_seq': nextSeq ?? afterSeq,
    'safe_head': safeHead,
    'blocked': blocked,
    'has_more': false,
  };

  @override
  Future<Map<String, dynamic>?> historyBackfill({
    required String chatType,
    required String peerId,
    int afterSeq = 0,
    int limit = 50,
    String did = '',
  }) async {
    afterCalls.add(afterSeq);
    if (afterSeq == failAfter) return null;
    if (malformed != null) return malformed;
    final end = (afterSeq + step).clamp(0, safeHead);
    return {
      'messages': [
        for (var seq = afterSeq + 1; emitRows && seq <= end; seq++)
          {
            'msg_id': 'repair-$seq',
            'type': 'C2C',
            'from': '990001',
            'to': '990002',
            'msg_type': 'text',
            'created_at': 1750000000000,
            'conv_seq': seq,
            'accepted_at': '2025-06-15T15:06:40Z',
            'payload': {'text': 'message-$seq'},
          },
      ],
      'next_seq': end,
      'has_more': end < safeHead,
    };
  }
}

class _OtherServer implements Env {
  @override
  String get apiBaseUrl => 'https://other-server.invalid';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PausedRepairApi extends _RepairApi {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Map<String, dynamic>?> historyBackfill({
    required String chatType,
    required String peerId,
    int afterSeq = 0,
    int limit = 50,
    String did = '',
  }) async {
    final response = await super.historyBackfill(
      chatType: chatType,
      peerId: peerId,
      afterSeq: afterSeq,
      limit: limit,
      did: did,
    );
    entered.complete();
    await release.future;
    return response;
  }
}

class _IncomingRepairApi extends _RepairApi {
  @override
  Future<Map<String, dynamic>?> historyBackfill({
    required String chatType,
    required String peerId,
    int afterSeq = 0,
    int limit = 50,
    String did = '',
  }) async {
    final response = await super.historyBackfill(
      chatType: chatType,
      peerId: peerId,
      afterSeq: afterSeq,
      limit: limit,
      did: did,
    );
    return {
      ...response!,
      'messages': [
        for (final row in response['messages'] as List)
          {
            ...row as Map<String, dynamic>,
            'from': '990002',
            'to': '990001',
            'payload': {'text': ''},
          },
      ],
    };
  }
}

class _NotificationAwaitDatabase implements Database {
  _NotificationAwaitDatabase(this.delegate);

  final Database delegate;
  final entered = Completer<void>();
  final release = Completer<void>();
  bool committed = false;

  @override
  bool get isOpen => delegate.isOpen;

  @override
  Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool? exclusive,
  }) async {
    final result = await delegate.transaction(action, exclusive: exclusive);
    committed = true;
    return result;
  }

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
    final rows = await delegate.query(
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
    if (table == 'contact' && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return rows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RepairPreferenceStore extends InMemorySharedPreferencesStore {
  _RepairPreferenceStore() : super.empty();
  String failure = '';
  Completer<void>? uidWriteEntered;
  Completer<void>? uidWriteRelease;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.endsWith(Keys.currentUid) && value == '990002') {
      uidWriteEntered?.complete();
      await uidWriteRelease?.future;
    }
    if (key.contains('_repair_v2_')) {
      if (failure == 'throw') throw StateError('synthetic preference failure');
      if (failure == 'false') return Future.value(false);
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database database;
  late ProviderContainer container;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '990001'});
    await StorageService.init();
    currentEnv = 'local';
    database = await openFixtureDatabaseAtVersion(version: 35);
    SqliteService.setDbForTest(database);
    container = ProviderContainer();
    MessageRepo.setProviderContainer(container);
  });
  tearDown(() async {
    container.dispose();
    SqliteService.setDbForTest(null);
    await database.close();
  });

  test('P2 API挂起时切号及清理历史key，旧任务不得写新库或复活断点', () async {
    const convKey = '990001_C2C_990002';
    final cursorKey = '${Keys.msgHistorySeqPrefix}$convKey';
    final store = _RepairPreferenceStore();
    SharedPreferencesStorePlatform.instance = store;
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '990001');
    await StorageService.to.setInt(cursorKey, 40);
    final nextDatabase = await openFixtureDatabaseAtVersion(version: 35);
    final api = _PausedRepairApi()..safeHead = 1;
    final pending = ChatArchiveService(api: api)
        .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002')
        .then<Object?>((_) => null, onError: (Object error) => error);
    Future<bool>? switching;
    try {
      await api.entered.future.timeout(const Duration(seconds: 5));
      store.uidWriteEntered = Completer<void>();
      store.uidWriteRelease = Completer<void>();
      switching = StorageService.to.setString(Keys.currentUid, '990002');
      await store.uidWriteEntered!.future.timeout(const Duration(seconds: 5));
      expect(StorageService.to.getString(Keys.currentUid), '990002');
      for (final key
          in StorageService.to
              .getKeys()
              .where((key) => key.startsWith(Keys.msgHistorySeqPrefix))
              .toList()) {
        await StorageService.to.remove(key);
      }
      SqliteService.setDbForTest(nextDatabase);
      api.release.complete();
      final outcome = await pending.timeout(const Duration(seconds: 5));
      expect(outcome, isA<HistoryFetchException>());
      expect(await nextDatabase.query('msg_c2c'), isEmpty);
      expect(await nextDatabase.query('conversation'), isEmpty);
      expect(await database.query('msg_c2c'), isEmpty);
      expect(
        StorageService.to.getKeys().where(
          (key) => key.startsWith(Keys.msgHistorySeqPrefix),
        ),
        isEmpty,
      );
      expect(ChatArchiveService.overshootWatermark(convKey), 0);
    } finally {
      if (!api.release.isCompleted) api.release.complete();
      if (store.uidWriteRelease?.isCompleted == false) {
        store.uidWriteRelease!.complete();
      }
      await switching;
      await pending;
      SqliteService.setDbForTest(database);
      await nextDatabase.close();
    }
  });

  test('P2 API挂起时切换endpoint，旧任务失效且不写新库或断点', () async {
    const convKey = '990001_C2C_990002';
    final cursorKey = '${Keys.msgHistorySeqPrefix}$convKey';
    await StorageService.to.setInt(cursorKey, 40);
    final nextDatabase = await openFixtureDatabaseAtVersion(version: 35);
    final originalEnv = envMap['local']!;
    final api = _PausedRepairApi()..safeHead = 1;
    final pending = ChatArchiveService(api: api)
        .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002')
        .then<Object?>((_) => null, onError: (Object error) => error);
    try {
      await api.entered.future.timeout(const Duration(seconds: 5));
      envMap['local'] = _OtherServer();
      SqliteService.setDbForTest(nextDatabase);
      api.release.complete();
      final outcome = await pending.timeout(const Duration(seconds: 5));
      expect(outcome, isA<HistoryFetchException>());
      expect(await nextDatabase.query('msg_c2c'), isEmpty);
      expect(await nextDatabase.query('conversation'), isEmpty);
      expect(await database.query('msg_c2c'), isEmpty);
      expect(StorageService.to.getInt(cursorKey), 40);
      expect(
        StorageService.to.getKeys().where(
          (key) => key.startsWith(Keys.msgHistorySeqPrefix),
        ),
        [cursorKey],
      );
      expect(ChatArchiveService.overshootWatermark(convKey), 0);
    } finally {
      if (!api.release.isCompleted) api.release.complete();
      await pending;
      envMap['local'] = originalEnv;
      SqliteService.setDbForTest(database);
      await nextDatabase.close();
    }
  });

  test('P2 归档提交后通知await切号，旧任务不得复活主或repair断点', () async {
    const convKey = 'C2C_990001_990002';
    final cursorKey = '${Keys.msgHistorySeqPrefix}$convKey';
    await StorageService.to.setInt(cursorKey, 40);
    await ChatArchiveService.markOvershootBackfilled(convKey, 1);
    await database.insert('contact', {
      'user_id': '990001',
      'peer_id': '990002',
      'nickname': 'synthetic peer',
    });
    final nextDatabase = await openFixtureDatabaseAtVersion(version: 35);
    final notificationDatabase = _NotificationAwaitDatabase(database);
    SqliteService.setDbForTest(notificationDatabase);
    MessageRepo.setCurrentActiveConversationUk3(convKey);
    final api = _IncomingRepairApi()..safeHead = 2;
    final pending = ChatArchiveService(api: api)
        .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002')
        .then<Object?>((_) => null, onError: (Object error) => error);
    try {
      await notificationDatabase.entered.future.timeout(
        const Duration(seconds: 5),
      );
      expect(notificationDatabase.committed, isTrue);
      final committedRows = await database.query('msg_c2c');
      expect(committedRows.single['conv_seq'], 2);
      expect(committedRows.single['conversation_uk3'], convKey);
      final committedConversations = await database.query('conversation');
      expect(committedConversations, hasLength(1));
      expect(StorageService.to.getInt(cursorKey), 40);
      expect(ChatArchiveService.overshootWatermark(convKey), 1);

      await StorageService.to.setString(Keys.currentUid, '990002');
      expect(ChatArchiveService.overshootWatermark(convKey), 0);
      for (final key
          in StorageService.to
              .getKeys()
              .where((key) => key.startsWith(Keys.msgHistorySeqPrefix))
              .toList()) {
        await StorageService.to.remove(key);
      }
      SqliteService.setDbForTest(nextDatabase);
      notificationDatabase.release.complete();

      final outcome = await pending.timeout(const Duration(seconds: 5));
      expect(outcome, isA<HistoryFetchException>());
      expect(await nextDatabase.query('msg_c2c'), isEmpty);
      expect(await nextDatabase.query('conversation'), isEmpty);
      expect(await database.query('msg_c2c'), committedRows);
      expect(await database.query('conversation'), committedConversations);
      expect(
        StorageService.to.getKeys().where(
          (key) => key.startsWith(Keys.msgHistorySeqPrefix),
        ),
        isEmpty,
      );
      expect(ChatArchiveService.overshootWatermark(convKey), 0);
      final persisted = await SharedPreferencesStorePlatform.instance.getAll();
      expect(
        persisted.keys.where(
          (key) => key.startsWith('flutter.${Keys.msgHistorySeqPrefix}'),
        ),
        isEmpty,
      );
    } finally {
      if (!notificationDatabase.release.isCompleted) {
        notificationDatabase.release.complete();
      }
      await pending;
      MessageRepo.setCurrentActiveConversationUk3(null);
      SqliteService.setDbForTest(database);
      await nextDatabase.close();
    }
  });

  test('旧游标超过安全边界且blocked时仍修复已安全的前缀', () {
    final plan = ChatArchiveService.planHistorySync(
      currentSeq: 40,
      nextSeq: 40,
      safeHead: 20,
      blocked: true,
      gaps: const [],
      overshootScannedTo: 0,
    );
    expect(plan.advanceTo, 40);
    expect(plan.backfillRanges, [(fromSeq: 0, toSeq: 20)]);
  });

  test('旧游标落在安全边界内也必须补齐旧版本遗漏', () {
    final plan = ChatArchiveService.planHistorySync(
      currentSeq: 2,
      nextSeq: 3,
      safeHead: 3,
      blocked: false,
      gaps: const [],
      overshootScannedTo: 0,
    );
    expect(plan.backfillRanges, [(fromSeq: 0, toSeq: 2)]);
  });

  test('safe_head为零不能退化成next_seq并跳过待归档消息', () {
    final plan = ChatArchiveService.planHistorySync(
      currentSeq: 0,
      nextSeq: 2,
      safeHead: 0,
      blocked: false,
      gaps: const [],
    );
    expect(plan.advanceTo, 0);
    expect(plan.backfillRanges, isEmpty);
  });

  test('blocked过冲实际补扫入库，预算耗尽后新实例从持久断点续扫', () async {
    const convKey = '990001_C2C_990002';
    final cursorKey = '${Keys.msgHistorySeqPrefix}$convKey';
    await StorageService.to.setInt(cursorKey, 40);
    final api = _RepairApi();
    await ChatArchiveService(api: api).syncHistory(
      convKey: convKey,
      chatType: 'C2C',
      peerId: '990002',
      maxPages: 2,
    );
    expect(api.afterCalls, [0]);
    expect(ChatArchiveService.overshootWatermark(convKey), 10);
    expect(StorageService.to.getInt(cursorKey), 40);
    await StorageService.init();
    await ChatArchiveService(api: api).syncHistory(
      convKey: convKey,
      chatType: 'C2C',
      peerId: '990002',
      maxPages: 2,
    );
    expect(api.afterCalls, [0, 10]);
    expect(ChatArchiveService.overshootWatermark(convKey), 20);
    final rows = await database.query('msg_c2c', orderBy: 'conv_seq');
    expect(
      rows.map((row) => row['conv_seq']),
      List.generate(20, (index) => index + 1),
    );
    await ChatArchiveService(api: api)
        .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002');
    expect(api.afterCalls, [0, 10]);
    final oldEnv = envMap['pro']!;
    envMap['pro'] = _OtherServer();
    addTearDown(() => envMap['pro'] = oldEnv);
    currentEnv = 'pro';
    expect(ChatArchiveService.overshootWatermark(convKey), 0);
    currentEnv = 'local';
    expect(ChatArchiveService.overshootWatermark('other-account'), 0);
    expect(ChatArchiveService.overshootWatermark(convKey), 20);
  });

  test('中途API失败只保留已提交断点，重复补扫幂等且不改未读', () async {
    const convKey = '990001_C2C_990002';
    await StorageService.to.setInt('${Keys.msgHistorySeqPrefix}$convKey', 40);
    final api = _RepairApi()..failAfter = 10;
    await expectLater(
      ChatArchiveService(api: api)
          .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002'),
      throwsA(isA<HistoryFetchException>()),
    );
    expect(ChatArchiveService.overshootWatermark(convKey), 10);
    api.failAfter = null;
    await ChatArchiveService(api: api)
        .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002');
    final before = await database.query('conversation');
    await ChatArchiveService(api: api).backfillMissing(
      chatType: 'C2C',
      peerId: '990002',
      afterSeq: 0,
      targetSeq: 20,
    );
    expect((await database.query('msg_c2c')).length, 20);
    expect(await database.query('conversation'), before);
    expect(api.afterCalls, [0, 10, 10, 0, 10]);
  });

  test('坏补扫页及无进度不得推进持久断点', () async {
    const convKey = '990001_C2C_990002';
    await StorageService.to.setInt('${Keys.msgHistorySeqPrefix}$convKey', 40);
    for (final response in [
      {
        'messages': [null],
        'next_seq': 20,
        'has_more': false,
      },
      {
        'messages': <Map<String, dynamic>>[{}],
        'next_seq': 20,
        'has_more': false,
      },
      {'messages': <dynamic>[], 'next_seq': 0, 'has_more': true},
    ]) {
      final api = _RepairApi()..malformed = response;
      await expectLater(
        ChatArchiveService(api: api)
            .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002'),
        throwsA(isA<HistoryFetchException>()),
      );
      expect(ChatArchiveService.overshootWatermark(convKey), 0);
    }
  });

  test('旧游标仍在安全范围内时真实补回低序号集合', () async {
    const convKey = '990001_C2C_990002';
    final cursorKey = '${Keys.msgHistorySeqPrefix}$convKey';
    await StorageService.to.setInt(cursorKey, 2);
    final api = _RepairApi()
      ..safeHead = 3
      ..blocked = false
      ..nextSeq = 3;
    await ChatArchiveService(api: api)
        .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002');
    expect(api.afterCalls, [0]);
    expect(
      (await database.query(
        'msg_c2c',
        orderBy: 'conv_seq',
      )).map((row) => row['conv_seq']),
      [1, 2, 3],
    );
    expect(StorageService.to.getInt(cursorKey), 3);
    expect(ChatArchiveService.overshootWatermark(convKey), 3);
  });

  test('超过1000且存在保留空洞的历史分窗口推进并可续跑', () async {
    const convKey = '990001_C2C_990002';
    await StorageService.to.setInt('${Keys.msgHistorySeqPrefix}$convKey', 3000);
    final api = _RepairApi()
      ..safeHead = 2501
      ..step = 1000
      ..emitRows = false;
    await ChatArchiveService(api: api).syncHistory(
      convKey: convKey,
      chatType: 'C2C',
      peerId: '990002',
      maxPages: 3,
    );
    expect(api.afterCalls, [0, 1000]);
    expect(ChatArchiveService.overshootWatermark(convKey), 2000);
    await ChatArchiveService(api: api).syncHistory(
      convKey: convKey,
      chatType: 'C2C',
      peerId: '990002',
      maxPages: 2,
    );
    expect(api.afterCalls, [0, 1000, 2000]);
    expect(ChatArchiveService.overshootWatermark(convKey), 2501);
  });

  test('SQLite提交失败不得标记完成或推进修复断点', () async {
    const convKey = '990001_C2C_990002';
    final cursorKey = '${Keys.msgHistorySeqPrefix}$convKey';
    await StorageService.to.setInt(cursorKey, 40);
    await database.execute('DROP TABLE msg_c2c');
    await expectLater(
      ChatArchiveService(api: _RepairApi())
          .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002'),
      throwsA(isA<Exception>()),
    );
    expect(ChatArchiveService.overshootWatermark(convKey), 0);
    expect(StorageService.to.getInt(cursorKey), 40);
  });

  test('安全边界为零时实际同步不推进两类游标也不发补扫', () async {
    const convKey = 'zero-safe-head';
    final api = _RepairApi()
      ..safeHead = 0
      ..nextSeq = 2
      ..blocked = false;
    await ChatArchiveService(api: api)
        .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002');
    expect(api.afterCalls, isEmpty);
    expect(
      StorageService.to.getInt('${Keys.msgHistorySeqPrefix}$convKey'),
      isNull,
    );
    expect(ChatArchiveService.overshootWatermark(convKey), 0);
  });

  for (final failure in ['false', 'throw']) {
    test('修复断点保存$failure时回滚缓存并从原断点幂等重试', () async {
      const convKey = '990001_C2C_990002';
      final store = _RepairPreferenceStore();
      SharedPreferencesStorePlatform.instance = store;
      await StorageService.init();
      await StorageService.to.setString(Keys.currentUid, '990001');
      await StorageService.to.setInt('${Keys.msgHistorySeqPrefix}$convKey', 40);
      store.failure = failure;
      final api = _RepairApi();
      await expectLater(
        ChatArchiveService(api: api)
            .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002'),
        throwsStateError,
      );
      expect(ChatArchiveService.overshootWatermark(convKey), 0);
      store.failure = '';
      await ChatArchiveService(api: api)
          .syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002');
      expect(api.afterCalls, [0, 0, 10]);
      expect(ChatArchiveService.overshootWatermark(convKey), 20);
      expect((await database.query('msg_c2c')).length, 20);
    });
  }

  test('重复归档权威字段补齐失败不得被ACK掩盖或推进断点', () async {
    const convKey = '990001_C2C_990002';
    final api = _RepairApi()..safeHead = 1;
    final service = ChatArchiveService(api: api);
    await service.backfillMissing(
      chatType: 'C2C',
      peerId: '990002',
      afterSeq: 0,
      targetSeq: 1,
    );
    await database.execute(
      'UPDATE msg_c2c SET conv_seq = NULL, accepted_at = NULL',
    );
    await database.execute(
      "CREATE TRIGGER fail_archive_facts BEFORE UPDATE OF conv_seq, accepted_at "
      "ON msg_c2c BEGIN SELECT RAISE(ABORT, 'synthetic fact failure'); END",
    );
    await StorageService.to.setInt('${Keys.msgHistorySeqPrefix}$convKey', 40);
    await expectLater(
      service.syncHistory(convKey: convKey, chatType: 'C2C', peerId: '990002'),
      throwsA(isA<Exception>()),
    );
    expect(ChatArchiveService.overshootWatermark(convKey), 0);
    await database.execute('DROP TRIGGER fail_archive_facts');
    await service.syncHistory(
      convKey: convKey,
      chatType: 'C2C',
      peerId: '990002',
    );
    final row = (await database.query('msg_c2c')).single;
    expect(row['conv_seq'], 1);
    expect(row['accepted_at'], 1750000000000);
    expect(ChatArchiveService.overshootWatermark(convKey), 1);
  });
}
