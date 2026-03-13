import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';

/// 会话 API 客户端
///
/// 仅负责获取服务端权威会话列表，不在此处做本地组装。
class ConversationApi extends HttpClient {
  /// 获取当前用户的服务端权威会话列表
  Future<List<Map<String, dynamic>>> listMine({int? lastServerTs}) async {
    final query = <String, dynamic>{};
    if (lastServerTs != null && lastServerTs > 0) {
      query['last_server_ts'] = lastServerTs;
    }

    final resp = await get(
      API.conversationList,
      queryParameters: query.isEmpty ? null : query,
    );
    if (!resp.ok || resp.payload == null) {
      return const [];
    }

    final payload = resp.payload;
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    if (payload is Map) {
      final rawList = payload['list'] ?? payload['items'] ?? payload['rows'];
      if (rawList is List) {
        return rawList
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }

    return const [];
  }
}
