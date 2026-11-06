import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:dio/dio.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/store/model/channel_decimal_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/messaging/public.dart' show burnExpiresAtMs;
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/sqlite.dart';

/// 后端 ERR_FEATURE_DISABLED 错误码（见 imboy/include/error_code.hrl:225）。
/// 当 E2EE 模式为 secure_e2ee/required 时，后端策略强制关闭 message_search。
const _kErrFeatureDisabled = 5190;

/// 搜索功能被策略禁用时抛出（如当前加密模式不支持服务端搜索）。
/// UI 层应捕获此异常显示"功能未启用"而非笼统的"搜索失败"。
class FtsFeatureDisabledException implements Exception {
  final String message;
  FtsFeatureDisabledException([this.message = '当前加密模式不支持消息搜索']);
  @override
  String toString() => 'FtsFeatureDisabledException: $message';
}

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
  // 本地回查时保留真实 is_author；远端响应未给出时由当前用户 ID 判断。
  final int? isAuthor;

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
    this.isAuthor,
  });

  int? expiresAtMs(String currentUid) => burnExpiresAtMs(
    payload ?? const {},
    fallbackStartMs:
        (isAuthor == 1 || (isAuthor == null && fromId == currentUid))
        ? createdAt
        : 0,
  );

  bool isVisibleAt(int nowMs, String currentUid) {
    if (payload?['burn_deleted'] == true) return false;
    if (status != null && status! >= 30 && status! < 40) return false;
    final deadline = expiresAtMs(currentUid);
    return deadline == null || nowMs < deadline;
  }

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
      toId: parseModelString(json['to'] ?? json['to_id'] ?? json['group_id']),
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
      fromId: fromId,
      toId: toId,
      payload: payload ?? {'text': content},
      isAuthor: isAuthor ?? 0,
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

  /// 本页原始条数用于继续翻页；客户端过滤到期结果不能截断后续页。
  final int sourceItemCount;

  MessageSearchResponse({
    required this.items,
    required this.total,
    int? sourceItemCount,
  }) : sourceItemCount = sourceItemCount ?? items.length;

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

  /// 远端搜索不能覆盖本机的已读期限、撤回或焚毁墓碑。没有本地行时
  /// 保留远端事实；后端未提供 expire_at，不能在客户端猜它的期限。
  Future<MessageSearchResponse> _withLocalVisibility(
    MessageSearchResponse response, {
    required String uid,
    required int sessionGeneration,
  }) async {
    final session = UserRepoLocal.to;
    bool current() =>
        session.currentUid == uid &&
        session.isCurrentSession(sessionGeneration) &&
        !session.isAuthTransitioning;
    final visible = <MessageSearchResult>[];
    for (final item in response.items) {
      if (!current()) return MessageSearchResponse(items: [], total: 0);
      if (!item.isVisibleAt(DateTimeHelper.millisecond(), uid)) continue;
      var resolved = item;
      var localChecked = false;
      if (item.type == 'C2C' || item.type == 'C2G') {
        try {
          final db = await SqliteService.to.db;
          if (!current()) return MessageSearchResponse(items: [], total: 0);
          if (db != null) {
            final table = item.type == 'C2G' ? 'msg_c2g' : 'msg_c2c';
            final rows = await db.rawQuery(
              'SELECT payload, created_at, is_author, status, msg_type FROM $table '
              'WHERE id = ? AND from_id = ? AND to_id = ? LIMIT 1',
              [item.id, item.fromId, item.toId],
            );
            if (!current()) return MessageSearchResponse(items: [], total: 0);
            localChecked = true;
            if (rows.isNotEmpty) {
              final row = rows.first;
              final payload = parseModelJsonMap(row['payload']) ?? item.payload;
              resolved = MessageSearchResult(
                id: item.id,
                content:
                    parseModelNullableString(payload?['text']) ?? item.content,
                fromId: item.fromId,
                toId: item.toId,
                type: item.type,
                createdAt: parseModelInt(row['created_at']),
                msgType:
                    parseModelNullableString(row['msg_type']) ?? item.msgType,
                payload: payload,
                status: row['status'] == null
                    ? item.status
                    : parseModelInt(row['status']),
                isAuthor: row['is_author'] == null
                    ? item.isAuthor
                    : parseModelInt(row['is_author']),
                // 远端高亮可能仍含编辑前正文，不与本机新 payload 混用。
              );
            }
          }
        } on Exception {
          // 下方对 burn 结果明确报错；不能把读取失败解释为本机未读。
        }
      }
      if (!current()) return MessageSearchResponse(items: [], total: 0);
      if (!localChecked &&
          (item.payload?['burn'] == true || item.payload?['is_burn'] == true)) {
        throw const FormatException('Local burn visibility is unavailable');
      }
      if (resolved.isVisibleAt(DateTimeHelper.millisecond(), uid)) {
        visible.add(resolved);
      }
    }
    final removed = response.items.length - visible.length;
    return MessageSearchResponse(
      items: visible,
      total: response.total > removed ? response.total - removed : 0,
      sourceItemCount: response.sourceItemCount,
    );
  }

  /// 点击前重新读取当前账号的已知事实，处理搜索后才开始的接收方计时。
  Future<MessageSearchResult?> refreshResultVisibility(
    MessageSearchResult item,
  ) async {
    final session = UserRepoLocal.to;
    try {
      final response = await _withLocalVisibility(
        MessageSearchResponse(items: [item], total: 1),
        uid: session.currentUid,
        sessionGeneration: session.sessionGeneration,
      );
      return response.items.firstOrNull;
    } on FormatException {
      // 点击时不能核验也不打开旧正文；重新搜索会显示明确的错误态。
      return null;
    }
  }

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

    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final sessionGeneration = session.sessionGeneration;

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

    final IMBoyHttpResponse resp = await get(
      API.ftsMessage,
      options: Options(
        responseDecoder: channelIdResponseDecoder(ChannelResponseShape.fts),
      ),
      queryParameters: queryParams,
    );

    if (!resp.ok) {
      if (resp.code == _kErrFeatureDisabled) {
        throw FtsFeatureDisabledException();
      }
      // 失败必须抛出（fail-open 改造）：调用方（message_search_provider /
      // search_chat_page / web_search_page）均有 catch 并渲染错误态，
      // return null 会把网络失败压成「搜索无结果」。
      resp.throwIfFailed();
    }

    final payload = resp.payload;
    if (payload is Map<String, dynamic>) {
      return _withLocalVisibility(
        MessageSearchResponse.fromJson(payload),
        uid: uid,
        sessionGeneration: sessionGeneration,
      );
    }

    return null;
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
    // 消息类型筛选（text/image/video 等，见 MessageType），'all' 或空表示不筛选。
    // 后端 fts_handler.erl msg_type 参数已支持，见 imboy/src/api/fts_handler.erl。
    String? msgType,
  }) async {
    if (keyword.trim().isEmpty) {
      return MessageSearchResponse(items: [], total: 0);
    }

    final queryParams = <String, dynamic>{
      'keyword': keyword.trim(),
      'page': page,
      'size': size,
    };

    if (msgType != null && msgType.isNotEmpty && msgType != 'all') {
      queryParams['msg_type'] = msgType;
    }

    final session = UserRepoLocal.to;
    final uid = session.currentUid;
    final sessionGeneration = session.sessionGeneration;
    final scope = buildConversationFilter(conversationUk3, uid);
    queryParams.addAll(scope);

    final IMBoyHttpResponse resp = await get(
      API.ftsMessage,
      options: Options(
        responseDecoder: channelIdResponseDecoder(ChannelResponseShape.fts),
      ),
      queryParameters: queryParams,
    );

    if (!resp.ok) {
      if (resp.code == _kErrFeatureDisabled) {
        throw FtsFeatureDisabledException();
      }
      // 同 searchMessages：失败必须抛出，调用方均有 catch 渲染错误态。
      resp.throwIfFailed();
    }

    final payload = resp.payload;
    if (payload is Map<String, dynamic>) {
      _validateConversationResponse(payload, uid, scope);
      return _withLocalVisibility(
        MessageSearchResponse.fromJson(payload),
        uid: uid,
        sessionGeneration: sessionGeneration,
      );
    }

    throw const FormatException('Invalid conversation search response');
  }

  static void _validateConversationResponse(
    Map<String, dynamic> payload,
    String uid,
    Map<String, dynamic> scope,
  ) {
    final rows = payload['list'] ?? payload['items'];
    if (rows is! List) {
      throw const FormatException('Invalid conversation search response');
    }
    final expectedType = scope['type'];
    final peer = channelDecimalId(scope['conversation_id']);
    final user = channelDecimalId(uid);
    for (final row in rows) {
      if (row is! Map) {
        throw const FormatException('Invalid conversation search response');
      }
      String? type;
      for (final key in ['conversation_type', 'type']) {
        final value = row[key];
        if (value == null) continue;
        if (value is! String || (type != null && type != value.toUpperCase())) {
          throw const FormatException('Conversation search scope mismatch');
        }
        type = value.toUpperCase();
      }
      final from = _consistentScopeId(row, ['from', 'from_id']);
      final to = _consistentScopeId(row, ['group_id', 'to', 'to_id']);
      final matches =
          type == expectedType &&
          from != null &&
          peer != null &&
          user != null &&
          (expectedType == 'C2G'
              ? to == peer
              : (from == user && to == peer) || (from == peer && to == user));
      if (!matches) {
        throw const FormatException('Conversation search scope mismatch');
      }
    }
  }

  static String? _consistentScopeId(
    Map<dynamic, dynamic> row,
    List<String> keys,
  ) {
    String? result;
    for (final key in keys) {
      final raw = row[key];
      if (raw == null) continue;
      final value = channelDecimalId(raw);
      if (value == null || (result != null && result != value)) {
        throw const FormatException('Conversation search scope mismatch');
      }
      result = value;
    }
    return result;
  }

  /// 由 conversationUk3 推导后端可用的过滤参数。
  ///
  /// 不能确定当前账号和会话范围时抛错，避免降级成全局搜索。
  @visibleForTesting
  static Map<String, dynamic> buildConversationFilter(
    String conversationUk3,
    String currentUid,
  ) {
    final parts = conversationUk3.split('_');
    String? id(String value) =>
        RegExp(r'^[0-9]+$').hasMatch(value) ? channelDecimalId(value) : null;
    final uid = id(currentUid);
    if (parts.length != 3 || uid == null) {
      throw const FormatException('Invalid conversation scope');
    }
    final first = id(parts[1]);
    final second = id(parts[2]);
    final type = parts[0].toUpperCase();
    if (first == null || second == null) {
      throw const FormatException('Invalid conversation scope');
    }
    if (type == 'C2G' && first == uid) {
      return {'type': type, 'conversation_id': decimalIdForWire(second)};
    }
    if (type == 'C2C' && (first == uid || second == uid)) {
      final peer = first == uid ? second : first;
      // 旧服务端将自身作为对端时会扩大到所有单聊。
      if (peer == uid) {
        throw const FormatException('Invalid conversation scope');
      }
      return {'type': type, 'conversation_id': decimalIdForWire(peer)};
    }
    throw const FormatException('Invalid conversation scope');
  }

  /// 毫秒时间戳 → YYYY-MM-DD（后端 start_date/end_date 格式）
  static String _msToDateString(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$m-$d';
  }
}
