import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

ConversationModel _incoming() => ConversationModel(
  id: 0,
  peerId: 995012,
  avatar: '',
  title: 'Synthetic peer',
  subtitle: 'First message',
  type: 'C2C',
  msgType: 'text',
  unreadNum: 1,
  mentionUnread: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
    await StorageService.init();
    sqfliteFfiInit();
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await applyBaselineSchema(db);
    await db.execute(
      'ALTER TABLE conversation ADD COLUMN mention_unread INTEGER DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE conversation ADD COLUMN is_muted INTEGER DEFAULT 0',
    );
    SqliteService.setDbForTest(db);
  });
  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  test(
    'new metadata-only conversation counts first incoming message once',
    () async {
      final repo = ConversationRepo();
      final incoming = _incoming();
      await db.transaction((txn) async {
        final saved = await repo.save(incoming, txn: txn, autoIncrement: false);
        expect(saved.unreadNum, 0);
        expect(saved.mentionUnread, 0);
        await repo.incrementUnread(
          saved.id,
          txn: txn,
          unreadDelta: 1,
          mentionDelta: 1,
        );
      });
      final row = (await db.query('conversation')).single;
      expect(row['unread_num'], 1);
      expect(row['mention_unread'], 1);
      expect(incoming.unreadNum, 1);
    },
  );

  test(
    'metadata replay preserves existing unread and mention counts',
    () async {
      final repo = ConversationRepo();
      final incoming = _incoming();
      final saved = await repo.save(incoming);
      await db.update('conversation', {'mention_unread': 3, 'unread_num': 4});
      final replay = await repo.save(incoming, autoIncrement: false);
      expect(replay.id, saved.id);
      expect(replay.unreadNum, 4);
      expect(replay.mentionUnread, 3);
    },
  );

  test(
    'default save retains initial unread count for existing callers',
    () async {
      final saved = await ConversationRepo().save(_incoming());
      expect(saved.unreadNum, 1);
      expect((await db.query('conversation')).single['unread_num'], 1);
    },
  );

  for (final type in ['C2C', 'C2G']) {
    test(
      'late $type delivery preserves the head and still increments unread',
      () async {
        final repo = ConversationRepo();
        final current = _incoming().copyWith(
          type: type,
          lastTime: 1700000002000,
          lastMsgId: 'newer-message',
          subtitle: 'newer preview',
          lastMsgStatus: 21,
          payload: {'text': 'newer text'},
          mentionUnread: 0,
        );
        await repo.save(current);
        final older = current.copyWith(
          lastTime: 1700000001000,
          lastMsgId: 'older-message',
          subtitle: 'older preview',
          lastMsgStatus: 11,
          payload: {'text': 'older text'},
          mentionUnread: 1,
        );
        final result = await repo.save(older);
        expect(result.lastTime, current.lastTime);
        expect(result.lastMsgId, current.lastMsgId);
        expect(result.lastMsgStatus, current.lastMsgStatus);
        expect(result.subtitle, current.subtitle);
        expect(result.payload, current.payload);
        expect(result.unreadNum, 2);
        expect(result.mentionUnread, 1);
        final replay = await repo.save(older, autoIncrement: false);
        expect(replay.lastMsgId, current.lastMsgId);
        expect(replay.unreadNum, 2);
        expect(replay.mentionUnread, 1);
      },
    );
  }

  test(
    'concurrent first deliveries keep one conversation and all unread deltas',
    () async {
      final repo = ConversationRepo();
      await Future.wait(
        List.generate(
          8,
          (i) => repo.save(
            _incoming().copyWith(
              lastTime: 1700000000000 + i,
              lastMsgId: 'synthetic-$i',
              mentionUnread: 0,
            ),
          ),
        ),
      );
      final rows = await db.query('conversation');
      expect(rows, hasLength(1));
      expect(rows.single['unread_num'], 8);
      expect(rows.single['last_msg_id'], 'synthetic-7');
      expect(rows.single['last_time'], 1700000000007);
    },
  );
}
