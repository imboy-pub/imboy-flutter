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
