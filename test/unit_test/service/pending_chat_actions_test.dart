import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/pending_chat_actions.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import '../../fixtures/sqlite_migration/migration_inventory.dart';
import '../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _DelayedPendingStore extends InMemorySharedPreferencesStore {
  _DelayedPendingStore() : super.empty();
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${PendingChatActions.readReceiptsKey}' &&
        !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  final pending = PendingChatActions.instance;
  const reads = PendingChatActions.readReceiptsKey;
  const reactions = PendingChatActions.reactionsKey;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test(
    'account removal keeps foreign owners even when action ids are equal',
    () async {
      for (final key in [reads, reactions]) {
        await StorageService.to.setString(
          key,
          jsonEncode([
            {'from': 'A', 'id': 'same'},
            {'from': 'AB', 'id': 'same'},
            {'from': 'B', 'id': 'same'},
          ]),
        );
      }
      await pending.validateAccountRemoval('A');
      await pending.removeAccount('A');
      for (final key in [reads, reactions]) {
        expect(await pending.snapshot(key), [
          {'from': 'AB', 'id': 'same'},
          {'from': 'B', 'id': 'same'},
        ]);
      }
      await pending.removeAccount('A');
      expect(await pending.snapshot(reads), hasLength(2));
    },
  );

  for (final unknown in [
    '{',
    '{}',
    '[1]',
    '[{}]',
    '[{"from":""}]',
    '[{"from":100}]',
  ]) {
    test(
      'unknown pending ownership refuses preflight and removal without partial changes: $unknown',
      () async {
        final retained = jsonEncode([
          {'from': 'A', 'id': 'read'},
        ]);
        await StorageService.to.setString(reads, retained);
        await StorageService.to.setString(reactions, unknown);
        await expectLater(
          pending.validateAccountRemoval('A'),
          throwsA(isA<AccountLocalDataOwnershipException>()),
        );
        await expectLater(
          pending.removeAccount('A'),
          throwsA(isA<AccountLocalDataOwnershipException>()),
        );
        expect(StorageService.to.getString(reads), retained);
        expect(StorageService.to.getString(reactions), unknown);
      },
    );
  }

  test('removal joins an in-flight mutation and stale queued updates cannot restore A', () async {
    final store = _DelayedPendingStore();
    SharedPreferencesStorePlatform.instance = store;
    var current = true;
    final write = pending.update(
      reads,
      (items) => items.addAll([
        {'from': 'A', 'id': 'A-read'},
        {'from': 'B', 'id': 'B-read'},
      ]),
      isCurrent: () => current,
    );
    await store.entered.future;
    final cleanup = pending.removeAccount('A');
    final late = pending.update(
      reads,
      (items) => items.add({'from': 'A', 'id': 'late'}),
      isCurrent: () => current,
    );
    current = false;
    try {
      store.release.complete();
      await Future.wait([write, cleanup, late]);
      expect(await pending.snapshot(reads), [
        {'from': 'B', 'id': 'B-read'},
      ]);
      final persisted = await store.getAll();
      expect(jsonDecode(persisted['flutter.$reads'] as String), [
        {'from': 'B', 'id': 'B-read'},
      ]);
    } finally {
      if (!store.release.isCompleted) store.release.complete();
      await Future.wait([write, cleanup, late]);
    }
  });

  group('FL-03 编辑版本与撤回先到终态收敛', () {
    late Database fl03Db;
    late ProviderContainer fl03Container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        Keys.currentUid: '100',
        Keys.currentUser: '{"uid": "100"}',
      });
      String enc(Object v) =>
          base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
      FlutterSecureStorage.setMockInitialValues({
        'secure_token':
            '${enc({'alg': 'none'})}.${enc({'exp': 4102444800, 'uid': 100})}.test',
      });
      await StorageService.init();
      databaseFactory = databaseFactoryFfi;
      sqfliteFfiInit();
      fl03Db = await openFixtureDatabaseAtVersion(
        version: kInventoryCurrentDbVersion,
      );
      SqliteService.setDbForTest(fl03Db);
      fl03Container = ProviderContainer();
      MessageService.setProviderContainer(fl03Container);
    });

    tearDown(() async {
      fl03Container.dispose();
      SqliteService.setDbForTest(null);
      await fl03Db.close();
    });

    Future<void> seedMessage(
      String id, {
      int fromId = 1001,
      int toId = 100,
      int isAuthor = 0,
      String text = 'original',
    }) async {
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      await repo.insert(
        MessageModel(
          id,
          autoId: 0,
          type: 'C2C',
          status: 20,
          fromId: fromId,
          toId: toId,
          payload: {'msg_type': 'text', 'text': text},
          isAuthor: isAuthor,
          conversationUk3: 'C2C_${fromId}_$toId',
          msgType: 'text',
          createdAt: 1751850000000,
        ),
      );
    }

    Future<void> seedConversation(
      String lastMsgId, {
      int unread = 1,
      String subtitle = 'original',
    }) async {
      await fl03Db.insert('conversation', {
        'user_id': 100,
        'peer_id': 1001,
        'type': 'C2C',
        'last_msg_id': lastMsgId,
        'last_time': 1751850000000,
        'unread_num': unread,
        'subtitle': subtitle,
        'msg_type': 'text',
      });
    }

    Map<String, dynamic> peerEditFrame(
      String opId,
      String originalId,
      String content,
      int editedAt,
    ) => {
      'id': opId,
      'type': 'C2C',
      'from': '1001',
      'to': '100',
      'msg_type': 'custom',
      'action': 'message_edit',
      'payload': {
        'original_msg_id': originalId,
        'content': content,
        'edited_at': editedAt,
      },
      'server_ts': 1751850000000,
    };

    Map<String, dynamic> peerRevokeFrame(String opId, String originalId) => {
      'id': opId,
      'type': 'C2C',
      'from': '1001',
      'to': '100',
      'msg_type': 'custom',
      'action': 'message_revoke',
      'payload': {'original_msg_id': originalId},
      'server_ts': 1751850000000,
    };

    Future<Map<String, dynamic>> messagePayload(String id) async {
      final rows = await fl03Db.query(
        'msg_c2c',
        columns: ['payload', 'status'],
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows, hasLength(1));
      return jsonDecode(rows.first['payload'] as String)
          as Map<String, dynamic>;
    }

    test('1.1 顺序编辑：v1→v2，权威最新为 v2', () async {
      const id = 'fl03m00000000000001';
      await seedMessage(id);
      await seedConversation(id);
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000001a', id, 'v1', 1000),
      );
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000001b', id, 'v2', 2000),
      );
      await pumpEventQueue(times: 50);
      final payload = await messagePayload(id);
      expect(payload['text'], 'v2');
      expect(payload['edited_at'], 2000);
      expect(payload['is_edited'], true);
    });

    test('1.2 反序：v2 先落，旧 v1 后到不回退正文（无静默覆盖）', () async {
      const id = 'fl03m00000000000002';
      await seedMessage(id);
      await seedConversation(id);
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000002a', id, 'v2', 2000),
      );
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000002b', id, 'stale-v1', 1000),
      );
      await pumpEventQueue(times: 50);
      final payload = await messagePayload(id);
      expect(payload['text'], 'v2', reason: '旧版本编辑不得回退权威最新正文');
      expect(payload['edited_at'], 2000);
    });

    test('1.3 并发同窗编辑：收敛到唯一终态，不崩溃不半写', () async {
      const id = 'fl03m00000000000003';
      await seedMessage(id);
      await seedConversation(id);
      // 同一版本时戳的两个并发编辑交错到达：后到者胜出为确定性行为，
      // 关键断言是唯一终态 + 无异常 + 无半写。
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000003a', id, 'a', 3000),
      );
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000003b', id, 'b', 3000),
      );
      await pumpEventQueue(times: 50);
      final payload = await messagePayload(id);
      expect(payload['text'], anyOf('a', 'b'));
      expect(payload['is_edited'], true);
    });

    test('1.4 旧设备重放已应用编辑：幂等，不重复联动', () async {
      const id = 'fl03m00000000000004';
      await seedMessage(id);
      await seedConversation(id);
      final frame = peerEditFrame('fl03op0000000004a', id, 'v2', 2000);
      await MessageService.to.processMessage('C2C', frame);
      await pumpEventQueue(times: 50);
      // 同帧重放（旧设备重投）：正文与版本不变
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000004b', id, 'v2', 2000),
      );
      await pumpEventQueue(times: 50);
      final payload = await messagePayload(id);
      expect(payload['text'], 'v2');
      expect(payload['edited_at'], 2000);
      final conv = await fl03Db.query(
        'conversation',
        where: 'peer_id = ?',
        whereArgs: [1001],
      );
      expect(conv.first['subtitle'], 'v2');
    });

    test('2.1/2.2 撤回先到：正文不复活，晚到编辑被拒', () async {
      const id = 'fl03m00000000000005';
      await seedMessage(id);
      await seedConversation(id);
      // 撤回先到（终态）
      await MessageService.to.processMessage(
        'C2C',
        peerRevokeFrame('fl03op0000000005r', id),
      );
      await pumpEventQueue(times: 50);
      var rows = await fl03Db.query(
        'msg_c2c',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows.first['status'], IMBoyMessageStatus.peerRevoked);

      // 晚到的编辑帧：edit target changed or revoked 路径，正文不复活
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000005e', id, 'zombie-edit', 9000),
      );
      await pumpEventQueue(times: 50);
      final payload = await messagePayload(id);
      expect(payload['text'], isNot('zombie-edit'), reason: '撤回终态后正文不得被晚到编辑复活');
      rows = await fl03Db.query(
        'msg_c2c',
        columns: ['status'],
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(
        rows.first['status'],
        IMBoyMessageStatus.peerRevoked,
        reason: '2.3 控制事实（撤回状态）可恢复且不被后续帧清除',
      );
    });

    test('3.1/3.3 客户端时钟被改与时间倒挂：服务端权威时戳生效', () async {
      const id = 'fl03m00000000000006';
      await seedMessage(id);
      await seedConversation(id);
      // 客户端不采信本地时钟：落库 edited_at == 帧携带的服务端时戳
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000006a', id, 'v2', 2000),
      );
      await pumpEventQueue(times: 50);
      var payload = await messagePayload(id);
      expect(payload['edited_at'], 2000, reason: '本地时钟（≈1.79e12）不得覆盖服务端时戳');

      // 伪造时间倒挂的旧编辑（incoming < existing）：单调钳制保持权威
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000006b', id, 'forged-old', 1000),
      );
      await pumpEventQueue(times: 50);
      payload = await messagePayload(id);
      expect(payload['text'], 'v2');
      expect(payload['edited_at'], 2000);
    });

    test('4.1 编辑旧消息时新消息已成最后一条：预览不回退', () async {
      const olderId = 'fl03m00000000000007';
      await seedMessage(olderId);
      // 会话最后一条指向更新的消息
      await seedConversation('fl03m00000000000008', subtitle: 'newest');
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000007a', olderId, 'edit-old', 7000),
      );
      await pumpEventQueue(times: 50);
      final payload = await messagePayload(olderId);
      expect(payload['text'], 'edit-old', reason: '旧消息编辑仍落库');
      final conv = await fl03Db.query(
        'conversation',
        where: 'peer_id = ?',
        whereArgs: [1001],
      );
      expect(conv.first['subtitle'], 'newest', reason: '会话预览不被旧编辑回退');
      expect(conv.first['last_msg_id'], 'fl03m00000000000008', reason: '排序键不变');
    });

    test('4.2 编辑不产生未读联动；4.3 会话行缺失时消息编辑仍落库', () async {
      // 4.2：unread 不因编辑变化
      const idA = 'fl03m00000000000009';
      await seedMessage(idA);
      await seedConversation(idA, unread: 3);
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000009a', idA, 'no-unread', 9000),
      );
      await pumpEventQueue(times: 50);
      var conv = await fl03Db.query(
        'conversation',
        columns: ['unread_num'],
        where: 'peer_id = ?',
        whereArgs: [1001],
      );
      expect(conv.first['unread_num'], 3, reason: '编辑不增不减未读');

      // 4.3：会话行缺失 → 消息编辑仍成功落库（无半写、不抛出）
      const idB = 'fl03m00000000000010';
      await seedMessage(idB);
      await MessageService.to.processMessage(
        'C2C',
        peerEditFrame('fl03op0000000010a', idB, 'orphan-edit', 10000),
      );
      await pumpEventQueue(times: 50);
      final payload = await messagePayload(idB);
      expect(payload['text'], 'orphan-edit');
    });
  });
}
