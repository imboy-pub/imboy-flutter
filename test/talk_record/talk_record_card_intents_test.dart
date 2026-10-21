import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_card_intents.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_card_delivery.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_share_service.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';

class _Target extends ConversationModel {
  _Target()
    : super(
        id: 1,
        peerId: 2,
        avatar: '',
        title: '',
        subtitle: '',
        type: 'C2C',
        msgType: 'talk_record_card',
        unreadNum: 0,
      );
  @override
  String get uk3 => 'C2C_1_2';
}

void main() {
  test('two explicit shares each enqueue a distinct message and require their own ACK', () async {
    var nextIntent = 0;
    var queuedCount = 0;
    final intents = TalkRecordCardIntents(
      nextId: () => 'intent-${++nextIntent}',
    );
    final receipts = <String>{};
    final ack = StreamController<MessageSentEvent>.broadcast();
    final failures = StreamController<MessageSendFailedEvent>.broadcast();
    final delivery = TalkRecordCardDelivery(
      timeout: Duration.zero,
      ackEvents: ack.stream,
      failureEvents: failures.stream,
      receipts: (id, _) => receipts.contains(id),
      enqueue: (target, message, queued, current) async {
        queuedCount++;
        queued(
          MessageModel(
            'message-$queuedCount',
            autoId: 0,
            type: 'C2C',
            status: 10,
            fromId: 1,
            toId: 2,
            payload: <String, dynamic>{},
            isAuthor: 1,
            conversationUk3: target.uk3,
          ),
        );
        return true;
      },
    );
    Future<TalkRecordCardSendResult> send(String intent) => delivery.send(
      target: _Target(),
      message: const CustomMessage(id: 'card', authorId: '1'),
      intentKey: intent,
      isCurrent: () => true,
    );
    final first = intents.begin('owner-A:g1', '1001');
    expect(await send(first), TalkRecordCardSendResult.pending);
    expect(intents.begin('owner-A:g1', '1001'), first);
    expect(await send(first), TalkRecordCardSendResult.pending);
    expect(queuedCount, 1);
    receipts.add('message-1');
    expect(await send(first), TalkRecordCardSendResult.sent);
    expect(
      intents.finish(
        'owner-A:g1',
        '1001',
        first,
        TalkRecordCardSendResult.sent,
      ),
      true,
    );
    delivery.forgetIntent(first);
    final second = intents.begin('owner-A:g1', '1001');
    expect(second, isNot(first));
    expect(await send(second), TalkRecordCardSendResult.pending);
    expect(
      queuedCount,
      2,
    ); // Historical message-1 ACK cannot certify message-2.
    receipts.add('message-2');
    expect(await send(second), TalkRecordCardSendResult.sent);
    expect(queuedCount, 2);
    expect(ack.hasListener, false);
    expect(failures.hasListener, false);
    await ack.close();
    await failures.close();
  });
  test('failed and pending retain intent; cancel and success retire it; owners are isolated', () {
    var counter = 0;
    final intents = TalkRecordCardIntents(nextId: () => 'i${++counter}');
    final a = intents.begin('owner-A:g1', 'r');
    final b = intents.begin('owner-B:g1', 'r');
    final relogin = intents.begin('owner-A:g2', 'r');
    expect({a, b, relogin}.length, 3);
    for (final outcome in [
      TalkRecordCardSendResult.pending,
      TalkRecordCardSendResult.failed,
    ]) {
      expect(intents.finish('owner-A:g1', 'r', a, outcome), false);
      expect(intents.begin('owner-A:g1', 'r'), a);
    }
    expect(
      intents.finish('owner-A:g1', 'r', a, TalkRecordCardSendResult.cancelled),
      true,
    );
    final fresh = intents.begin('owner-A:g1', 'r');
    expect(fresh, isNot(a));
    expect(intents.begin('owner-B:g1', 'r'), b);
    expect(
      intents.finish('owner-A:g1', 'r', a, TalkRecordCardSendResult.sent),
      false,
    );
    expect(
      intents.begin('owner-A:g1', 'r'),
      fresh,
    ); // A late old completion cannot retire a new intent.
  });
}
