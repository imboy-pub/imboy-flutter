import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/server_ack_receipts.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('durable receipt restores once after session startup', () async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '9182',
      Keys.currentUser: jsonEncode({'id': '9182'}),
    });
    await StorageService.init();
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(
      'CREATE TABLE msg_c2c (auto_id INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT, type TEXT, from_id TEXT, to_id TEXT, payload TEXT, created_at INTEGER, is_author INTEGER, status INTEGER, conversation_uk3 TEXT, topic_id INTEGER, msg_type TEXT, action TEXT, e2ee TEXT, sender_did TEXT)',
    );
    await db.execute(
      'CREATE TABLE server_ack_receipt (user_id TEXT, anchor TEXT, chat_type TEXT, conversation TEXT, PRIMARY KEY(user_id,anchor,chat_type))',
    );
    await db.insert('msg_c2c', {
      'id': 'recovered-id',
      'type': 'C2C',
      'from_id': '9182',
      'to_id': '9183',
      'payload': '{}',
      'created_at': 0,
      'is_author': 1,
      'status': 11,
      'conversation_uk3': 'c2c-9182-9183',
      'topic_id': 0,
    });
    await db.insert('server_ack_receipt', {
      'user_id': '9182',
      'anchor': 'recovered-id',
      'chat_type': 'C2C',
      'conversation': 'c2c-9182-9183',
    });
    SqliteService.setDbForTest(db);
    final events = <MessageSentEvent>[];
    final subscription = AppEventBus.on<MessageSentEvent>().listen(events.add);
    final generation = UserRepoLocal.to.sessionGeneration;
    await ServerAckReceipts.restoreDurable('9182', generation);
    await ServerAckReceipts.restoreDurable('9182', generation);
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    expect(
      ServerAckReceipts.contains(
        '9182',
        generation,
        'recovered-id',
        'c2c-9182-9183',
      ),
      isTrue,
    );
    await subscription.cancel();
    SqliteService.setDbForTest(null);
    await db.close();
  });
}
