import 'dart:convert';

import 'package:imboy/service/e2ee/protected_frame_v3.dart';

import 'registered_fixture.dart';

/// Offline C2G envelope binding to initial fixture identities only.
/// Does not prove current server membership, epoch authorization or delivery.
class RegisteredGroupBinding {
  const RegisteredGroupBinding(this.fixture);
  final RegisteredFixture fixture;

  RegisteredGroupFrame receive(
    String receiverAlias,
    Map<String, dynamic> body,
  ) {
    final copy = jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
    final receiver = fixture.devices[receiverAlias];
    final groups = fixture.groupIds.entries.where(
      (entry) => _matchesId(copy['to'], entry.value),
    );
    final senders = fixture.devices.values.where(
      (device) =>
          device.did == copy['sender_did'] &&
          _matchesId(copy['from'], device.accountId),
    );
    if (receiver == null ||
        groups.length != 1 ||
        senders.length != 1 ||
        copy['id'] is! String) {
      throw const FormatException('unbound received group identity');
    }
    final group = groups.single.key, sender = senders.single;
    if (!(fixture.groupMembers[group]?.contains(receiver.accountAlias) ??
        false)) {
      throw const FormatException('receiver outside initial group membership');
    }
    final normalized = Map<String, dynamic>.from(copy);
    normalized['from'] = int.parse(sender.accountId);
    normalized['to'] = int.parse(groups.single.value);
    if (normalized['created_at'] is String) {
      normalized['created_at'] = _receivedTimestamp(
        normalized['created_at'] as String,
      );
    }
    prepare(
      messageId: copy['id'] as String,
      senderAlias: sender.alias,
      groupAlias: group,
      body: normalized,
    );
    return RegisteredGroupFrame._(
      copy['id'] as String,
      sender.alias,
      receiverAlias,
      group,
      _immutableGroupValue(copy) as Map<String, dynamic>,
    );
  }

  bool _matchesId(dynamic value, String expected) =>
      (value is String && value == expected) ||
      (value is int && value.toString() == expected);

  int _receivedTimestamp(String value) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?(Z|[+-]\d{2}:\d{2})$',
    ).firstMatch(value);
    if (match == null) throw const FormatException('invalid group timestamp');
    final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    final ms = int.parse((match.group(7) ?? '0').padRight(3, '0'));
    final date = DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
      ms,
    );
    final actual = [
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
    ];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] != actual[i]) {
        throw const FormatException('invalid group timestamp');
      }
    }
    final zone = match.group(8)!;
    if (zone == 'Z') return date.millisecondsSinceEpoch;
    final hours = int.parse(zone.substring(1, 3)),
        minutes = int.parse(zone.substring(4));
    if (hours > 23 || minutes > 59) {
      throw const FormatException('invalid group timestamp');
    }
    final offset = (hours * 60 + minutes) * (zone.startsWith('-') ? -1 : 1);
    return date.subtract(Duration(minutes: offset)).millisecondsSinceEpoch;
  }

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

/// Received encrypted group frame, not a decrypt/display or authorization proof.
class RegisteredGroupFrame {
  const RegisteredGroupFrame._(
    this.messageId,
    this.senderAlias,
    this.receiverAlias,
    this.groupAlias,
    this.body,
  );
  final String messageId;
  final String senderAlias;
  final String receiverAlias;
  final String groupAlias;
  final Map<String, dynamic> body;
}

Object? _immutableGroupValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(
      value.map((key, item) => MapEntry(key, _immutableGroupValue(item))),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_immutableGroupValue));
  }
  return value;
}
