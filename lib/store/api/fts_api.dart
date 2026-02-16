import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/message_model.dart';

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
  });

  factory MessageSearchResult.fromJson(Map<String, dynamic> json) {
    return MessageSearchResult(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      fromId: json['from_id']?.toString() ?? '',
      toId: json['to_id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'C2C',
      createdAt: _parseTimestamp(json['created_at']),
      msgType: json['msg_type']?.toString(),
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload']
          : null,
      status: json['status'] as int?,
    );
  }

  static int _parseTimestamp(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
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
      fromId: fromId,
      toId: toId,
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

  MessageSearchResponse({
    required this.items,
    required this.total,
  });

  factory MessageSearchResponse.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return MessageSearchResponse(
      items: itemsList
          .map((item) => MessageSearchResult.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
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
    if (startTime != null) {
      queryParams['start_time'] = startTime;
    }
    if (endTime != null) {
      queryParams['end_time'] = endTime;
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
    } catch (e) {
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

    try {
      final IMBoyHttpResponse resp = await get(
        API.ftsMessage,
        queryParameters: {
          'keyword': keyword.trim(),
          'conversation_uk3': conversationUk3,
          'page': page,
          'size': size,
        },
      );

      if (!resp.ok) {
        return null;
      }

      final payload = resp.payload;
      if (payload is Map<String, dynamic>) {
        return MessageSearchResponse.fromJson(payload);
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
