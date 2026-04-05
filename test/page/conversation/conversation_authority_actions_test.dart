library;

import 'dart:io';

import 'package:flutter/services.dart';
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

const _testUid = 'test_uid_conversation_authority_actions';

class _FakeConversationApi extends ConversationApi {
  List<Map<String, dynamic>> entries = const <Map<String, dynamic>>[];
  bool pinResult = true;
  bool deleteResult = true;
  bool restoreResult = true;

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
  required String peerId,
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
      title: peerId,
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
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (methodCall) async {
          switch (methodCall.method) {
            case 'getTemporaryDirectory':
            case 'getApplicationDocumentsDirectory':
            case 'getApplicationSupportDirectory':
            case 'getDatabasesPath':
              return Directory.systemTemp.path;
            default:
              return Directory.systemTemp.path;
          }
        });

    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, _testUid);
    await SqliteService.to.db;
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  setUp(() async {
    await SqliteService.to.delete(
      ConversationRepo.tableName,
      where: '${ConversationRepo.userId} = ?',
      whereArgs: <Object?>[_testUid],
    );
  });

  group('Conversation authority actions', () {
    test('ConversationState 应将置顶会话排在更晚时间的未置顶会话前', () {
      final pinned = ConversationModel(
        id: 1,
        peerId: 'pinned-peer',
        avatar: '',
        title: 'pinned-peer',
        subtitle: 'pinned',
        type: 'C2C',
        msgType: 'text',
        lastTime: 1000,
        lastMsgId: 'm1',
        unreadNum: 0,
        payload: {
          'authoritative': {'is_pinned': true},
        },
      );
      final recent = ConversationModel(
        id: 2,
        peerId: 'recent-peer',
        avatar: '',
        title: 'recent-peer',
        subtitle: 'recent',
        type: 'C2C',
        msgType: 'text',
        lastTime: 3000,
        lastMsgId: 'm2',
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

      expect(state.conversations.first.peerId, 'pinned-peer');
      expect(state.conversations.last.peerId, 'recent-peer');
    });

    test('authoritative pull 应隐藏服务端已不存在的本地会话', () async {
      final api = _FakeConversationApi()
        ..entries = const <Map<String, dynamic>>[];
      await _insertConversation(
        peerId: 'stale-peer',
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

      await container
          .read(conversationProvider.notifier)
          .syncAuthoritativeConversationList(trigger: 'test_pull');

      final hidden = await ConversationRepo().findByPeerId('C2C', 'stale-peer');
      final visible = await ConversationRepo().list();

      expect(hidden, isNotNull);
      expect(hidden!.isShow, 0);
      expect(visible.where((c) => c.peerId == 'stale-peer'), isEmpty);
      expect(container.read(conversationProvider).conversationMap, isEmpty);

      keepAlive.close();
      container.dispose();
    });

    test('authoritative pull 应恢复隐藏会话并刷新置顶排序', () async {
      final api = _FakeConversationApi()
        ..entries = <Map<String, dynamic>>[
          {
            'conversation_id': 'hidden-peer',
            'conversation_type': 'c2c',
            'server_ts': 2000,
            'last_msg_id': 'msg-hidden',
            'last_msg': {'text': 'hello hidden'},
            'is_pinned': 1,
          },
          {
            'conversation_id': 'recent-peer',
            'conversation_type': 'c2c',
            'server_ts': 5000,
            'last_msg_id': 'msg-recent',
            'last_msg': {'text': 'hello recent'},
            'is_pinned': 0,
          },
        ];

      await _insertConversation(
        peerId: 'hidden-peer',
        type: 'C2C',
        lastTime: 1000,
        isShow: false,
      );
      await _insertConversation(
        peerId: 'recent-peer',
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

      await container
          .read(conversationProvider.notifier)
          .syncAuthoritativeConversationList(trigger: 'test_restore');

      final restored = await ConversationRepo().findByPeerId(
        'C2C',
        'hidden-peer',
      );
      final conversations = container.read(conversationProvider).conversations;

      expect(restored, isNotNull);
      expect(restored!.isShow, 1);
      expect(restored.isPinned, isTrue);
      expect(conversations, hasLength(2));
      expect(conversations.first.peerId, 'hidden-peer');
      expect(conversations.first.isPinned, isTrue);

      keepAlive.close();
      container.dispose();
    });

    test('服务端删除失败时不应修改本地会话可见性', () async {
      final api = _FakeConversationApi()..deleteResult = false;
      final conversation = await _insertConversation(
        peerId: 'delete-peer',
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
      final stored = await ConversationRepo().findByPeerId(
        'C2C',
        'delete-peer',
      );

      expect(ok, isFalse);
      expect(api.deleteCalls.single, {
        'conversation_id': 'delete-peer',
        'type': 'C2C',
      });
      expect(stored, isNotNull);
      expect(stored!.isShow, 1);

      container.dispose();
    });

    test('服务端置顶失败时不应提前改本地 payload', () async {
      final api = _FakeConversationApi()..pinResult = false;
      final conversation = await _insertConversation(
        peerId: 'pin-peer',
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
      final stored = await ConversationRepo().findByPeerId('C2C', 'pin-peer');

      expect(ok, isFalse);
      expect(api.pinCalls.single, {
        'conversation_id': 'pin-peer',
        'type': 'C2C',
      });
      expect(stored, isNotNull);
      expect(stored!.isPinned, isFalse);

      container.dispose();
    });
  });
}
