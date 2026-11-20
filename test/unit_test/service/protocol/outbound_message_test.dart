import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/protocol/outbound_message.dart';

void main() {
  test('v3 retry omits the locally retained plaintext payload', () {
    final local = {'quote_text': 'private response'};
    expect(OutboundMessage.retryPayload(local, {'meta_version': 3}), '');
    expect(OutboundMessage.retryPayload(local, null), same(local));
    expect(
      OutboundMessage.retryPayload('legacy ciphertext', {'meta_version': 2}),
      'legacy ciphertext',
    );
  });

  test('retains only the quote source ID outside an encrypted C2C payload', () {
    final wire = <String, dynamic>{
      'type': 'C2C',
      'msg_type': 'quote',
      'payload': '',
    };
    OutboundMessage.attachPersonalQuoteReference(wire, {
      'quote_msg': {'id': 'source-id', 'text': 'private original'},
      'quote_text': 'private response',
    });
    expect(wire['reply_to'], {'msg_id': 'source-id'});
    expect(wire['payload'], '');
  });

  test('preserves untouched JSON bytes and string message identity', () {
    const wire = ' { "id": "cxyz123", "type": "C2G", "msg_type": "text" }';
    final message = OutboundMessage.parse(wire);
    expect(message.wire, wire);
    expect(message.id, 'cxyz123');
    expect(message.type, 'C2G');
    expect(message.isControlAck, isFalse);
    expect(message.typeDescription, 'C2G/text/PLAIN');
  });

  test('strips only local sender metadata before framing or sending', () {
    final message = OutboundMessage.parse(
      jsonEncode({
        'id': 'signed-message',
        'type': 'C2C',
        'msg_type': 'text',
        'payload': 'ciphertext',
        'e2ee': {
          OutboundMessage.localSenderDidKey: 'private-device-binding',
          'ciphertext': 'ciphertext',
          'sig': 'signature',
        },
      }),
    );
    final sent = jsonDecode(message.wire) as Map<String, dynamic>;
    expect(sent['e2ee'], {'ciphertext': 'ciphertext', 'sig': 'signature'});
    expect(sent['payload'], 'ciphertext');
    expect(message.data, sent);
    expect(message.id, 'signed-message');
    expect(message.typeDescription, 'C2C/text/E2EE');
  });

  test('recognizes plain and JSON control ACKs without outbox claims', () {
    for (final wire in [
      'CLIENT_ACK,C2C,message-1,device-1',
      '{"id":"revoke-1","action":"message_revoke_ack"}',
      '{"id":"edit-1","action":"message_edit_ack"}',
    ]) {
      final message = OutboundMessage.parse(wire);
      expect(message.isControlAck, isTrue);
      expect(message.wire, wire);
    }
  });

  test('keeps malformed and non-object frames on their existing path', () {
    for (final wire in ['ping', '{broken', '[]', 'null', '42', '"hello"']) {
      final message = OutboundMessage.parse(wire);
      expect(message.wire, wire);
      expect(message.id, isNull);
      expect(message.data, isNull);
      expect(message.typeDescription, 'UNKNOWN');
      expect(message.isControlAck, isFalse);
    }
  });

  test('empty encryption placeholders remain plaintext diagnostics', () {
    for (final e2ee in [null, '', <String, dynamic>{}]) {
      final message = OutboundMessage.parse(
        jsonEncode({'type': 'C2C', 'msg_type': 'read', 'e2ee': e2ee}),
      );
      expect(message.typeDescription, 'C2C/read/PLAIN');
    }
  });
}
