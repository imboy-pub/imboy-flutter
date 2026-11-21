import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/conversation_api.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart' show IMBoyMessageStatus;
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart'
    show MessageRepo;
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
  final List<Map<String, String>> unpinCalls = <Map<String, String>>[];
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
  Future<bool> unpin({
    required String conversationId,
    required String type,
  }) async {
    unpinCalls.add({'conversation_id': conversationId, 'type': type});
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
  String avatar = '',
}) async {
  final repo = ConversationRepo();
  final id = await repo.insert(
    ConversationModel(
      id: 0,
      peerId: peerId,
      avatar: avatar,
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

/// UX-02：给会话种一条消息行（真实 msg_c2c/msg_c2g 表）。
Future<void> _seedMessage(
  Database db, {
  required String type,
  required String uk3,
  required int autoId,
  required int msgId,
  required int status,
  required bool own,
}) async {
  await db.insert(MessageRepo.getTableName(type), {
    MessageRepo.autoId: autoId,
    MessageRepo.id: msgId,
    'msg_type': 'text',
    MessageRepo.from: own ? int.parse(_testUid) : 8000,
    MessageRepo.to: own ? 8000 : int.parse(_testUid),
    MessageRepo.conversationUk3: uk3,
    'e2ee': '',
    MessageRepo.payload: '{"text":"m-$msgId"}',
    MessageRepo.createdAt: autoId,
    MessageRepo.topicId: 0,
    MessageRepo.status: status,
    MessageRepo.isAuthor: own ? 1 : 0,
    MessageRepo.type: type,
    'action': '',
  });
}

ProviderContainer _containerWith(ConversationApi api) {
  final container = ProviderContainer(
    overrides: [
      conversationProvider.overrideWith(
        () => _TestConversationNotifier(api: api),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen(conversationProvider, (_, _) {});
  return container;
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
          peer: '8005',
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

      expect(state.conversations.first.peerId, '2001');
      expect(state.conversations.last.peerId, '2002');
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
      expect(visible.where((c) => c.peerId == '3001'), isEmpty);
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
      expect(conversations.first.peerId, '4001');
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

    test('J17.a: 明确 pin=true/false 分别落服务端真源并可回读排序', () async {
      final api = _FakeConversationApi();
      final conversation = await _insertConversation(
        peerId: 6101,
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
      final keepAlive = container.listen(conversationProvider, (_, prev) {});

      // 明确目标 true（非 toggle）：成功后本地 authoritative 真源回读
      // is_pinned=true，且会话排序进位（置顶优先于更晚的未置顶）。
      final pinned = await container
          .read(conversationProvider.notifier)
          .setConversationPinned(conversation, true);
      expect(pinned, isTrue);
      expect(api.pinCalls.single, {'conversation_id': '6101', 'type': 'C2C'});
      final afterPin = await ConversationRepo().findByPeerId('C2C', '6101');
      expect(afterPin, isNotNull);
      expect(afterPin!.isPinned, isTrue);
      expect(
        (afterPin.payload?['authoritative'] as Map?)?['is_pinned'],
        isTrue,
      );
      container
          .read(conversationProvider.notifier)
          .applyConversationSnapshot(afterPin.copyWith(lastTime: 900));
      // replaceConversation 走 100ms 批量 Timer，等 flush 后再断言排序。
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        container.read(conversationProvider).conversations.first.peerId,
        '6101',
      );

      // 明确目标 false：unpin 调用明确，真源回读翻回。
      final unpinned = await container
          .read(conversationProvider.notifier)
          .setConversationPinned(afterPin, false);
      expect(unpinned, isTrue);
      expect(api.unpinCalls.single, {'conversation_id': '6101', 'type': 'C2C'});
      final afterUnpin = await ConversationRepo().findByPeerId('C2C', '6101');
      expect(afterUnpin, isNotNull);
      expect(afterUnpin!.isPinned, isFalse);

      // 工作区成员向量：C2G 会话同 API 通道，type 明确 c2g。
      final groupConversation = await _insertConversation(
        peerId: 6102,
        type: 'C2G',
        lastTime: 800,
      );
      final groupPinned = await container
          .read(conversationProvider.notifier)
          .setConversationPinned(groupConversation, true);
      expect(groupPinned, isTrue);
      expect(api.pinCalls.last, {'conversation_id': '6102', 'type': 'C2G'});
      final groupRow = await ConversationRepo().findByPeerId('C2G', '6102');
      expect(groupRow, isNotNull);
      expect(groupRow!.isPinned, isTrue);

      keepAlive.close();
      container.dispose();
    });

    test('J17.b: hidden=true/false 明确目标本地与远端一致，失败可重试', () async {
      final api = _FakeConversationApi();
      final conversation = await _insertConversation(
        peerId: 6201,
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
      final keepAlive = container.listen(conversationProvider, (_, prev) {});
      final notifier = container.read(conversationProvider.notifier);

      // hidden=true：远端 200 → 本地 is_show=0（本地与远端一致）。
      final hidden = await notifier.deleteConversationRemote(conversation);
      expect(hidden, isTrue);
      expect(api.deleteCalls.single, {
        'conversation_id': '6201',
        'type': 'C2C',
      });
      final afterHide = await ConversationRepo().findByPeerId('C2C', '6201');
      expect(afterHide, isNotNull);
      expect(afterHide!.isShow, 0);

      // 防重/失败可重试：先一次失败（本地可见性不动），随后成功同语义。
      api.deleteResult = false;
      final retryFailed = await notifier.deleteConversationRemote(afterHide);
      expect(retryFailed, isFalse);
      final stillHidden = await ConversationRepo().findByPeerId('C2C', '6201');
      expect(stillHidden!.isShow, 0);
      api.deleteResult = true;
      final retryOk = await notifier.deleteConversationRemote(stillHidden);
      expect(retryOk, isTrue);

      // hidden=false：restore 走权威 pull 恢复本地可见性（真源一致）。
      api.entries = <Map<String, dynamic>>[
        {
          'conversation_id': '6201',
          'conversation_type': 'c2c',
          'server_ts': 3000,
          'last_msg_id': 16201,
          'last_msg': {'text': 'restored'},
          'is_pinned': 0,
        },
      ];
      final restored = await notifier.restoreConversationRemote(
        peerId: '6201',
        type: 'C2C',
      );
      expect(restored, isTrue);
      expect(api.restoreCalls.single, {
        'conversation_id': '6201',
        'type': 'C2C',
      });
      final afterRestore = await ConversationRepo().findByPeerId('C2C', '6201');
      expect(afterRestore, isNotNull);
      expect(afterRestore!.isShow, 1);

      keepAlive.close();
      container.dispose();
    });

    group('UX-02:LOCAL:01 权限撤回与世代隔离（持久终态）', () {
      test('退群撤权：行删除后入口/未读终态清空且重入不复活', () async {
        final api = _FakeConversationApi();
        final conv = await _insertConversation(
          peerId: 8101,
          type: 'C2G',
          lastTime: 1750000002000,
          // 已设自定义头像的群不预热成员拼图（产品规则），避免
          // conversationsList 的后台 warmup 走网络路径污染纯本地旅程。
          avatar: 'group-avatar-ref',
        );
        await _seedMessage(
          db,
          type: 'C2G',
          uk3: conv.uk3,
          autoId: 1,
          msgId: 101,
          status: IMBoyMessageStatus.delivered,
          own: false,
        );
        await _seedMessage(
          db,
          type: 'C2G',
          uk3: conv.uk3,
          autoId: 2,
          msgId: 102,
          status: IMBoyMessageStatus.delivered,
          own: false,
        );
        final container = _containerWith(api);
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
        expect(
          after.conversationMap[conv.uk3],
          isNull,
          reason: '撤权后的会话不得在重入时复活',
        );
        expect(after.conversationRemind[conv.uk3], isNull);
        expect(
          await db.query('conversation', where: 'id = ?', whereArgs: [conv.id]),
          isEmpty,
        );
      });

      test('世代隔离：切号后重入列表为空且旧账号行不被串写', () async {
        final api = _FakeConversationApi();
        final conv = await _insertConversation(
          peerId: 8201,
          type: 'C2C',
          lastTime: 1750000001500,
        );
        final container = _containerWith(api);
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
          expect(rows.single['user_id'].toString(), _testUid);
          expect(rows.single['is_show'], 1);
        } finally {
          await StorageService.to.setString(Keys.currentUid, _testUid);
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
        final api = _FakeConversationApi();
        final conv = await _insertConversation(
          peerId: 8301,
          type: 'C2C',
          lastTime: 1000,
        );
        // auto_id 1/2 对方未读；3 对方已读；4 水位之上的本人消息。
        await _seedMessage(
          db,
          type: 'C2C',
          uk3: conv.uk3,
          autoId: 1,
          msgId: 201,
          status: IMBoyMessageStatus.delivered,
          own: false,
        );
        await _seedMessage(
          db,
          type: 'C2C',
          uk3: conv.uk3,
          autoId: 2,
          msgId: 202,
          status: IMBoyMessageStatus.delivered,
          own: false,
        );
        await _seedMessage(
          db,
          type: 'C2C',
          uk3: conv.uk3,
          autoId: 3,
          msgId: 203,
          status: IMBoyMessageStatus.seen,
          own: false,
        );
        await _seedMessage(
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

        final container = _containerWith(api);
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
        final api = _FakeConversationApi();
        final conv = await _insertConversation(
          peerId: 8401,
          type: 'C2C',
          lastTime: 1750000002000,
        );
        await _seedMessage(
          db,
          type: 'C2C',
          uk3: conv.uk3,
          autoId: 141,
          msgId: 141,
          status: IMBoyMessageStatus.delivered,
          own: false,
        );
        await _seedMessage(
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
        final container = _containerWith(api);
        final notifier = container.read(conversationProvider.notifier);

        await notifier.syncAuthoritativeConversationList(
          trigger: 'ux02_advance',
        );
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
  });
}
