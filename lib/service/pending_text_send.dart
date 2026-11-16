import 'dart:convert';

import 'package:flutter_chat_core/flutter_chat_core.dart'
    show Message, TextMessage;
import 'package:imboy/modules/messaging/infrastructure/message_repository.dart';
import 'package:imboy/service/account_draft_store.dart';
import 'package:imboy/store/model/message_model.dart';

typedef ComposerSubmission = ({String text, Future<bool> draftSaved});

/// Only a completed pending send carries a token for post-draft-save cleanup.
class ComposerSendReceipt {
  const ComposerSendReceipt(this.accepted, {this.completedPendingJson});

  final bool accepted;
  final String? completedPendingJson;
}

TextMessage? readPendingTextSend(
  String value, {
  required String uid,
  required String peerId,
}) {
  if (value.isEmpty) return null;
  final message = Message.fromJson(jsonDecode(value) as Map<String, dynamic>);
  if (message is! TextMessage ||
      message.id.isEmpty ||
      message.authorId != uid ||
      message.metadata?['peer_id'] != peerId) {
    throw const FormatException('Invalid pending text context');
  }
  return message;
}

bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _sameJson(a[key], b[key]));
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameJson(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

bool _accepted(MessageModel? message) =>
    message != null &&
    const {
      IMBoyMessageStatus.sent,
      IMBoyMessageStatus.delivered,
      IMBoyMessageStatus.seen,
    }.contains(message.status);

void _checkContext(
  MessageModel? row,
  TextMessage message,
  String type,
  String peerId,
) {
  if (row != null &&
      (row.fromId != message.authorId ||
          row.toId != peerId ||
          row.type != type)) {
    throw StateError('Pending message context mismatch');
  }
}

Future<bool> dispatchPendingTextSend({
  required TextMessage message,
  required String type,
  required String peerId,
  required MessageRepository repository,
  required Future<bool> Function(TextMessage) sendNew,
  required Future<bool> Function(String, String) retry,
  required bool Function() isCurrent,
}) async {
  if (!isCurrent()) return false;
  final existing = await repository.find(message.id);
  if (!isCurrent()) return false;
  _checkContext(existing, message, type, peerId);
  if (_accepted(existing)) return true;
  final sent = existing == null
      ? await sendNew(message)
      : await retry(message.id, type);
  if (!isCurrent()) return false;
  if (sent) return true;
  final reconciled = await repository.find(message.id);
  if (!isCurrent()) return false;
  _checkContext(reconciled, message, type, peerId);
  return _accepted(reconciled);
}

/// Only explicit composer submissions can consume a compatible pending draft.
Future<ComposerSendReceipt> submitComposerText({
  required AccountDraftStore drafts,
  required TextMessage proposed,
  required String type,
  required String peerId,
  required bool allowPendingHandoff,
  required MessageRepository repository,
  required Future<bool> Function(TextMessage) sendNew,
  required Future<bool> Function(String, String) retry,
  required bool Function() isCurrent,
}) async {
  bool current() =>
      drafts.isCurrent && drafts.owner.uid == proposed.authorId && isCurrent();
  if (!current()) return const ComposerSendReceipt(false);
  if (allowPendingHandoff) {
    var token = drafts.readPendingSend();
    final pending = readPendingTextSend(
      token,
      uid: proposed.authorId,
      peerId: peerId,
    );
    TextMessage? selected;
    if (pending != null &&
        pending.text == proposed.text &&
        _sameJson(pending.metadata, proposed.metadata)) {
      selected = pending;
    } else if (proposed.metadata?.length == 1 &&
        proposed.metadata?['peer_id'] == peerId) {
      // Plain native drafts share Web recovery; rich native send modes keep their own semantics.
      selected = proposed;
      token = jsonEncode(proposed.toJson());
      await drafts.savePendingSend(token);
      if (!current()) return const ComposerSendReceipt(false);
    }
    if (selected != null) {
      final accepted = await dispatchPendingTextSend(
        message: selected,
        type: type,
        peerId: peerId,
        repository: repository,
        sendNew: sendNew,
        retry: retry,
        isCurrent: current,
      );
      return ComposerSendReceipt(
        accepted,
        completedPendingJson: accepted ? token : null,
      );
    }
  }
  if (!current()) return const ComposerSendReceipt(false);
  final accepted = await sendNew(proposed);
  return ComposerSendReceipt(current() && accepted);
}
