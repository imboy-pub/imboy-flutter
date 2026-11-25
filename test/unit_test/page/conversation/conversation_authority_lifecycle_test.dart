// UX-02 生命周期域：LOCAL:01 退群撤权行删除终态+世代隔离、LOCAL:02 未读/预览/
// 历史与权威终态一致。
//
// 拆分自原 conversation_authority_actions_test.dart（ratchet <800 行约束）；
// 共享 fixture 见 conversation_authority_actions_support.dart。

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart' show IMBoyMessageStatus;
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';
import 'conversation_authority_actions_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, authorityTestUid);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    db = await openFixtureDatabaseAtVersion(version: 32);
    SqliteService.setDbForTest(db);
  });

  tearDownAll(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  setUp(() async {
    await SqliteService.to.delete(
      ConversationRepo.tableName,
      where: '${ConversationRepo.userId} = ?',
      whereArgs: <Object?>[authorityTestUid],
    );
  });

  group('UX-02:LOCAL:01 权限撤回与世代隔离（持久终态）', () {
    test('退群撤权：行删除后入口/未读终态清空且重入不复活', () async {
      final api = FakeConversationApi();
      final conv = await insertConversationFixture(
        peerId: 8101,
        type: 'C2G',
        lastTime: 1750000002000,
        // 已设自定义头像的群不预热成员拼图（产品规则），避免
        // conversationsList 的后台 warmup 走网络路径污染纯本地旅程。
        avatar: 'group-avatar-ref',
      );
      await seedMessageFixture(
        db,
        type: 'C2G',
        uk3: conv.uk3,
        autoId: 1,
        msgId: 101,
        status: IMBoyMessageStatus.delivered,
        own: false,
      );
      await seedMessageFixture(
        db,
        type: 'C2G',
        uk3: conv.uk3,
        autoId: 2,
        msgId: 102,
        status: IMBoyMessageStatus.delivered,
        own: false,
      );
      final container = containerWithFixture(api);
      final notifier = container.read(conversationProvider.notifier);

      await notifier.conversationsList();
      final loaded = container.read(conversationProvider);
      expect(loaded.conversationMap[conv.uk3], isNotNull);
      expect(loaded.conversationRemind[conv.uk3], 2);

      // 退群 cleanData 管线：先删消息行，再删会话行（J19.a 链）。
      await db.delete(
        'msg_c2g',
        where: 'conversation_uk3 = ?',
        whereArgs: [conv.uk3],
      );
      await db.delete('conversation', where: 'id = ?', whereArgs: [conv.id]);

      // 页面等效收回：本地行查无 → 内存表与未读映射同步移除。
      expect(await ConversationRepo().findByPeerId('C2G', '8101'), isNull);
      notifier.removeConversationFromMap(conv.uk3);
      var after = container.read(conversationProvider);
      expect(after.conversationMap[conv.uk3], isNull);
      expect(after.conversationRemind[conv.uk3], isNull);

      // 重入（新页面 mount → 重新本地/权威拉取）不复活旧世代条目。
      await notifier.conversationsList();
      await notifier.conversationsList();
      after = container.read(conversationProvider);
      expect(after.conversationMap[conv.uk3], isNull, reason: '撤权后的会话不得在重入时复活');
      expect(after.conversationRemind[conv.uk3], isNull);
      expect(
        await db.query('conversation', where: 'id = ?', whereArgs: [conv.id]),
        isEmpty,
      );
    });

    test('世代隔离：切号后重入列表为空且旧账号行不被串写', () async {
      final api = FakeConversationApi();
      final conv = await insertConversationFixture(
        peerId: 8201,
        type: 'C2C',
        lastTime: 1750000001500,
      );
      final container = containerWithFixture(api);
      final notifier = container.read(conversationProvider.notifier);

      await notifier.conversationsList();
      expect(
        container.read(conversationProvider).conversationMap[conv.uk3],
        isNotNull,
      );

      await StorageService.to.setString(Keys.currentUid, '2002');
      // 仿按账号供库：新账号打开自己的库（此处仍用同一句柄承接，
      // 行隔离由 user_id 列保证——正是本用例要验证的边界）。
      SqliteService.setDbForTest(db);
      try {
        // 换账号后的重入拉取：不得继承旧账号会话。
        await notifier.conversationsList();
        final switched = container.read(conversationProvider);
        expect(switched.conversationMap[conv.uk3], isNull);
        expect(switched.conversationRemind[conv.uk3], isNull);
        // 旧账号行原样保留（未被新账号旅程串写/隐藏）。
        final rows = await db.query(
          'conversation',
          where: 'id = ?',
          whereArgs: [conv.id],
        );
        expect(rows.single['user_id'].toString(), authorityTestUid);
        expect(rows.single['is_show'], 1);
      } finally {
        await StorageService.to.setString(Keys.currentUid, authorityTestUid);
        SqliteService.setDbForTest(db);
      }

      // 切回原账号：自己的会话恢复可见（无跨账号残留破坏）。
      await notifier.conversationsList();
      expect(
        container.read(conversationProvider).conversationMap[conv.uk3],
        isNotNull,
      );
    });
  });

  group('UX-02:LOCAL:02 未读/预览/历史与权威终态一致', () {
    test('未读重算：本人消息/已读消息不误计，重复推进幂等且落库', () async {
      final api = FakeConversationApi();
      final conv = await insertConversationFixture(
        peerId: 8301,
        type: 'C2C',
        lastTime: 1000,
      );
      // auto_id 1/2 对方未读；3 对方已读；4 水位之上的本人消息。
      await seedMessageFixture(
        db,
        type: 'C2C',
        uk3: conv.uk3,
        autoId: 1,
        msgId: 201,
        status: IMBoyMessageStatus.delivered,
        own: false,
      );
      await seedMessageFixture(
        db,
        type: 'C2C',
        uk3: conv.uk3,
        autoId: 2,
        msgId: 202,
        status: IMBoyMessageStatus.delivered,
        own: false,
      );
      await seedMessageFixture(
        db,
        type: 'C2C',
        uk3: conv.uk3,
        autoId: 3,
        msgId: 203,
        status: IMBoyMessageStatus.seen,
        own: false,
      );
      await seedMessageFixture(
        db,
        type: 'C2C',
        uk3: conv.uk3,
        autoId: 4,
        msgId: 204,
        status: IMBoyMessageStatus.delivered,
        own: true,
      );
      await db.update(
        'conversation',
        {'mention_unread': 1},
        where: 'id = ?',
        whereArgs: [conv.id],
      );

      final container = containerWithFixture(api);
      final notifier = container.read(conversationProvider.notifier);
      await notifier.conversationsList();
      var state = container.read(conversationProvider);
      expect(state.conversationRemind[conv.uk3], 2, reason: '本人消息与已读消息不计入未读');
      expect(state.conversationMap[conv.uk3]!.unreadNum, 2);

      // 标已读：水位推进到来自对方最新（auto_id=3），未读终态归零。
      await notifier.advanceWatermarkToLatest(conv);
      state = container.read(conversationProvider);
      expect(state.conversationRemind[conv.uk3], 0);
      var stored = await ConversationRepo().findByPeerId('C2C', '8301');
      expect(stored!.unreadNum, 0);
      expect(stored.mentionUnread, 0, reason: '未读清零时 @ 未读同步清零（C7-β）');
      expect(stored.payload?['last_read_auto_id'], 3);

      // 重复标读/重算幂等：不出现负数、不复活（AC-11 重复已读不误计）。
      await notifier.recalculateConversationRemind(stored);
      await notifier.advanceWatermarkToLatest(stored);
      await notifier.recalculateConversationRemind(stored);
      stored = await ConversationRepo().findByPeerId('C2C', '8301');
      expect(stored!.unreadNum, 0);
      expect(
        container.read(conversationProvider).conversationRemind[conv.uk3],
        0,
      );
    });

    test('权威终态：预览/时间推进到服务端终态且逆序条目不回退、不伪造未读', () async {
      final api = FakeConversationApi();
      final conv = await insertConversationFixture(
        peerId: 8401,
        type: 'C2C',
        lastTime: 1750000002000,
      );
      await seedMessageFixture(
        db,
        type: 'C2C',
        uk3: conv.uk3,
        autoId: 141,
        msgId: 141,
        status: IMBoyMessageStatus.delivered,
        own: false,
      );
      await seedMessageFixture(
        db,
        type: 'C2C',
        uk3: conv.uk3,
        autoId: 142,
        msgId: 142,
        status: IMBoyMessageStatus.delivered,
        own: false,
      );

      api.entries = <Map<String, dynamic>>[
        {
          'conversation_id': '8401',
          'conversation_type': 'c2c',
          'server_ts': 1750000003000,
          'last_msg_id': 9401,
          'last_msg': {'text': 'authoritative-final-preview'},
          'is_pinned': 1,
        },
      ];
      final container = containerWithFixture(api);
      final notifier = container.read(conversationProvider.notifier);

      await notifier.syncAuthoritativeConversationList(trigger: 'ux02_advance');
      var model = await ConversationRepo().findByPeerId('C2C', '8401');
      expect(model!.subtitle, 'authoritative-final-preview');
      expect(model.lastTime, 1750000003000);
      expect(model.lastMsgId, '9401');
      expect(model.isPinned, isTrue);
      // 未读不受权威预览旅程影响（不伪造增量）。
      expect(model.unreadNum, 2, reason: '权威预览合并不得改动本地未读水位');
      expect(
        container.read(conversationProvider).conversationRemind[conv.uk3],
        2,
      );

      // 逆序/迟到条目（server_ts 更旧）不得回退已推进的预览与历史。
      api.entries = <Map<String, dynamic>>[
        {
          'conversation_id': '8401',
          'conversation_type': 'c2c',
          'server_ts': 1750000001000,
          'last_msg_id': 9301,
          'last_msg': {'text': 'stale-out-of-order'},
          'is_pinned': 1,
        },
      ];
      await notifier.syncAuthoritativeConversationList(trigger: 'ux02_stale');
      model = await ConversationRepo().findByPeerId('C2C', '8401');
      expect(model!.lastTime, 1750000003000, reason: '逆序权威条目不得回退 lastTime');
      expect(
        model.subtitle,
        'authoritative-final-preview',
        reason: '逆序权威条目不得回退预览',
      );
      expect(model.lastMsgId, '9401');
      expect(model.unreadNum, 2);
      expect(
        container.read(conversationProvider).conversationRemind[conv.uk3],
        2,
      );
    });
  });
}
