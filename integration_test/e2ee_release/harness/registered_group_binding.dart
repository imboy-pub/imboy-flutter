import 'dart:convert';

import 'package:imboy/service/e2ee/protected_frame_v3.dart';

import 'registered_fixture.dart';

/// Offline C2G envelope binding to initial fixture identities only.
/// Does not prove current server membership, epoch authorization or delivery.
class RegisteredGroupBinding {
  const RegisteredGroupBinding(this.fixture);
  final RegisteredFixture fixture;

  Map<String, dynamic> prepare({
    required String messageId,
    required String senderAlias,
    required String groupAlias,
    required Map<String, dynamic> body,
  }) {
    final sender = fixture.devices[senderAlias];
    final gid = fixture.groupIds[groupAlias];
    if (sender == null ||
        gid == null ||
        !(fixture.groupMembers[groupAlias]?.contains(sender.accountAlias) ??
            false)) {
      throw const FormatException('unbound initial group participant');
    }
    final copy = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
    if (messageId.isEmpty ||
        utf8.encode(messageId).length > 40 ||
        copy['id'] != messageId ||
        copy['type'] != 'C2G' ||
        copy['payload'] != '') {
      throw const FormatException('invalid group wire identity');
    }
    final header = _header(copy['e2ee'], messageId, sender, gid);
    final expected = <String, Object?>{
      'from': int.parse(sender.accountId),
      'to': int.parse(gid),
      'msg_type': header['message_type'],
      'action': header['action'] == 'message' ? '' : header['action'],
      'created_at': header['created_at_ms'],
    };
    for (final entry in expected.entries) {
      if (copy.containsKey(entry.key) &&
          (copy[entry.key] != entry.value ||
              (entry.value is int && copy[entry.key] is! int))) {
        throw const FormatException('outer group context mismatch');
      }
      copy[entry.key] = entry.value;
    }
    return copy;
  }

  Map<String, dynamic> _header(
    dynamic envelope,
    String messageId,
    RegisteredDevice sender,
    String gid,
  ) {
    if (envelope is! Map<String, dynamic> ||
        envelope['meta_version'] != 3 ||
        envelope.containsKey('fan_out') ||
        envelope.containsKey('devices') ||
        envelope['ciphertext'] is! String ||
        (envelope['ciphertext'] as String).isEmpty) {
      throw const FormatException('invalid group envelope');
    }
    ProtectedFrameV3.validateEnvelopeBounds(envelope);
    final verification = ProtectedFrameV3.verifyOuterEnvelope(envelope);
    final header = verification.decodedHeader;
    final metadata = envelope['protocol_metadata'];
    if (!verification.isValid ||
        header == null ||
        header['message_id'] != messageId ||
        header['scope'] != 'group' ||
        header['sender_uid'] != sender.accountId ||
        header['sender_did'] != sender.did ||
        header['conversation_id'] != gid ||
        header['destination'] != gid ||
        header['protocol'] != 'megolm' ||
        header['protocol_version'] != 1 ||
        header['message_type'] is! String ||
        (header['message_type'] as String).isEmpty ||
        header['action'] is! String ||
        header['created_at_ms'] is! int ||
        header['epoch_or_counter'] is! int ||
        (header['epoch_or_counter'] as int) < 0 ||
        header['session_ref'] is! String ||
        (header['session_ref'] as String).isEmpty ||
        metadata is! Map<String, dynamic> ||
        metadata['session_id'] != header['session_ref']) {
      throw const FormatException(
        'registered group protected context mismatch',
      );
    }
    return header;
  }
}
