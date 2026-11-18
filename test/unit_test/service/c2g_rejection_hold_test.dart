import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/c2g_rejection_hold.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE msg_c2g (
        auto_id INTEGER PRIMARY KEY, id TEXT UNIQUE, type TEXT,
        from_id TEXT, to_id TEXT, is_author INTEGER, status INTEGER,
        conversation_uk3 TEXT, payload TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE attachment_upload_task (
        id TEXT PRIMARY KEY, user_id TEXT, anchor_msg_id TEXT, stage TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE crypto_outbox (id TEXT PRIMARY KEY, status TEXT)
    ''');
    await db.execute('''
      CREATE TABLE message_send_attempt (
        user_id TEXT, anchor TEXT, token TEXT,
        PRIMARY KEY (user_id, anchor, token)
      )
    ''');
    await db.insert('msg_c2g', {
      'auto_id': 1,
      'id': 'msg-1',
      'type': 'C2G',
      'from_id': '101',
      'to_id': '202',
      'is_author': 1,
      'status': IMBoyMessageStatus.sending,
      'conversation_uk3': 'c2g-101-202',
      'payload': '{"text":"retain original"}',
    });
    await db.insert('attachment_upload_task', {
      'id': 'attachment-1',
      'user_id': '101',
      'anchor_msg_id': 'msg-1',
      'stage': 'commit_unknown',
    });
    await db.insert('crypto_outbox', {'id': 'msg-1', 'status': 'pending'});
    await db.insert('message_send_attempt', {
      'user_id': '101',
      'anchor': 'msg-1',
      'token': 'sent-attempt',
    });
  });

  tearDown(() => db.close());

  Future<bool> hold({
    String id = 'msg-1',
    String owner = '101',
    int autoId = 1,
    String peer = '202',
    bool current = true,
  }) => C2gRejectionHold.persist(
    db: db,
    messageId: id,
    ownerUid: owner,
    expectedAutoId: autoId,
    expectedPeerId: peer,
    isCurrent: () => current,
  );

  Future<Map<String, Object?>> message() async =>
      (await db.query('msg_c2g')).single;

  test('会话摘要与消息一起提交，只更新匹配的最后消息', () async {
    await db.execute(
      'CREATE TABLE conversation (user_id TEXT, peer_id TEXT, '
      'type TEXT, last_msg_id TEXT, last_msg_status INTEGER)',
    );
    await db.insert('conversation', {
      'user_id': '101',
      'peer_id': '202',
      'type': 'C2G',
      'last_msg_id': 'msg-1',
      'last_msg_status': 10,
    });
    await db.insert('conversation', {
      'user_id': '101',
      'peer_id': '303',
      'type': 'C2G',
      'last_msg_id': 'msg-1',
      'last_msg_status': 10,
    });
    expect(await hold(), isTrue);
    final rows = await db.query('conversation', orderBy: 'peer_id');
    expect(rows[0]['last_msg_status'], 42);
    expect(rows[1]['last_msg_status'], 10);
  });

  for (final initialStatus in [
    IMBoyMessageStatus.sending,
    IMBoyMessageStatus.pendingRetry,
    IMBoyMessageStatus.error,
  ]) {
    test(
      'holds attempted status $initialStatus and preserves recovery data',
      () async {
        await db.update('msg_c2g', {'status': initialStatus});
        final before = await message();
        final uploads = await db.query('attachment_upload_task');
        final outbox = await db.query('crypto_outbox');

        expect(await hold(), isTrue);
        expect(await message(), {...before, 'status': 42});
        expect(await db.query('attachment_upload_task'), uploads);
        expect(await db.query('crypto_outbox'), outbox);
        expect(
          await hold(),
          isFalse,
          reason: 'duplicate rejection is idempotent',
        );
      },
    );
  }

  test(
    'rejects missing identity, wrong owner, peer, instance and stale session',
    () async {
      final before = await message();
      expect(await hold(id: ''), isFalse);
      expect(await hold(id: 'missing'), isFalse);
      expect(await hold(owner: ''), isFalse);
      expect(await hold(owner: 'other'), isFalse);
      expect(await hold(peer: 'other'), isFalse);
      expect(await hold(autoId: 2), isFalse);
      expect(await hold(current: false), isFalse);
      expect(await message(), before);
    },
  );

  test('requires a send attempt matching both owner and message', () async {
    final before = await message();
    await db.delete('message_send_attempt');
    expect(await hold(), isFalse);

    await db.insert('message_send_attempt', {
      'user_id': 'other',
      'anchor': 'msg-1',
      'token': 'other-owner',
    });
    expect(await hold(), isFalse);

    await db.insert('message_send_attempt', {
      'user_id': '101',
      'anchor': 'other-message',
      'token': 'other-anchor',
    });
    expect(await hold(), isFalse);
    expect(await message(), before);
  });

  test('session expiry after the update rolls back the transaction', () async {
    final before = await message();
    final uploads = await db.query('attachment_upload_task');
    final outbox = await db.query('crypto_outbox');
    var checks = 0;

    await expectLater(
      C2gRejectionHold.persist(
        db: db,
        messageId: 'msg-1',
        ownerUid: '101',
        expectedAutoId: 1,
        expectedPeerId: '202',
        isCurrent: () => ++checks < 3,
      ),
      throwsStateError,
    );
    expect(checks, 3);
    expect(await message(), before);
    expect(await db.query('attachment_upload_task'), uploads);
    expect(await db.query('crypto_outbox'), outbox);
  });

  for (final change in <Map<String, Object?>>[
    {'type': 'C2C'},
    {'from_id': 'other'},
    {'to_id': 'other'},
    {'is_author': 0},
    {'conversation_uk3': ''},
    {'conversation_uk3': null},
    {'status': IMBoyMessageStatus.sent},
    {'status': IMBoyMessageStatus.delivered},
    {'status': IMBoyMessageStatus.seen},
    {'status': IMBoyMessageStatus.myRevoked},
  ]) {
    test('does not change unmatched or terminal message $change', () async {
      await db.update('msg_c2g', change);
      final before = await message();
      expect(await hold(), isFalse);
      expect(await message(), before);
    });
  }

  test('concurrent duplicate rejections only transition once', () async {
    final results = await Future.wait([hold(), hold()]);
    expect(results.where((result) => result), hasLength(1));
    expect((await message())['status'], 42);
  });
}
