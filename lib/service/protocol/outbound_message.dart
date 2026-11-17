import 'dart:convert';

/// One decoded view shared by outbox checks, framing and safe diagnostics.
/// Keep the original wire bytes unless local-only metadata must be removed.
class OutboundMessage {
  static const localSenderDidKey = '_local_sender_did';

  final String wire;
  final Map<String, dynamic>? data;

  const OutboundMessage._(this.wire, this.data);

  factory OutboundMessage.parse(String message) {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      // Plain-text ACKs and malformed frames retain their existing handling.
    }
    final metadata = data?['e2ee'];
    if (metadata is Map && metadata.containsKey(localSenderDidKey)) {
      final publicMetadata = Map<String, dynamic>.from(metadata)
        ..remove(localSenderDidKey);
      data = {...data!, 'e2ee': publicMetadata};
      message = jsonEncode(data);
    }
    return OutboundMessage._(message, data);
  }

  String? get id => data?['id']?.toString();

  bool get isControlAck =>
      wire.startsWith('CLIENT_ACK,') ||
      data?['action'] == 'message_revoke_ack' ||
      data?['action'] == 'message_edit_ack';

  String get type => (data?['type']?.toString() ?? '').toUpperCase();

  String get typeDescription {
    final fields = data;
    if (fields == null) return 'UNKNOWN';
    final e2ee = fields['e2ee'];
    final hasE2ee =
        e2ee != null && e2ee != '' && !(e2ee is Map && e2ee.isEmpty);
    return '${fields['type'] ?? 'UNKNOWN'}/'
        '${fields['msg_type'] ?? 'unknown'}/${hasE2ee ? 'E2EE' : 'PLAIN'}';
  }
}
