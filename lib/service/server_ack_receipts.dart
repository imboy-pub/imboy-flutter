/// Receipts are recorded only by the validated server-ACK persistence path.
library;

import 'package:imboy/service/events/events.dart';
import 'package:imboy/store/model/message_model.dart';

class ServerAckReceipts {
  static final _receipts = <String>{};
  static String _key(
    String uid,
    int generation,
    String id,
    String conversation,
  ) => '$uid:$generation:$id:$conversation';
  static bool contains(
    String uid,
    int generation,
    String id,
    String conversation,
  ) => _receipts.contains(_key(uid, generation, id, conversation));

  static bool record({
    required MessageModel? message,
    required String ackId,
    required String ackType,
    required String ownerUid,
    required int generation,
    required bool Function() isCurrent,
    required void Function(MessageSentEvent) emit,
  }) {
    if (!isCurrent() ||
        message == null ||
        message.status != IMBoyMessageStatus.sent ||
        message.type == null ||
        message.id != ackId ||
        message.fromId.toString() != ownerUid ||
        ackType != '${message.type}_SERVER_ACK' ||
        message.conversationUk3.isEmpty) {
      return false;
    }
    final key = _key(ownerUid, generation, ackId, message.conversationUk3);
    if (_receipts.length >= 1024) _receipts.remove(_receipts.first);
    _receipts.add(key);
    emit(
      MessageSentEvent(
        messageId: ackId,
        messageType: message.type!,
        conversationUk3: message.conversationUk3,
        serverTimestamp: 0,
        sendDuration: 0,
      ),
    );
    return true;
  }
}
