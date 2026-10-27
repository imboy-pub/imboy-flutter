import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/conversation_api.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../fixtures/sqlite_migration/sqlite_migration_fixtures.dart';

const _testUid = '995011';

class _FakeConversationApi extends ConversationApi {
  List<Map<String, dynamic>> entries = const <Map<String, dynamic>>[];
  bool pinResult = true;
  bool deleteResult = true;
  bool restoreResult = true;
  Completer<bool>? deleteGate;
  bool deleteThrows = false;

  final List<Map<String, String>> pinCalls = <Map<String, String>>[];
  final List<Map<String, String>> deleteCalls = <Map<String, String>>[];
  final List<Map<String, String>> restoreCalls = <Map<String, String>>[];

  @override
  Future<List<Map<String, dynamic>>> listMine({int? lastServerTs}) async {
    return entries;
  }

  @override
  Future<bool> pin({
    required String conversationId,
    required String type,
  }) async {
    pinCalls.add({'conversation_id': conversationId, 'type': type});
    return pinResult;
  }

  @override
  Future<bool> deleteConversation({
    required String conversationId,
    required String type,
  }) async {
    deleteCalls.add({'conversation_id': conversationId, 'type': type});
    if (deleteThrows) throw StateError('transport unavailable');
    if (deleteGate != null) return deleteGate!.future;
    return deleteResult;
  }

  @override
  Future<bool> restoreConversation({
    required String conversationId,
    required String type,
  }) async {
    restoreCalls.add({'conversation_id': conversationId, 'type': type});
    return restoreResult;
  }
}

class _TestConversationNotifier extends ConversationNotifier {
  _TestConversationNotifier({required ConversationApi api})
    : super(conversationApi: api);
}

Future<ConversationModel> _insertConversation({
  required int peerId,
  required String type,
  required int lastTime,
  bool isShow = true,
  bool isPinned = false,
}) async {
  final repo = ConversationRepo();
  final id = await repo.insert(
    ConversationModel(
      id: 0,
      peerId: peerId,
      avatar: '',
      title: '$peerId',
      subtitle: 'subtitle-$peerId',
      type: type,
      msgType: 'text',
      lastTime: lastTime,
      lastMsgId: 'msg-$peerId',
      unreadNum: 0,
      isShow: isShow ? 1 : 0,
      payload: {
        'authoritative': {
          'is_pinned': isPinned,
          'server_ts': lastTime,
          'last_msg': {'text': 'subtitle-$peerId'},
        },
      },
    ),
  );
  return (await repo.findById(id))!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, _testUid);
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
      whereArgs: <Object?>[_testUid],
    );
  });

  group('Conversation authority actions', () {
    test('免打扰等待数据库事务期间切号，不写入旧账号偏好', () async {
      final visible = await _insertConversation(
        peerId: 8007,
        type: 'C2C',
        lastTime: 1000,
      );
      final entered = Completer<void>();
      final release = Completer<void>();
      final held = db.transaction((_) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final pending = ConversationRepo().setMutedForPeer('C2C', '8006', true);
      final rejected = expectLater(pending, throwsStateError);
      final hidden = ConversationRepo().hideForAccount(
        account: _testUid,
        kind: 'C2C',
        peer: visible.peerId,
      );
      await Future<void>.delayed(Duration.zero);
      await StorageService.to.setString(Keys.currentUid, 'another-account');
      release.complete();
      try {
        await held;
        await rejected;
        expect(await hidden, isFalse);
        final original = await db.query(
          'conversation',
          where: 'id = ?',
          whereArgs: [visible.id],
        );
        expect(original.single['is_show'], 1);
        expect(
          await db.query(
            'conversation',
            where: 'peer_id = ?',
            whereArgs: [8006],
          ),
          isEmpty,
        );
      } finally {
        await StorageService.to.setString(Keys.currentUid, _testUid);
      }
    });

    test('先保存免打扰再收首消息，补齐身份且保留静音', () async {
      final repo = ConversationRepo();
      await repo.setMutedForPeer('C2C', '8004', true);
      final incoming = ConversationModel(
        id: 0,
        peerId: 8004,
        type: 'C2C',
        title: 'First sender',
        avatar: 'authorized-avatar-reference',
        subtitle: 'First message',
        msgType: 'text',
        lastTime: 1000,
        lastMsgId: 'first-message',
        unreadNum: 1,
        payload: const {},
      );
      final stored = await repo.save(incoming);
      expect(stored.title, incoming.title);
      expect(stored.avatar, incoming.avatar);
      expect(stored.subtitle, incoming.subtitle);
      expect(stored.isMuted, 1);
      expect(stored.isShow, 1);
      expect(stored.unreadNum, 1);
    });

    test('隐藏写入按账号和对象寻址，不使用另一账号的本地行号', () async {
      final row = await _insertConversation(
        peerId: 8005,
        type: 'C2C',
        lastTime: 1000,
      );
      await db.update(
        'conversation',
        {'user_id': 'another-account'},
        where: 'id = ?',
        whereArgs: [row.id],
      );
      expect(
        await ConversationRepo().hideForAccount(
          account: _testUid,
          kind: 'C2C',
          peer: 8005,
        ),
        isFalse,
      );
      final rows = await db.query(
        'conversation',
        where: 'id = ?',
        whereArgs: [row.id],
      );
      expect(rows.single['is_show'], 1);
      await db.delete('conversation', where: 'id = ?', whereArgs: [row.id]);
    });

    test('首条消息之前保存免打扰，不新增可见空会话', () async {
      final repo = ConversationRepo();
      await repo.setMutedForPeer('C2C', '8001', true);
      final stored = await repo.findByPeerId('C2C', '8001');
      expect(stored, isNotNull);
      expect(stored!.isMuted, 1);
      expect(stored.isShow, 0);
      expect(stored.unreadNum, 0);
      await repo.setMutedForPeer('C2C', '8001', false);
      expect((await repo.findByPeerId('C2C', '8001'))!.isMuted, 0);
    });

    test('免打扰保留消息、未读和会话可见性', () async {
      final row = await _insertConversation(
        peerId: 8002,
        type: 'C2G',
        lastTime: 1000,
      );
      final repo = ConversationRepo();
      await repo.setMutedForPeer('C2G', '8002', true);
      final stored = (await repo.findById(row.id))!;
      expect(stored.isMuted, 1);
      expect(stored.lastTime, row.lastTime);
      expect(stored.subtitle, row.subtitle);
      expect(stored.isShow, row.isShow);
      expect(stored.payload, row.payload);
    });

    test('免打扰写入失败抛出错误且原状态不变', () async {
      final repo = ConversationRepo();
      await repo.setMutedForPeer('C2C', '8003', false);
      await db.execute(
        '''CREATE TRIGGER reject_mute BEFORE UPDATE OF is_muted
        ON conversation BEGIN SELECT RAISE(ABORT, 'test write failure'); END''',
      );
      try {
        await expectLater(
          repo.setMutedForPeer('C2C', '8003', true),
          throwsA(isA<DatabaseException>()),
        );
        expect((await repo.findByPeerId('C2C', '8003'))!.isMuted, 0);
      } finally {
        await db.execute('DROP TRIGGER reject_mute');
      }
    });

    test('移除忙态防重且失败后可以重试', () async {
      final gate = Completer<bool>();
      final api = _FakeConversationApi()..deleteGate = gate;
      final conversation = await _insertConversation(
        peerId: 7001,
        type: 'C2G',
        lastTime: 1000,
      );
      final container = ProviderContainer(
        overrides: [
          conversationProvider.overrideWith(
            () => _TestConversationNotifier(api: api),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(conversationProvider, (_, _) {});
      final notifier = container.read(conversationProvider.notifier);
      final first = notifier.deleteConversationRemote(conversation);
      final second = notifier.deleteConversationRemote(conversation);
      expect(identical(first, second), isTrue);
      expect(api.deleteCalls, hasLength(1));
      gate.complete(false);
      expect(await first, isFalse);
      expect((await ConversationRepo().findById(conversation.id))!.isShow, 1);
      api.deleteGate = null;
      expect(await notifier.deleteConversationRemote(conversation), isTrue);
      expect(api.deleteCalls, hasLength(2));
      expect((await ConversationRepo().findById(conversation.id))!.isShow, 0);
    });

    test('移除请求抛错时保留本地会话并释放忙态', () async {
      final api = _FakeConversationApi()..deleteThrows = true;
      final conversation = await _insertConversation(
        peerId: 7002,
        type: 'C2C',
        lastTime: 1000,
      );
      final container = ProviderContainer(
        overrides: [
          conversationProvider.overrideWith(
            () => _TestConversationNotifier(api: api),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(conversationProvider, (_, _) {});
      final notifier = container.read(conversationProvider.notifier);
      expect(await notifier.deleteConversationRemote(conversation), isFalse);
      expect((await ConversationRepo().findById(conversation.id))!.isShow, 1);
      api.deleteThrows = false;
      expect(await notifier.deleteConversationRemote(conversation), isTrue);
    });

    test('ConversationState 应将置顶会话排在更晚时间的未置顶会话前', () {
      final pinned = ConversationModel(
        id: 1,
        peerId: 2001,
        avatar: '',
        title: 'pinned-peer',
        subtitle: 'pinned',
        type: 'C2C',
        msgType: 'text',
        lastTime: 1000,
        lastMsgId: 'msg-1',
        unreadNum: 0,
        payload: {
          'authoritative': {'is_pinned': true},
        },
      );
      final recent = ConversationModel(
        id: 2,
        peerId: 2002,
        avatar: '',
        title: 'recent-peer',
        subtitle: 'recent',
        type: 'C2C',
        msgType: 'text',
        lastTime: 3000,
        lastMsgId: 'msg-2',
        unreadNum: 0,
        payload: {
          'authoritative': {'is_pinned': false},
        },
      );

      final state = ConversationState(
        conversationMap: <String, ConversationModel>{
          pinned.uk3: pinned,
          recent.uk3: recent,
        },
      );

      expect(state.conversations.first.peerId, 2001);
      expect(state.conversations.last.peerId, 2002);
    });

    test('authoritative pull 应隐藏服务端已不存在的本地会话', () async {
      final api = _FakeConversationApi()
        ..entries = const <Map<String, dynamic>>[];
      await _insertConversation(peerId: 3001, type: 'C2C', lastTime: 1000);

      final container = ProviderContainer(
        overrides: [
          conversationProvider.overrideWith(
            () => _TestConversationNotifier(api: api),
          ),
        ],
      );
      final keepAlive = container.listen(conversationProvider, (_, prev) {});

      await container
          .read(conversationProvider.notifier)
          .syncAuthoritativeConversationList(trigger: 'test_pull');

      final hidden = await ConversationRepo().findByPeerId('C2C', '3001');
      final visible = await ConversationRepo().list();

      expect(hidden, isNotNull);
      expect(hidden!.isShow, 0);
      expect(visible.where((c) => c.peerId == 3001), isEmpty);
      expect(container.read(conversationProvider).conversationMap, isEmpty);

      keepAlive.close();
      container.dispose();
    });

    test('authoritative pull 应恢复隐藏会话并刷新置顶排序', () async {
      final api = _FakeConversationApi()
        ..entries = <Map<String, dynamic>>[
          {
            'conversation_id': '4001',
            'conversation_type': 'c2c',
            'server_ts': 2000,
            'last_msg_id': 14001,
            'last_msg': {'text': 'hello hidden'},
            'is_pinned': 1,
          },
          {
            'conversation_id': '4002',
            'conversation_type': 'c2c',
            'server_ts': 5000,
            'last_msg_id': 14002,
            'last_msg': {'text': 'hello recent'},
            'is_pinned': 0,
          },
        ];

      await _insertConversation(
        peerId: 4001,
        type: 'C2C',
        lastTime: 1000,
        isShow: false,
      );
      await _insertConversation(peerId: 4002, type: 'C2C', lastTime: 1000);

      final container = ProviderContainer(
        overrides: [
          conversationProvider.overrideWith(
            () => _TestConversationNotifier(api: api),
          ),
        ],
      );
      final keepAlive = container.listen(conversationProvider, (_, prev) {});

      await container
          .read(conversationProvider.notifier)
          .syncAuthoritativeConversationList(trigger: 'test_restore');

      final restored = await ConversationRepo().findByPeerId('C2C', '4001');
      final conversations = container.read(conversationProvider).conversations;

      expect(restored, isNotNull);
      expect(restored!.isShow, 1);
      expect(restored.isPinned, isTrue);
      expect(conversations, hasLength(2));
      expect(conversations.first.peerId, 4001);
      expect(conversations.first.isPinned, isTrue);

      keepAlive.close();
      container.dispose();
    });

    test('服务端删除失败时不应修改本地会话可见性', () async {
      final api = _FakeConversationApi()..deleteResult = false;
      final conversation = await _insertConversation(
        peerId: 5001,
        type: 'C2C',
        lastTime: 1000,
      );

      final container = ProviderContainer(
        overrides: [
          conversationProvider.overrideWith(
            () => _TestConversationNotifier(api: api),
          ),
        ],
      );

      final ok = await container
          .read(conversationProvider.notifier)
          .deleteConversationRemote(conversation);
      final stored = await ConversationRepo().findByPeerId('C2C', '5001');

      expect(ok, isFalse);
      expect(api.deleteCalls.single, {
        'conversation_id': '5001',
        'type': 'C2C',
      });
      expect(stored, isNotNull);
      expect(stored!.isShow, 1);

      container.dispose();
    });

    test('服务端置顶失败时不应提前改本地 payload', () async {
      final api = _FakeConversationApi()..pinResult = false;
      final conversation = await _insertConversation(
        peerId: 6001,
        type: 'C2C',
        lastTime: 1000,
        isPinned: false,
      );

      final container = ProviderContainer(
        overrides: [
          conversationProvider.overrideWith(
            () => _TestConversationNotifier(api: api),
          ),
        ],
      );

      final ok = await container
          .read(conversationProvider.notifier)
          .setConversationPinned(conversation, true);
      final stored = await ConversationRepo().findByPeerId('C2C', '6001');

      expect(ok, isFalse);
      expect(api.pinCalls.single, {'conversation_id': '6001', 'type': 'C2C'});
      expect(stored, isNotNull);
      expect(stored!.isPinned, isFalse);

      container.dispose();
    });
  });
}
