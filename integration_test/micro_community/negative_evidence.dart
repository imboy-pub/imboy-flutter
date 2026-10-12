import 'dart:async';

import 'package:crypto/crypto.dart';

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show Message, MessageStatus;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/page/chat/chat/chat_message_item.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/secure_token_storage_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/repository/channel_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'negative_phase.dart';
import 'negative_ui.dart';
import '../flows/test_utils.dart' show flowLog;

class NegativeEvidence {
  NegativeEvidence._(
    this.db,
    this._token,
    this._refresh,
    this._did,
    this._uid,
    this._generation,
  ) {
    _subscriptions.add(
      AppEventBus.on<WebSocketMessageReceivedEvent>().listen((event) {
        if (event.type == 'C2G') {
          final id = (event.data['id'] ?? event.data['msg_id']).toString();
          received[id] = (received[id] ?? 0) + 1;
        }
      }),
    );
    _subscriptions.add(
      AppEventBus.on<DataWrapperEvent<dynamic>>().listen(
        _observeMessageUpdates,
      ),
    );
    _subscriptions.add(
      AppEventBus.on<RemoveFromRetryQueueRequestedEvent>().listen((event) {
        if (event.reason == 'server_ack' &&
            event.messageType == 'C2G_SERVER_ACK' &&
            event.ownerUid == _uid &&
            event.sessionGeneration == _generation) {
          acknowledged.add(event.messageId);
        }
      }),
    );
  }

  final Database db;
  final String _token, _refresh, _did, _uid;
  final int _generation;
  final Map<String, int> received = {};
  final Map<String, List<MessageStatus?>> statuses = {};
  final Set<String> acknowledged = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  void _observeMessageUpdates(DataWrapperEvent<dynamic> event) {
    final Iterable<Message> messages;
    if (event.data is Message) {
      messages = [event.data as Message];
    } else if ({
          'MessageList',
          'messages',
          'List<Message>',
        }.contains(event.dataType) &&
        event.data is List) {
      messages = (event.data as List).whereType<Message>();
    } else {
      return;
    }
    for (final message in messages) {
      statuses
          .putIfAbsent(message.id, () => <MessageStatus?>[])
          .add(message.status);
    }
  }

  bool _reportedLocalUnsent = false;

  static String _fingerprint(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static Future<NegativeEvidence> capture() async {
    final db = await SqliteService.to.db;
    expect(db != null && db.isOpen, isTrue);
    final token = await SecureTokenStorageService.getToken();
    final refresh = await SecureTokenStorageService.getRefreshToken();
    expect(token.isNotEmpty && refresh.isNotEmpty, isTrue);
    return NegativeEvidence._(
      db!,
      _fingerprint(token),
      _fingerprint(refresh),
      _fingerprint(deviceId),
      UserRepoLocal.to.currentUid,
      UserRepoLocal.to.sessionGeneration,
    );
  }

  Future<void> sameSession() async {
    expect(
      _fingerprint(await SecureTokenStorageService.getToken()) == _token,
      isTrue,
      reason: 'JWT changed during negative journey',
    );
    expect(
      _fingerprint(await SecureTokenStorageService.getRefreshToken()) ==
          _refresh,
      isTrue,
    );
    expect(_fingerprint(deviceId) == _did, isTrue);
    expect(UserRepoLocal.to.currentUid == _uid, isTrue);
    expect(UserRepoLocal.to.sessionGeneration, _generation);
    expect(identical(await SqliteService.to.db, db), isTrue);
    expect(db.isOpen, isTrue);
  }

  Future<void> expectWarmCache(NegativeUi ui) async {
    for (var attempt = 0; attempt < 30; attempt++) {
      if (await GroupRepo().findById(negativeGroupId) != null &&
          await GroupMemberRepo().findByUserId(negativeGroupId, _uid) != null) {
        break;
      }
      await negativePump(ui.tester);
    }
    expect(await ChannelRepo().getChannel(negativeChannelId), isNotNull);
    expect(await ChannelRepo().getSubscription(negativeChannelId), isNotNull);
    expect(await GroupRepo().findById(negativeGroupId), isNotNull);
    expect(
      await GroupMemberRepo().findByUserId(negativeGroupId, _uid),
      isNotNull,
    );
    await sameSession();
  }

  Future<List<Map<String, Object?>>> _messageRows(String id) => db.query(
    MessageRepo.c2gTable,
    columns: [MessageRepo.id, MessageRepo.status],
    where: '${MessageRepo.id} = ? AND ${MessageRepo.to} = ?',
    whereArgs: [id, negativeGroupId],
  );

  Future<void> beforeReceived(NegativeUi ui, NegativePhase phase) async {
    for (var attempt = 0; attempt < 80; attempt++) {
      await negativePump(ui.tester);
      if ((received[phase.beforeId] ?? 0) > 0 &&
          (statuses[phase.beforeId] ?? []).isNotEmpty &&
          (await _messageRows(phase.beforeId)).isNotEmpty &&
          ui.tester.any(ui.message(phase.beforeId))) {
        break;
      }
    }
    expect(received[phase.beforeId] ?? 0, greaterThan(0));
    expect(
      statuses[phase.beforeId] ?? [],
      isNotEmpty,
      reason: 'actual production message-update observer positive required',
    );
    expect(await _messageRows(phase.beforeId), isNotEmpty);
    expect(ui.message(phase.beforeId), findsOneWidget);
    expect(
      await ConversationRepo().findByPeerId('C2G', negativeGroupId),
      isNotNull,
    );
    await absent(ui, phase.afterId);
    await absent(ui, phase.offlineId);
    await sameSession();
  }

  Future<void> absent(NegativeUi ui, String id) async {
    expect(received[id] ?? 0, 0, reason: 'new revoked C2G frame received');
    expect(
      await _messageRows(id),
      isEmpty,
      reason: 'new canary persisted in actual SQLite',
    );
    final conversations = await db.query(
      ConversationRepo.tableName,
      columns: [ConversationRepo.id],
      where:
          '${ConversationRepo.userId} = ? AND ${ConversationRepo.peerId} = ? '
          'AND ${ConversationRepo.type} = ? AND ${ConversationRepo.lastMsgId} = ?',
      whereArgs: [_uid, negativeGroupId, 'C2G', id],
    );
    expect(conversations, isEmpty);
    ui.expectAbsent(id);
  }

  Future<void> observeRevoked(NegativeUi ui, NegativePhase phase) async {
    for (var tick = 0; tick < 20; tick++) {
      await negativePump(ui.tester);
      expect(WebSocketService.to.status, SocketStatus.connected);
      await absent(ui, phase.afterId);
      await absent(ui, phase.offlineId);
    }
    await sameSession();
  }

  Future<List<Map<String, Object?>>> markerRows(String marker) => db.query(
    MessageRepo.c2gTable,
    columns: [MessageRepo.id, MessageRepo.status],
    where:
        "${MessageRepo.from} = ? AND ${MessageRepo.to} = ? AND "
        "json_extract(${MessageRepo.payload}, '\$.text') = ?",
    whereArgs: [_uid, negativeGroupId, marker],
  );

  Future<String?> rejectState(NegativeUi ui, String marker) async {
    final rows = await markerRows(marker);
    expect(rows.length, lessThanOrEqualTo(1));
    if (rows.isEmpty) {
      final input = ui.tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('chat_message_input')),
          matching: find.byType(EditableText),
        ),
      );
      expect(
        input.controller.text,
        marker,
        reason: 'no outbox requires retained unsent input',
      );
      if (!_reportedLocalUnsent) {
        flowLog('MC22 send_gate=local_unsent_input_no_outbox');
        _reportedLocalUnsent = true;
      }
      return null;
    }
    final id = rows.single[MessageRepo.id].toString();
    final status = rows.single[MessageRepo.status];
    expect(
      status == 10 || status == 12 || (status is int && status >= 40),
      isTrue,
      reason: 'refused message must not be marked sent/delivered/seen',
    );
    expect(acknowledged.contains(id), isFalse);
    expect(
      (statuses[id] ?? []).any(
        (s) =>
            s == MessageStatus.sent ||
            s == MessageStatus.delivered ||
            s == MessageStatus.seen,
      ),
      isFalse,
    );
    for (final item in ui.tester.widgetList<ChatMessageItem>(ui.message(id))) {
      // 合同意图是"拒收后不得展示为已发出/已送达/已读"。C2G_ERROR 从未被
      // app 处理（全历史无 handler），重试出队后 UI 模型 status 可为 null，
      // 故按本义断言非 sent/delivered/seen，DB 层权威断言（status
      // 10/12/>=40 + 从未 ack）已在上方守住。
      expect(
        item.message.status,
        isNot(
          anyOf(
            MessageStatus.sent,
            MessageStatus.delivered,
            MessageStatus.seen,
          ),
        ),
      );
    }
    await sameSession();
    return id;
  }

  Future<String> queuedState(NegativeUi ui, String marker) async {
    for (var attempt = 0; attempt < 80; attempt++) {
      if ((await markerRows(marker)).isNotEmpty) break;
      await negativePump(ui.tester);
    }
    final rows = await markerRows(marker);
    expect(rows, hasLength(1), reason: 'actual offline outbox row required');
    expect(rows.single[MessageRepo.status], anyOf(10, 12));
    return (await rejectState(ui, marker))!;
  }

  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
