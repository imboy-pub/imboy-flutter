import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/message_preview_text.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// Ephemeral authorized snapshot. Never read global conversation/draft caches.
class WorkspaceConversationModel {
  final GroupModel group;
  final int memberStartSeq;
  final int unreadCount;
  final Map<String, dynamic>? latest;
  final int serverTs;
  final int expiresAt;

  const WorkspaceConversationModel({
    required this.group,
    required this.memberStartSeq,
    this.unreadCount = 0,
    this.latest,
    this.serverTs = 0,
    this.expiresAt = 0,
  });

  factory WorkspaceConversationModel.fromJson(Map<String, dynamic> row) {
    final start = int.tryParse('${row['member_start_seq']}');
    final unread = int.tryParse('${row['unread_count'] ?? 0}');
    final raw = row['latest_message'];
    if (start == null ||
        start < 1 ||
        unread == null ||
        unread < 0 ||
        unread > 2147483647 ||
        !row.containsKey('latest_message')) {
      throw const FormatException('Invalid workspace message snapshot');
    }
    if (raw == null) {
      return WorkspaceConversationModel(
        group: GroupModel.fromJson(row),
        memberStartSeq: start,
        unreadCount: unread,
      );
    }
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid workspace message');
    }
    final seq = int.tryParse('${raw['conv_seq']}');
    final time = _timestamp(raw['server_ts']);
    final expires = raw['expire_at'] == null
        ? null
        : _timestamp(raw['expire_at']);
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
      unreadCount: unread,
      latest: Map.unmodifiable(raw),
      serverTs: time.millisecondsSinceEpoch,
      expiresAt: expires?.millisecondsSinceEpoch ?? 0,
    );
  }

  static DateTime? _timestamp(dynamic value) {
    if (value is num && value is! int) return null;
    try {
      return parseModelNullableDateTime(value);
    } on ArgumentError {
      return null;
    }
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
    // 预览文案全类型收口到 messagePreviewText：聊天页能渲染的类型
    // （群作业/群投票/群日程/语音/红包/通话等）这里都必须有可读摘要，
    // 不能再显示「[不支持的消息]」——白名单只写 5 种类型曾让
    // 企业工作台群聊列表与聊天页能力脱节（EO-20261009）。
    return messagePreviewText('${msg['msg_type']}', body);
  }
}
