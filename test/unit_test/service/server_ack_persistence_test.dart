import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/server_ack_receipts.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE msg_c2c (auto_id INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT UNIQUE, type TEXT, from_id TEXT, to_id TEXT, is_author INTEGER, status INTEGER, conversation_uk3 TEXT)',
    );
    await db.execute(
      'CREATE TABLE msg_c2g (auto_id INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT UNIQUE, type TEXT, from_id TEXT, to_id TEXT, is_author INTEGER, status INTEGER, conversation_uk3 TEXT)',
    );
    await db.execute(
      'CREATE TABLE attachment_upload_task (id TEXT PRIMARY KEY, user_id TEXT, anchor_msg_id TEXT, stage TEXT, business_intent TEXT)',
    );
    await db.execute(
      'CREATE TABLE message_send_attempt (user_id TEXT, anchor TEXT, token TEXT, PRIMARY KEY(user_id,anchor,token))',
    );
    await db.insert('message_send_attempt', {
      'user_id': '101',
      'anchor': 'm1',
      'token': 'sent-attempt',
    });
    await db.execute(
      'CREATE TABLE crypto_outbox (id TEXT PRIMARY KEY, status TEXT, sent_at INTEGER)',
    );
    await db.insert('msg_c2c', {
      'id': 'm1',
      'type': 'C2C',
      'from_id': '101',
      'to_id': '202',
      'is_author': 1,
      'status': IMBoyMessageStatus.sending,
      'conversation_uk3': 'c2c-101-202',
    });
    await db.insert('attachment_upload_task', {
      'id': 'a1',
      'user_id': '101',
      'anchor_msg_id': 'm1',
      'stage': 'confirmed',
      'business_intent': jsonEncode({
        'author_id': '101',
        'chat_type': 'c2c',
        'state': 'commit_unknown',
      }),
    });
    await db.insert('crypto_outbox', {'id': 'm1', 'status': 'pending'});
  });
  tearDown(() async => db.close());

  Future<bool> ack({
    String type = 'C2C_SERVER_ACK',
    String owner = '101',
    bool current = true,
  }) => ServerAckReceipts.persist(
    db: db,
    ackId: 'm1',
    ackType: type,
    ownerUid: owner,
    expectedAutoId: 1,
    expectedPeerId: '202',
    isCurrent: () => current,
  );
  Future<List<Object?>> state() async => [
    (await db.query('msg_c2c')).single['status'],
    jsonDecode(
      (await db.query('attachment_upload_task')).single['business_intent']
          as String,
    )['state'],
    (await db.query('crypto_outbox')).single['status'],
  ];

  test('拒绝错误类型、账户、过期会话以及未发送附件状态', () async {
    expect(await ack(type: 'C2G_SERVER_ACK'), isFalse);
    expect(await ack(type: 'FAKE_SERVER_ACK'), isFalse);
    expect(await ack(owner: '202'), isFalse);
    expect(await ack(current: false), isFalse);
    await db.update('msg_c2c', {'is_author': 0});
    expect(await ack(), isFalse);
    await db.update('msg_c2c', {'is_author': 1});
    await db.update('attachment_upload_task', {
      'business_intent': jsonEncode({
        'author_id': '101',
        'chat_type': 'c2c',
        'state': 'dispatch_reserved_v2',
      }),
    });
    expect(await ack(), isFalse);
    expect(await state(), [
      IMBoyMessageStatus.sending,
      'dispatch_reserved_v2',
      'pending',
    ]);
  });

  test('查询期间消息实例被替换时拒绝迟到 ACK', () async {
    await db.delete('msg_c2c');
    await db.insert('msg_c2c', {
      'id': 'm1',
      'type': 'C2C',
      'from_id': '101',
      'to_id': '202',
      'is_author': 1,
      'status': IMBoyMessageStatus.sending,
      'conversation_uk3': 'c2c-101-202',
    });
    expect(await ack(), isFalse);
    expect(await state(), [
      IMBoyMessageStatus.sending,
      'commit_unknown',
      'pending',
    ]);
  });

  test('未到达发送边界的伪造 ACK 不生效', () async {
    await db.delete('message_send_attempt');
    expect(await ack(), isFalse);
    expect(await state(), [
      IMBoyMessageStatus.sending,
      'commit_unknown',
      'pending',
    ]);
  });

  test('有效确认原子落账，重放和迟到不重复确认或改写终态', () async {
    expect(await ack(), isTrue);
    expect(await state(), [IMBoyMessageStatus.sent, 'committed', 'sent']);
    expect(await db.query('server_ack_receipt'), hasLength(1));
    expect(await ack(), isFalse);
    await db.update('msg_c2c', {'status': IMBoyMessageStatus.myRevoked});
    expect(await ack(), isFalse);
    expect(await state(), [IMBoyMessageStatus.myRevoked, 'committed', 'sent']);
  });

  test('并发重复 ACK 只有一个事务产生确认', () async {
    final results = await Future.wait([ack(), ack()]);
    expect(results.where((value) => value), hasLength(1));
    expect(await state(), [IMBoyMessageStatus.sent, 'committed', 'sent']);
  });

  test('锚点仅含 NULL-intent journal 行时 ACK 照常落账置 sent', () async {
    // business_intent 为 NULL 的行是纯上传 journal（转发明文附件重上传
    // 形态），不属于 outbox 派发协议：ACK 提交校验与状态推进须跳过它们
    // 照常落账（与 repo 层 _isOutboxManaged 同口径的接收侧回归防线）。
    await db.update('attachment_upload_task', {'business_intent': null});
    expect(await ack(), isTrue);
    expect(
      (await db.query('msg_c2c')).single['status'],
      IMBoyMessageStatus.sent,
    );
    expect(
      (await db.query('attachment_upload_task')).single['business_intent'],
      isNull,
      reason: 'NULL-intent 行不被 ACK 路径编码改写',
    );
    expect((await db.query('crypto_outbox')).single['status'], 'sent');
    expect(await db.query('server_ack_receipt'), hasLength(1));
  });

  test('落账失败回滚消息及附件状态', () async {
    await db.execute('DROP TABLE crypto_outbox');
    await db.execute('CREATE TABLE crypto_outbox (id TEXT PRIMARY KEY)');
    await expectLater(ack(), throwsA(isA<Exception>()));
    expect(
      (await db.query('msg_c2c')).single['status'],
      IMBoyMessageStatus.sending,
    );
    expect(
      jsonDecode(
        (await db.query('attachment_upload_task')).single['business_intent']
            as String,
      )['state'],
      'commit_unknown',
    );
  });
}
