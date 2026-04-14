import 'package:imboy/store/model/model_parse_utils.dart';

/// Resolve conversation peer ID for different message types.
///
/// For C2C, always returns the counterparty UID:
/// - incoming from other user: `from`
/// - self echo from current user: `to`
String resolveConversationPeerId({
  required String msgType,
  required Map data,
  required String currentUid,
}) {
  if (msgType == 'C2G') {
    return parseModelString(data['to']);
  }

  final from = parseModelString(data['from']);
  final to = parseModelString(data['to']);

  if (msgType == 'C2C') {
    if (from == currentUid && to.isNotEmpty) {
      return to;
    }
    if (from.isNotEmpty) {
      return from;
    }
    return to;
  }

  if (from.isNotEmpty) {
    return from;
  }
  return to;
}

/// Compute unread increment for one received message.
///
/// Unread increases only when:
/// - message is not sent by current user
/// - user is not currently inside the target conversation
int computeConversationUnreadIncrement({
  required bool isFromCurrentUser,
  required bool isUserInChat,
}) {
  return (!isFromCurrentUser && !isUserInChat) ? 1 : 0;
}

/// C7-β：Compute the @-mention unread increment for one received message.
///
/// Mirrors [computeConversationUnreadIncrement]: a message that does NOT
/// bump the regular unread (self-sent, or user already in chat) must also
/// NOT bump mention_unread. Otherwise, the delta is 1 when the payload
/// mentions the current user either explicitly (by uid) or via the group
/// "all" sentinel; 0 otherwise.
///
/// Empty [currentUid] is treated defensively: no match, even if the
/// incoming [mentionIds] happens to contain an empty string.
int computeMentionUnreadIncrement({
  required bool isFromCurrentUser,
  required bool isUserInChat,
  required List<String>? mentionIds,
  required String currentUid,
}) {
  if (isFromCurrentUser || isUserInChat) return 0;
  if (mentionIds == null || mentionIds.isEmpty) return 0;
  if (mentionIds.contains('all')) return 1;
  if (currentUid.isEmpty) return 0;
  if (mentionIds.contains(currentUid)) return 1;
  return 0;
}
