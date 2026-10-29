import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/message_scroll_provider.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/page/chat/chat/services/chat_archive_service.dart';
import 'package:imboy/page/chat/chat/sqlite_chat_service.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/msg_api.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends Mock implements MessageRepository {}

class _Api extends Mock implements MsgApi {}

class _Environment extends Mock implements Env {}

class _Sessions extends ChangeNotifier implements AuthSessionReader {
  @override
  AuthSessionScope current = (uid: '1001', generation: 1, transitioning: false);
  @override
  bool isCurrent(AuthSessionScope captured) =>
      !current.transitioning && current == captured;
}

final _controllerProvider = Provider<SqliteChatService>(SqliteChatService.new);

ConversationModel _conversation({String type = 'C2C', int peerId = 2002}) =>
    ConversationModel(
      id: 1,
      peerId: peerId,
      avatar: '',
      title: 'Synthetic conversation',
      subtitle: '',
      type: type,
      msgType: 'text',
      unreadNum: 0,
    );

MessageModel _row(String id, String conversationId, {int autoId = 10}) =>
    MessageModel(
      id,
      autoId: autoId,
      type: 'C2C',
      status: IMBoyMessageStatus.sent,
      fromId: 1001,
      toId: 2002,
      payload: <String, dynamic>{'text': 'Synthetic'},
      isAuthor: 1,
      conversationUk3: conversationId,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      msgType: 'text',
    );

Map<String, dynamic> _wire(
  String id, {
  int sequence = 10,
  String type = 'c2c',
}) => {
  'msg_id': id,
  'conv_seq': sequence,
  'chat_type': type,
  'from': '1001',
  if (type == 'c2g') 'group_id': '2002' else 'to': '2002',
  'msg_type': 'text',
  'payload': <String, dynamic>{'text': 'Synthetic'},
  'created_at': DateTime.now().millisecondsSinceEpoch,
};

IMBoyHttpResponse _context(
  String id,
  List<dynamic> rows, {
  String type = 'c2c',
}) => IMBoyHttpResponse.success(<String, dynamic>{
  'context_msg_id': id,
  'conv_key': type == 'c2g' ? 'c2g:2002' : 'c2c:1001:2002',
  'messages': rows,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late SqliteChatService controller;
  late _Repository repository;
  late _Api api;
  late _Sessions sessions;
  late ChatArchiveService archive;
  late ConversationModel conversation;
  late IMBoyHttpResponse response;
  Future<IMBoyHttpResponse> Function(String)? answer;
  final stored = <String, MessageModel>{};
  final requests = <String>[];
  final writes = <List<Map<String, dynamic>>>[];
  final updates = <({int next, int previous, String conversation})>[];

  Future<MessageLocationResult> locate(
    String id, {
    bool Function()? isCurrent,
  }) => archive.loadMessagesAround(
    chatService: controller,
    scrollManager: container.read(messageScrollManagerProvider.notifier),
    conversation: conversation,
    msgId: id,
    isCurrent: isCurrent ?? () => true,
    updateState:
        ({
          required int nextAutoId,
          required int prevAutoId,
          required String currentConversationId,
        }) => updates.add((
          next: nextAutoId,
          previous: prevAutoId,
          conversation: currentConversationId,
        )),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '1001',
      Keys.currentUser: '{"uid":"1001","nickname":"Synthetic user"}',
      '${Keys.msgHistorySeqPrefix}C2C_1001_2002': 7,
    });
    await StorageService.init();
    container = ProviderContainer();
    container.listen(messageScrollManagerProvider, (_, _) {});
    controller = container.read(_controllerProvider);
    repository = _Repository();
    api = _Api();
    sessions = _Sessions();
    archive = ChatArchiveService(
      api: api,
      repository: repository,
      sessions: sessions,
    );
    conversation = _conversation();
    response = IMBoyHttpResponse.failure(
      errCode: 404,
      errMsg: 'history_context_unavailable',
    );
    answer = null;
    stored.clear();
    requests.clear();
    writes.clear();
    updates.clear();
    when(
      () => api.historyContext(
        chatType: any(named: 'chatType'),
        peerId: any(named: 'peerId'),
        targetMsgId: any(named: 'targetMsgId'),
        limit: any(named: 'limit'),
        did: any(named: 'did'),
      ),
    ).thenAnswer((call) async {
      final id = call.namedArguments[#targetMsgId] as String;
      requests.add(id);
      return answer == null ? response : await answer!(id);
    });
    when(() => repository.find(any()))
        .thenAnswer((call) async => stored[call.positionalArguments[0]]);
    when(
      () => repository.batchInsertOfflineMessages(any(), trustedArchive: true),
    ).thenAnswer((call) async {
      final rows = call.positionalArguments[0] as List<Map<String, dynamic>>;
      writes.add(rows);
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        final id = row['msg_id'] as String;
        stored.putIfAbsent(
          id,
          () => _row(id, conversation.uk3, autoId: index + 9)
            ..type = row['type'] as String
            ..fromId = row['from'].toString()
            ..toId = row['to'].toString(),
        );
      }
      return rows.map((row) => row['msg_id'] as String).toList();
    });
  });

  tearDown(() {
    expect(
      StorageService.to.getInt('${Keys.msgHistorySeqPrefix}C2C_1001_2002'),
      7,
    );
    verifyNever(
      () => api.history(
        chatType: any(named: 'chatType'),
        peerId: any(named: 'peerId'),
      ),
    );
    verifyNever(
      () => api.historyBackfill(
        chatType: any(named: 'chatType'),
        peerId: any(named: 'peerId'),
        afterSeq: any(named: 'afterSeq'),
      ),
    );
    verifyNever(() => repository.pageForConversation(any(), any(), any()));
    verifyNever(() => repository.pageNewerForConversation(any(), any(), any()));
    controller.dispose();
    container.dispose();
    sessions.dispose();
  });

  test('J18.e 已加载目标保持列表与游标，不读库或请求历史', () async {
    final message = TextMessage(
      id: 'loaded',
      authorId: '1001',
      text: 'Synthetic',
      metadata: {'conversation_uk3': conversation.uk3},
    );
    await controller.setMessages([message]);
    expect(await locate('loaded'), MessageLocationResult.located);
    expect(controller.messages.single, same(message));
    expect(updates, isEmpty);
    expect(requests, isEmpty);
    verifyZeroInteractions(repository);
  });

  test('J18.f 本机缺失经合法目标上下文定位并更新双向游标', () async {
    expect(stored, isEmpty);
    response = _context('target', [
      _wire('newer', sequence: 11),
      _wire('target'),
      _wire('older', sequence: 9),
    ]);
    expect(await locate('target'), MessageLocationResult.located);
    expect(controller.messages.map((message) => message.id), [
      'older',
      'target',
      'newer',
    ]);
    expect(updates.single, (
      next: 9,
      previous: 11,
      conversation: conversation.uk3,
    ));
    expect(requests, ['target']);
    expect(writes.single.map((row) => row['conv_seq']), [9, 10, 11]);
  });

  test('J18.f 混合缓存入库顺序按上下文两端设游标，不取auto_id极值', () async {
    stored['older'] = _row('older', conversation.uk3, autoId: 92);
    stored['target'] = _row('target', conversation.uk3, autoId: 93);
    stored['newer'] = _row('newer', conversation.uk3, autoId: 2);
    response = _context('target', [
      _wire('newer', sequence: 11),
      _wire('target'),
      _wire('older', sequence: 9),
    ]);
    expect(await locate('target'), MessageLocationResult.located);
    expect(controller.messages.map((message) => message.id), [
      'older',
      'target',
      'newer',
    ]);
    expect(updates.single, (
      next: 92,
      previous: 2,
      conversation: conversation.uk3,
    ));
  });

  test('J18.f 有权C2G未加载目标使用服务端当前代际上下文', () async {
    conversation = _conversation(type: 'C2G');
    response = _context('group-target', [
      _wire('group-target', type: 'c2g'),
    ], type: 'c2g');
    expect(await locate('group-target'), MessageLocationResult.located);
    expect(controller.messages.single.id, 'group-target');
    expect(writes.single.single['type'], 'C2G');
    expect(writes.single.single['to'], '2002');
    verify(
      () => api.historyContext(
        chatType: 'c2g',
        peerId: '2002',
        targetMsgId: 'group-target',
        limit: 41,
        did: any(named: 'did'),
      ),
    ).called(1);
  });

  test('J18.f 迟到目标等待目标API完成后定位', () async {
    final pending = Completer<IMBoyHttpResponse>();
    answer = (_) => pending.future;
    var finished = false;
    final operation = locate('late').then((result) {
      finished = true;
      return result;
    });
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    expect(writes, isEmpty);
    pending.complete(_context('late', [_wire('late')]));
    expect(await operation, MessageLocationResult.located);
    expect(controller.messages.single.id, 'late');
  });

  test('J18.f 旧服务端忽略target即使头部包含目标也不得定位或落库', () async {
    response = IMBoyHttpResponse.success(<String, dynamic>{
      'conv_key': 'c2c:1001:2002',
      'messages': [_wire('target')],
      'next_seq': 999,
    });
    expect(
      await locate('target'),
      MessageLocationResult.authorizationUnavailable,
    );
    expect(writes, isEmpty);
    expect(updates, isEmpty);
  });

  test('J18.e 已加载但属于另一会话或参与者的同ID不定位', () async {
    await controller.setMessages([
      TextMessage(
        id: 'foreign',
        authorId: '3003',
        text: 'Synthetic',
        metadata: {'conversation_uk3': conversation.uk3},
      ),
    ]);
    expect(await locate('foreign'), MessageLocationResult.forbidden);
    await controller.setMessages([
      TextMessage(
        id: 'foreign',
        authorId: '1001',
        text: 'Synthetic',
        metadata: {'conversation_uk3': 'C2C_1001_3003'},
      ),
    ]);
    expect(await locate('foreign'), MessageLocationResult.forbidden);
    expect(requests, isEmpty);
  });

  test('J18.f 错误目标回显不能作为授权上下文', () async {
    response = _context('different', [_wire('target')]);
    expect(
      await locate('target'),
      MessageLocationResult.authorizationUnavailable,
    );
    expect(writes, isEmpty);
  });

  for (final failure in [
    (
      code: 401,
      message: 'unauthorized',
      result: MessageLocationResult.forbidden,
    ),
    (code: 403, message: 'forbidden', result: MessageLocationResult.forbidden),
    (
      code: 404,
      message: 'history_context_unavailable',
      result: MessageLocationResult.unavailable,
    ),
    (
      code: 404,
      message: 'route not found',
      result: MessageLocationResult.authorizationUnavailable,
    ),
    (
      code: 500,
      message: 'archive disabled',
      result: MessageLocationResult.failed,
    ),
  ]) {
    test(
      'J18.f envelope ${failure.code}/${failure.message} 保持原列表可重试',
      () async {
        final original = TextMessage(
          id: 'original',
          authorId: '1001',
          text: 'Synthetic',
        );
        await controller.setMessages([original]);
        stored['target'] = _row('target', conversation.uk3);
        response = IMBoyHttpResponse.failure(
          errCode: failure.code,
          errMsg: failure.message,
        );
        expect(await locate('target'), failure.result);
        expect(controller.messages.single, same(original));
        expect(writes, isEmpty);
        expect(updates, isEmpty);
      },
    );
  }

  for (final malformed in [
    <dynamic>[],
    [_wire('different')],
    [_wire('target'), 'malformed'],
    [_wire('target'), _wire('target', sequence: 11)],
    [_wire('target'), _wire('duplicate-sequence')],
    [_wire('target')..['conv_seq'] = null],
    [_wire('target')..['to'] = '3003'],
    [_wire('target')..['chat_type'] = 'c2g'],
    [_wire('target')..['conv_key'] = 'c2c:1001:3003'],
  ].indexed) {
    test('J18.f 畸形或越界上下文 ${malformed.$1} 不落库', () async {
      response = _context('target', malformed.$2);
      expect(await locate('target'), MessageLocationResult.failed);
      expect(writes, isEmpty);
      expect(controller.messages, isEmpty);
    });
  }

  test('J18.f conv_key不匹配不得读取另一会话的缓存', () async {
    response = _context('target', [_wire('target')]);
    response.payload['conv_key'] = 'c2c:1001:3003';
    expect(await locate('target'), MessageLocationResult.failed);
    verifyZeroInteractions(repository);
  });

  test('J18.f 有界上下文超限不得显示', () async {
    response = _context('target', [
      _wire('target'),
      ...List.generate(
        41,
        (index) => _wire('extra-$index', sequence: index + 11),
      ),
    ]);
    expect(await locate('target'), MessageLocationResult.failed);
    expect(writes, isEmpty);
  });

  for (final wrongLocal in ['conversation', 'participant', 'type']) {
    test('J18.f 仅按ID命中的本地行$wrongLocal错误不得展示', () async {
      response = _context('target', [_wire('target')]);
      stored['target'] = _row('target', conversation.uk3);
      if (wrongLocal == 'conversation') {
        stored['target']!.conversationUk3 = 'C2C_1001_3003';
      }
      if (wrongLocal == 'participant') stored['target']!.toId = '3003';
      if (wrongLocal == 'type') stored['target']!.type = 'C2G';
      expect(await locate('target'), isNot(MessageLocationResult.located));
      expect(updates, isEmpty);
      expect(controller.messages, isEmpty);
    });
  }

  for (final failure in [
    (reason: 'no_device_key', result: MessageLocationResult.missingKey),
    (
      reason: 'historical_room_key_scope_denied',
      result: MessageLocationResult.forbidden,
    ),
    (reason: 'no_device_envelope', result: MessageLocationResult.undecryptable),
    (reason: 'decrypt_failed', result: MessageLocationResult.undecryptable),
  ]) {
    test('J18.f 合法目标本地解密占位 ${failure.reason} 不伪报成功', () async {
      response = _context('encrypted', [_wire('encrypted')]);
      stored['encrypted'] = _row('encrypted', conversation.uk3)
        ..payload = <String, dynamic>{
          'text': 'Synthetic placeholder',
          '_e2ee_failed': true,
          '_e2ee_reason': failure.reason,
        };
      expect(await locate('encrypted'), failure.result);
      expect(updates, isEmpty);
      expect(controller.messages, isEmpty);
    });
  }

  test('J18.f 已加载过期阅后即焚消息不定位', () async {
    await controller.setMessages([
      TextMessage(
        id: 'expired',
        authorId: '2002',
        text: 'Synthetic',
        metadata: {
          'conversation_uk3': conversation.uk3,
          'burn': true,
          'burn_after_ms': 1,
          'burn_read_at': 1,
        },
      ),
    ]);
    expect(await locate('expired'), MessageLocationResult.expired);
    expect(requests, isEmpty);
  });

  test('J18.f 本地墓碑不因授权归档再次展示', () async {
    response = _context('tombstone', [_wire('tombstone')]);
    stored['tombstone'] = _row('tombstone', conversation.uk3)
      ..payload = <String, dynamic>{'text': '', 'burn_deleted': true};
    expect(await locate('tombstone'), MessageLocationResult.expired);
    expect(controller.messages, isEmpty);
    expect(updates, isEmpty);
  });

  test('J18.f 过期邻居不随合法目标进入上下文', () async {
    response = _context('target', [
      _wire('expired', sequence: 9),
      _wire('target'),
    ]);
    stored['expired'] = _row('expired', conversation.uk3)
      ..payload = <String, dynamic>{'text': '', 'burn_deleted': true};
    expect(await locate('target'), MessageLocationResult.located);
    expect(controller.messages.map((message) => message.id), ['target']);
  });

  for (final boundary in [
    'account',
    'generation',
    'conversation',
    'membership',
  ]) {
    test('J18.f $boundary切换丢弃晚到上下文，不落库或渲染', () async {
      conversation.payload = {'member_generation_id': 1};
      final pending = Completer<IMBoyHttpResponse>();
      answer = (_) => pending.future;
      var current = true;
      final operation = locate('late', isCurrent: () => current);
      if (boundary == 'account') {
        sessions.current = (uid: '3003', generation: 2, transitioning: false);
      }
      if (boundary == 'generation') {
        sessions.current = (uid: '1001', generation: 2, transitioning: false);
      }
      if (boundary == 'conversation') {
        current = false;
        conversation = _conversation(peerId: 3003);
      }
      if (boundary == 'membership') {
        conversation.payload!['member_generation_id'] = 2;
      }
      pending.complete(_context('late', [_wire('late')]));
      expect(await operation, MessageLocationResult.cancelled);
      expect(writes, isEmpty);
      expect(updates, isEmpty);
      expect(controller.messages, isEmpty);
    });
  }

  test('J18.f 目标切换后旧请求不覆盖新目标上下文', () async {
    final pending = Completer<IMBoyHttpResponse>();
    answer = (id) async =>
        id == 'first' ? await pending.future : _context(id, [_wire(id)]);
    var request = 1;
    final first = locate('first', isCurrent: () => request == 1);
    request = 2;
    expect(
      await locate('second', isCurrent: () => request == 2),
      MessageLocationResult.located,
    );
    pending.complete(_context('first', [_wire('first')]));
    expect(await first, MessageLocationResult.cancelled);
    expect(controller.messages.single.id, 'second');
    expect(updates, hasLength(1));
    expect(writes, hasLength(1));
  });

  test('J18.f 服务源切换丢弃旧源响应，不落库或渲染', () async {
    final previous = envMap[currentEnv]!;
    final environment = _Environment();
    var endpoint = 'http://127.0.0.1:9800';
    when(() => environment.apiBaseUrl).thenAnswer((_) => endpoint);
    envMap[currentEnv] = environment;
    try {
      final pending = Completer<IMBoyHttpResponse>();
      answer = (_) => pending.future;
      final operation = locate('old-source');
      endpoint = 'http://127.0.0.1:9801';
      pending.complete(_context('old-source', [_wire('old-source')]));
      expect(await operation, MessageLocationResult.cancelled);
      expect(writes, isEmpty);
      expect(updates, isEmpty);
    } finally {
      envMap[currentEnv] = previous;
    }
  });

  test('J18.f 读取本地行等待期间目标切换，不展示旧上下文', () async {
    final pending = Completer<MessageModel?>();
    response = _context('first', [_wire('first')]);
    when(() => repository.find('first')).thenAnswer((_) => pending.future);
    var current = true;
    final operation = locate('first', isCurrent: () => current);
    await Future<void>.delayed(Duration.zero);
    current = false;
    pending.complete(_row('first', conversation.uk3));
    expect(await operation, MessageLocationResult.cancelled);
    expect(updates, isEmpty);
    expect(controller.messages, isEmpty);
  });

  test('J18.f 归档落库失败不得报告找到或改变游标', () async {
    response = _context('target', [_wire('target')]);
    when(
      () => repository.batchInsertOfflineMessages(any(), trustedArchive: true),
    ).thenAnswer((_) async => null);
    expect(await locate('target'), MessageLocationResult.failed);
    expect(updates, isEmpty);
    expect(controller.messages, isEmpty);
  });

  test('J18.f 落库等待期间账号代次变化不读取或展示旧目标', () async {
    final pending = Completer<List<String>?>();
    response = _context('target', [_wire('target')]);
    when(
      () => repository.batchInsertOfflineMessages(any(), trustedArchive: true),
    ).thenAnswer((_) => pending.future);
    final operation = locate('target');
    await Future<void>.delayed(Duration.zero);
    sessions.current = (uid: '1001', generation: 2, transitioning: false);
    pending.complete(['target']);
    expect(await operation, MessageLocationResult.cancelled);
    verifyNever(() => repository.find(any()));
    expect(updates, isEmpty);
  });

  test('J18.f 网络失败保留原上下文并可再次点击重试', () async {
    answer = (_) => Future<IMBoyHttpResponse>.error(
      StateError('synthetic network failure'),
    );
    expect(await locate('target'), MessageLocationResult.failed);
    answer = null;
    response = _context('target', [_wire('target')]);
    expect(await locate('target'), MessageLocationResult.located);
    expect(requests, ['target', 'target']);
  });

  testWidgets('J18.f 目标查询12秒超时，晚到结果不修改列表', (tester) async {
    final pending = Completer<IMBoyHttpResponse>();
    answer = (_) => pending.future;
    final operation = locate('late');
    await tester.pump(const Duration(seconds: 12));
    expect(await operation, MessageLocationResult.failed);
    pending.complete(_context('late', [_wire('late')]));
    await tester.pump();
    expect(writes, isEmpty);
    expect(updates, isEmpty);
    expect(controller.messages, isEmpty);
  });
}
