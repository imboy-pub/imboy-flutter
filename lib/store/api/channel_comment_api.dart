import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/model/channel_comment_model.dart';

mixin ChannelCommentApi on HttpClient {
  // ==================== 评论 API ====================

  /// 获取消息评论列表
  Future<List<ChannelCommentModel>> getComments({
    required String channelId,
    required String messageId,
    int cursor = 0,
    int limit = 20,
  }) async {
    final resp = await get(
      '/api/v1/channel/$channelId/message/$messageId/comments',
      queryParameters: {'cursor': cursor, 'limit': limit},
    );
    if (!resp.ok || resp.payload == null) return [];
    final list = IMBoyHttpResponse.payloadList(resp.payload);
    return list.map((json) => ChannelCommentModel.fromJson(json)).toList();
  }

  /// 创建评论
  Future<ChannelCommentModel?> createComment({
    required String channelId,
    required String messageId,
    required String content,
    int parentId = 0,
  }) async {
    final resp = await post(
      '/api/v1/channel/$channelId/message/$messageId/comment',
      data: {'content': content, 'parent_id': parentId},
    );
    if (!resp.ok || resp.payload == null) return null;
    return ChannelCommentModel.fromJson(
      Map<String, dynamic>.from(IMBoyHttpResponse.payloadAsMap(resp.payload)),
    );
  }

  /// 删除评论
  Future<bool> deleteComment({
    required String channelId,
    required String commentId,
  }) async {
    final resp = await post(
      '/api/v1/channel/$channelId/comment/$commentId/delete',
    );
    return resp.ok;
  }

  /// 点赞评论
  Future<bool> likeComment({
    required String channelId,
    required String commentId,
  }) async {
    final resp = await post(
      '/api/v1/channel/$channelId/comment/$commentId/like',
    );
    return resp.ok;
  }

  /// 取消点赞评论
  Future<bool> unlikeComment({
    required String channelId,
    required String commentId,
  }) async {
    final resp = await post(
      '/api/v1/channel/$channelId/comment/$commentId/unlike',
    );
    return resp.ok;
  }
}
