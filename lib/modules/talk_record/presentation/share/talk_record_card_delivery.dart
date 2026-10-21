/// Explicit IM confirmation; local queue insertion is never an ACK receipt.
library;

import 'dart:async';

import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/model/message_model.dart';

import 'talk_record_share_service.dart';

typedef TalkCardEnqueue = Future<bool> Function(
  ConversationModel,
  Message,
  void Function(MessageModel),
  bool Function(),
);

class TalkRecordCardDelivery {
  TalkRecordCardDelivery({
    required this.enqueue,
    required this.receipts,
    required this.ackEvents,
    required this.failureEvents,
    this.timeout = const Duration(seconds: 20),
  });
  final TalkCardEnqueue enqueue;
  final bool Function(String, String) receipts;
  final Stream<MessageSentEvent> ackEvents;
  final Stream<MessageSendFailedEvent> failureEvents;
  final Duration timeout;
  final _queued = <String, String>{};
  void forgetIntent(String intent) =>
      _queued.removeWhere((key, _) => key.startsWith('$intent:'));

  Future<TalkRecordCardSendResult> send({
    required ConversationModel target,
    required Message message,
    required String intentKey,
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return TalkRecordCardSendResult.stale;
    final key = '$intentKey:${target.uk3}';
    var id = _queued[key];
    final done = Completer<TalkRecordCardSendResult>();
    void complete(TalkRecordCardSendResult value) {
      if (!done.isCompleted) done.complete(value);
    }

    final ack = ackEvents.listen((event) {
      if (!isCurrent()) {
        complete(TalkRecordCardSendResult.stale);
        return;
      }
      if (event.messageId == id &&
          event.conversationUk3 == target.uk3 &&
          receipts(event.messageId, target.uk3)) {
        complete(TalkRecordCardSendResult.sent);
      }
    });
    final failure = failureEvents.listen((event) {
      if (event.messageId == id && event.conversationUk3 == target.uk3) {
        complete(
          event.willRetry
              ? TalkRecordCardSendResult.pending
              : TalkRecordCardSendResult.failed,
        );
      }
    });
    try {
      if (id == null) {
        final queued = await enqueue(target, message, (model) {
          id = model.id;
          _queued[key] = model.id;
        }, isCurrent);
        if (!queued || id == null) return TalkRecordCardSendResult.failed;
      }
      if (!isCurrent()) return TalkRecordCardSendResult.stale;
      if (receipts(id!, target.uk3)) return TalkRecordCardSendResult.sent;
      final result = await done.future.timeout(
        timeout,
        onTimeout: () => TalkRecordCardSendResult.pending,
      );
      return isCurrent() ? result : TalkRecordCardSendResult.stale;
    } finally {
      await ack.cancel();
      await failure.cancel();
    }
  }
}
