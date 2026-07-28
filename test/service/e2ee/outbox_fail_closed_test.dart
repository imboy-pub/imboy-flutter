/// E2EE-027 补课 — 出站 outbox 提交必须 fail-closed。
///
/// 背景：`E2eeOutboundRouter.encryptV3` 在加密后写 immutable outbox，但整段被
/// `try { ... } catch (_) {}` 包住，且 DB 不可用时直接跳过。后果是密文照常返回
/// 给调用方发送，而崩溃恢复所依赖的 outbox 条目可能根本不存在——用户看到
/// "已发送"，重启后既无投递也无重发依据。
///
/// 对应条款：
/// - ADR 14 §4.2 不变量 7：密码学状态与消息状态要么同时提交，要么全部回滚；
/// - ADR 14 §8「CryptoStore 提交失败」→ 消息保留"未发送"，不得静默继续；
/// - ADR 20 §S2.3：加密后先原子提交 state + immutable outbox，**再**发送。
///
/// 使用真实 SQLite（ffi in-memory）与真实 Protected Frame v3 编码；协议插件用
/// 确定性替身（本用例验证的是提交语义，不是密码学）。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/service/e2ee/crypto_store.dart';
import 'package:imboy/service/e2ee/e2ee_outbound_router.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/sqlite.dart';

/// 确定性协议替身：密文 = 'CT(' + 明文长度 + ')'，绝不回显明文。
class _StubOlmProtocol implements E2eeSessionProtocol {
  @override
  ProtocolSuite get suite => ProtocolSuite.olm;

  @override
  Future<void> initialize({
    required String userId,
    required String deviceId,
  }) async {}

  @override
  Future<E2eeCiphertext> encrypt({
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
  }) async => E2eeCiphertext('CT(${plaintext.length})', const {
    'session_id': 'sess-outbox',
    'message_type': 1,
  });

  @override
  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    E2eeContext? context,
  }) async => ciphertext;

  @override
  Future<void> clearAll() async {}
}

const String _secretText = 'top-secret-plaintext-must-not-leak';

Future<E2eeCiphertext> encryptOnce(String messageId) {
  return E2eeOutboundRouter.encryptV3(
    suite: ProtocolSuite.olm,
    plaintext: jsonEncode({'msg_type': 'text', 'text': _secretText}),
    recipients: const [
      RecipientDevice(deviceId: 'dev-b', keyId: 'kid-b', publicKey: 'pk-b'),
    ],
    context: const E2eeContext(peerUid: '200', scope: 'c2c'),
    messageId: messageId,
    senderUid: '100',
    senderDid: 'dev-a',
    destination: '200',
    messageType: 'text',
    action: 'message',
    sessionRef: 'sess-outbox',
    createdAtMs: 1780000000000,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late CryptoStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    E2eeProtocolRegistry.resetForTest();
    E2eeProtocolRegistry.register(_StubOlmProtocol());
  });

  tearDownAll(E2eeProtocolRegistry.resetForTest);

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    SqliteService.setDbForTest(db);
    store = CryptoStore(db);
    await store.ensureSchema();
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  group('E2EE-027 outbox fail-closed', () {
    test('CryptoStore 不可用时不得返回可发送信封', () async {
      SqliteService.setDbForTest(null);

      await expectLater(
        encryptOnce('mid-no-db'),
        throwsA(isA<E2eeOutboxCommitException>()),
        reason: '无法持久化 immutable 密文就不得让调用方发送（ADR 14 §8）',
      );
    });

    test('outbox 写入报错不得被静默吞掉', () async {
      // 用不兼容的既有表制造确定性写入失败（ensureSchema 是 IF NOT EXISTS，
      // 不会覆盖），模拟磁盘/约束级故障。
      await db.close();
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      SqliteService.setDbForTest(db);
      await db.execute('''
        CREATE TABLE crypto_outbox (
          id            TEXT PRIMARY KEY,
          payload       TEXT NOT NULL,
          status        TEXT NOT NULL DEFAULT 'pending',
          created_at    INTEGER NOT NULL,
          required_col  TEXT NOT NULL
        )
      ''');

      await expectLater(
        encryptOnce('mid-write-error'),
        throwsA(anything),
        reason: 'outbox 写入失败必须向上抛出，不得 catch(_) 后照常返回密文',
      );

      // 且不得留下"半条"记录
      final rows = await db.rawQuery('SELECT id FROM crypto_outbox');
      expect(rows, isEmpty);
    });

    test('成功路径：返回前 outbox 已落 pending，且 payload 与信封逐字节一致', () async {
      final result = await encryptOnce('mid-ok');

      final entry = await store.getOutboxEntry('mid-ok');
      expect(entry, isNotNull);
      expect(entry!['status'], equals('pending'));
      expect(
        entry['payload'],
        equals(jsonEncode(result.metadata)),
        reason: '重发必须能直接复用已提交密文，不得重新 encrypt（推进 ratchet）',
      );

      final pending = await store.pendingOutbox();
      expect(pending.length, equals(1));
    });

    test('outbox 持久化内容不得包含消息明文', () async {
      await encryptOnce('mid-secret');
      final entry = await store.getOutboxEntry('mid-secret');
      expect(entry!['payload'].toString(), isNot(contains(_secretText)));
    });
  });
}
