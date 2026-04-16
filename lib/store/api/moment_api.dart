import 'package:flutter/foundation.dart';

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
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

    final resp = await post(API.momentCreate, data: body);
    debugPrint('MomentApi.createPost ok=${resp.ok}, code=${resp.code}');
    if (!resp.ok || resp.payload == null || resp.payload is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(resp.payload);
  }

  Future<Map<String, dynamic>?> getPost(String momentId) async {
    final resp = await get(API.momentDetail(momentId));
    debugPrint('MomentApi.getPost ok=${resp.ok}, code=${resp.code}');
    if (!resp.ok || resp.payload == null || resp.payload is! Map) {
      return null;
    }
    return Map<String, dynamic>.from(resp.payload);
  }

  Future<bool> deletePost(String momentId) async {
    final resp = await post(API.momentDelete(momentId), data: {});
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
    final resp = await get(API.momentsFeed, queryParameters: params);
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
    final resp = await get(API.momentsUser(uid), queryParameters: params);
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
    final resp = await post(API.momentLike(momentId), data: {});
    return resp.ok;
  }

  Future<bool> unlikePost(String momentId) async {
    final resp = await post(API.momentUnlike(momentId), data: {});
    return resp.ok;
  }

  Future<Map<String, dynamic>?> addComment(
    String momentId, {
    required String content,
    String? replyToUid,
    List<String> mentions = const [],
  }) async {
    final body = <String, dynamic>{'content': content};
    if (replyToUid != null && replyToUid.isNotEmpty) {
      body['reply_to_uid'] = replyToUid;
    }
    if (mentions.isNotEmpty) {
      body['mentions'] = mentions;
    }

    final resp = await post(API.momentComment(momentId), data: body);
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
      API.momentComments(momentId),
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
      API.momentCommentDelete(momentId, commentId),
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
      API.momentReport(momentId),
      data: <String, dynamic>{'reason': reason, 'description': description},
    );
    return resp.ok;
  }
}
