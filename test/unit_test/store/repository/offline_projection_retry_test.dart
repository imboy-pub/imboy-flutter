import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

class _FailingProjection extends ConversationNotifier {
  bool fail = true;
  @override
  void applyConversationSnapshot(ConversationModel conversation) {
    if (fail) throw StateError('synthetic projection failure');
    super.applyConversationSnapshot(conversation);
  }
}

const _messages = <Map<String, dynamic>>[
  {
    'msg_id': '116838000000000001',
    'type': 'C2C',
    'from': '995012',
    'to': '995011',
    'msg_type': 'text',
    'payload': {'text': ''},
    'created_at': 1750000000000,
  },
];

Future<void> _expectProjectionRecovery(
  Database db,
  MessageRepo repo,
  ProviderContainer container,
  _FailingProjection notifier,
) async {
  notifier.fail = false;
  for (var attempt = 0; attempt < 2; attempt++) {
    expect(await repo.batchInsertOfflineMessages(_messages), [
      _messages.single['msg_id'],
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final state = container.read(conversationProvider);
    expect(state.conversationMap.length, 1);
    expect(state.conversationMap.values.single.unreadNum, 1);
    expect(state.conversationRemind.values.single, 1);
    expect((await db.query('msg_c2c')).length, 1);
    expect((await db.query('conversation')).single['unread_num'], 1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('duplicate retry repairs failed UI projection without recounting unread', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final notifier = _FailingProjection();
    final container = ProviderContainer(
      overrides: [conversationProvider.overrideWith(() => notifier)],
    );
    final listener = container.listen(conversationProvider, (_, _) {});
    SqliteService.setDbForTest(db);
    MessageRepo.setProviderContainer(container);
    try {
      await applyBaselineSchema(db);
      await db.execute(
        'ALTER TABLE conversation ADD COLUMN mention_unread INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE conversation ADD COLUMN is_muted INTEGER DEFAULT 0',
      );
      final repo = MessageRepo(tableName: MessageRepo.c2cTable);
      await expectLater(
        repo.batchInsertOfflineMessages(_messages),
        throwsStateError,
      );
      expect((await db.query('msg_c2c')).length, 1);
      expect((await db.query('conversation')).single['unread_num'], 1);
      expect(container.read(conversationProvider).conversationMap, isEmpty);
      await _expectProjectionRecovery(db, repo, container, notifier);
    } finally {
      listener.close();
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    }
  });
}
