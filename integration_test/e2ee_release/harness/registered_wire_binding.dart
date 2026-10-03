import 'dart:convert';

import 'package:imboy/service/e2ee/protected_frame_v3.dart';

import 'backend_transport.dart';
import 'registered_fixture.dart';

/// Validates the complete registered C2C device envelope set against registered IDs before WS send.
/// Hash/context checks do not authenticate ciphertext or prove key ownership.
class RegisteredWireBinding {
  const RegisteredWireBinding(this.fixture);
  final RegisteredFixture fixture;

  /// Validate server-downlink string IDs without changing received evidence.
  /// Outgoing messages keep their existing integer-ID contract.
  void validateReceivedC2c(WireFrame frame) {
    final body = Map<String, dynamic>.from(frame.body);
    for (final key in ['from', 'to']) {
      final value = body[key];
      if (value is String) {
        if (!RegExp(r'^[1-9][0-9]*$').hasMatch(value)) {
          throw const FormatException('invalid received account ID');
        }
        final parsed = int.tryParse(value);
        if (parsed == null || parsed.toString() != value) {
          throw const FormatException('invalid received account ID');
        }
        body[key] = parsed;
      } else if (value is! int || value <= 0) {
        throw const FormatException('invalid received account ID');
      }
    }
    prepareC2c(
      WireFrame(
        messageId: frame.messageId,
        senderUid: frame.senderUid,
        senderDid: frame.senderDid,
        recipientUid: frame.recipientUid,
        recipientDid: frame.recipientDid,
        body: body,
      ),
    );
  }

  Map<String, dynamic> prepareC2c(WireFrame frame) {
    final sender = _device(frame.senderDid, frame.senderUid);
    final recipient = _logicalRecipient(frame, sender);
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
    final header = _verifyDevices(e2ee, frame, sender, recipient);
    final action = header['action'] == 'message' ? '' : header['action'];
    _checkExisting(body, 'from', int.parse(sender.accountId));
    _checkExisting(body, 'to', int.parse(recipient.accountId));
    _checkExisting(body, 'msg_type', header['message_type']);
    _checkExisting(body, 'action', action);
    _checkExisting(body, 'created_at', header['created_at_ms']);
    body['from'] = int.parse(sender.accountId);
    body['to'] = int.parse(recipient.accountId);
    body['msg_type'] = header['message_type'];
    body['action'] = action;
    body['created_at'] = header['created_at_ms'];
    return body;
  }

  Map<String, dynamic> _verifyDevices(
    Map<String, dynamic> e2ee,
    WireFrame frame,
    RegisteredDevice sender,
    RegisteredDevice recipient,
  ) {
    final expected = _expectedDids(sender, recipient);
    final devices = e2ee['devices'];
    final skipped = e2ee['skipped_devices'];
    if (devices is! Map<String, dynamic> ||
        devices.length != expected.length ||
        devices.keys.any((did) => !expected.contains(did)) ||
        (skipped != null && (skipped is! Map || skipped.isNotEmpty))) {
      throw const FormatException('incomplete registered fanout');
    }
    Map<String, dynamic>? common;
    for (final envelope in devices.values) {
      if (envelope is! Map<String, dynamic>) {
        throw const FormatException('invalid device envelope');
      }
      final header = _verifyContext(
        {'meta_version': 3, ...envelope},
        frame,
        sender,
        recipient,
      );
      if (common != null &&
          [
            'message_type',
            'action',
            'created_at_ms',
          ].any((key) => header[key] != common![key])) {
        throw const FormatException('inconsistent fanout context');
      }
      common = header;
    }
    if (common == null) throw const FormatException('empty fanout');
    return common;
  }

  Set<String> _expectedDids(
    RegisteredDevice sender,
    RegisteredDevice recipient,
  ) {
    return fixture.devices.values
        .where(
          (device) =>
              device.accountAlias == recipient.accountAlias ||
              (device.accountAlias == sender.accountAlias &&
                  device.did != sender.did),
        )
        .map((device) => device.did)
        .toSet();
  }

  RegisteredDevice _logicalRecipient(WireFrame frame, RegisteredDevice sender) {
    final peers = fixture.devices.values.where(
      (device) => device.accountAlias == frame.recipientUid,
    );
    final receiver = fixture.devices[frame.recipientDid];
    if (peers.isEmpty ||
        receiver == null ||
        receiver.did == sender.did ||
        (receiver.accountAlias != frame.recipientUid &&
            receiver.accountAlias != sender.accountAlias)) {
      throw const FormatException('wire recipient ownership mismatch');
    }
    return peers.first;
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
    final participants = [sender.accountId, recipient.accountId]..sort();
    final metadata = envelope['protocol_metadata'];
    if (!verification.isValid ||
        header == null ||
        header['message_id'] != frame.messageId ||
        header['scope'] != 'c2c' ||
        header['sender_uid'] != sender.accountId ||
        header['sender_did'] != sender.did ||
        header['conversation_id'] != participants.join(':') ||
        header['destination'] != recipient.accountId ||
        header['message_type'] is! String ||
        (header['message_type'] as String).isEmpty ||
        header['action'] is! String ||
        header['created_at_ms'] is! int ||
        metadata is! Map<String, dynamic> ||
        header['session_ref'] is! String ||
        (header['session_ref'] as String).isEmpty ||
        metadata['session_id'] != header['session_ref'] ||
        envelope['ciphertext'] is! String ||
        (envelope['ciphertext'] as String).isEmpty) {
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
