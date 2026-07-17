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
import 'package:share_plus/share_plus.dart';
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
  // 点赞防抖：请求 in-flight 标志（避免快速双击 like/unlike 乱序）
  bool _isLiking = false;
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
    } on Exception catch (_) {
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
    } on Exception catch (_) {
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
    // 防抖：点赞请求 in-flight 期间忽略重复点击，避免快速双击 like/unlike
    // 乱序导致本地与服务端最终状态不一致。
    if (_isLiking) return;
    final momentId = parseModelString(post['id']);
    if (momentId.isEmpty) return;
    final liked = parseModelBool(post['liked']);
    HapticFeedback.lightImpact();
    final oldMoment = post;
    _isLiking = true;
    setState(() => _moment = applyOptimisticLikeToggle(post));
    try {
      final ok = liked
          ? await _api.unlikePost(momentId)
          : await _api.likePost(momentId);
      if (!ok && mounted) setState(() => _moment = oldMoment);
    } on Exception catch (_) {
      if (mounted) setState(() => _moment = oldMoment);
    } finally {
      _isLiking = false;
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
    // 通知 feed 刷新以带回最新 comments_preview；详情页自身忽略该 action
    // （见 shouldRefreshDetailOnEvent），不会触发白刷。
    AppEventBus.fire(
      MomentTimelineChangedEvent(
        action: momentActionCommentChanged,
        momentId: widget.momentId,
        payload: const <String, dynamic>{},
      ),
    );
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
    // 同 _addComment：让 feed 拉回最新 comments_preview
    AppEventBus.fire(
      MomentTimelineChangedEvent(
        action: momentActionCommentChanged,
        momentId: widget.momentId,
        payload: const <String, dynamic>{},
      ),
    );
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
          // 分享（系统分享面板，走 share_plus，参考 profile_page 既有用法）。
          // 注：应用内"转发到聊天"依赖 lib/page/chat/send_to/SendToPage(msg: Message)，
          // 要求一个真实的 flutter_chat_core Message 实例；朋友圈动态是纯 REST Map，
          // 与聊天消息领域模型无关，构造一个"假消息"塞进去超出本次改动范围，
          // 故此处仅接系统分享，不臆造转发到聊天入口。
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              _shareMoment();
            },
            child: Text(t.common.share),
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

  /// 系统分享面板分享动态文字内容（对齐 profile_page._shareProfile 的用法）。
  Future<void> _shareMoment() async {
    final post = _moment;
    if (post == null) return;
    final displayName = resolveMomentDisplayName(
      remark: parseModelString(post['author_remark']),
      nickname: parseModelString(post['author_nickname']),
      uid: parseModelString(post['author_uid']),
    );
    final content = parseModelString(post['content']);
    final text = content.isEmpty ? displayName : '$displayName: $content';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } on Exception {
      if (mounted) AppLoading.showError(t.common.shareFailed);
    }
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
      slivers: [
        // 下拉刷新：详情页此前无刷新入口，改用 sliver 模式补齐
        CupertinoSliverRefreshControl(onRefresh: _loadAll),
        SliverToBoxAdapter(
          child: _buildPostContent(context, post, isDark, brightness),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (_comments.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.chat_bubble,
                      size: 44,
                      color: AppColors.iosGray.withValues(alpha: 0.3),
                    ),
                    AppSpacing.verticalSmall,
                    Text(
                      t.common.momentsNoComments,
                      style: context.textStyle(
                        FontSizeType.subheadline,
                        color: AppColors.iosGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          // ListView.builder 的 sliver 等价物：SliverList 按需惰性构建评论项，
          // 避免 Column+.map() 一次性构建整页评论（评论可分页累积到很长）。
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildCommentItem(
                  context,
                  _comments[index],
                  isDark,
                  currentUid,
                ),
                childCount: _comments.length,
              ),
            ),
          ),
        if (_commentsHasMore || _loadMoreCommentsError)
          SliverToBoxAdapter(
            child: Center(
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
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
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
      // 单视频按宽高比 letterbox（无元数据退化 16:9），与 feed 对齐
      return LayoutBuilder(
        builder: (context, constraints) {
          final videoSize = momentVideoDisplaySize(
            maxWidth: constraints.maxWidth,
            aspectRatio: mediaAspectRatio(media.first),
          );
          return _buildMediaItem(
            media.first,
            videoSize.width,
            const [],
            0,
            height: videoSize.height,
          );
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = momentGridLayout(
          count: media.length,
          maxWidth: constraints.maxWidth,
          spacing: AppSpacing.small,
        );
        // 限定行宽以实现 4 图 2×2（微信标准）；其余仍三列自然流式
        final rowWidth =
            layout.cellSize * layout.columns +
            AppSpacing.small * (layout.columns - 1);
        int imgIdx = 0;
        return SizedBox(
          width: rowWidth,
          child: Wrap(
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.small,
            children: media.map((m) {
              final isVideo = parseModelString(m['type']) == 'video';
              final idx = isVideo ? 0 : imgIdx++;
              return _buildMediaItem(
                m,
                layout.cellSize,
                isVideo ? const [] : imageUrls,
                idx,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildMediaItem(
    Map<String, dynamic> item,
    double size,
    List<String> imageUrls,
    int imageIndex, {
    // 单视频 letterbox 场景传入高度；为 null 时为正方形（网格 cell）
    double? height,
  }) {
    final previewUrl = pickMediaPreviewUrl(item);
    final isVideo = parseModelString(item['type']) == 'video';
    final durationMs = mediaDurationMs(item);
    final imageChild = Image(
      image: cachedImageProvider(previewUrl),
      fit: BoxFit.cover,
      // 加载中灰底占位（替代空白）
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(color: AppColors.iosGray.withValues(alpha: 0.08));
      },
      // 加载失败：居中破损图标（替代空白）
      errorBuilder: (_, _, _) => Center(
        child: Icon(CupertinoIcons.photo, size: 28, color: AppColors.iosGray3),
      ),
    );
    final child = Container(
      width: size,
      height: height ?? size,
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

  /// 单条评论卡片。
  ///
  /// 原实现是外层一个共享圆角容器包住整段 `Column`（评论多时须一次性
  /// 构建全部子节点）。改用 SliverList 惰性构建后，共享容器无法再包裹
  /// 动态子节点，故改为每条评论各自一张小卡片（bento 式分组），
  /// 视觉上仍保持圆角分组观感。
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: userId != currentUid ? () => _startReplyTo(comment) : null,
      onLongPress: () => _showCommentActionSheet(
        comment,
        canDeleteComment(comment, _moment!, currentUid: currentUid),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceGroupedTertiary
              : AppColors.lightSurfaceGrouped,
          borderRadius: AppRadius.borderRadiusMedium,
        ),
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
          // 回复条 AnimatedSize：出现/消失高度平滑过渡
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _replyToUid.isNotEmpty
                ? Padding(
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
                  )
                : const SizedBox.shrink(),
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
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      final img = info.image;
      final w = img.width.toDouble();
      final h = img.height.toDouble();
      if (h > 0 && mounted) {
        setState(() => _aspectRatio = w / h);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 图片流解析依赖 MediaQuery(devicePixelRatio/size)，必须在 didChangeDependencies
    // 而非 initState —— 否则 createLocalImageConfiguration 会在 initState 完成前访问
    // InheritedWidget，触发 dependOnInheritedWidgetOfExactType 断言（图片渲染成红框）。
    final url = pickMediaPreviewUrl(widget.item);
    if (url.isEmpty) return;
    final provider = cachedImageProvider(url);
    final newStream = provider.resolve(createLocalImageConfiguration(context));
    // 仅当流 key 变化时重挂监听，避免重复监听/泄漏。
    if (newStream.key != _imageStream?.key) {
      _imageStream?.removeListener(_listener);
      _imageStream = newStream;
      _imageStream!.addListener(_listener);
    }
  }

  @override
  void dispose() {
    _imageStream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = pickMediaPreviewUrl(widget.item);
    final availWidth = MediaQuery.sizeOf(context).width - 24 * 2;
    final maxHeight = MediaQuery.sizeOf(context).width * 0.7;
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
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: AppColors.iosGray.withValues(alpha: 0.08),
              );
            },
            errorBuilder: (_, _, _) => Center(
              child: Icon(
                CupertinoIcons.photo,
                size: 28,
                color: AppColors.iosGray3,
              ),
            ),
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
    final screenW = MediaQuery.sizeOf(context).width;

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
