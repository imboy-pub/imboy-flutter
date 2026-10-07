import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('read watermark survives removal of the last UI listener', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 32);
    SqliteService.setDbForTest(db);
    final container = ProviderContainer();
    final release = Completer<void>();
    Future<void>? lock;
    try {
      final id = await db.insert('conversation', {
        'user_id': 995011,
        'peer_id': 995012,
        'type': 'C2C',
        'unread_num': 2,
        'last_time': 1750000000000,
      });
      final conversation = (await ConversationRepo().findById(id))!;
      for (var index = 1; index <= 2; index++) {
        await db.insert('msg_c2c', {
          'id': '11684000000000000$index',
          'type': 'C2C',
          'from_id': 995012,
          'to_id': 995011,
          'conversation_uk3': conversation.uk3,
          'payload': '{}',
          'created_at': 1750000000000 + index,
          'status': 20,
          'is_author': 0,
          'msg_type': 'text',
          'action': '',
        });
      }
      final listener = container.listen(conversationProvider, (_, _) {});
      final notifier = container.read(conversationProvider.notifier);
      final entered = Completer<void>();
      lock = db.transaction((txn) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final pending = notifier.advanceReadWatermarkByMsgIds(conversation, [
        '116840000000000001',
      ]);
      listener.close();
      await container.pump();
      final survived = container.exists(conversationProvider);
      release.complete();
      await lock;
      await pending;
      expect(survived, isTrue);
      final row = (await db.query('conversation')).single;
      expect(jsonDecode(row['payload'] as String)['last_read_auto_id'], 1);
      expect(row['unread_num'], 1);
      await container.pump();
      expect(container.exists(conversationProvider), isFalse);
    } finally {
      if (!release.isCompleted) release.complete();
      await lock;
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });
}
