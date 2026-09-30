import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/group_model.dart';

/// Ephemeral authorized snapshot. Never read global conversation/draft caches.
class WorkspaceConversationModel {
  final GroupModel group;
  final int memberStartSeq;
  final Map<String, dynamic>? latest;
  final int serverTs;
  final int expiresAt;

  const WorkspaceConversationModel({
    required this.group,
    required this.memberStartSeq,
    this.latest,
    this.serverTs = 0,
    this.expiresAt = 0,
  });

  factory WorkspaceConversationModel.fromJson(Map<String, dynamic> row) {
    final start = int.tryParse('${row['member_start_seq']}');
    final raw = row['latest_message'];
    if (start == null || start < 1 || !row.containsKey('latest_message')) {
      throw const FormatException('Invalid workspace message snapshot');
    }
    if (raw == null) {
      return WorkspaceConversationModel(
        group: GroupModel.fromJson(row),
        memberStartSeq: start,
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid workspace message');
    }
    final seq = int.tryParse('${raw['conv_seq']}');
    final time = DateTime.tryParse('${raw['server_ts']}');
    final expires = raw['expire_at'] == null
        ? null
        : DateTime.tryParse('${raw['expire_at']}');
    if (seq == null ||
        seq < start ||
        raw['msg_id'] is! String ||
        (raw['msg_id'] as String).isEmpty ||
        raw['msg_type'] is! String ||
        raw['payload'] is! Map<String, dynamic> ||
        time == null ||
        !raw.containsKey('expire_at') ||
        (raw['expire_at'] != null && expires == null)) {
      throw const FormatException('Invalid workspace message boundary');
    }
    return WorkspaceConversationModel(
      group: GroupModel.fromJson(row),
      memberStartSeq: start,
      latest: Map.unmodifiable(raw),
      serverTs: time.millisecondsSinceEpoch,
      expiresAt: expires?.millisecondsSinceEpoch ?? 0,
    );
  }

  String get previewText {
    final msg = latest;
    if (msg == null ||
        (expiresAt > 0 && expiresAt <= DateTimeHelper.millisecond())) {
      return '';
    }
    final envelope = msg['payload'] as Map<String, dynamic>;
    if (msg['e2ee'] != null || envelope['e2ee'] != null) {
      return t.chat.encryptedMessagePlaceholder;
    }
    final body = envelope['payload'] is Map
        ? envelope['payload'] as Map
        : envelope;
    if (envelope['action'] == 'message_revoke_ack' ||
        body['action'] == 'message_revoke_ack') {
      return t.common.messageRevoked;
    }
    // Burn previews never persist outside the chat's actual read/expiry state.
    if ((body['burn_after'] ?? 0) != 0 || (envelope['burn_after'] ?? 0) != 0) {
      return '';
    }
    return switch (msg['msg_type']) {
      'text' || 'quote' =>
        body['text'] is String
            ? body['text'] as String
            : (body['content'] is String ? body['content'] as String : ''),
      'image' => t.chat.imageMessage,
      'video' => t.chat.videoMessage,
      'file' => t.chat.file,
      _ => t.chat.invalidMessageType,
    };
  }
}
