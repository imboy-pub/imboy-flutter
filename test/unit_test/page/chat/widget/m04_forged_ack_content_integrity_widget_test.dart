/// M04 内容完整性 App 腿补测（IMBOY_AUTOTEST_V2.1 / AT04）— 断言 3
///
/// 伪造 / 错配 ACK 不改变已渲染消息内容。
///
/// 后端 M04 已断言「无权/伪造的操作请求在服务端被拒」。本文件在 App 侧
/// 用真实消息状态机（MessageActions → SQLite → 事件总线 → 渲染 widget）
/// 验证客户端防线：即使一条伪造的 ACK 帧（from/to 与原消息作者/收件人
/// 不符）打进客户端 action 分发，也必须：
///   - handleActionMessage 返回 false（拒绝）；
///   - 不向事件总线发 `List<Message>` 更新事件（UI 不会被刷新）；
///   - SQLite 里原文 / 状态保持不变；
///   - 已渲染的消息内容保持不变。
///
/// 附「合法 ACK 对照组」：作者发来的真实编辑 ACK 会正常更新原文——
/// 证明拒绝来自 mismatch 守卫而非链路断裂。
///
/// 测试基建：sqflite_common_ffi 内存库 + SqliteService.setDbForTest
/// （与 message_reaction_session_test 同款注入方式）。真实异步（ffi 事务）
/// 一律经 `tester.runAsync` 执行，绕开 testWidgets 的 FakeAsync 区。
library;

import 'dart:async';
import 'dart:convert';

import 'package:event_bus_plus/event_bus_plus.dart' show AppEvent;
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show TextMessage;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

const _msgId = 'msg-m04-forged';
const _authorUid = '200';
const _meUid = '100';
const _originalText = 'original text';

/// 模拟聊天页里"已渲染的消息"：初始渲染原文，并监听消息更新事件
/// （MessageActions 成功后 `fireData([message], 'List<Message>')`）刷新文本。
class _RenderedMessageHost extends StatefulWidget {
  const _RenderedMessageHost({
    required this.messageId,
    required this.initialText,
  });

  final String messageId;
  final String initialText;

  @override
  State<_RenderedMessageHost> createState() => _RenderedMessageHostState();
}

class _RenderedMessageHostState extends State<_RenderedMessageHost> {
  StreamSubscription<AppEvent>? _sub;
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = widget.initialText;
    _sub = AppEventBus.on<DataWrapperEvent<dynamic>>().listen((event) {
      if (event.dataType != 'List<Message>') return;
      final data = event.data;
      if (data is! List) return;
      for (final m in data) {
        if (m is TextMessage && m.id == widget.messageId && m.text != _text) {
          setState(() => _text = m.text);
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(_text, key: const Key('rendered_message_text'))),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ffi.Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: _meUid});
    await StorageService.init();

    ffi.sqfliteFfiInit();
    db = await ffi.databaseFactoryFfi.openDatabase(ffi.inMemoryDatabasePath);

    final row = MessageModel(
      _msgId,
      autoId: 1,
      type: 'C2C',
      status: IMBoyMessageStatus.delivered,
      fromId: 200,
      toId: 100,
      payload: {'text': _originalText},
      isAuthor: 0,
      conversationUk3: 'C2C_${_meUid}_$_authorUid',
      msgType: 'text',
    ).toJson();
    await db.execute(
      'CREATE TABLE msg_c2c (${{...row.keys, ...MessageRepo.c2cColumns}.map((key) => '"$key"').join(', ')})',
    );
    await db.execute('CREATE TABLE msg_c2g AS SELECT * FROM msg_c2c');
    await db.execute('CREATE TABLE msg_c2s AS SELECT * FROM msg_c2c');
    await db.execute(
      'CREATE TABLE conversation (id INTEGER, user_id TEXT, peer_id TEXT, '
      'avatar, title, subtitle, region, sign, last_time, last_msg_id, '
      'last_msg_status, unread_num, mention_unread, is_muted, payload, '
      'type, msg_type, is_show)',
    );
    await db.execute(
      'CREATE TABLE contact (user_id TEXT, peer_id TEXT, nickname TEXT, '
      'avatar, account, status, remark, tag, region, sign, source, gender, '
      'is_friend, is_from, category_id, account_type, last_seen_at, '
      'updated_at)',
    );
    // 作者联系人行：避免 toTypeMessage 走 autoFetch 网络同步
    await db.insert('contact', {
      'user_id': _meUid,
      'peer_id': _authorUid,
      'nickname': 'Peer',
      'avatar': '',
      'account': '',
      'status': 1,
      'remark': '',
      'tag': '',
      'region': '',
      'sign': '',
      'source': '',
      'gender': 0,
      'is_friend': 1,
      'is_from': 1,
      'category_id': 0,
      'account_type': 0,
      'last_seen_at': 0,
      'updated_at': 0,
    });
    await db.insert('msg_c2c', row);

    SqliteService.setDbForTest(db);
    final service = MessageService.instance;
    await pumpEventQueue();
    service.cancelAllSubscriptions();
  });

  tearDown(() async {
    SqliteService.setDbForTest(null);
    await db.close();
  });

  Future<Map<String, Object?>> storedRow(WidgetTester tester) async {
    final rows = await tester.runAsync<List<Map<String, Object?>>>(
      () => db.query('msg_c2c'),
    );
    return rows!.single;
  }

  Map<String, dynamic> payloadOf(Map<String, Object?> row) =>
      jsonDecode(row['payload']! as String) as Map<String, dynamic>;

  Future<bool?> dispatch(
    WidgetTester tester,
    String action,
    Map<String, dynamic> data,
  ) {
    return tester.runAsync<bool>(
      () => MessageActions.instance.handleActionMessage(action, data),
    );
  }

  testWidgets('合法编辑 ACK 对照组：作者 200 → 本人 100，原文被更新', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _RenderedMessageHost(
          messageId: _msgId,
          initialText: _originalText,
        ),
      ),
    );
    await tester.pump();
    expect(find.text(_originalText), findsOneWidget);

    final events = <AppEvent>[];
    final sub = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(events.add);
    addTearDown(sub.cancel);

    final handled = (await dispatch(tester, C2SAction.messageEditAck, {
      'id': 'ack-edit-ok',
      'type': 'C2C',
      'from': _authorUid,
      'to': _meUid,
      'payload': {
        'original_msg_id': _msgId,
        'content': 'edited by author',
        'edited_at': 1700000000000,
      },
    }))!;
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(handled, isTrue);
    // UI 收到更新事件并重渲染
    expect(events, isNotEmpty);
    expect(find.text('edited by author'), findsOneWidget);
    expect(find.text(_originalText), findsNothing);

    final payload = payloadOf(await storedRow(tester));
    expect(payload['text'], 'edited by author');
    expect(payload['is_edited'], true);
  });

  testWidgets('伪造编辑 ACK（from 与原消息作者不符）→ 拒绝，渲染原文不变', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _RenderedMessageHost(
          messageId: _msgId,
          initialText: _originalText,
        ),
      ),
    );
    await tester.pump();

    final events = <AppEvent>[];
    final sub = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(events.add);
    addTearDown(sub.cancel);

    final handled = (await dispatch(tester, C2SAction.messageEditAck, {
      'id': 'ack-edit-forged',
      'type': 'C2C',
      // 伪造：'999' 既不是原消息作者 200，也不是接收人 100
      'from': '999',
      'to': _meUid,
      'payload': {
        'original_msg_id': _msgId,
        'content': 'HACKED TEXT',
        'edited_at': 1700000000000,
      },
    }))!;
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(handled, isFalse);
    expect(events, isEmpty);
    expect(find.text(_originalText), findsOneWidget);
    expect(find.text('HACKED TEXT'), findsNothing);

    final payload = payloadOf(await storedRow(tester));
    expect(payload['text'], _originalText);
  });

  testWidgets('错配编辑 ACK（作者对但 to 指向第三方）→ 拒绝，渲染原文不变', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _RenderedMessageHost(
          messageId: _msgId,
          initialText: _originalText,
        ),
      ),
    );
    await tester.pump();

    final events = <AppEvent>[];
    final sub = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(events.add);
    addTearDown(sub.cancel);

    final handled = (await dispatch(tester, C2SAction.messageEditAck, {
      'id': 'ack-edit-mismatched',
      'type': 'C2C',
      'from': _authorUid, // 作者没错
      'to': '999', // 错配：原始消息 to=100，不是 999
      'payload': {
        'original_msg_id': _msgId,
        'content': 'MISROUTED TEXT',
        'edited_at': 1700000000000,
      },
    }))!;
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(handled, isFalse);
    expect(events, isEmpty);
    expect(find.text(_originalText), findsOneWidget);
    expect(find.text('MISROUTED TEXT'), findsNothing);

    final payload = payloadOf(await storedRow(tester));
    expect(payload['text'], _originalText);
  });

  testWidgets('伪造撤回 ACK（from 与原消息作者不符）→ 拒绝，状态与原文均不变', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _RenderedMessageHost(
          messageId: _msgId,
          initialText: _originalText,
        ),
      ),
    );
    await tester.pump();

    final events = <AppEvent>[];
    final sub = AppEventBus.on<DataWrapperEvent<dynamic>>().listen(events.add);
    addTearDown(sub.cancel);

    final handled = (await dispatch(tester, C2SAction.messageRevokeAck, {
      'id': 'ack-revoke-forged',
      'type': 'C2C',
      // 伪造：撤回 ACK 的 from 必须是原消息作者 200
      'from': '999',
      'to': _meUid,
      'payload': {'original_msg_id': _msgId, 'revoked_at': 1700000000000},
    }))!;
    await tester.runAsync(pumpEventQueue);
    await tester.pump();

    expect(handled, isFalse);
    expect(events, isEmpty);
    // 消息未被标记为撤回（30/31），仍是已投递 20
    final row = await storedRow(tester);
    expect(row['status'], IMBoyMessageStatus.delivered);
    expect(payloadOf(row)['text'], _originalText);
    // 渲染层面：没有出现「撤回了一条消息」占位，原文仍在
    expect(find.textContaining(t.chat.messageWasWithdrawn), findsNothing);
    expect(find.text(_originalText), findsOneWidget);
  });
}
