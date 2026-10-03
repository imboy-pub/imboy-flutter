import 'dart:convert';

import 'package:imboy/service/e2ee/protected_frame_v3.dart';

import 'backend_transport.dart';
import 'registered_fixture.dart';

/// Validates one C2C device envelope against registered IDs before WS send.
/// Hash/context checks do not authenticate ciphertext or prove key ownership.
class RegisteredWireBinding {
  const RegisteredWireBinding(this.fixture);
  final RegisteredFixture fixture;

  Map<String, dynamic> prepareC2c(WireFrame frame) {
    final sender = _device(frame.senderDid, frame.senderUid);
    final recipient = _device(frame.recipientDid, frame.recipientUid);
    // Snapshot before validation; caller mutation cannot alter checked bytes.
    final body = jsonDecode(jsonEncode(frame.body)) as Map<String, dynamic>;
    if (body['id'] != frame.messageId ||
        body['type'] != 'C2C' ||
        body['payload'] != '') {
      throw const FormatException('wire message identity mismatch');
    }
    final e2ee = body['e2ee'];
    if (e2ee is! Map<String, dynamic> ||
        e2ee['meta_version'] != 3 ||
        e2ee['fan_out'] != 'per_device') {
      throw const FormatException('unsupported registered envelope');
    }
    final devices = e2ee['devices'];
    if (devices is! Map<String, dynamic> || devices.length != 1) {
      throw const FormatException('expected one recipient envelope');
    }
    final envelope = devices[recipient.did];
    if (envelope is! Map<String, dynamic>) {
      throw const FormatException('recipient DID not registered');
    }
    final header = _verifyContext(envelope, frame, sender, recipient);
    _checkExisting(body, 'from', int.parse(sender.accountId));
    _checkExisting(body, 'to', int.parse(recipient.accountId));
    _checkExisting(body, 'msg_type', header['message_type']);
    _checkExisting(body, 'action', header['action']);
    _checkExisting(body, 'created_at', header['created_at_ms']);
    body['from'] = int.parse(sender.accountId);
    body['to'] = int.parse(recipient.accountId);
    body['msg_type'] = header['message_type'];
    body['action'] = header['action'];
    body['created_at'] = header['created_at_ms'];
    return body;
  }

  RegisteredDevice _device(String alias, String owner) {
    final device = fixture.devices[alias];
    if (device == null || device.accountAlias != owner) {
      throw const FormatException('wire fixture ownership mismatch');
    }
    return device;
  }

  Map<String, dynamic> _verifyContext(
    Map<String, dynamic> envelope,
    WireFrame frame,
    RegisteredDevice sender,
    RegisteredDevice recipient,
  ) {
    ProtectedFrameV3.validateEnvelopeBounds(envelope);
    final verification = ProtectedFrameV3.verifyOuterEnvelope(envelope);
    final header = verification.decodedHeader;
    if (!verification.isValid ||
        header == null ||
        header['message_id'] != frame.messageId ||
        header['scope'] != 'c2c' ||
        header['sender_uid'] != sender.accountId ||
        header['sender_did'] != sender.did ||
        header['conversation_id'] != recipient.accountId ||
        header['destination'] != recipient.did ||
        header['message_type'] is! String ||
        (header['message_type'] as String).isEmpty ||
        header['action'] is! String ||
        header['created_at_ms'] is! int) {
      throw const FormatException('registered protected context mismatch');
    }
    return header;
  }

  void _checkExisting(Map<String, dynamic> body, String key, Object? expected) {
    if (body.containsKey(key) && body[key] != expected) {
      throw const FormatException('outer protected context mismatch');
    }
  }
}
