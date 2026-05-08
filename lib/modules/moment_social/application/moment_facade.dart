import 'package:imboy/store/api/moment_api.dart';

/// Stable module entry for upper layers. Current implementation remains a thin
/// facade over the legacy MomentApi until the internal move is complete.
class MomentFacade {
  MomentFacade({MomentApi? api}) : _api = api ?? MomentApi();

  static final MomentFacade instance = MomentFacade();

  final MomentApi _api;

  Future<Map<String, dynamic>?> createPost({
    required String content,
    List<Map<String, dynamic>> media = const [],
    int visibility = 1,
    bool allowComment = true,
    List<String> allowUids = const [],
    List<String> denyUids = const [],
  }) => _api.createPost(
    content: content,
    media: media,
    visibility: visibility,
    allowComment: allowComment,
    allowUids: allowUids,
    denyUids: denyUids,
  );

  Future<Map<String, dynamic>?> getPost(String momentId) =>
      _api.getPost(momentId);

  Future<bool> deletePost(String momentId) => _api.deletePost(momentId);

  Future<MomentPageResult<Map<String, dynamic>>> getFeedPage({
    String? cursor,
    int limit = 20,
  }) => _api.getFeedPage(cursor: cursor, limit: limit);

  Future<MomentPageResult<Map<String, dynamic>>> getUserPostsPage(
    String uid, {
    String? cursor,
    int limit = 20,
  }) => _api.getUserPostsPage(uid, cursor: cursor, limit: limit);

  Future<bool> likePost(String momentId) => _api.likePost(momentId);

  Future<bool> unlikePost(String momentId) => _api.unlikePost(momentId);

  Future<Map<String, dynamic>?> addComment(
    String momentId, {
    required String content,
    String? replyToUid,
    List<String> mentions = const [],
  }) => _api.addComment(
    momentId,
    content: content,
    replyToUid: replyToUid,
    mentions: mentions,
  );

  Future<MomentPageResult<Map<String, dynamic>>> listComments(
    String momentId, {
    String? cursor,
    int limit = 20,
  }) => _api.listComments(momentId, cursor: cursor, limit: limit);

  Future<bool> deleteComment(String momentId, String commentId) =>
      _api.deleteComment(momentId, commentId);

  Future<bool> reportPost(
    String momentId, {
    required String reason,
    String description = '',
  }) => _api.reportPost(momentId, reason: reason, description: description);
}
