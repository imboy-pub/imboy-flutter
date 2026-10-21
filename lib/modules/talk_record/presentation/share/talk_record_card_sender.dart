library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/config/init.dart' show navigatorKey;
import 'package:imboy/page/chat/send_to/send_to_page.dart';
import 'package:imboy/page/chat/send_to/send_to_provider.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/server_ack_receipts.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../../application/talk_record_recording_runtime.dart';
import 'talk_record_share_service.dart';
import 'talk_record_card_delivery.dart';
import 'talk_record_card_intents.dart';

Map<String, dynamic> talkRecordCardPayload(TalkRecordShareCardData card) {
  if (card.cardType != 'talk_record_card' ||
      !RegExp(r'^[0-9]+$').hasMatch(card.recordId)) {
    throw const FormatException('Invalid controlled record card');
  }
  return {
    'msg_type': 'talk_record_card',
    'record_id': card.recordId,
    'content': card.title,
    'title': card.title,
  };
}

class ImTalkRecordShareCardSender implements TalkRecordShareCardSender {
  ImTalkRecordShareCardSender(this.ref);
  final Ref ref;
  final _intents = TalkRecordCardIntents();
  final _deliveries = <String, TalkRecordCardDelivery>{};
  TalkRecordCardDelivery _delivery(String uid, int generation, String key) =>
      _deliveries.putIfAbsent(
        key,
        () => TalkRecordCardDelivery(
          enqueue: (target, message, queued, current) => ref
              .read(sendToProvider.notifier)
              .sendMsg(target, message, onQueued: queued, isCurrent: current),
          receipts: (id, conversation) =>
              ServerAckReceipts.contains(uid, generation, id, conversation),
          ackEvents: AppEventBus.on<MessageSentEvent>(),
          failureEvents: AppEventBus.on<MessageSendFailedEvent>(),
        ),
      );
  @override
  bool get isAvailable => navigatorKey.currentState?.overlay != null;

  @override
  Future<TalkRecordCardSendResult> send(TalkRecordShareCardData card) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return TalkRecordCardSendResult.unavailable;
    final payload = talkRecordCardPayload(card);
    final owner = currentTalkRecordAccount();
    final generation = UserRepoLocal.to.sessionGeneration;
    final ownerKey = '${owner.storageKey}:$generation';
    final delivery = _delivery(owner.userId, generation, ownerKey);
    bool current() =>
        owner.valid &&
        currentTalkRecordAccount() == owner &&
        UserRepoLocal.to.isCurrentSession(generation);
    if (!current()) return TalkRecordCardSendResult.stale;
    final intent = _intents.begin(ownerKey, card.recordId);
    void finish(TalkRecordCardSendResult outcome) {
      if (_intents.finish(ownerKey, card.recordId, intent, outcome)) {
        delivery.forgetIntent(intent);
      }
    }

    final message = CustomMessage(
      id: 'talk-card-${card.recordId}',
      authorId: owner.userId,
      metadata: payload,
    );
    var result = TalkRecordCardSendResult.cancelled;
    final route = CupertinoPageRoute<bool>(
      builder: (_) => SendToPage(
        msg: message,
        onConfirmedSend: (targets) async {
          result = TalkRecordCardSendResult.pending;
          var aggregate = TalkRecordCardSendResult.sent;
          for (final target in targets) {
            if (!current()) {
              aggregate = TalkRecordCardSendResult.stale;
              break;
            }
            final next = await delivery.send(
              target: target,
              message: message,
              intentKey: intent,
              isCurrent: current,
            );
            if (next != TalkRecordCardSendResult.sent) aggregate = next;
          }
          result = aggregate;
          finish(result);
          return result == TalkRecordCardSendResult.sent;
        },
      ),
    );
    void authChanged() {
      if (!current() && route.isActive) navigator.removeRoute(route);
    }

    UserRepoLocal.to.addAuthListener(authChanged);
    try {
      await navigator.push<bool>(route);
    } finally {
      UserRepoLocal.to.removeAuthListener(authChanged);
    }
    final outcome = current() ? result : TalkRecordCardSendResult.stale;
    finish(outcome);
    return outcome;
  }
}
