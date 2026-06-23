import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart'
    show zoomInPhotoViewGalleryWithInitialPage;
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/moment_social/application/moment_facade.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'moment_confirm_dialog.dart';
import 'moment_interactions.dart';
import 'moment_utils.dart';

/// 朋友圈详情页面 - 极致 iOS 17 Premium 风格重构
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

  String _replyToUid = '';
  String _replyToName = '';

  StreamSubscription<MomentTimelineChangedEvent>? _momentSub;

  @override
  void initState() {
    super.initState();
    _momentSub = AppEventBus.on<MomentTimelineChangedEvent>().listen((event) {
      if (shouldRefreshDetailOnEvent(
        action: event.action,
        eventMomentId: event.momentId,
        viewingMomentId: widget.momentId,
      )) {
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

    final enrichedPost = rawPost != null
        ? await enrichPostWithAuthor(rawPost)
        : null;
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
    if (!canLoadMoreComments(
      isLoading: _loadingMoreComments,
      hasMore: _commentsHasMore,
      cursor: _commentsCursor,
    )) {
      return;
    }
    final cursor = _commentsCursor!;
    setState(() => _loadingMoreComments = true);
    final page = await _api.listComments(
      widget.momentId,
      cursor: cursor,
      limit: _commentsPageSize,
    );
    if (!mounted) return;
    final enriched = await enrichCommentsWithUser(page.list);
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
    final oldMoment = post;
    setState(() => _moment = applyOptimisticLikeToggle(post));
    try {
      final ok = liked
          ? await _api.unlikePost(momentId)
          : await _api.likePost(momentId);
      if (!ok && mounted) setState(() => _moment = oldMoment);
    } catch (_) {
      if (mounted) setState(() => _moment = oldMoment);
    }
  }

  Future<void> _deleteMoment() async {
    final post = _moment;
    if (post == null) return;
    final momentId = parseModelString(post['id']);
    if (momentId.isEmpty) return;
    final confirmed = await showMomentConfirmDialog(
      context,
      title: t.common.delete,
      message: t.common.momentsDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await _api.deletePost(momentId);
    if (!mounted) return;
    if (!ok) {
      EasyLoading.showError(t.common.momentsDeleteFailed);
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
    final target = buildReplyTarget(comment);
    if (target.isNone) return;
    setState(() {
      _replyToUid = target.uid;
      _replyToName = target.name;
    });
  }

  void _cancelReply() => setState(() {
    _replyToUid = '';
    _replyToName = '';
  });

  Future<void> _addComment() async {
    if (_sendingComment) return;
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    setState(() => _sendingComment = true);
    final added = await _api.addComment(
      widget.momentId,
      content: content,
      replyToUid: _replyToUid.isEmpty ? null : _replyToUid,
      mentions: extractMentions(content).map((m) => m.name).toList(),
    );
    if (added == null) {
      if (mounted) setState(() => _sendingComment = false);
      EasyLoading.showError(t.common.momentsCommentFailed);
      return;
    }
    _commentController.clear();
    final list = await enrichCommentsWithUser([added]);
    if (!mounted) return;
    setState(() {
      _sendingComment = false;
      _comments = [list.first, ..._comments];
      _replyToUid = '';
      _replyToName = '';
      final post = _moment;
      if (post != null) _moment = applyCommentCountDelta(post, 1);
    });
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showMomentConfirmDialog(
      context,
      title: t.common.delete,
      message: t.common.momentsDeleteCommentConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await _api.deleteComment(widget.momentId, commentId);
    if (!mounted) return;
    if (!ok) {
      EasyLoading.showError(t.common.momentsDeleteFailed);
      return;
    }
    setState(() {
      _comments = removeCommentById(_comments, commentId);
      final post = _moment;
      if (post != null) _moment = applyCommentCountDelta(post, -1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = _moment;
    if (_loading) {
      return const Scaffold(body: Center(child: CupertinoActivityIndicator()));
    }
    if (post == null) {
      return Scaffold(body: Center(child: Text(t.common.momentsNotFound)));
    }

    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final currentUid = currentUidOrEmpty();
    final canDeletePost = canDeleteMoment(post, currentUid);

    return IosPageTemplate(
      title: t.discovery.moments,
      useLargeTitle: false,
      actions: [
        if (canDeletePost)
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _deleteMoment,
            child: const Icon(CupertinoIcons.delete, size: 20),
          )
        else
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {},
            child: const Icon(CupertinoIcons.flag, size: 20),
          ),
      ],
      bottomWidget: _buildCommentInput(context, isDark, brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostContent(context, post, isDark, brightness),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              t.discovery.momentsComments,
              style: context.textStyle(
                FontSizeType.footnote,
                fontWeight: FontWeight.w600,
                color: AppColors.iosGray,
              ),
            ),
          ),
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  t.common.momentsNoComments,
                  style: const TextStyle(color: AppColors.iosGray),
                ),
              ),
            )
          else
            ImBoySettingsSection(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              children: _comments
                  .map(
                    (c) => _buildCommentItem(
                      context,
                      c,
                      isDark,
                      currentUid,
                      brightness,
                    ),
                  )
                  .toList(),
            ),
          if (_commentsHasMore)
            Center(
              child: CupertinoButton(
                onPressed: _loadMoreComments,
                child: _loadingMoreComments
                    ? const CupertinoActivityIndicator(radius: 8)
                    : Text(
                        t.common.momentsLoadMoreComments,
                        style: context.textStyle(FontSizeType.normal),
                      ),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildPostContent(
    BuildContext context,
    Map<String, dynamic> post,
    bool isDark,
    Brightness brightness,
  ) {
    final authorAvatar = parseModelString(post['author_avatar']);
    final displayName = resolveMomentDisplayName(
      remark: parseModelString(post['author_remark']),
      nickname: parseModelString(post['author_nickname']),
      uid: parseModelString(post['author_uid']),
    );
    final content = parseModelString(post['content']);
    final media = normalizeMedia(post['media']);
    final liked = parseModelBool(post['liked']);
    final stats = post['stats'] is Map
        ? Map<String, dynamic>.from(post['stats'] as Map)
        : const <String, dynamic>{};

    return Container(
      width: double.infinity,
      padding: AppSpacing.allLarge,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.getIosSeparator(brightness).withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(imgUri: authorAvatar, width: 48, height: 48),
              AppSpacing.horizontalMedium,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: context.textStyle(
                        FontSizeType.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      parseModelString(post['created_at']),
                      style: context.textStyle(
                        FontSizeType.footnote,
                        color: AppColors.iosGray,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                content,
                style: context
                    .textStyle(FontSizeType.medium)
                    .copyWith(height: 1.4),
              ),
            ),
          if (media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _buildMediaGrid(context, media),
            ),
          AppSpacing.verticalLarge,
          Row(
            children: [
              _buildInteraction(
                CupertinoIcons.heart,
                liked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                formatMomentCountLabel(parseModelInt(stats['like_count'])),
                liked ? AppColors.iosRed : AppColors.iosGray,
                _toggleLike,
              ),
              AppSpacing.horizontalXLarge,
              _buildInteraction(
                CupertinoIcons.chat_bubble,
                CupertinoIcons.chat_bubble,
                formatMomentCountLabel(parseModelInt(stats['comment_count'])),
                AppColors.iosGray,
                () => FocusScope.of(context).requestFocus(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid(
    BuildContext context,
    List<Map<String, dynamic>> media,
  ) {
    final imageUrls = media
        .where((m) => parseModelString(m['type']) != 'video')
        .map(pickMediaPreviewUrl)
        .where((u) => u.isNotEmpty)
        .toList();
    if (media.length == 1) {
      final isVideo = parseModelString(media.first['type']) == 'video';
      return _buildMediaItem(
        media.first,
        240,
        isVideo ? const [] : imageUrls,
        0,
      );
    }
    int imgIdx = 0;
    final cellSize = (MediaQuery.of(context).size.width - 64) / 3;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: media.map((m) {
        final isVideo = parseModelString(m['type']) == 'video';
        final idx = isVideo ? 0 : imgIdx++;
        return _buildMediaItem(
          m,
          cellSize,
          isVideo ? const [] : imageUrls,
          idx,
        );
      }).toList(),
    );
  }

  Widget _buildMediaItem(
    Map<String, dynamic> item,
    double size,
    List<String> imageUrls,
    int imageIndex,
  ) {
    final previewUrl = pickMediaPreviewUrl(item);
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.iosGray.withValues(alpha: 0.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image(image: cachedImageProvider(previewUrl), fit: BoxFit.cover),
    );
    if (imageUrls.isEmpty) return child;
    return GestureDetector(
      onTap: () =>
          zoomInPhotoViewGalleryWithInitialPage(context, imageUrls, imageIndex),
      child: child,
    );
  }

  Widget _buildInteraction(
    IconData icon,
    IconData activeIcon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(label == '0' ? icon : activeIcon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: context.textStyle(
              FontSizeType.normal,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(
    BuildContext context,
    Map<String, dynamic> comment,
    bool isDark,
    String currentUid,
    Brightness brightness,
  ) {
    final userId = parseModelString(comment['user_id']);
    final displayName = resolveMomentDisplayName(
      remark: parseModelString(comment['user_remark']),
      nickname: parseModelString(comment['user_nickname']),
      uid: userId,
    );
    final content = parseModelString(comment['content']);
    final replyToUid = extractCommentReplyTarget(comment);
    final replyToName = replyToUid.isEmpty
        ? ''
        : resolveMomentDisplayName(
            remark: parseModelString(comment['reply_to_remark']),
            nickname: parseModelString(comment['reply_to_nickname']),
            uid: replyToUid,
          );
    final subtitleText = composeReplyDisplay(
      content: content,
      replyToName: replyToName == '?' ? '' : replyToName,
      prefix: t.chat.momentsReplyPrefix,
      separator: t.chat.momentsReplySeparator,
    );

    return ImBoyListTile(
      onTap: userId != currentUid ? () => _startReplyTo(comment) : null,
      leading: Avatar(
        imgUri: parseModelString(comment['user_avatar']),
        width: 36,
        height: 36,
      ),
      title: Text(
        displayName,
        style: context.textStyle(
          FontSizeType.subheadline,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitleText,
        style: context.textStyle(FontSizeType.normal).copyWith(height: 1.3),
      ),
      trailing: canDeleteComment(comment, _moment!, currentUid: currentUid)
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(
                CupertinoIcons.delete,
                size: 16,
                color: AppColors.iosGray,
              ),
              onPressed: () => _deleteComment(parseModelString(comment['id'])),
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildCommentInput(
    BuildContext context,
    bool isDark,
    Brightness brightness,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: AppColors.getIosSeparator(brightness).withValues(alpha: 0.3),
            width: 0.33,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyToUid.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.chat.momentsReplyingTo.replaceAll(
                        '{name}',
                        _replyToName,
                      ),
                      style: context.textStyle(
                        FontSizeType.small,
                        color: AppColors.iosGray,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 16,
                      color: AppColors.iosGray,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.iosGray.withValues(alpha: 0.05)
                        : AppColors.lightSurfaceGrouped,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: t.discovery.momentsWriteComment,
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: context.textStyle(
                        FontSizeType.subheadline,
                        color: AppColors.iosGray,
                      ),
                    ),
                    style: context.textStyle(FontSizeType.subheadline),
                  ),
                ),
              ),
              AppSpacing.horizontalSmall,
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: AppColors.getIosBlue(brightness),
                borderRadius: BorderRadius.circular(20),
                onPressed: _sendingComment ? null : _addComment,
                child: _sendingComment
                    ? const CupertinoActivityIndicator(
                        radius: 8,
                        color: AppColors.onPrimary,
                      )
                    : Text(
                        t.chat.momentsSend,
                        style: TextStyle(
                          fontSize: FontSizeType.normal.size,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
