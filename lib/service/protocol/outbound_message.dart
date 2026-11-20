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
    if (metadata is Map &&
        (metadata.containsKey(localSenderDidKey) ||
            metadata.containsKey('_local_reply_source_id'))) {
      final publicMetadata = Map<String, dynamic>.from(metadata)
        ..remove(localSenderDidKey)
        ..remove('_local_reply_source_id');
      data = {...data!, 'e2ee': publicMetadata};
      message = jsonEncode(data);
    }
    return OutboundMessage._(message, data);
  }

  /// Protected Frame v3 carries ciphertext in its metadata, not in payload.
  static Object? retryPayload(
    Object? storedPayload,
    Map<String, dynamic>? e2ee,
  ) => e2ee?['meta_version'] == 3 ? '' : storedPayload;

  static void attachPersonalQuoteReference(
    Map<String, dynamic> envelope,
    Map<String, dynamic> plaintext,
  ) {
    if (envelope['type']?.toString().toUpperCase() != 'C2C' ||
        envelope['msg_type'] != 'quote' ||
        envelope.containsKey('reply_to')) {
      return;
    }
    final quote = plaintext['quote_msg'];
    final sourceId = quote is Map ? quote['id'] : null;
    if (sourceId is String &&
        sourceId.isNotEmpty &&
        utf8.encode(sourceId).length <= 50) {
      envelope['reply_to'] = {'msg_id': sourceId};
    }
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
