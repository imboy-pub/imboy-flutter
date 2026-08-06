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

  /// 空页（请求失败 / payload 结构不符）。
  static const MomentPageResult<Map<String, dynamic>> empty =
      MomentPageResult<Map<String, dynamic>>(
        list: [],
        nextCursor: null,
        hasMore: false,
      );

  /// 从后端分页 payload 解析出一页数据。
  ///
  /// hasMore 判据是**本页返回条数是否满一页**（`list.length >= limit`），
  /// 不是「cursor 非空」—— 服务端对最后一页也照样回一个 cursor，按 cursor
  /// 推 hasMore 会让「加载更多」在没有下一页时也一直显示（只有 1 条评论时
  /// 底部照样转圈）。cursor 为空时同样翻不了页，故两者取与。
  static MomentPageResult<Map<String, dynamic>> fromPayload(
    Map<String, dynamic> payload, {
    required int limit,
  }) {
    final rawList = payload['list'];
    final list = rawList is List
        ? rawList
              .whereType<Map<String, dynamic>>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : <Map<String, dynamic>>[];
    final nextCursor = parseModelNullableString(payload['cursor']);
    final hasMore =
        limit > 0 &&
        list.length >= limit &&
        nextCursor != null &&
        nextCursor.isNotEmpty;
    return MomentPageResult(
      list: list,
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }
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
    Map<String, dynamic>? location,
    List<String> atUids = const [],
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
    if (location != null && location.isNotEmpty) {
      body['location'] = location;
    }
    if (atUids.isNotEmpty) {
      body['at_uids'] = atUids;
    }

    final resp = await post(API.momentCreate, data: body);
    if (!resp.ok ||
        resp.payload == null ||
        resp.payload is! Map<String, dynamic>) {
      return null;
    }
    return Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
  }

  Future<Map<String, dynamic>?> getPost(String momentId) async {
    final resp = await get(API.momentDetail(momentId));
    if (!resp.ok ||
        resp.payload == null ||
        resp.payload is! Map<String, dynamic>) {
      return null;
    }
    return Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
  }

  Future<bool> deletePost(String momentId) async {
    final resp = await post(
      API.momentDelete(momentId),
      data: <String, dynamic>{},
    );
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
    if (!resp.ok || resp.payload is! Map<String, dynamic>) {
      return MomentPageResult.empty;
    }
    return MomentPageResult.fromPayload(
      Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>),
      limit: limit,
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
    if (!resp.ok || resp.payload is! Map<String, dynamic>) {
      return MomentPageResult.empty;
    }
    return MomentPageResult.fromPayload(
      Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>),
      limit: limit,
    );
  }

  Future<bool> likePost(String momentId) async {
    final resp = await post(
      API.momentLike(momentId),
      data: <String, dynamic>{},
    );
    return resp.ok;
  }

  Future<bool> unlikePost(String momentId) async {
    final resp = await post(
      API.momentUnlike(momentId),
      data: <String, dynamic>{},
    );
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
    if (!resp.ok ||
        resp.payload == null ||
        resp.payload is! Map<String, dynamic>) {
      return null;
    }
    return Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>);
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
    if (!resp.ok || resp.payload is! Map<String, dynamic>) {
      return MomentPageResult.empty;
    }
    return MomentPageResult.fromPayload(
      Map<String, dynamic>.from(resp.payload as Map<dynamic, dynamic>),
      limit: limit,
    );
  }

  Future<bool> deleteComment(String momentId, String commentId) async {
    final resp = await post(
      API.momentCommentDelete(momentId, commentId),
      data: <String, dynamic>{},
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
