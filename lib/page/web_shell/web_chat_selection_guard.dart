import 'web_shell_state.dart';

/// Chat peers share PostgreSQL bigint and protobuf sint64 identity boundaries.
/// Keep this business guard separate from the generic shell route codec.
bool isValidWebChatSelection(ChatSelection selection) {
  if (selection.chatType != 'C2C' && selection.chatType != 'C2G') return false;
  final id = selection.peerId;
  // Bound work before parsing and reject non-canonical aliases of the same peer.
  if (id.isEmpty || id.length > 19 || id.codeUnitAt(0) == 0x30) return false;
  for (final code in id.codeUnits) {
    if (code < 0x30 || code > 0x39) return false;
  }
  final number = BigInt.tryParse(id);
  return number != null && number <= BigInt.parse('9223372036854775807');
}
