import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/shimmer_box.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:go_router/go_router.dart';
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
import 'package:imboy/theme/default/font_types.dart';

import 'moment_confirm_dialog.dart';
import 'moment_interactions.dart';
import 'moment_utils.dart';

/// 朋友圈详情页面 - 对标微信朋友圈体验重构
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
  final FocusNode _commentFocusNode = FocusNode();

  static const int _commentsPageSize = 20;

  Map<String, dynamic>? _moment;
  List<Map<String, dynamic>> _comments = [];
  String? _commentsCursor;
  bool _commentsHasMore = false;
  bool _loading = true;
  bool _loadError = false;
  bool _sendingComment = false;
  bool _loadingMoreComments = false;
  bool _loadMoreCommentsError = false;

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
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = false;
    });
    try {
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
    } catch (_) {
      // 网络异常时必须解除 _loading，否则永久转圈无法恢复
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = true;
        });
      }
    }
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
    setState(() {
      _loadingMoreComments = true;
      _loadMoreCommentsError = false;
    });
    try {
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingMoreComments = false;
          _loadMoreCommentsError = true;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    final post = _moment;
    if (post == null) return;
    final momentId = parseModelString(post['id']);
    if (momentId.isEmpty) return;
    final liked = parseModelBool(post['liked']);
    HapticFeedback.lightImpact();
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
      AppLoading.showError(t.common.momentsDeleteFailed);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _commentFocusNode.requestFocus();
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
      AppLoading.showError(t.common.momentsCommentFailed);
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
      AppLoading.showError(t.common.momentsDeleteFailed);
      return;
    }
    setState(() {
      _comments = removeCommentById(_comments, commentId);
      final post = _moment;
      if (post != null) _moment = applyCommentCountDelta(post, -1);
    });
  }

  /// 评论长按菜单：复制文字 / 删除（本人或作者可见）。
  void _showCommentActionSheet(Map<String, dynamic> comment, bool canDelete) {
    final content = parseModelString(comment['content']);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          if (content.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                Clipboard.setData(ClipboardData(text: content));
                AppLoading.showSuccess(t.common.chatCopy);
              },
              child: Text(t.common.buttonCopy),
            ),
          if (canDelete)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteComment(parseModelString(comment['id']));
              },
              child: Text(t.discovery.momentActionDelete),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.discovery.momentActionCancel),
        ),
      ),
    );
  }

  void _showPostActionSheet(BuildContext context, bool canDeletePost) {
    final post = _moment;
    final liked = post != null && parseModelBool(post['liked']);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _toggleLike();
            },
            child: Text(
              liked
                  ? t.discovery.momentActionCancelLike
                  : t.discovery.momentActionLike,
            ),
          ),
          if (canDeletePost)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteMoment();
              },
              child: Text(t.discovery.momentActionDelete),
            )
          else
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                _showReportSheet();
              },
              child: Text(t.discovery.momentActionReport),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.discovery.momentActionCancel),
        ),
      ),
    );
  }

  void _showReportSheet() {
    final post = _moment;
    if (post == null) return;
    final momentId = parseModelString(post['id']);
    final options = <(String, String)>[
      ('spam', t.common.momentReportReasonSpam),
      ('harassment', t.common.momentReportReasonHarassment),
      ('porn', t.common.momentReportReasonPorn),
      ('fraud', t.common.momentReportReasonFraud),
      ('infringement', t.common.momentReportReasonInfringement),
      ('other', t.common.momentReportReasonOther),
    ];
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(t.common.momentReportReasonPrompt),
        actions: options
            .map(
              (o) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _submitReport(momentId, o.$1);
                },
                child: Text(o.$2),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.discovery.momentActionCancel),
        ),
      ),
    );
  }

  Future<void> _submitReport(String momentId, String reason) async {
    final ok = await _api.reportPost(momentId, reason: reason);
    if (!mounted) return;
    if (ok) {
      AppLoading.showSuccess(t.common.momentsReportSubmitted);
    } else {
      AppLoading.showError(t.common.momentsReportFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _moment;
    if (_loading) {
      return Scaffold(
        appBar: CupertinoNavigationBar(middle: Text(t.discovery.moments)),
        body: const _DetailSkeleton(),
      );
    }
    if (_loadError && post == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.wifi_exclamationmark,
                size: 48,
                color: AppColors.iosGray.withValues(alpha: 0.4),
              ),
              AppSpacing.verticalMedium,
              Text(
                t.common.loadError,
                style: context.textStyle(
                  FontSizeType.subheadline,
                  color: AppColors.iosGray,
                ),
              ),
              AppSpacing.verticalMedium,
              CupertinoButton.filled(
                onPressed: _loadAll,
                child: Text(t.common.buttonRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (post == null) {
      return Scaffold(
        body: Center(
          child: Text(
            t.common.momentsNotFound,
            style: context.textStyle(
              FontSizeType.subheadline,
              color: AppColors.iosGray,
            ),
          ),
        ),
      );
    }

    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final currentUid = currentUidOrEmpty();
    final canDeletePost = canDeleteMoment(post, currentUid);

    return IosPageTemplate(
      title: t.discovery.moments,
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => _showPostActionSheet(context, canDeletePost),
          child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
        ),
      ],
      bottomWidget: _buildCommentInput(context, isDark, brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostContent(context, post, isDark, brightness),
          const SizedBox(height: 8),
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  t.common.momentsNoComments,
                  style: context.textStyle(
                    FontSizeType.subheadline,
                    color: AppColors.iosGray,
                  ),
                ),
              ),
            )
          else
            _buildCommentsBlock(context, isDark, currentUid, brightness),
          if (_commentsHasMore || _loadMoreCommentsError)
            Center(
              child: CupertinoButton(
                onPressed: _loadingMoreComments ? null : _loadMoreComments,
                child: _loadingMoreComments
                    ? const CupertinoActivityIndicator(radius: 8)
                    : Text(
                        _loadMoreCommentsError
                            ? t.common.buttonRetry
                            : t.common.momentsLoadMoreComments,
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
    final stats = post['stats'] is Map
        ? Map<String, dynamic>.from(post['stats'] as Map)
        : const <String, dynamic>{};
    final likers = parseRecentLikers(post);
    final likeCount = parseModelInt(stats['like_count']);

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
              Avatar(
                imgUri: authorAvatar,
                width: 46,
                height: 46,
                heroTag: 'moment_avatar_${parseModelString(post['id'])}',
                onTap: () => context.push(
                  '/contact/people/${parseModelString(post['author_uid'])}'
                  '?scene=contact_page',
                ),
              ),
              AppSpacing.horizontalMedium,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 点作者名跳资料页（与头像一致）
                    GestureDetector(
                      onTap: () => context.push(
                        '/contact/people/${parseModelString(post['author_uid'])}'
                        '?scene=contact_page',
                      ),
                      child: Text(
                        displayName,
                        style: context.textStyle(
                          FontSizeType.body,
                          fontWeight: FontWeight.w600,
                          color: AppColors.wechatBlue,
                        ),
                      ),
                    ),
                    Text(
                      momentRelativeTime(parseModelString(post['created_at'])),
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
              padding: const EdgeInsets.only(top: 12),
              child: SelectableText(
                content,
                style: context
                    .textStyle(FontSizeType.medium)
                    .copyWith(height: 1.45),
              ),
            ),
          if (media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildMediaGrid(context, media),
            ),
          if (likeCount > 0 || likers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _MomentDetailLikersRow(
                likers: likers,
                totalCount: likeCount,
              ),
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
      if (!isVideo) {
        return _DetailSingleImage(
          item: media.first,
          imageUrls: imageUrls,
          imageIndex: 0,
        );
      }
      return _buildMediaItem(media.first, 240, const [], 0);
    }
    int imgIdx = 0;
    final cellSize = (MediaQuery.of(context).size.width - 64) / 3;
    return Wrap(
      spacing: AppSpacing.small,
      runSpacing: AppSpacing.small,
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
    final isVideo = parseModelString(item['type']) == 'video';
    final durationMs = mediaDurationMs(item);
    final imageChild = Image(
      image: cachedImageProvider(previewUrl),
      fit: BoxFit.cover,
    );
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderRadiusMedium,
        color: AppColors.iosGray.withValues(alpha: 0.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: isVideo
          ? Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: imageChild),
                const Icon(
                  CupertinoIcons.play_circle_fill,
                  color: AppColors.onPrimary,
                  size: 30,
                ),
                if (durationMs > 0)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _DetailVideoBadge(
                      text: formatVideoDuration(durationMs),
                    ),
                  ),
              ],
            )
          : imageChild,
    );
    if (imageUrls.isEmpty) return child;
    return GestureDetector(
      onTap: () =>
          zoomInPhotoViewGalleryWithInitialPage(context, imageUrls, imageIndex),
      child: child,
    );
  }

  Widget _buildCommentsBlock(
    BuildContext context,
    bool isDark,
    String currentUid,
    Brightness brightness,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurfaceGrouped,
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _comments
            .map((c) => _buildCommentItem(context, c, isDark, currentUid))
            .toList(),
      ),
    );
  }

  Widget _buildCommentItem(
    BuildContext context,
    Map<String, dynamic> comment,
    bool isDark,
    String currentUid,
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

    return InkWell(
      onTap: userId != currentUid ? () => _startReplyTo(comment) : null,
      onLongPress: () => _showCommentActionSheet(
        comment,
        canDeleteComment(comment, _moment!, currentUid: currentUid),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Avatar(
              imgUri: parseModelString(comment['user_avatar']),
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 点评论人名跳资料页
                  GestureDetector(
                    onTap: () => context.push(
                      '/contact/people/$userId?scene=contact_page',
                    ),
                    child: Text(
                      displayName,
                      style: context.textStyle(
                        FontSizeType.footnote,
                        fontWeight: FontWeight.w600,
                        color: AppColors.wechatBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _buildCommentBody(context, content, replyToName),
                ],
              ),
            ),
            if (canDeleteComment(comment, _moment!, currentUid: currentUid))
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _deleteComment(parseModelString(comment['id'])),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      CupertinoIcons.delete,
                      size: 15,
                      color: AppColors.iosGray,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentBody(
    BuildContext context,
    String content,
    String replyToName,
  ) {
    final trimmedReply = replyToName == '?' ? '' : replyToName;
    if (trimmedReply.isEmpty) {
      return SelectableText(
        content,
        style: context
            .textStyle(FontSizeType.subheadline)
            .copyWith(height: 1.35),
      );
    }
    return SelectableText.rich(
      TextSpan(
        style: context
            .textStyle(FontSizeType.subheadline)
            .copyWith(height: 1.35),
        children: [
          TextSpan(
            text:
                '${t.chat.momentsReplyPrefix}$trimmedReply'
                '${t.chat.momentsReplySeparator}',
            style: context.textStyle(
              FontSizeType.subheadline,
              color: AppColors.wechatBlue,
            ),
          ),
          TextSpan(text: content),
        ],
      ),
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
            width: 0.5,
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    child: Center(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _addComment(),
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
                ),
                AppSpacing.horizontalSmall,
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _commentController,
                  builder: (context, value, _) {
                    final canSend =
                        value.text.trim().isNotEmpty && !_sendingComment;
                    return CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: AppColors.getIosBlue(brightness),
                      borderRadius: BorderRadius.circular(20),
                      onPressed: canSend ? _addComment : null,
                      child: _sendingComment
                          ? const CupertinoActivityIndicator(
                              radius: 8,
                              color: AppColors.onPrimary,
                            )
                          : Text(
                              t.chat.momentsSend,
                              style: context.textStyle(
                                FontSizeType.normal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 详情页点赞人横排。
class _MomentDetailLikersRow extends StatelessWidget {
  final List<Map<String, dynamic>> likers;
  final int totalCount;

  const _MomentDetailLikersRow({
    required this.likers,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = buildLikersLabel(likers, totalCount, translations: context.t);
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurfaceGrouped,
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnimatedHeart(count: totalCount, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.wechatBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 详情页点赞心形：点赞数增加时弹跳（带 size 参数）。
class _AnimatedHeart extends StatefulWidget {
  final int count;
  final double size;
  const _AnimatedHeart({required this.count, required this.size});

  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  int _prevCount = 0;

  @override
  void initState() {
    super.initState();
    _prevCount = widget.count;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(_AnimatedHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > _prevCount) {
      _controller.forward(from: 0);
    }
    _prevCount = widget.count;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Icon(
        CupertinoIcons.heart_fill,
        size: widget.size,
        color: AppColors.wechatBlue,
      ),
    );
  }
}

/// 详情页视频时长角标。
class _DetailVideoBadge extends StatelessWidget {
  final String text;
  const _DetailVideoBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.darkBackground.withValues(alpha: 0.5),
        borderRadius: AppRadius.borderRadiusTiny,
      ),
      child: Text(
        text,
        style: context
            .textStyle(
              FontSizeType.tiny,
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w500,
            )
            .copyWith(height: 1.2),
      ),
    );
  }
}

/// 详情页单图按真实宽高比展示。
class _DetailSingleImage extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<String> imageUrls;
  final int imageIndex;

  const _DetailSingleImage({
    required this.item,
    required this.imageUrls,
    required this.imageIndex,
  });

  @override
  State<_DetailSingleImage> createState() => _DetailSingleImageState();
}

class _DetailSingleImageState extends State<_DetailSingleImage> {
  double? _aspectRatio;
  ImageStream? _imageStream;
  late ImageStreamListener _listener;

  @override
  void initState() {
    super.initState();
    final url = pickMediaPreviewUrl(widget.item);
    if (url.isEmpty) return;
    final provider = cachedImageProvider(url);
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final img = info.image;
      final w = img.width.toDouble();
      final h = img.height.toDouble();
      if (h > 0 && mounted) {
        setState(() => _aspectRatio = w / h);
      }
    });
    _imageStream = provider.resolve(createLocalImageConfiguration(context));
    _imageStream!.addListener(_listener);
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = pickMediaPreviewUrl(widget.item);
    final availWidth = MediaQuery.of(context).size.width - 24 * 2;
    final maxHeight = MediaQuery.of(context).size.width * 0.7;
    final aspect = _aspectRatio ?? 4 / 3;
    var displayWidth = availWidth;
    var displayHeight = displayWidth / aspect;
    if (displayHeight > maxHeight) {
      displayHeight = maxHeight;
      displayWidth = displayHeight * aspect;
    }

    return GestureDetector(
      onTap: widget.imageUrls.isNotEmpty
          ? () => zoomInPhotoViewGalleryWithInitialPage(
              context,
              widget.imageUrls,
              widget.imageIndex,
            )
          : null,
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusMedium,
        child: Container(
          width: displayWidth,
          height: displayHeight,
          color: AppColors.iosGray.withValues(alpha: 0.1),
          child: Image(
            image: cachedImageProvider(url),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
          ),
        ),
      ),
    );
  }
}

/// 详情页加载骨架屏。
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  Widget _bar(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.mediaScrimWhite,
      borderRadius: AppRadius.borderRadiusTiny,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final base = colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final highlight = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.2,
    );
    final screenW = MediaQuery.of(context).size.width;

    return ShimmerBox(
      baseColor: base,
      highlightColor: highlight,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: AppSpacing.allLarge,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.mediaScrimWhite,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(120, 14),
                    const SizedBox(height: 8),
                    _bar(70, 11),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _bar(screenW * 0.9, 14),
          const SizedBox(height: 10),
          _bar(screenW * 0.75, 14),
          const SizedBox(height: 10),
          _bar(screenW * 0.5, 14),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: screenW * 0.45,
            decoration: BoxDecoration(
              color: AppColors.mediaScrimWhite,
              borderRadius: AppRadius.borderRadiusMedium,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.mediaScrimWhite,
              borderRadius: AppRadius.borderRadiusMedium,
            ),
            child: Column(
              children: List.generate(3, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.iosGray,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bar(90, 12),
                            const SizedBox(height: 6),
                            _bar(screenW * 0.6, 13),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
