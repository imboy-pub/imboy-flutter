import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';

/// 消息 API 客户端
///
/// 负责消息相关的 HTTP REST 请求（历史查询、离线同步等）。
/// WebSocket 消息投递由 service/websocket.dart 负责，不在此处处理。
class MsgApi extends HttpClient {
  /// 查询会话消息历史（conv_seq 游标分页）
  ///
  /// 后端接口：GET /v1/msg/history
  ///
  /// 参数：
  /// - [chatType]  会话类型，'c2c' 或 'c2g'
  /// - [peerId]    对端 ID（hashids 编码的 uid 或 group_id）
  /// - [afterSeq]  从该 conv_seq 之后查询（0 表示从头）
  /// - [limit]     每页条数，最大 100，默认 50
  ///
  /// 返回值（解析自 payload）：
  /// ```json
  /// {
  ///   "messages":  [...],   // 消息列表
  ///   "next_seq":  42,      // 下一页起始 conv_seq（传给 afterSeq）
  ///   "has_more":  true,    // 是否还有更多
  ///   "conv_key":  "c2c:1:2"
  /// }
  /// ```
  /// 失败时返回 null。
  Future<Map<String, dynamic>?> history({
    required String chatType,
    required String peerId,
    int afterSeq = 0,
    int limit = 50,
  }) async {
    final resp = await get(
      API.msgHistory,
      queryParameters: {
        'chat_type': chatType,
        'peer_id': peerId,
        'after_seq': afterSeq,
        'limit': limit.clamp(1, 100),
      },
    );
    if (!resp.ok || resp.payload == null) return null;
    return Map<String, dynamic>.from(resp.payload as Map);
  }
}
