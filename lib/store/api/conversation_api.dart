import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';

/// 会话 API 客户端
///
/// 仅负责获取服务端权威会话列表，不在此处做本地组装。
class ConversationApi extends HttpClient {
  String _normalizeConversationType(String type) {
    switch (type.trim().toUpperCase()) {
      case 'C2C':
        return 'c2c';
      case 'C2G':
        return 'c2g';
      default:
        return type.trim().toLowerCase();
    }
  }

  List<Map<String, dynamic>> _parseMapListPayload(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map<String, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    if (payload is Map<String, dynamic>) {
      final rawList = payload['list'] ?? payload['items'] ?? payload['rows'];
      if (rawList is List) {
        return rawList
            .whereType<Map<String, dynamic>>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    }

    return const [];
  }

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

    return _parseMapListPayload(resp.payload);
  }

  /// 置顶会话
  Future<bool> pin({
    required String conversationId,
    required String type,
  }) async {
    final resp = await post(
      API.conversationPin,
      data: {
        'conversation_id': conversationId,
        'type': _normalizeConversationType(type),
      },
    );
    return resp.ok;
  }

  /// 取消置顶会话
  Future<bool> unpin({
    required String conversationId,
    required String type,
  }) async {
    final resp = await post(
      API.conversationUnpin,
      data: {
        'conversation_id': conversationId,
        'type': _normalizeConversationType(type),
      },
    );
    return resp.ok;
  }

  /// 删除会话
  Future<bool> deleteConversation({
    required String conversationId,
    required String type,
  }) async {
    final resp = await post(
      API.conversationDelete,
      data: {
        'conversation_id': conversationId,
        'type': _normalizeConversationType(type),
      },
    );
    return resp.ok;
  }

  /// 恢复会话
  Future<bool> restoreConversation({
    required String conversationId,
    required String type,
  }) async {
    final resp = await post(
      API.conversationRestore,
      data: {
        'conversation_id': conversationId,
        'type': _normalizeConversationType(type),
      },
    );
    return resp.ok;
  }

  /// 获取服务端权威置顶会话列表
  Future<List<Map<String, dynamic>>> pinnedList() async {
    final resp = await get(API.conversationPinned);
    if (!resp.ok || resp.payload == null) {
      return const [];
    }

    return _parseMapListPayload(resp.payload);
  }

  /// W09.a（§6.7/J17.c）：显式目标 true/false 设置会话人工待处理。
  ///
  /// 真实未读水位不依赖本元数据；服务端无变化同目标重试返回当前状态
  /// 不重复副作用。成功返回服务端权威版本；失败返回 null（调用方给
  /// 重试，不假成功）。
  Future<({bool value, int version})?> setManualPending({
    required String uk3,
    required bool value,
  }) async {
    final resp = await post(
      API.conversationManualPending,
      data: {'uk3': uk3, 'value': value},
    );
    if (!resp.ok) return null;
    final payload = IMBoyHttpResponse.payloadAsMap(resp.payload);
    final version = int.tryParse('${payload['version']}');
    if (version == null) return null;
    return (value: value, version: version);
  }

  /// 当前账号全部人工待处理元数据（uk3/value/version 投影）。
  Future<List<Map<String, dynamic>>> manualPendingList() async {
    final resp = await get(API.conversationManualPendingList);
    if (!resp.ok || resp.payload == null) {
      return const [];
    }
    return _parseMapListPayload(resp.payload);
  }
}
