import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart'
    show cachedImageProvider, iPrint;
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/model/channel_comment_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 频道消息评论页
///
/// 对标公众号/知识星球评论区：
/// - 评论列表（含作者头像/昵称/时间/内容/点赞）
/// - 底部输入栏发布评论
/// - 支持回复（parentId）
class ChannelCommentPage extends ConsumerStatefulWidget {
  final String channelId;
  final String messageId;

  const ChannelCommentPage({
    super.key,
    required this.channelId,
    required this.messageId,
  });

  @override
  ConsumerState<ChannelCommentPage> createState() => _ChannelCommentPageState();
}

class _ChannelCommentPageState extends ConsumerState<ChannelCommentPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChannelService _service = ChannelService.to;

  List<ChannelCommentModel> _comments = [];
  bool _isLoading = false;
  bool _isSending = false;
  int _replyToCommentId = 0;
  String _replyToName = '';

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _service.getComments(
        channelId: widget.channelId,
        messageId: widget.messageId,
      );
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      iPrint('评论加载失败: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final comment = await _service.createComment(
        channelId: widget.channelId,
        messageId: widget.messageId,
        content: content,
        parentId: _replyToCommentId,
      );
      if (comment != null && mounted) {
        HapticFeedback.lightImpact();
        setState(() {
          _comments.add(comment);
          _replyToCommentId = 0;
          _replyToName = '';
        });
        _inputController.clear();
        // 滚到底部
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
    FocusScope.of(context).requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = 0;
      _replyToName = '';
    });
  }

  Future<void> _toggleLike(ChannelCommentModel comment) async {
    HapticFeedback.lightImpact();
    // 真 toggle：按当前 isLiked 分流 like/unlike，计数 ±1。
    // 此前永远调 likeComment 且 likeCount 只增不减、unlikeComment 从未被
    // 调用，导致连点计数持续偏离、且用户无法取消自己的赞。
    final bool willLike = !comment.isLiked;
    final commentId = comment.id.toString();
    final success = willLike
        ? await _service.likeComment(
            channelId: widget.channelId,
            commentId: commentId,
          )
        : await _service.unlikeComment(
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
    if (confirmed != true) return;

    final success = await _service.deleteComment(
      channelId: widget.channelId,
      commentId: comment.id.toString(),
    );
    if (success && mounted) {
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('${t.channel.comment} (${_comments.length})')),
      body: Column(
        children: [
          Expanded(child: _buildCommentList(isDark)),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildCommentList(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_comments.isEmpty) {
      return NoDataView(
        icon: Icons.chat_bubble_outline,
        text: context.t.channel.noComments,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadComments,
      child: ListView.builder(
        controller: _scrollController,
        padding: AppSpacing.allSmall,
        itemCount: _comments.length,
        itemBuilder: (context, index) =>
            _buildCommentItem(_comments[index], isDark),
      ),
    );
  }

  Widget _buildCommentItem(ChannelCommentModel comment, bool isDark) {
    final currentUid = int.tryParse(UserRepoLocal.to.currentUid) ?? 0;
    final isMine = comment.userId == currentUid;
    final hasAvatar = comment.userAvatar.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      padding: AppSpacing.allSmall,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: AppRadius.borderRadiusSmall,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: hasAvatar
                ? cachedImageProvider(comment.userAvatar, w: 64)
                : null,
            child: !hasAvatar
                ? Text(
                    comment.userName.isNotEmpty
                        ? comment.userName[0].toUpperCase()
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
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: context.textStyle(
                        FontSizeType.subheadline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isMine) ...[
                      AppSpacing.horizontalTiny,
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          context.t.common.me,
                          style: context.textStyle(
                            FontSizeType.tiny,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                AppSpacing.verticalTiny,
                // 回复引用
                if (comment.replyToName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '@${comment.replyToName}',
                      style: context.textStyle(
                        FontSizeType.small,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                Text(
                  comment.content,
                  style: context
                      .textStyle(FontSizeType.body)
                      .copyWith(height: 1.4),
                ),
                AppSpacing.verticalSmall,
                // 操作行
                Row(
                  children: [
                    Text(
                      _relativeTime(comment.createdAt),
                      style: context.textStyle(
                        FontSizeType.caption2,
                        color: AppColors.getTextColor(
                          Theme.of(context).brightness,
                          isSecondary: true,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // 回复
                    _actionChip(
                      icon: Icons.reply,
                      label: context.t.channel.reply,
                      onTap: () => _startReply(comment),
                    ),
                    AppSpacing.horizontalSmall,
                    // 点赞
                    _actionChip(
                      // 图标随 isLiked 切换实心/描边，让 toggle 状态可见
                      icon: comment.isLiked
                          ? Icons.favorite
                          : Icons.favorite_border,
                      label: comment.likeCount > 0
                          ? '${comment.likeCount}'
                          : context.t.channel.like,
                      onTap: () => _toggleLike(comment),
                    ),
                    if (isMine) ...[
                      AppSpacing.horizontalSmall,
                      _actionChip(
                        icon: Icons.delete_outline,
                        label: '',
                        onTap: () => _deleteComment(comment),
                        color: AppColors.iosRed,
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

  Widget _actionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c =
        color ??
        AppColors.getTextColor(Theme.of(context).brightness, isSecondary: true);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: c),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                label,
                style: context.textStyle(FontSizeType.caption2, color: c),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final t = context.t;
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
          if (_replyToCommentId > 0)
            Container(
              padding: AppSpacing.allSmall,
              margin: const EdgeInsets.only(bottom: AppSpacing.small),
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    hintText: t.channel.writeComment,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.borderRadiusRegular,
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.getIosSeparator(
                      Theme.of(context).brightness,
                    ).withValues(alpha: 0.08),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendComment(),
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
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return context.t.common.justNow;
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${context.t.common.minutesAgo}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} ${context.t.common.hoursAgo}';
    }
    if (diff.inDays < 7) return '${diff.inDays} ${context.t.channel.daysAgo}';
    return '${dt.month}-${dt.day.toString().padLeft(2, '0')}';
  }
}
