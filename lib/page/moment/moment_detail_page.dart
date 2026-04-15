import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/helper/func.dart'; // cachedImageProvider
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/moment_social/application/moment_facade.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

import 'moment_interactions.dart';
import 'moment_utils.dart'; // enrichPostWithAuthor, enrichCommentsWithUser

class MomentDetailPage extends StatefulWidget {
  final String momentId;

  const MomentDetailPage({super.key, required this.momentId});

  @override
  State<MomentDetailPage> createState() => _MomentDetailPageState();
}

class _MomentDetailPageState extends State<MomentDetailPage> {
  final MomentFacade _api = MomentFacade.instance;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const int _commentsPageSize = 20;

  Map<String, dynamic>? _moment;
  List<Map<String, dynamic>> _comments = [];
  String? _commentsCursor;
  bool _commentsHasMore = false;
  bool _loading = true;
  bool _sendingComment = false;
  bool _loadingMoreComments = false;

  // Reply target — empty string means "top-level comment"
  String _replyToUid = '';
  String _replyToName = '';

  StreamSubscription<MomentTimelineChangedEvent>? _momentSub;

  @override
  void initState() {
    super.initState();
    _momentSub = AppEventBus.on<MomentTimelineChangedEvent>().listen((event) {
      if (event.momentId == widget.momentId || event.momentId.isEmpty) {
        _loadAll();
      }
    });
    _loadAll();
  }

  @override
  void dispose() {
    _momentSub?.cancel();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final results = await Future.wait([
      _api.getPost(widget.momentId),
      _api.listComments(widget.momentId, limit: _commentsPageSize),
    ]);
    if (!mounted) return;

    final rawPost = results[0] as Map<String, dynamic>?;
    final page = results[1] as dynamic;
    final rawComments = page.list as List<Map<String, dynamic>>;

    // 填充作者/评论者昵称和头像
    final enrichedPost =
        rawPost != null ? await enrichPostWithAuthor(rawPost) : null;
    final enrichedComments = await enrichCommentsWithUser(rawComments);
    if (!mounted) return;

    setState(() {
      _moment = enrichedPost;
      _comments = enrichedComments;
      _commentsCursor = page.nextCursor as String?;
      _commentsHasMore = page.hasMore as bool;
      _loading = false;
    });
  }

  Future<void> _loadMoreComments() async {
    if (_loadingMoreComments || !_commentsHasMore) return;
    final cursor = _commentsCursor;
    if (cursor == null || cursor.isEmpty) return;

    setState(() {
      _loadingMoreComments = true;
    });
    final page = await _api.listComments(
      widget.momentId,
      cursor: cursor,
      limit: _commentsPageSize,
    );
    if (!mounted) return;
    final enriched = await enrichCommentsWithUser(page.list);
    if (!mounted) return;
    setState(() {
      _comments = appendCommentsPage(_comments, enriched);
      _commentsCursor = page.nextCursor;
      _commentsHasMore = page.hasMore;
      _loadingMoreComments = false;
    });
  }

  Future<void> _toggleLike() async {
    final post = _moment;
    if (post == null) return;
    final momentId = parseModelString(post['id']);
    if (momentId.isEmpty) return;
    final liked = parseModelBool(post['liked']);

    // 保存旧状态用于回滚
    final oldMoment = post;

    // 乐观更新 UI
    setState(() {
      _moment = applyOptimisticLikeToggle(post);
    });

    // 发送请求，失败时回滚
    try {
      final ok = liked
          ? await _api.unlikePost(momentId)
          : await _api.likePost(momentId);
      if (!ok && mounted) {
        setState(() {
          _moment = oldMoment;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _moment = oldMoment;
        });
      }
    }
  }

  Future<void> _deleteMoment() async {
    final post = _moment;
    if (post == null) return;
    final momentId = parseModelString(post['id']);
    if (momentId.isEmpty) return;
    final ok = await _api.deletePost(momentId);
    if (!mounted) return;
    if (!ok) {
      EasyLoading.showError(context.t.momentsDeleteFailed);
      return;
    }

    AppEventBus.fire(
      MomentTimelineChangedEvent(
        action: 'moment_deleted',
        momentId: momentId,
        payload: const <String, dynamic>{},
      ),
    );
    Navigator.of(context).pop(true);
  }

  void _startReplyTo(Map<String, dynamic> comment) {
    final uid = parseModelString(comment['user_id']);
    if (uid.isEmpty) return;
    final remark = parseModelString(comment['user_remark']);
    final nickname = parseModelString(comment['user_nickname']);
    final name = resolveMomentDisplayName(
      remark: remark,
      nickname: nickname,
      uid: uid,
    );
    setState(() {
      _replyToUid = uid;
      _replyToName = name;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToUid = '';
      _replyToName = '';
    });
  }

  Future<void> _addComment() async {
    if (_sendingComment) return;
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _sendingComment = true;
    });
    final replyToUid = _replyToUid;
    final added = await _api.addComment(
      widget.momentId,
      content: content,
      replyToUid: replyToUid.isEmpty ? null : replyToUid,
    );
    if (!mounted) return;
    if (added == null) {
      setState(() {
        _sendingComment = false;
      });
      EasyLoading.showError(context.t.momentsCommentFailed);
      return;
    }
    _commentController.clear();
    final list = await enrichCommentsWithUser([added]);
    final enrichedComment = list.first;
    if (!mounted) return;
    setState(() {
      _sendingComment = false;
      _comments = [enrichedComment, ..._comments];
      _replyToUid = '';
      _replyToName = '';
      final post = _moment;
      if (post != null) {
        _moment = applyCommentCountDelta(post, 1);
      }
    });
  }

  Future<void> _deleteComment(String commentId) async {
    final ok = await _api.deleteComment(widget.momentId, commentId);
    if (!mounted) return;
    if (!ok) {
      EasyLoading.showError(context.t.momentsDeleteFailed);
      return;
    }
    setState(() {
      _comments = _comments
          .where((item) => parseModelString(item['id']) != commentId)
          .toList(growable: false);
      final post = _moment;
      if (post != null) {
        _moment = applyCommentCountDelta(post, -1);
      }
    });
  }

  Future<void> _reportMoment() async {
    final reasonController = TextEditingController();
    final descController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(context.t.momentsReport),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                decoration: InputDecoration(labelText: context.t.momentsReportReason),
              ),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: context.t.momentsReportDesc),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.t.buttonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(context.t.confirm),
            ),
          ],
        );
      },
    );

    final reason = reasonController.text.trim();
    final description = descController.text.trim();
    reasonController.dispose();
    descController.dispose();
    if (confirmed == true && reason.isNotEmpty && mounted) {
      final ok = await _api.reportPost(
        widget.momentId,
        reason: reason,
        description: description,
      );
      if (!mounted) return;
      if (ok) {
        EasyLoading.showSuccess(context.t.momentsReportSubmitted);
      } else {
        EasyLoading.showError(context.t.momentsReportFailed);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final post = _moment;
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (post == null) {
      return Scaffold(body: Center(child: Text(context.t.momentsNotFound)));
    }

    final currentUid = currentUidOrEmpty();
    final authorUid = parseModelString(post['author_uid']);
    final authorNickname = parseModelString(post['author_nickname']);
    final authorRemark = parseModelString(post['author_remark']);
    final authorAvatar = parseModelString(post['author_avatar']);
    final displayName = resolveMomentDisplayName(
      remark: authorRemark,
      nickname: authorNickname,
      uid: authorUid,
    );
    final canDeletePost = canDeleteMoment(post, currentUid);
    final content = parseModelString(post['content']);
    final createdAt = parseModelString(post['created_at']);
    final liked = parseModelBool(post['liked']);
    final stats = post['stats'] is Map
        ? Map<String, dynamic>.from(post['stats'] as Map)
        : const <String, dynamic>{};
    final likeCount = parseModelInt(stats['like_count']);
    final commentCount = parseModelInt(stats['comment_count']);
    final media = normalizeMedia(post['media']);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t.moments),
        actions: [
          if (canDeletePost)
            IconButton(
              onPressed: _deleteMoment,
              icon: const Icon(Icons.delete_outline),
              tooltip: context.t.delete,
            )
          else
            IconButton(
              onPressed: _reportMoment,
              icon: const Icon(Icons.flag_outlined),
              tooltip: context.t.momentsReport,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: authorAvatar.isNotEmpty
                            ? cachedImageProvider(authorAvatar, w: 36)
                            : null,
                        child: authorAvatar.isEmpty
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName.substring(0, 1)
                                    : '?',
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(content),
                  ],
                  if (media.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: media
                          .map((item) {
                            final url = parseModelString(item['url']);
                            final type = parseModelString(item['type']);
                            return Stack(
                              children: [
                                Container(
                                  width: 110,
                                  height: 110,
                                  color: Colors.black12,
                                  child: url.isEmpty
                                      ? const Icon(Icons.broken_image_outlined)
                                      : Image(
                          image: cachedImageProvider(url),
                          fit: BoxFit.cover,
                        ),
                                ),
                                if (type == 'video')
                                  const Positioned.fill(
                                    child: Center(
                                      child: Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          })
                          .toList(growable: false),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _toggleLike,
                        icon: Icon(
                          liked ? Icons.favorite : Icons.favorite_border,
                          color: liked ? Colors.red : null,
                        ),
                      ),
                      Text(formatMomentCountLabel(likeCount)),
                      const SizedBox(width: 12),
                      const Icon(Icons.chat_bubble_outline, size: 20),
                      const SizedBox(width: 4),
                      Text(formatMomentCountLabel(commentCount)),
                      const Spacer(),
                      Text(
                        createdAt,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text(
                    context.t.momentsComments,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (_comments.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: Text(context.t.momentsNoComments)),
                    )
                  else
                    ..._comments.map((comment) {
                      final commentId = parseModelString(comment['id']);
                      final userId = parseModelString(comment['user_id']);
                      final userNickname =
                          parseModelString(comment['user_nickname']);
                      final userRemark =
                          parseModelString(comment['user_remark']);
                      final commentDisplayName = resolveMomentDisplayName(
                        remark: userRemark,
                        nickname: userNickname,
                        uid: userId,
                      );
                      final commentContent = parseModelString(
                        comment['content'],
                      );
                      final replyToUid = extractCommentReplyTarget(comment);
                      final replyToName = replyToUid.isEmpty
                          ? ''
                          : resolveMomentDisplayName(
                              remark: parseModelString(
                                comment['reply_to_remark'],
                              ),
                              nickname: parseModelString(
                                comment['reply_to_nickname'],
                              ),
                              uid: replyToUid,
                            );
                      final subtitleText = composeReplyDisplay(
                        content: commentContent,
                        replyToName: replyToName == '?' ? '' : replyToName,
                        prefix: context.t.momentsReplyPrefix,
                        separator: context.t.momentsReplySeparator,
                      );
                      final canRemoveComment = canDeleteComment(
                        comment,
                        post,
                        currentUid: currentUid,
                      );
                      final canReply =
                          currentUid.isNotEmpty && userId != currentUid;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: canReply ? () => _startReplyTo(comment) : null,
                        title: Text(commentDisplayName),
                        subtitle: Text(subtitleText),
                        trailing: canRemoveComment
                            ? IconButton(
                                onPressed: () => _deleteComment(commentId),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                              )
                            : null,
                      );
                    }),
                  if (_commentsHasMore)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: _loadingMoreComments
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : TextButton(
                                onPressed: _loadMoreComments,
                                child: Text(context.t.momentsLoadMoreComments),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyToUid.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.t.momentsReplyingTo
                                .replaceAll('{name}', _replyToName),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        InkWell(
                          onTap: _cancelReply,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: context.t.momentsWriteComment,
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _sendingComment ? null : _addComment,
                        child: _sendingComment
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(context.t.momentsSend),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
