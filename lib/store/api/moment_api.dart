import 'package:flutter/foundation.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

class MomentPageResult<T> {
  final List<T> list;
  final String? nextCursor;
  final bool hasMore;

  const MomentPageResult({
    required this.list,
    required this.nextCursor,
    required this.hasMore,
  });
}

/// Moment(朋友圈) API 客户端
class MomentApi extends HttpClient {
  Future<Map<String, dynamic>?> createPost({
    required String content,
    List<Map<String, dynamic>> media = const [],
    int visibility = 1,
    bool allowComment = true,
    List<String> allowUids = const [],
    List<String> denyUids = const [],
  }) async {
    final body = <String, dynamic>{
      'content': content,
      'media': media,
      'visibility': visibility,
      'allow_comment': allowComment,
    };
    if (allowUids.isNotEmpty) {
      body['allow_uids'] = allowUids;
    }
    if (denyUids.isNotEmpty) {
      body['deny_uids'] = denyUids;
    }

    final resp = await post('/v1/moment/create', data: body);
    debugPrint('MomentApi.createPost ok=${resp.ok}, code=${resp.code}');
    if (!resp.ok || resp.payload == null || resp.payload is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(resp.payload);
  }

  Future<Map<String, dynamic>?> getPost(String momentId) async {
    final resp = await get('/v1/moment/$momentId');
    debugPrint('MomentApi.getPost ok=${resp.ok}, code=${resp.code}');
    if (!resp.ok || resp.payload == null || resp.payload is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(resp.payload);
  }

  Future<bool> deletePost(String momentId) async {
    final resp = await post('/v1/moment/$momentId/delete', data: {});
    return resp.ok;
  }

  Future<MomentPageResult<Map<String, dynamic>>> getFeedPage({
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) {
      params['cursor'] = cursor;
    }
    final resp = await get('/v1/moments/feed', queryParameters: params);
    debugPrint('MomentApi.getFeedPage ok=${resp.ok}, code=${resp.code}');
    if (!resp.ok || resp.payload == null || resp.payload is! Map) {
      return const MomentPageResult(list: [], nextCursor: null, hasMore: false);
    }
    final payload = Map<String, dynamic>.from(resp.payload);
    final rawList = payload['list'];
    final list = rawList is List
        ? rawList
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : <Map<String, dynamic>>[];
    final nextCursor = parseModelNullableString(payload['cursor']);
    return MomentPageResult(
      list: list,
      nextCursor: nextCursor,
      hasMore: nextCursor != null && nextCursor.isNotEmpty,
    );
  }

  Future<MomentPageResult<Map<String, dynamic>>> getUserPostsPage(
    String uid, {
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) {
      params['cursor'] = cursor;
    }
    final resp = await get('/v1/moments/user/$uid', queryParameters: params);
    debugPrint('MomentApi.getUserPostsPage ok=${resp.ok}, code=${resp.code}');
    if (!resp.ok || resp.payload == null || resp.payload is! Map) {
      return const MomentPageResult(list: [], nextCursor: null, hasMore: false);
    }
    final payload = Map<String, dynamic>.from(resp.payload);
    final rawList = payload['list'];
    final list = rawList is List
        ? rawList
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : <Map<String, dynamic>>[];
    final nextCursor = parseModelNullableString(payload['cursor']);
    return MomentPageResult(
      list: list,
      nextCursor: nextCursor,
      hasMore: nextCursor != null && nextCursor.isNotEmpty,
    );
  }

  Future<bool> likePost(String momentId) async {
    final resp = await post('/v1/moment/$momentId/like', data: {});
    return resp.ok;
  }

  Future<bool> unlikePost(String momentId) async {
    final resp = await post('/v1/moment/$momentId/unlike', data: {});
    return resp.ok;
  }

  Future<Map<String, dynamic>?> addComment(
    String momentId, {
    required String content,
    String? replyToUid,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (replyToUid != null && replyToUid.isNotEmpty) {
      body['reply_to_uid'] = replyToUid;
    }

    final resp = await post('/v1/moment/$momentId/comment', data: body);
    if (!resp.ok || resp.payload == null || resp.payload is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(resp.payload);
  }

  Future<MomentPageResult<Map<String, dynamic>>> listComments(
    String momentId, {
    String? cursor,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null && cursor.isNotEmpty) {
      params['cursor'] = cursor;
    }
    final resp = await get(
      '/v1/moment/$momentId/comments',
      queryParameters: params,
    );
    if (!resp.ok || resp.payload == null || resp.payload is! Map) {
      return const MomentPageResult(list: [], nextCursor: null, hasMore: false);
    }
    final payload = Map<String, dynamic>.from(resp.payload);
    final rawList = payload['list'];
    final list = rawList is List
        ? rawList
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : <Map<String, dynamic>>[];
    final nextCursor = parseModelNullableString(payload['cursor']);
    return MomentPageResult(
      list: list,
      nextCursor: nextCursor,
      hasMore: nextCursor != null && nextCursor.isNotEmpty,
    );
  }

  Future<bool> deleteComment(String momentId, String commentId) async {
    final resp = await post(
      '/v1/moment/$momentId/comment/$commentId/delete',
      data: {},
    );
    return resp.ok;
  }

  Future<bool> reportPost(
    String momentId, {
    required String reason,
    String description = '',
  }) async {
    final resp = await post(
      '/v1/moment/$momentId/report',
      data: <String, dynamic>{'reason': reason, 'description': description},
    );
    return resp.ok;
  }
}
