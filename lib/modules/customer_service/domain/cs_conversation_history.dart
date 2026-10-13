import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';

const csHistoryPageLimit = 50;

class CsConversationHistoryPage {
  final List<CsConversationMessage> messages;
  final Map<String, DateTime> readAt;
  CsConversationHistoryPage(this.messages, this.readAt);
}

/// Uses the existing CS-routed Enterprise history endpoint; no alternate auth.
Future<CsConversationHistoryPage> fetchCsHistoryPage(
  CsApi api, {
  required String orgId,
  required String workspaceId,
  required String conversationId,
  bool latest = false,
  String? beforeId,
  String? afterId,
}) async {
  final response = await api.get(
    '/api/v1/enterprise/conversations/$conversationId/messages',
    queryParameters: {
      'organization_id': orgId,
      'workspace_id': workspaceId,
      'limit': csHistoryPageLimit,
      if (latest) 'order': 'desc',
      'before_id': ?beforeId,
      if (afterId != null && afterId.isNotEmpty) 'after_id': afterId,
    },
  );
  if (!response.ok) throw CsApiException(response.code, response.msg);
  return parseCsHistoryPage(
    response.payload,
    orgId,
    conversationId,
    latest: latest,
    beforeId: beforeId,
    afterId: afterId,
  );
}

CsConversationHistoryPage parseCsHistoryPage(
  dynamic payload,
  String org,
  String conversation, {
  bool latest = false,
  String? beforeId,
  String? afterId,
}) {
  final raw = payload is List
      ? payload
      : payload is Map
      ? payload['messages'] ?? payload['list']
      : null;
  if (raw is! List || raw.length > csHistoryPageLimit) {
    throw const CsApiException(0, 'history-invalid');
  }
  final rows = <CsConversationMessage>[];
  final reads = <String, DateTime>{};
  BigInt? previous;
  for (final value in raw) {
    if (value is! Map) throw const CsApiException(0, 'history-invalid');
    final row = CsConversationMessage.fromJson(
      Map<String, dynamic>.from(value),
    );
    final id = csMessageId(row.message.id);
    if (row.message.organizationId != org ||
        row.message.conversationId != conversation ||
        (beforeId != null && id >= csMessageId(beforeId)) ||
        (afterId != null && afterId.isNotEmpty && id <= csMessageId(afterId)) ||
        (previous != null && (latest ? id >= previous : id <= previous))) {
      throw const CsApiException(0, 'history-invalid');
    }
    previous = id;
    rows.add(row);
    final at = _receiptAt(value);
    if (at != null) reads[row.message.id] = at;
  }
  return CsConversationHistoryPage(
    List.unmodifiable(rows),
    Map.unmodifiable(reads),
  );
}

DateTime? _receiptAt(Map<dynamic, dynamic> value) {
  if (value['sender_type'] != 'business_identity' ||
      value['visibility'] != 'visible') {
    return null;
  }
  final at = value['read_at'];
  if (at is! String) return null;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?Z$',
  ).firstMatch(at);
  if (match == null) return null;
  final parsed = DateTime.tryParse(at);
  if (parsed == null || !parsed.isUtc) return null;
  final fields = [
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
  ];
  for (var i = 0; i < fields.length; i++) {
    if (fields[i] != int.parse(match.group(i + 1)!)) return null;
  }
  return parsed;
}

BigInt csMessageId(String id) {
  final parsed = RegExp(r'^[1-9][0-9]*$').hasMatch(id)
      ? BigInt.tryParse(id)
      : null;
  if (parsed == null || parsed > BigInt.parse('9223372036854775807')) {
    throw const CsApiException(0, 'message-id-invalid');
  }
  return parsed;
}

Future<void> acknowledgeCsVisible(
  CsApi api,
  String org,
  String workspace,
  String session,
  String message,
) async {
  final response = await api.post(
    '/api/v1/cs/organizations/$org/sessions/$session/read-cursor',
    data: {'workspace_id': workspace, 'last_read_message_id': message},
  );
  if (!response.ok) throw CsApiException(response.code, response.msg);
}

Future<CsReadState> fetchCsReadState(
  CsApi api,
  String org,
  String workspace,
  String session,
) async {
  final response = await api.get(
    '/api/v1/cs/organizations/$org/sessions/$session/read-cursor',
    queryParameters: {'workspace_id': workspace},
  );
  if (!response.ok) throw CsApiException(response.code, response.msg);
  if (response.payload is! Map) {
    throw const CsApiException(0, 'read-state-invalid');
  }
  final payload = response.payload as Map;
  final state = CsReadState.fromJson(payload);
  final cursor = payload['last_read_message_id'];
  if (state.unreadCount < 0 || (cursor is! int && cursor is! String)) {
    throw const CsApiException(0, 'read-state-invalid');
  }
  if ('$cursor' != '0') csMessageId('$cursor');
  if (state.sessionId != session) {
    throw const CsApiException(0, 'read-state-invalid');
  }
  return state;
}
