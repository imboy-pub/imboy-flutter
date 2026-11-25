// 离线拉取进度域：:03 无进度分页有界失败 / :04 c2g 游标按 env+uid 隔离 /
// :05 已读未读分离 / :06 密集原生接收多页毒帧交错稳定。
//
// 拆分自原 offline_cursor_recovery_test.dart（ratchet <800 行约束）；
// 共享 adapter fixture 见 offline_cursor_recovery_support.dart。

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

import 'offline_cursor_recovery_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    ':03 progress-less pagination (same timestamp / empty page) fails bounded',
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
      final adapter = ScriptedPullAdapter(
        // 同时间戳帧：next_last_msg_at 恒等于请求游标 → 无进展。
        frames: [fl04S2cFrame('stuck-frame', 500)],
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
      final db = await fl04OpenDb();
      SqliteService.setDbForTest(db);
      final originalDevice = init.deviceId;
      final originalFeatures = AppFeatureRegistry.snapshot;
      init.deviceId = 'synthetic-cursor-device';
      AppFeatureRegistry.replaceSnapshotForTest({
        ...originalFeatures,
        'e2ee': false,
      });
      await fl04InstallToken(105);
      final container = ProviderContainer();
      MessageRepo.setProviderContainer(container);
      final adapter = ScriptedPullAdapter(
        frames: [fl04C2cFrame('c2g-scope-a', 2000)],
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
    final db = await fl04OpenDb();
    SqliteService.setDbForTest(db);
    final originalDevice = init.deviceId;
    final originalFeatures = AppFeatureRegistry.snapshot;
    init.deviceId = 'synthetic-cursor-device';
    AppFeatureRegistry.replaceSnapshotForTest({
      ...originalFeatures,
      'e2ee': false,
    });
    await fl04InstallToken(106);
    final container = ProviderContainer();
    MessageRepo.setProviderContainer(container);
    final frames = [
      fl04S2cFrame('switch-page-1', 2000),
      fl04S2cFrame('switch-page-2', 3000),
    ];
    final adapter =
        ScriptedPullAdapter(frames: frames, sectionKey: 's2c', pageSize: 1)
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
    final db = await fl04OpenDb();
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
        fl04S2cFrame('dense-p1-a', 1000),
        fl04S2cFrame('dense-p1-b', 1100),
        fl04S2cFrame('dense-p2-poison', 1200),
        fl04S2cFrame('dense-p2-b', 1300),
        fl04S2cFrame('dense-p3-a', 1400),
        fl04S2cFrame('dense-p3-poison', 1500),
        fl04S2cFrame('dense-p4-a', 1600),
        fl04S2cFrame('dense-p4-b', 1700),
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
