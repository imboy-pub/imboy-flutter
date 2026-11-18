import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/group_list/group_list_service.dart';
import 'package:imboy/store/model/conversation_model.dart';

/// 会话列表「无名群显示未命名」的真根因回归测试。
///
/// 真机实证（2026-08-06 18:03，华为 MRD_AL00 / 生产）：
///   computeTitle 104603643803863040, 1 members found in local db
///   computeTitle local result: IMBoy          ← 成员昵称回落**成功**
///   104603643803863040 computedTitle          ← 群自身无名，返回空串
/// 也就是说 `obj.computeTitle` 确实被赋成了「IMBoy」；界面上仍是「未命名」，
/// 断点在**之后**：`recalculateAllReminds` 触发 500ms 防抖回写未读数，
/// `setConversationRemind` 用 `copyWith(unreadNum:)` 重建模型放回 state，
/// 而 `copyWith` 走 `fromJson`，认不出 `computeTitle` 这个只活在内存里的派生名。
///
/// 群列表页不受影响：它每次 build 都重新 `service.computeTitle()`，
/// 从不 copyWith，所以同一批群在群列表有名字、在会话列表没有。
ConversationModel _groupConv({String title = '', String computeTitle = ''}) {
  final m = ConversationModel(
    id: 1,
    peerId: 104603643803863040,
    avatar: '',
    title: title,
    subtitle: '',
    type: 'C2G',
    msgType: 'text',
    unreadNum: 3,
    isShow: 1,
  );
  m.computeTitle = computeTitle;
  return m;
}

void main() {
  group('真实数据库新快照保留派生名', () {
    late Database db;
    late ProviderContainer container;
    late ProviderSubscription<ConversationState> subscription;
    late ConversationNotifier notifier;
    Future<void> flush() =>
        Future<void>.delayed(const Duration(milliseconds: 130));
    Future<ConversationModel> fresh() async =>
        (await ConversationRepo().findById(1))!;

    setUp(() async {
      UserRepoLocal.to.clearAuthTransitionFailureForTest();
      SharedPreferences.setMockInitialValues({Keys.currentUid: '995011'});
      await StorageService.init();
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      db = await openFixtureDatabaseAtVersion(version: 39);
      SqliteService.setDbForTest(db);
      await db.insert('conversation', {
        'id': 1,
        'user_id': '995011',
        'peer_id': '104603643803863040',
        'type': 'C2G',
        'title': '',
        'is_show': 1,
        'last_time': 1,
        'last_msg_id': '',
        'last_msg_status': 20,
        'unread_num': 1,
        'mention_unread': 0,
        'msg_type': 'text',
        'payload': '{}',
      });
      container = ProviderContainer();
      subscription = container.listen(conversationProvider, (_, _) {});
      notifier = container.read(conversationProvider.notifier);
      await db.insert('group_member', {
        'group_id': '104603643803863040',
        'user_id': '995012',
        'nickname': '合成成员昵称',
        'created_at': 1,
      });
      await db.insert('contact', {
        'user_id': '995011',
        'peer_id': '995012',
        'remark': '合成成员备注',
      });
      final initial = await fresh();
      await notifier.computeTitle(initial);
      expect(initial.computeTitle, '合成成员备注');
      notifier.replaceConversation(initial);
      await flush();
    });
    tearDown(() async {
      subscription.close();
      container.dispose();
      SqliteService.setDbForTest(null);
      await db.close();
    });

    for (final uid in ['995011', '995013']) {
      test('账号/同UID换代 $uid 不继承旧派生名', () async {
        final next = await fresh();
        const channel = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'write' &&
                  (call.arguments as Map)['key'] == 'secure_token') {
                throw PlatformException(code: 'synthetic-login-stop');
              }
              return null;
            });
        try {
          final previous = UserRepoLocal.to.sessionGeneration;
          await expectLater(
            UserRepoLocal.to.loginAfter('synthetic-session', {
              'uid': uid,
              'token': 'synthetic-token',
              'refreshtoken': 'synthetic-refresh',
            }),
            throwsA(isA<PlatformException>()),
          );
          expect(UserRepoLocal.to.sessionGeneration, previous + 1);
          await StorageService.to.setString(Keys.currentUid, uid);
          expect(UserRepoLocal.to.currentUid, uid);
          notifier.replaceConversation(next);
          await flush();
          expect(
            container
                .read(conversationProvider)
                .conversationMap[next.uk3]!
                .computeTitle,
            '',
          );
        } finally {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        }
      });
    }

    test('重新计算为空不得继承旧成员名', () async {
      await db.update('group_member', {'nickname': ''});
      await db.update('contact', {'remark': ''});
      final next = await fresh();
      await notifier.computeTitle(next);
      notifier.replaceConversation(next);
      await flush();
      expect(
        container
            .read(conversationProvider)
            .conversationMap[next.uk3]!
            .computeTitle,
        '',
      );
    });

    test('recount 返回数据库新对象仍保留派生名且不落库', () async {
      final model = container
          .read(conversationProvider)
          .conversationMap
          .values
          .single;
      await notifier.recalculateConversationRemind(model);
      await flush();
      expect(
        container
            .read(conversationProvider)
            .conversationMap
            .values
            .single
            .displayTitle,
        '合成成员备注',
      );
      expect((await fresh()).title, '');
      expect((await fresh()).computeTitle, '');
    });

    test('已读 fresh snapshot replace 不得清空派生名', () async {
      await notifier.replace(await fresh());
      await flush();
      expect(
        container
            .read(conversationProvider)
            .conversationMap
            .values
            .single
            .displayTitle,
        '合成成员备注',
      );
    });

    test('同批 pending 新派生名及显式名称优先，其他会话不继承', () async {
      final changed = await fresh();
      changed.computeTitle = '新成员备注';
      notifier.replaceConversation(changed);
      notifier.replaceConversation(await fresh());
      await flush();
      expect(
        container
            .read(conversationProvider)
            .conversationMap[changed.uk3]!
            .displayTitle,
        '新成员备注',
      );
      final named = await fresh();
      named.title = '显式群名';
      notifier.replaceConversation(named);
      final other = named.copyWith(peerId: '104603643803863041', title: '');
      other.computeTitle = '';
      notifier.replaceConversation(other);
      await flush();
      expect(
        container
            .read(conversationProvider)
            .conversationMap[named.uk3]!
            .displayTitle,
        '显式群名',
      );
      expect(
        container
            .read(conversationProvider)
            .conversationMap[other.uk3]!
            .computeTitle,
        '',
      );
    });
  });

  group('无名群回落到成员昵称', () {
    test('成员行按 别名→好友备注→昵称→账号 取名', () {
      final names = GroupListService.pickMemberNames([
        {'alias': '', 'remark': '', 'nickname': 'IMBoy', 'account': 'imboy01'},
      ]);
      expect(names, ['IMBoy']);
    });

    test('拼好的成员名经 computeTitle 进入展示名', () {
      final conv = _groupConv(computeTitle: 'IMBoy');
      expect(conv.resolvedTitle, 'IMBoy');
      expect(conv.displayTitle, 'IMBoy');
    });

    test('确实取不到名字才回落占位，且不泄漏 TSID', () {
      final shown = _groupConv().displayTitle;
      expect(shown, isNotEmpty);
      expect(shown.contains('104603643803863040'), isFalse);
    });
  });

  group('copyWith 必须带上派生名（本次根因）', () {
    test('未读数回写不得把成员昵称抹成「未命名」', () {
      final conv = _groupConv(computeTitle: 'IMBoy');
      final afterUnreadWrite = conv.copyWith(unreadNum: 0, mentionUnread: 0);

      expect(
        afterUnreadWrite.computeTitle,
        'IMBoy',
        reason: 'copyWith 走 fromJson，不显式搬运就会丢掉只在内存里的 computeTitle',
      );
      expect(afterUnreadWrite.displayTitle, 'IMBoy');
    });

    test('存量脏值 title==peerId 时，派生名仍要能顶上来', () {
      final conv = _groupConv(
        title: '104603643803863040',
        computeTitle: 'IMBoy',
      );
      expect(conv.copyWith(unreadNum: 1).displayTitle, 'IMBoy');
    });

    test('派生名依然不落库：copyWith 不把它写进 title', () {
      final copied = _groupConv(computeTitle: 'IMBoy').copyWith(unreadNum: 0);
      expect(copied.title, '', reason: '成员改名后派生名要能跟着变，固化进 title 就永远更新不了');
    });
  });
}
