import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/chat/composer_field.dart';
import 'package:imboy/component/helper/func.dart'
    show cachedImageProvider, iPrint;
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_comment_tile.dart';
import 'package:imboy/page/moment/moment_utils.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/channel_comment_model.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 频道沉浸式全屏阅读页（订阅号消费模型中心件）
///
/// 把频道内容从「点进只看一条聊天卡」升级为「点击卡片 → 全屏沉浸阅读」：
/// - 顶部一次性展示作者/频道信息（不像 feed 每卡重复）
/// - 完整正文（不折叠）+ 图片/图文九宫格 / 视频
/// - 内联评论列表（复用 [ChannelCommentTile]），不再跳独立评论页
/// - 底部固定操作栏（赞/评论/转发）+ 常驻评论输入
class ChannelArticlePage extends ConsumerStatefulWidget {
  final String channelId;

  /// 经 route extra 传入的消息；深链/重启导致 extra 丢失时为空，页面降级为空态。
  final ChannelMessageModel? message;

  const ChannelArticlePage({
    super.key,
    required this.channelId,
    required this.message,
  });

  @override
  ConsumerState<ChannelArticlePage> createState() => _ChannelArticlePageState();
}

class _ChannelArticlePageState extends ConsumerState<ChannelArticlePage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  static const int _pageSize = 20;

  List<ChannelCommentModel> _comments = [];
  bool _isLoadingComments = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _isSending = false;
  String? _loadError;
  int _replyToCommentId = 0;
  String _replyToName = '';

  // 点赞本地状态：与 ChannelMessageItem 同一 _likeDelta 模式，
  // 让底栏计数即时反映操作（消息本身不随点赞实时刷新）。
  bool _liked = false;
  int _likeDelta = 0;

  @override
  void initState() {
    super.initState();
    _liked =
        widget.message?.myReactions.contains(ChannelReactionType.like) ?? false;
    _scrollController.addListener(_onScroll);
    if (widget.message != null) {
      _loadComments();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent - pos.pixels <= 200) {
      _loadMoreComments();
    }
  }

  // ---- 评论数据 ----

  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
      _loadError = null;
    });
    try {
      final comments = await ref
          .read(channelServiceProvider)
          .getComments(
            channelId: widget.channelId,
            messageId: widget.message!.id.toString(),
            cursor: 0,
            limit: _pageSize,
          );
      if (mounted) {
        setState(() {
          _comments = comments;
          _hasMore = comments.length >= _pageSize;
          _isLoadingComments = false;
        });
      }
    } on Exception catch (e) {
      iPrint('阅读页评论加载失败: $e');
      if (mounted) {
        setState(() {
          _loadError = t.common.loadError;
          _isLoadingComments = false;
        });
      }
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMore || _isLoadingComments) return;
    _isLoadingMore = true;
    try {
      final more = await ref
          .read(channelServiceProvider)
          .getComments(
            channelId: widget.channelId,
            messageId: widget.message!.id.toString(),
            cursor: _comments.length,
            limit: _pageSize,
          );
      if (mounted) {
        setState(() {
          _comments = [..._comments, ...more];
          _hasMore = more.length >= _pageSize;
        });
      }
    } on Exception catch (e) {
      iPrint('阅读页评论加载更多失败: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> _sendComment() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final comment = await ref
          .read(channelServiceProvider)
          .createComment(
            channelId: widget.channelId,
            messageId: widget.message!.id.toString(),
            content: content,
            parentId: _replyToCommentId,
          );
      if (comment != null && mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _comments = [..._comments, comment];
          _replyToCommentId = 0;
          _replyToName = '';
        });
        _inputController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else if (mounted) {
        AppLoading.showError(context.t.channel.commentFailed);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startReply(ChannelCommentModel comment) {
    HapticFeedback.selectionClick();
    setState(() {
      _replyToCommentId = comment.id;
      _replyToName = comment.userName;
    });
    _inputFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = 0;
      _replyToName = '';
    });
  }

  Future<void> _toggleCommentLike(ChannelCommentModel comment) async {
    HapticFeedback.lightImpact();
    final bool willLike = !comment.isLiked;
    final commentId = comment.id.toString();
    final service = ref.read(channelServiceProvider);
    final success = willLike
        ? await service.likeComment(
            channelId: widget.channelId,
            commentId: commentId,
          )
        : await service.unlikeComment(
            channelId: widget.channelId,
            commentId: commentId,
          );
    if (success && mounted) {
      setState(() {
        final idx = _comments.indexWhere((c) => c.id == comment.id);
        if (idx >= 0) {
          final int nextCount = willLike
              ? _comments[idx].likeCount + 1
              : (_comments[idx].likeCount - 1).clamp(0, 1 << 31);
          _comments[idx] = _comments[idx].copyWith(
            isLiked: willLike,
            likeCount: nextCount,
          );
        }
      });
    }
  }

  Future<void> _deleteComment(ChannelCommentModel comment) async {
    final currentUid = int.tryParse(UserRepoLocal.to.currentUid) ?? 0;
    if (comment.userId != currentUid) {
      AppLoading.showToast(context.t.channel.commentDeleteNoPermission);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t.channel.deleteComment),
        content: Text(context.t.channel.deleteCommentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.iosRed),
            child: Text(context.t.common.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await ref
        .read(channelServiceProvider)
        .deleteComment(
          channelId: widget.channelId,
          commentId: comment.id.toString(),
        );
    if (success && mounted) {
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
    }
  }

  // ---- 消息点赞（底部操作栏）----

  Future<void> _toggleMessageLike() async {
    HapticFeedback.lightImpact();
    final service = ref.read(channelServiceProvider);
    final messageId = widget.message!.id.toString();
    final willLike = !_liked;
    final success = willLike
        ? await service.addReaction(
            channelId: widget.channelId,
            messageId: messageId,
            reactionType: ChannelReactionType.like,
          )
        : await service.removeReaction(
            channelId: widget.channelId,
            messageId: messageId,
            reactionType: ChannelReactionType.like,
          );
    if (success && mounted) {
      setState(() {
        _liked = willLike;
        _likeDelta += willLike ? 1 : -1;
      });
    }
  }

  void _shareMessage() {
    final t = context.t;
    final message = widget.message!;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(t.channel.share),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.contentPreview));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.main.copiedToClipboard)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.send),
              title: Text(t.channel.shareToChat),
              onTap: () {
                Navigator.pop(ctx);
                context.push(
                  '/chat/send_to',
                  extra: {
                    'msg': {
                      'msg_type': 'channel_message',
                      'content': message.contentPreview,
                      'payload': {
                        'channel_id': widget.channelId,
                        'message_id': message.id,
                      },
                    },
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- 构建 ----

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final channel = ref.watch(channelDetailProvider).channel;
    final title = channel?.name ?? t.channel.title;

    if (widget.message == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: NoDataView(
          icon: Icons.article_outlined,
          text: t.common.loadError,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(child: _buildAuthorHeader(channel?.name)),
                SliverToBoxAdapter(child: _buildBody()),
                SliverToBoxAdapter(child: _buildCommentHeader()),
                ..._buildCommentSlivers(),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.large),
                ),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildAuthorHeader(String? channelName) {
    final message = widget.message!;
    final secondary = AppColors.getTextColor(
      Theme.of(context).brightness,
      isSecondary: true,
    );
    final hasAvatar =
        message.authorAvatar != null && message.authorAvatar!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.regular,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: hasAvatar
                ? cachedImageProvider(message.authorAvatar!, w: 64)
                : null,
            child: !hasAvatar
                ? Text(
                    (message.authorName ?? channelName ?? '?').isNotEmpty
                        ? (message.authorName ?? channelName ?? '?')[0]
                              .toUpperCase()
                        : '?',
                    style: context.textStyle(FontSizeType.normal),
                  )
                : null,
          ),
          AppSpacing.horizontalSmall,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.authorName ?? channelName ?? '',
                  style: context.textStyle(
                    FontSizeType.subheadline,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                AppSpacing.verticalTiny,
                Row(
                  children: [
                    Text(
                      channelRelativeTime(context, message.createdAt),
                      style: context.textStyle(
                        FontSizeType.caption2,
                        color: secondary,
                      ),
                    ),
                    if (message.viewCount > 0) ...[
                      AppSpacing.horizontalSmall,
                      Icon(
                        Icons.remove_red_eye_outlined,
                        size: 13,
                        color: secondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${message.viewCount} ${context.t.channel.views}',
                        style: context.textStyle(
                          FontSizeType.caption2,
                          color: secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 正文 + 媒体（完整不折叠）。
  Widget _buildBody() {
    final message = widget.message!;
    final textColor = AppColors.getTextColor(Theme.of(context).brightness);
    final hasText = message.content.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasText)
            SelectableText(
              message.content,
              style: TextStyle(
                fontSize: FontSizeType.body.size,
                height: 1.5,
                color: textColor,
              ),
            ),
          _buildMedia(),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    final message = widget.message!;
    switch (message.msgType) {
      case ChannelMessageType.imageText:
      case 'imageText':
        return _buildImageGrid();
      case ChannelMessageType.image:
      case 'image':
        return _buildSingleImage();
      case ChannelMessageType.video:
      case 'video':
        return _buildVideo();
      default:
        return const SizedBox.shrink();
    }
  }

  List<Map<String, dynamic>> _imageTextItems() {
    final raw = widget.message!.payload?['images'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['uri']?.toString() ?? '').isNotEmpty)
        .toList(growable: false);
  }

  Widget _buildImageGrid() {
    final images = _imageTextItems();
    if (images.isEmpty) return const SizedBox.shrink();
    final uris = [for (final e in images) e['uri'].toString()];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.small),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 4.0;
          final layout = momentGridLayout(
            count: images.length,
            maxWidth: constraints.maxWidth,
            spacing: spacing,
          );
          final cell = layout.cellSize;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var i = 0; i < uris.length; i++)
                GestureDetector(
                  onTap: () =>
                      zoomInPhotoViewGalleryWithInitialPage(context, uris, i),
                  child: ClipRRect(
                    borderRadius: AppRadius.borderRadiusSmall,
                    child: Image(
                      image: cachedImageProvider(uris[i], w: 400),
                      width: cell,
                      height: cell,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSingleImage() {
    final uri = widget.message!.payload?['uri'] as String?;
    if (uri == null || uri.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.small),
      child: GestureDetector(
        onTap: () => zoomInPhotoView(context, uri),
        child: ClipRRect(
          borderRadius: AppRadius.borderRadiusSmall,
          child: Image(
            image: cachedImageProvider(uri, w: 600),
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final payload = widget.message!.payload;
    String? thumb;
    final dynamic thumbRaw = payload?['thumb'];
    if (thumbRaw is String) {
      thumb = thumbRaw;
    } else if (thumbRaw is Map) {
      thumb = thumbRaw['uri']?.toString();
    }
    final videoUri = payload?['uri'] as String?;
    if (videoUri == null || videoUri.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.small),
      child: GestureDetector(
        onTap: () {
          context.push(
            '/video_viewer?url=${Uri.encodeComponent(videoUri)}&thumb=${Uri.encodeComponent(thumb ?? '')}',
          );
        },
        child: ClipRRect(
          borderRadius: AppRadius.borderRadiusSmall,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (thumb != null && thumb.isNotEmpty)
                Image(
                  image: cachedImageProvider(thumb, w: 600),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: MediaQuery.of(context).size.width * 0.56,
                )
              else
                Container(
                  width: double.infinity,
                  height: 200,
                  color: AppColors.getIosSeparator(
                    Theme.of(context).brightness,
                  ).withValues(alpha: 0.12),
                ),
              Container(
                padding: AppSpacing.allMedium,
                decoration: BoxDecoration(
                  color: AppColors.mediaScrimBlack.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: AppColors.mediaScrimWhite,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentHeader() {
    final secondary = AppColors.getTextColor(
      Theme.of(context).brightness,
      isSecondary: true,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.regular,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: AppColors.getIosSeparator(Theme.of(context).brightness),
          ),
          AppSpacing.verticalSmall,
          Text(
            '${context.t.channel.comment} (${_comments.length})',
            style: context.textStyle(
              FontSizeType.subheadline,
              fontWeight: FontWeight.w600,
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCommentSlivers() {
    if (_isLoadingComments) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.large),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (_loadError != null) {
      return [
        SliverToBoxAdapter(
          child: NoDataView(
            icon: Icons.cloud_off_outlined,
            text: context.t.common.loadError,
            onTop: _loadComments,
          ),
        ),
      ];
    }
    if (_comments.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.large),
            child: NoDataView(
              icon: Icons.chat_bubble_outline,
              text: context.t.channel.noComments,
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: AppSpacing.allSmall,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final comment = _comments[index];
            return ChannelCommentTile(
              comment: comment,
              onReply: () => _startReply(comment),
              onToggleLike: () => _toggleCommentLike(comment),
              onDelete: () => _deleteComment(comment),
            );
          }, childCount: _comments.length),
        ),
      ),
    ];
  }

  Widget _buildBottomBar() {
    final t = context.t;
    final message = widget.message!;
    final secondary = AppColors.getTextColor(
      Theme.of(context).brightness,
      isSecondary: true,
    );

    int totalReactions = 0;
    if (message.reactionSummary != null) {
      totalReactions = message.reactionSummary!.values.fold(0, (a, b) => a + b);
    }
    totalReactions = (totalReactions + _likeDelta).clamp(0, 1 << 31);

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.regular,
        right: AppSpacing.regular,
        top: AppSpacing.small,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.small,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.getIosSeparator(Theme.of(context).brightness),
          ),
        ),
      ),
      child: Column(
        children: [
          // 操作栏：赞 / 评论 / 转发
          Row(
            children: [
              _actionButton(
                icon: _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                label: totalReactions > 0 ? '$totalReactions' : t.channel.like,
                color: _liked ? AppColors.primary : secondary,
                onTap: _toggleMessageLike,
              ),
              AppSpacing.horizontalRegular,
              _actionButton(
                icon: Icons.chat_bubble_outline,
                label: _comments.isNotEmpty
                    ? '${_comments.length}'
                    : t.channel.comment,
                color: secondary,
                onTap: () => _inputFocusNode.requestFocus(),
              ),
              AppSpacing.horizontalRegular,
              _actionButton(
                icon: Icons.share_outlined,
                label: t.channel.share,
                color: secondary,
                onTap: _shareMessage,
              ),
            ],
          ),
          // 回复引用条
          if (_replyToCommentId > 0)
            Container(
              padding: AppSpacing.allSmall,
              margin: const EdgeInsets.only(top: AppSpacing.small),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: AppRadius.borderRadiusSmall,
              ),
              child: Row(
                children: [
                  Text(
                    '${t.channel.replyTo}: $_replyToName',
                    style: context.textStyle(
                      FontSizeType.small,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.iosGray,
                    ),
                  ),
                ],
              ),
            ),
          // 评论输入
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.small),
            child: Row(
              children: [
                Expanded(
                  child: ComposerField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    hintText: t.channel.writeComment,
                    maxLength: 500,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendComment,
                  ),
                ),
                AppSpacing.horizontalSmall,
                IconButton.filled(
                  onPressed: _isSending ? null : _sendComment,
                  icon: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: context.textStyle(FontSizeType.caption2, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
