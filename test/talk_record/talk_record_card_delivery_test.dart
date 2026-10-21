import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_card_delivery.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_service.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/server_ack_receipts.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';

class _Conversation extends ConversationModel {
  _Conversation()
    : super(
        id: 1,
        peerId: 2,
        avatar: '',
        title: '',
        subtitle: '',
        type: 'C2C',
        msgType: 'talk_record_card',
        lastTime: 0,
        lastMsgId: '',
        unreadNum: 0,
      );
  @override
  String get uk3 => 'C2C_1_2';
}

MessageModel _message(String id) => MessageModel(
  id,
  autoId: 0,
  type: 'C2C',
  status: 11,
  fromId: 1,
  toId: 2,
  payload: <String, dynamic>{},
  isAuthor: 1,
  conversationUk3: 'C2C_1_2',
);
void main() {
  test('validated persisted server ACK only; reject wrong id, owner, type, stale session', () {
    final events = <MessageSentEvent>[];
    bool record({
      String id = 'm',
      String uid = '1',
      String type = 'C2C_SERVER_ACK',
      bool current = true,
    }) => ServerAckReceipts.record(
      message: _message('m'),
      ackId: id,
      ackType: type,
      ownerUid: uid,
      generation: 1,
      isCurrent: () => current,
      emit: events.add,
    );
    expect(record(id: 'other'), false);
    expect(record(uid: '2'), false);
    expect(record(type: 'C2G_SERVER_ACK'), false);
    expect(record(current: false), false);
    expect(events, isEmpty);
    expect(record(), true);
    expect(events.single.messageId, 'm');
    expect(ServerAckReceipts.contains('1', 1, 'm', 'C2C_1_2'), true);
    expect(ServerAckReceipts.contains('1', 2, 'm', 'C2C_1_2'), false);
  });
  test(
    'queue insert is pending, late ACK receipt retry does not insert again',
    () async {
      final ack = StreamController<MessageSentEvent>.broadcast();
      final failures = StreamController<MessageSendFailedEvent>.broadcast();
      var count = 0;
      var receipt = false;
      final delivery = TalkRecordCardDelivery(
        timeout: Duration.zero,
        ackEvents: ack.stream,
        failureEvents: failures.stream,
        receipts: (_, _) => receipt,
        enqueue: (target, msg, queued, current) async {
          count++;
          queued(_message('unique'));
          return true;
        },
      );
      Future<TalkRecordCardSendResult> send() => delivery.send(
        target: _Conversation(),
        message: const CustomMessage(id: 'card', authorId: '1'),
        intentKey: 'owner:generation:record',
        isCurrent: () => true,
      );
      expect(await send(), TalkRecordCardSendResult.pending);
      expect(count, 1);
      receipt = true;
      expect(await send(), TalkRecordCardSendResult.sent);
      expect(count, 1);
      expect(ack.hasListener, false);
      expect(failures.hasListener, false);
      await ack.close();
      await failures.close();
    },
  );
  test(
    'matching ACK must include real receipt; wrong conversation is ignored',
    () async {
      final ack = StreamController<MessageSentEvent>.broadcast(sync: true);
      final failures = StreamController<MessageSendFailedEvent>.broadcast();
      var receipt = false;
      final delivery = TalkRecordCardDelivery(
        ackEvents: ack.stream,
        failureEvents: failures.stream,
        timeout: const Duration(milliseconds: 50),
        receipts: (_, _) => receipt,
        enqueue: (_, msg, queued, current) async {
          queued(_message('x'));
          ack.add(
            const MessageSentEvent(
              messageId: 'x',
              messageType: 'C2C',
              conversationUk3: 'other',
              serverTimestamp: 1,
              sendDuration: 0,
            ),
          );
          receipt = true;
          ack.add(
            const MessageSentEvent(
              messageId: 'x',
              messageType: 'C2C',
              conversationUk3: 'C2C_1_2',
              serverTimestamp: 1,
              sendDuration: 0,
            ),
          );
          return true;
        },
      );
      expect(
        await delivery.send(
          target: _Conversation(),
          message: const CustomMessage(id: 'card', authorId: '1'),
          intentKey: 'record',
          isCurrent: () => true,
        ),
        TalkRecordCardSendResult.sent,
      );
      expect(ack.hasListener, false);
      await ack.close();
      await failures.close();
    },
  );
  test('account transition rejects queue and never emits sent', () async {
    final ack = StreamController<MessageSentEvent>.broadcast();
    final failures = StreamController<MessageSendFailedEvent>.broadcast();
    var current = true;
    final delivery = TalkRecordCardDelivery(
      timeout: Duration.zero,
      ackEvents: ack.stream,
      failureEvents: failures.stream,
      receipts: (_, _) => true,
      enqueue: (_, msg, queued, guard) async {
        queued(_message('stale'));
        current = false;
        return true;
      },
    );
    expect(
      await delivery.send(
        target: _Conversation(),
        message: const CustomMessage(id: 'card', authorId: '1'),
        intentKey: 'owner:record',
        isCurrent: () => current,
      ),
      TalkRecordCardSendResult.stale,
    );
    expect(ack.hasListener, false);
    expect(failures.hasListener, false);
    await ack.close();
    await failures.close();
  });
}
