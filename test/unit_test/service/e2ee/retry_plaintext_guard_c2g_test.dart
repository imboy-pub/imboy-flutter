// E2EE-062 残留 3：**重发明文闸门的 C2G / 群级 E2EE 分支实证**。
//
// == 为什么需要这个文件 ==
//
// 第八刀（`evidence/E2EE-062-retry-plaintext-guard.md`）实现的
// `MessageRetry._isPlaintextRetryBlocked` 的判据是**两条**：
//
//     final groupMegolm = chatType == 'C2G'
//         && await GroupSessionService.to.isGroupE2EE(msg.toId.toString());
//     encryptionRequired = groupMegolm
//         || E2EEService.shouldEncryptOutgoingPayload(chatType);
//
// 第九刀（`evidence/E2EE-062-retry-guard-wiring-proof.md`）用真 SQLite + 真事件
// 总线实证了接线，但**只覆盖 C2C**——`chatType == 'C2G'` 那一支被明确记为
// 「**文件级阅读结论，未实证**」（该 evidence §5.3 / §6）。
//
// 这一支不是冗余：群级 E2EE（P0-B B4）是**独立于全局策略**的强制开关。
// 存在这样的部署：全局 policy 判 plaintext（`shouldEncryptOutgoingPayload` 为 false），
// 但某个群开了群级 E2EE。此时若只看全局策略，该群的明文行会被照常重发 —— 明文出网。
//
// == 守护 ==
//
// 1. 【对照组】群**未**开 E2EE + 全局 plaintext → 明文行**必须照常重投**。
//    对照组红 = harness 没驱动起重投，此时任何"没出网"的绿都无意义；
// 2. 群**已**开 E2EE + 全局 plaintext + 明文行 → **不得出网**（本文件的核心）；
// 3. 【正向可用性】群已开 E2EE + **已加密**行 → 必须照常重投。
//    一个「群开了 E2EE 就一律不发」的实现在"不泄漏明文"上恒满分，被这条否掉。
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/encryption_mode.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/group_session_service.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/retry_policy.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 群消息表最小 DDL（列集合 = MessageRepo.defaultColumns，与 msg_c2c 同构）。
const String _msgC2gDdl = '''
  CREATE TABLE msg_c2g (
    auto_id INTEGER PRIMARY KEY AUTOINCREMENT,
    id INTEGER,
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

const String _contactDdl = '''
  CREATE TABLE contact (
    user_id INTEGER,
    peer_id INTEGER,
    nickname TEXT,
    avatar TEXT,
    account TEXT,
    status INTEGER,
    remark TEXT,
    tag TEXT,
    region TEXT,
    sign TEXT,
    source TEXT,
    gender INTEGER,
    is_friend INTEGER,
    is_from INTEGER,
    category_id INTEGER,
    account_type INTEGER,
    last_seen_at INTEGER,
    updated_at INTEGER
  )
''';

const String _gid = '90210';

Future<void> _insertGroupMsg(
  String id, {
  required int status,
  Map<String, dynamic>? e2ee,
}) async {
  final repo = MessageRepo(tableName: MessageRepo.c2gTable);
  await repo.insert(
    MessageModel(
      id,
      autoId: 0,
      type: 'C2G',
      status: status,
      fromId: 1001,
      toId: int.parse(_gid),
      payload: {'msg_type': 'text', 'text': 'hi'},
      isAuthor: 1,
      conversationUk3: 'C2G_$_gid',
      msgType: 'text',
      createdAt: 1751850000000,
      e2ee: e2ee,
    ),
  );
}

void _makeDue(MessageRetry retry, String id) {
  final info = retry.getRetryInfo(id);
  if (info == null) return;
  info.lastRetryTime -=
      RetryPolicy.messageSendIntervalAt(info.retryCount) + 1000;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final secureStore = <String, String?>{};

  late MessageRetry retry;
  final List<WebSocketMessageSendRequestEvent> sendRequests = [];

  setUpAll(() async {
    // 与 group_session_service_test.dart 同一范式：mock secure storage channel。
    // `GroupSessionService.isGroupE2EE` 就是读它。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
          switch (call.method) {
            case 'write':
              secureStore[call.arguments['key'] as String] =
                  call.arguments['value'] as String?;
              return null;
            case 'read':
              return secureStore[call.arguments['key'] as String];
            case 'delete':
              secureStore.remove(call.arguments['key'] as String);
              return null;
            case 'deleteAll':
              secureStore.clear();
              return null;
            case 'readAll':
              return Map<String, String?>.from(secureStore);
            case 'containsKey':
              return secureStore.containsKey(call.arguments['key'] as String);
          }
          return null;
        });

    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(_msgC2gDdl);
    await db.execute(_contactDdl);
    SqliteService.setDbForTest(db);
    expect(await SqliteService.to.db, isNotNull);
    retry = MessageRetry.instance;
    await pumpEventQueue(times: 200);
    AppEventBus.on<WebSocketMessageSendRequestEvent>().listen(sendRequests.add);
  });

  setUp(() {
    // 全局策略一律设为 plaintext（不要求加密）——本文件专测**群级开关**这一支：
    // 若全局策略也要求加密，就分不清是哪一条判据在起作用。
    EncryptionModeService.debugSet(
      mode: EncryptionMode.plaintext,
      initialized: true,
    );
    secureStore.clear();
    retry.clearRetryQueue();
    sendRequests.clear();
  });

  tearDownAll(() {
    retry.dispose();
    SqliteService.setDbForTest(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, null);
  });

  Future<void> driveRetry(String id) async {
    retry.addToRetryQueue(id, 'C2G');
    _makeDue(retry, id);
    await retry.retryFailedMessages();
    await pumpEventQueue();
  }

  Iterable<WebSocketMessageSendRequestEvent> sentOf(String id) =>
      sendRequests.where((e) => e.messageId == id);

  group('重发明文闸门 · C2G 群级 E2EE 分支', () {
    test('实际发送入口：群已开 E2EE 时不受全局 plaintext 绕过', () async {
      final network = const ChatNetworkService();
      await GroupSessionService.to.setGroupE2EEMode(_gid, 1);

      expect(
        await network.shouldEncryptOutboundForTest(
          chatType: 'C2G',
          toId: _gid,
          action: '',
        ),
        isTrue,
      );
      expect(
        await network.shouldEncryptOutboundForTest(
          chatType: 'C2G',
          toId: 'other-group',
          action: '',
        ),
        isFalse,
      );
      expect(
        await network.shouldEncryptOutboundForTest(
          chatType: 'C2G',
          toId: _gid,
          action: 'message_read',
        ),
        isFalse,
      );
    });

    test('对照组：群未开 E2EE + 全局 plaintext → 明文行必须照常重投', () async {
      expect(await GroupSessionService.to.isGroupE2EE(_gid), isFalse);
      const id = 'gg0000000000000ct01';
      await _insertGroupMsg(id, status: IMBoyMessageStatus.error);

      await driveRetry(id);

      expect(
        sentOf(id).length,
        1,
        reason:
            '对照组红 = harness 没驱动起重投，'
            '此时任何"没出网"的绿都毫无意义',
      );
    });

    test('群已开 E2EE + 全局 plaintext + 明文行 → 不得出网', () async {
      await GroupSessionService.to.setGroupE2EEMode(_gid, 1);
      expect(await GroupSessionService.to.isGroupE2EE(_gid), isTrue);

      const id = 'gg0000000000000ct02';
      await _insertGroupMsg(id, status: IMBoyMessageStatus.error);

      await driveRetry(id);

      expect(
        sentOf(id),
        isEmpty,
        reason:
            '群级 E2EE 独立于全局策略（P0-B B4）。'
            '只看全局策略会让开了群级 E2EE 的群的明文行照常重发 = 明文出网',
      );
    });

    test('手动重试：群已开 E2EE + 明文行 → 不得出网', () async {
      await GroupSessionService.to.setGroupE2EEMode(_gid, 1);
      expect(await GroupSessionService.to.isGroupE2EE(_gid), isTrue);

      const id = 'gg0000000000000ct04';
      await _insertGroupMsg(id, status: IMBoyMessageStatus.error);

      expect(await retry.retryMessage(id, 'C2G'), isFalse);
      await pumpEventQueue();

      expect(sentOf(id), isEmpty, reason: '手动重试不能绕过群级 E2EE 明文闸门');
      final stored = await MessageRepo(
        tableName: MessageRepo.c2gTable,
      ).find(id);
      expect(stored?.status, IMBoyMessageStatus.error);
    });

    test('正向可用性：群已开 E2EE + 已加密行 → 必须照常重投', () async {
      await GroupSessionService.to.setGroupE2EEMode(_gid, 1);
      expect(await GroupSessionService.to.isGroupE2EE(_gid), isTrue);

      const id = 'gg0000000000000ct03';
      await _insertGroupMsg(
        id,
        status: IMBoyMessageStatus.error,
        e2ee: <String, dynamic>{
          'meta_version': 3,
          'protocol': 'megolm',
          'version': 1,
        },
      );

      await driveRetry(id);

      expect(
        sentOf(id).length,
        1,
        reason:
            '「群开了 E2EE 就一律不发」在"不泄漏明文"指标上恒满分，'
            '却会让群消息永久卡住',
      );
    });
  });
}
