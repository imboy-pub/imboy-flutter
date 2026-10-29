import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

void main() {
  test('conversation and message rows keep exact peer identities', () async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1001'});
    await StorageService.init();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await openFixtureDatabaseAtVersion(version: 37);
    SqliteService.setDbForTest(db);
    addTearDown(() async {
      SqliteService.setDbForTest(null);
      await db.close();
    });
    const gid = '9007199254740993';
    await ConversationRepo().setMutedForPeer('C2G', gid, true);
    final conversation = await ConversationRepo().findByPeerId('C2G', gid);
    expect(conversation?.peerId, gid);
    await db.insert('msg_c2g', {
      'id': 'synthetic-exact-id',
      'from_id': '9007199254740995',
      'to_id': gid,
      'type': 'C2G',
      'status': 11,
      'payload': '{}',
      'created_at': 1,
      'is_author': 0,
      'topic_id': 0,
      'conversation_uk3': 'C2G_1001_$gid',
      'msg_type': 'text',
    });
    final message = await MessageRepo(tableName: MessageRepo.c2gTable)
        .find('synthetic-exact-id');
    expect(message?.fromId, '9007199254740995');
    expect(message?.toId, gid);
  });
}
