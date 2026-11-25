// UX-02 会话权威操作（免打扰/隐藏/置顶/权威拉取）共享 fixture
// （拆分自 conversation_authority_actions_test.dart，ratchet <800 行约束）。
//
// FakeConversationApi / TestConversationNotifier / insertConversationFixture /
// seedMessageFixture / containerWithFixture / authorityTestUid。本文件不含用例。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/conversation/conversation_provider.dart';
import 'package:imboy/store/api/conversation_api.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart'
    show MessageRepo;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const authorityTestUid = '995011';

class FakeConversationApi extends ConversationApi {
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

class TestConversationNotifier extends ConversationNotifier {
  TestConversationNotifier({required ConversationApi api})
    : super(conversationApi: api);
}

Future<ConversationModel> insertConversationFixture({
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
Future<void> seedMessageFixture(
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
    MessageRepo.from: own ? int.parse(authorityTestUid) : 8000,
    MessageRepo.to: own ? 8000 : int.parse(authorityTestUid),
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

ProviderContainer containerWithFixture(ConversationApi api) {
  final container = ProviderContainer(
    overrides: [
      conversationProvider.overrideWith(
        () => TestConversationNotifier(api: api),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen(conversationProvider, (_, _) {});
  return container;
}
