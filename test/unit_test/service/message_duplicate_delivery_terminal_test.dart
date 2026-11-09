/// M02（AT03 / P0 重复结果）App 腿场景级补测 —— 终态不倒退 + 版本/序列单调
///
/// 收口缺口（closure-20261108 / M02_ASSERTION_MAP.md 行 2、行 5 标 NOT_COVERED）：
/// - 行 2「终态不倒退」：已终态消息收到重复投递/重复 ACK，终态不得回退到中间态
/// - 行 5「版本/序列有序处理」：同 msg_id 多投递下版本/序列单调
///
/// 全部驱动真实行为路径（禁自 mock）：
/// 1. 内容重复投递：`MessageService.to.processMessage` → `_receiveMessage` 的
///    existing-row 幂等短路（lib/service/message.dart L595-597）→ `AckManager.sendAck`
///    （去重跳过执行但仍逐次 ACK，阻止服务端按 2/5/7/11s 窗口继续重投）
/// 2. 重复 ACK：`ServerAckReceipts.persist` 的 CAS 守卫仅允许
///    in-flight{sending,pendingRetry,error} → sent，终态行重放一律拒绝；
///    `record` 以 (uid,generation,id,conversation) 为 key 幂等去重
/// 3. S2C 帧重复投递：`MessageS2CService.switchS2C` 去重层（key 单点登记 + TTL）
///    与 `_peerKeyChangedFiredAtMs` 频控版本戳的单调性
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_s2c.dart';
import 'package:imboy/service/server_ack_receipts.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

/// 列集合对齐 message_retry_terminal_state_test.dart（repo.insert / find /
/// persist 查询的完整列面），msg_c2c_fts 供 insert 后的延迟 FTS 重索引任务使用。
const String _msgC2cDdl = '''
  CREATE TABLE msg_c2c (
    auto_id INTEGER PRIMARY KEY AUTOINCREMENT,
    id TEXT,
    type TEXT,
    from_id INTEGER,
    to_id INTEGER,
    payload TEXT,
    created_at INTEGER,
    is_author INTEGER,
    status INTEGER,
    conversation_uk3 TEXT,
    topic_id INTEGER,
    msg_type TEXT,
    action TEXT,
    e2ee TEXT,
    sender_did TEXT
  )
''';

const String _msgC2cFtsDdl = '''
  CREATE TABLE msg_c2c_fts (
    id TEXT,
    conversation_uk3 TEXT,
    text_content TEXT
  )
''';

const String _sendAttemptDdl = '''
  CREATE TABLE message_send_attempt (
    user_id TEXT,
    anchor TEXT,
    token TEXT,
    PRIMARY KEY(user_id, anchor, token)
  )
''';

const String _ownerUid = '1001';
const String _peerUid = '2002';

/// 生命周期阶梯秩（对齐 lib/store/model/message_model.dart 的状态带注释）：
/// 中间态（sending/pendingRetry/error，可相互流转、可被 ACK 推进）= 0；
/// sent(11) 客户端发送完成 = 1；delivered(20) = 2；seen(21) = 3；撤回(30/31) = 4。
/// M02 行 2/5 的单调性定义：同一 msg_id 的观测状态序列秩不得下降。
int _lifecycleRank(int? status) {
  if (status == null) return -1;
  if (status == IMBoyMessageStatus.sent) return 1;
  if (status == IMBoyMessageStatus.delivered) return 2;
  if (status == IMBoyMessageStatus.seen) return 3;
  if (IMBoyMessageStatus.isRevokedStatus(status)) return 4;
  if (IMBoyMessageStatus.isSendingStatus(status)) return 0;
  if (IMBoyMessageStatus.isErrorStatus(status)) return 0;
  return -1;
}

Future<void> _insertC2cMsg(
  String id, {
  required int status,
  required int isAuthor,
}) async {
  final repo = MessageRepo(tableName: MessageRepo.c2cTable);
  await repo.insert(
    MessageModel(
      id,
      autoId: 0,
      type: 'C2C',
      status: status,
      fromId: isAuthor == 1 ? _ownerUid : _peerUid,
      toId: isAuthor == 1 ? _peerUid : _ownerUid,
      payload: {'msg_type': 'text', 'text': 'm02 original text'},
      isAuthor: isAuthor,
      conversationUk3: 'C2C_${_ownerUid}_$_peerUid',
      msgType: 'text',
      createdAt: 1751850000000,
    ),
  );
  // 对照组前置校验（红 = 种子本身有错，后续绿灯无意义）
  final seeded = await MessageRepo(tableName: MessageRepo.c2cTable).find(id);
  expect(seeded, isNotNull, reason: '种子消息必须落库成功');
  expect(seeded!.status, status, reason: '种子消息状态必须与预期一致');
}

/// 倒序场景种子：后发生的「撤回」事件（事件 2）已生效为终态，先发生的
/// 「内容投递」（事件 1）稍后重复到达。终态置位方式与
/// server_ack_persistence_test.dart（L137 直接 db.update 置终态）同款：
/// 撤回处理本身由 c2c_revoke 分支的既有测试覆盖，此处聚焦重复投递腿。
Future<void> _seedPeerRevokedTerminal(Database db, String id) async {
  await _insertC2cMsg(id, status: IMBoyMessageStatus.delivered, isAuthor: 0);
  final revokedPayload = jsonEncode({
    'msg_type': 'text',
    'peer_name': 'peer2002',
    'text': 'm02 original text',
    'revoke_time': 1751850001000,
    'revoke_user': _peerUid,
  });
  await db.update(
    'msg_c2c',
    {'status': IMBoyMessageStatus.peerRevoked, 'payload': revokedPayload},
    where: 'id = ?',
    whereArgs: [id],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late String originalDeviceId;

  setUpAll(() async {
    sqfliteFfiInit();
    SharedPreferences.setMockInitialValues({Keys.currentUid: _ownerUid});
    await StorageService.init();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(_msgC2cDdl);
    await db.execute(_msgC2cFtsDdl);
    await db.execute(_sendAttemptDdl);
    // 与 ServerAckReceipts.persistReceipt 同源建表（setUp 需要清空该表）
    await db.execute(
      'CREATE TABLE IF NOT EXISTS server_ack_receipt '
      '(user_id TEXT NOT NULL, anchor TEXT NOT NULL, chat_type TEXT NOT NULL, '
      'conversation TEXT NOT NULL, PRIMARY KEY(user_id, anchor, chat_type))',
    );
    SqliteService.setDbForTest(db);
    originalDeviceId = init.deviceId;
    init.deviceId = 'm02-at03-device';
  });

  setUp(() async {
    await db.delete('msg_c2c');
    await db.delete('message_send_attempt');
    await db.delete('server_ack_receipt');
    AckManager.to.clear();
  });

  tearDown(() {
    AckManager.to.dispose();
  });

  tearDownAll(() {
    SqliteService.setDbForTest(null);
    init.deviceId = originalDeviceId;
    db.close();
  });

  group('M02 行 2：重复内容投递不得倒退终态（倒序：撤回终态先落、内容投递后到）', () {
    test('已撤回终态消息收到同 msg_id 重复投递×3：单条记录、终态与终态行内容不回退、逐次 ACK', () async {
      const msgId = 'm02dup00000000000001';
      await _seedPeerRevokedTerminal(db, msgId);
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      final revokedPayloadBefore = (await repo.find(msgId))!.payloadMap;

      final ackEvents = <WebSocketMessageSendRequestEvent>[];
      final sub = AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(
        ackEvents.add,
      );

      final frame = <String, dynamic>{
        'id': msgId,
        'type': 'C2C',
        'msg_type': 'text',
        'from': _peerUid,
        'to': _ownerUid,
        'created_at': 1751850000000,
        'payload': {'msg_type': 'text', 'text': 'm02 original text'},
      };
      try {
        for (var delivery = 1; delivery <= 3; delivery++) {
          await MessageService.to.processMessage(
            'C2C',
            Map<String, dynamic>.from(frame),
          );
          final row = await repo.find(msgId);
          expect(
            row!.status,
            IMBoyMessageStatus.peerRevoked,
            reason: '第 $delivery 次重复投递后，撤回终态不得回退到中间态（delivered 等）',
          );
        }
        await pumpEventQueue(times: 20);
      } finally {
        await sub.cancel();
      }

      // 行 1 佐证：重复投递只保留一条持久化记录
      final rows = await db.query(
        'msg_c2c',
        where: 'id = ?',
        whereArgs: [msgId],
      );
      expect(rows, hasLength(1), reason: '同 msg_id 投递 3 次只能有一条持久化记录');
      // 行 2：终态行的撤回内容不得被原始内容投递覆盖
      final rowAfter = await repo.find(msgId);
      expect(
        rowAfter!.payloadMap,
        revokedPayloadBefore,
        reason: '重复投递不得改写已终态消息行的 payload（撤回提示必须保留）',
      );
      // 重复投递被幂等短路，但仍必须逐次 ACK（否则服务端在重发窗口内继续重投）
      final acksForMsg = ackEvents
          .where((event) => event.messageId == msgId)
          .toList();
      expect(acksForMsg, hasLength(3), reason: '每次重复投递都必须回 ACK 以停止服务端重发');
      expect(acksForMsg.map((event) => event.message).toSet(), {
        'CLIENT_ACK,C2C,$msgId,m02-at03-device',
      }, reason: 'ACK 内容必须精确（type/msgId/deviceId）');
    });
  });

  group('M02 行 2 + 行 5：重复 SERVER_ACK 生命周期场景（CAS 终态守卫 + 状态阶梯单调）', () {
    test('唯一确认点在 in-flight；其后每个终态重放均被拒，观测状态序列全程单调', () async {
      const msgId = 'm02ack00000000000001';
      await _insertC2cMsg(
        msgId,
        status: IMBoyMessageStatus.sending,
        isAuthor: 1,
      );
      final autoId =
          (await db.query(
                'msg_c2c',
                where: 'id = ?',
                whereArgs: [msgId],
              )).single['auto_id']
              as int;
      await db.insert('message_send_attempt', {
        'user_id': _ownerUid,
        'anchor': msgId,
        'token': 'sent-attempt',
      });

      final sentEvents = <MessageSentEvent>[];
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      Future<bool> recordOnce() async => ServerAckReceipts.record(
        message: await repo.find(msgId),
        ackId: msgId,
        ackType: 'C2C_SERVER_ACK',
        ownerUid: _ownerUid,
        generation: 0,
        isCurrent: () => true,
        emit: sentEvents.add,
      );
      Future<bool> replayAck() => ServerAckReceipts.persist(
        db: db,
        ackId: msgId,
        ackType: 'C2C_SERVER_ACK',
        ownerUid: _ownerUid,
        expectedAutoId: autoId,
        expectedPeerId: _peerUid,
        isCurrent: () => true,
      );
      Future<int> currentStatus() async => (await repo.find(msgId))!.status!;

      final observed = <int>[];
      // 阶段 0：sending —— SERVER_ACK 唯一合法确认点
      observed.add(await currentStatus());
      expect(
        await replayAck(),
        isTrue,
        reason: 'in-flight 阶段的 SERVER_ACK 必须被确认（对照组：绿 = 守卫没坏）',
      );
      observed.add(await currentStatus());
      expect(await currentStatus(), IMBoyMessageStatus.sent);
      expect(await recordOnce(), isTrue, reason: '首次确认必须发出恰一条成功事件');

      // 阶段 1：sent（ACK 腿终态）—— 同 msgId 重复 ACK 重放
      expect(
        await replayAck(),
        isFalse,
        reason: 'sent 已是 ACK 腿终态，重复 ACK 不得改写状态',
      );
      observed.add(await currentStatus());
      expect(await recordOnce(), isFalse, reason: '重复确认不得产生第二条成功事件');

      // 阶段 2..4：更靠后的终态逐级推进（delivered → seen → peerRevoked），
      // 每级重放同一重复 ACK（同 msg_id 多投递）
      const ladder = [
        IMBoyMessageStatus.delivered,
        IMBoyMessageStatus.seen,
        IMBoyMessageStatus.peerRevoked,
      ];
      for (final stage in ladder) {
        await db.update(
          'msg_c2c',
          {'status': stage},
          where: 'id = ?',
          whereArgs: [msgId],
        );
        expect(
          await replayAck(),
          isFalse,
          reason: '终态 $stage 下的重复 ACK 必须被 CAS 守卫拒绝',
        );
        final after = await currentStatus();
        observed.add(after);
        expect(after, stage, reason: '重复 ACK 不得把终态 $stage 回退到中间态');
        expect(
          IMBoyMessageStatus.isInFlightStatus(after),
          isFalse,
          reason: '终态行不得因重复 ACK 回到 in-flight 集合',
        );
        expect(await recordOnce(), isFalse, reason: '同一收据不得重复发事件');
      }

      // 行 5：全程观测状态序列按生命周期秩单调（重复 ACK 处状态保持不变）
      final ranks = observed.map(_lifecycleRank).toList();
      for (var i = 1; i < ranks.length; i++) {
        expect(
          ranks[i],
          greaterThanOrEqualTo(ranks[i - 1]),
          reason: '状态阶梯必须单调不倒退，观测序列=$observed',
        );
      }
      expect(observed, [
        IMBoyMessageStatus.sending,
        IMBoyMessageStatus.sent,
        IMBoyMessageStatus.sent,
        IMBoyMessageStatus.delivered,
        IMBoyMessageStatus.seen,
        IMBoyMessageStatus.peerRevoked,
      ], reason: '重复 ACK 全程状态序列必须精确为单调阶梯（含 sent 处的重放保持）');

      expect(
        await db.query('server_ack_receipt'),
        hasLength(1),
        reason: '重复 ACK 只允许落一条收据',
      );
      expect(sentEvents, hasLength(1));
      expect(sentEvents.single.messageId, msgId);
    });
  });

  group('M02 行 5：S2C 同帧重复投递的执行序列与版本戳单调', () {
    test('同 msg_id S2C 帧重复投递 3 次：动作处理恰一次（首达版本生效，重复不重放）', () async {
      final events = <UserStatusChangeEvent>[];
      final sub = AppEventBus.on<UserStatusChangeEvent>().listen(events.add);
      const frame = <String, dynamic>{
        'id': 'm02s2c0000000000001',
        'type': 'S2C',
        'action': 'offline',
        'from': _peerUid,
        'to': _ownerUid,
        'payload': {'nickname': 'peer2002'},
        'server_ts': '1751850000000',
      };
      try {
        await MessageS2CService.switchS2C(Map<String, dynamic>.from(frame));
        await MessageS2CService.switchS2C(Map<String, dynamic>.from(frame));
        await MessageS2CService.switchS2C(Map<String, dynamic>.from(frame));
        await pumpEventQueue(times: 20);
      } finally {
        await sub.cancel();
      }

      expect(
        events,
        hasLength(1),
        reason: '同 msg_id 多投递必须按去重层归并为一次处理（版本/序列有序）',
      );
      expect(events.single.userId, _peerUid);
      expect(events.single.status, 'offline');
    });

    test('倒序到达的旧版本副本不得回退频控版本戳（时间戳只前进）', () {
      const uid = 'm02stamp0000000000001';
      final t0 = DateTime.now().millisecondsSinceEpoch;
      expect(
        MessageS2CService.shouldFirePeerKeyChanged(uid, t0),
        isTrue,
        reason: '首个版本必须放行并登记版本戳（对照组）',
      );
      expect(
        MessageS2CService.shouldFirePeerKeyChanged(uid, t0 + 5000),
        isFalse,
        reason: '窗口内的新副本不得重发',
      );
      expect(
        MessageS2CService.shouldFirePeerKeyChanged(uid, t0 - 1000),
        isFalse,
        reason: '倒序到达的旧版本副本不得重发，也不得回退已登记版本戳',
      );
      // 判别点：若版本戳被旧副本回退到 t0-1000，窗口将在 t0+59000 过期，
      // 此处会误放行；版本戳保持 t0 时窗口未过期，必须继续压制。
      expect(
        MessageS2CService.shouldFirePeerKeyChanged(uid, t0 + 59500),
        isFalse,
        reason: '版本戳被旧副本回退则此处误放行 —— 该绿证明时间戳未回退',
      );
      expect(
        MessageS2CService.shouldFirePeerKeyChanged(uid, t0 + 61000),
        isTrue,
        reason: '自 t0 起算的窗口过期后必须重新放行（单调性不等于永久压制）',
      );
    });
  });
}
