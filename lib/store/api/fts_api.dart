import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

/// FTS (Full-Text Search) API 提供者的 Riverpod Provider
/// 提供对 FtsApi 单例的访问
final ftsApiProvider = Provider<FtsApi>((ref) {
  return FtsApi.to;
});

/// 消息搜索结果模型
class MessageSearchResult {
  final String id;
  final String content;
  final String fromId;
  final String toId;
  final String type; // C2C, C2G
  final int createdAt;
  final String? msgType;
  final Map<String, dynamic>? payload;
  final int? status;
  final String? highlight; // 后端 ts_headline 高亮片段

  MessageSearchResult({
    required this.id,
    required this.content,
    required this.fromId,
    required this.toId,
    required this.type,
    required this.createdAt,
    this.msgType,
    this.payload,
    this.status,
    this.highlight,
  });

  factory MessageSearchResult.fromJson(Map<String, dynamic> json) {
    final statusValue = json['status'];
    // 后端返回 message_id / from / to / conversation_type(小写)
    // 保留旧字段名作为兼容回退
    final rawType = parseModelString(
      json['conversation_type'] ?? json['type'],
      defaultValue: 'C2C',
    );
    final payloadRaw = json['payload'];
    final payloadMap = parseModelJsonMap(payloadRaw);
    final content = payloadMap != null
        ? parseModelString(payloadMap['text'] ?? payloadRaw)
        : parseModelString(payloadRaw);
    return MessageSearchResult(
      id: parseModelString(json['message_id'] ?? json['id']),
      content: content,
      fromId: parseModelString(json['from'] ?? json['from_id']),
      toId: parseModelString(json['to'] ?? json['to_id']),
      type: rawType.toUpperCase(),
      createdAt: parseModelInt(json['created_at']),
      msgType: parseModelNullableString(json['msg_type']),
      payload: payloadMap,
      status: statusValue == null ? null : parseModelInt(statusValue),
      highlight: parseModelNullableString(json['highlight']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'from_id': fromId,
      'to_id': toId,
      'type': type,
      'created_at': createdAt,
      'msg_type': msgType,
      'payload': payload,
      'status': status,
    };
  }

  /// 转换为 MessageModel
  MessageModel toMessageModel() {
    return MessageModel(
      id,
      autoId: 0,
      type: type,
      status: status ?? IMBoyMessageStatus.delivered,
      fromId: parseModelInt(fromId),
      toId: parseModelInt(toId),
      payload: payload ?? {'text': content},
      isAuthor: 0,
      conversationUk3: '',
      createdAt: createdAt,
      msgType: msgType,
    );
  }
}

/// 消息搜索响应模型
class MessageSearchResponse {
  final List<MessageSearchResult> items;
  final int total;

  MessageSearchResponse({required this.items, required this.total});

  factory MessageSearchResponse.fromJson(Map<String, dynamic> json) {
    // 后端返回 'list'，兼容旧字段名 'items'
    final itemsList = (json['list'] ?? json['items']) as List<dynamic>? ?? [];
    return MessageSearchResponse(
      items: itemsList
          .whereType<Map<String, dynamic>>()
          .map(
            (item) =>
                MessageSearchResult.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      total: parseModelInt(json['total']),
    );
  }
}

/// FTS API 客户端
/// 负责处理全文搜索相关的 HTTP 请求
/// 采用单例模式，通过 FtsApi.to 访问实例
class FtsApi extends HttpClient {
  // 私有构造函数，实现单例模式
  FtsApi._();

  // 单例实例
  static final FtsApi _instance = FtsApi._();

  /// 获取单例实例
  static FtsApi get to => _instance;

  /// 搜索消息
  ///
  /// [keyword] 搜索关键词
  /// [page] 页码，从1开始
  /// [size] 每页数量
  /// [type] 消息类型过滤：all, C2C, C2G
  /// [startTime] 开始时间戳（毫秒）
  /// [endTime] 结束时间戳（毫秒）
  Future<MessageSearchResponse?> searchMessages({
    required String keyword,
    int page = 1,
    int size = 20,
    String type = 'all',
    int? startTime,
    int? endTime,
  }) async {
    if (keyword.trim().isEmpty) {
      return MessageSearchResponse(items: [], total: 0);
    }

    final queryParams = <String, dynamic>{
      'keyword': keyword.trim(),
      'page': page,
      'size': size,
    };

    if (type != 'all') {
      queryParams['type'] = type;
    }
    // NOTE: type='all' 不传 type 参数，后端默认 C2C；全类型搜索需两次请求合并。
    if (startTime != null) {
      queryParams['start_date'] = _msToDateString(startTime);
    }
    if (endTime != null) {
      queryParams['end_date'] = _msToDateString(endTime);
    }

    try {
      final IMBoyHttpResponse resp = await get(
        API.ftsMessage,
        queryParameters: queryParams,
      );

      if (!resp.ok) {
        return null;
      }

      final payload = resp.payload;
      if (payload is Map<String, dynamic>) {
        return MessageSearchResponse.fromJson(payload);
      }

      return null;
    } on Exception catch (e) {
      debugPrint('[FtsApi] searchMessages error: $e');
      return null;
    }
  }

  /// 搜索指定会话的消息
  ///
  /// [keyword] 搜索关键词
  /// [conversationUk3] 会话唯一标识
  /// [page] 页码
  /// [size] 每页数量
  Future<MessageSearchResponse?> searchConversationMessages({
    required String keyword,
    required String conversationUk3,
    int page = 1,
    int size = 20,
  }) async {
    if (keyword.trim().isEmpty || conversationUk3.isEmpty) {
      return MessageSearchResponse(items: [], total: 0);
    }

    final queryParams = <String, dynamic>{
      'keyword': keyword.trim(),
      'page': page,
      'size': size,
    };

    // 后端不支持 conversation_uk3；解析出 type 和 conversation_id 做最大化过滤
    final parts = conversationUk3.split('_');
    if (parts.isNotEmpty) {
      final convType = parts[0].toUpperCase();
      queryParams['type'] = convType;
      if (convType == 'C2G' && parts.length >= 2) {
        final groupId = int.tryParse(parts[1]);
        if (groupId != null && groupId > 0) {
          queryParams['conversation_id'] = groupId;
        }
      }
    }

    try {
      final IMBoyHttpResponse resp = await get(
        API.ftsMessage,
        queryParameters: queryParams,
      );

      if (!resp.ok) {
        return null;
      }

      final payload = resp.payload;
      if (payload is Map<String, dynamic>) {
        return MessageSearchResponse.fromJson(payload);
      }

      return null;
    } on Exception catch (e) {
      debugPrint('[FtsApi] searchConversationMessages error: $e');
      return null;
    }
  }

  /// 毫秒时间戳 → YYYY-MM-DD（后端 start_date/end_date 格式）
  static String _msToDateString(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}
