import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/store/model/channel_message_model.dart';
import 'package:imboy/store/model/channel_stats_model.dart';

import 'channel_detail_rules.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 频道消息内容卡片
///
/// 对标微信公众号 + 知识星球的「内容卡片」交互范式：
/// - 统一卡片骨架（顶栏元信息 + 内容区 + 底栏社交互动）
/// - 长文折叠/展开（>6 行）
/// - 双击点赞 + 大拇指动画
/// - 底栏常驻：反应 / 评论 / 分享 / 更多
/// - 管理者：置顶徽章、管理菜单
class ChannelMessageItem extends ConsumerStatefulWidget {
  final ChannelMessageModel message;
  final String channelId;
  final bool isManaged;
  final VoidCallback? onReactionChanged;
  final ValueChanged<bool>? onPinned;
  final VoidCallback? onDeleted;

  const ChannelMessageItem({
    super.key,
    required this.message,
    required this.channelId,
    this.isManaged = false,
    this.onReactionChanged,
    this.onPinned,
    this.onDeleted,
  });

  @override
  ConsumerState<ChannelMessageItem> createState() => _ChannelMessageItemState();
}

class _ChannelMessageItemState extends ConsumerState<ChannelMessageItem>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _liked = false;
  // 双击点赞浮层动画
  late AnimationController _likeAnimController;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _liked = _isAlreadyLiked();
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    super.dispose();
  }

  bool _isAlreadyLiked() {
    // 后端消息列表已随行返回 my_reactions（当前用户已添加的反应类型），
    // 据此还原「我已赞」初始状态；add/remove 成功后仍由 setState 维护本地状态。
    return widget.message.myReactions.contains(ChannelReactionType.like);
  }

  Future<void> _addReaction(String reactionType) async {
    final channelService = ref.read(channelServiceProvider);
    final success = await channelService.addReaction(
      channelId: widget.channelId,
      messageId: widget.message.id.toString(),
      reactionType: reactionType,
    );
    if (success && mounted) {
      if (reactionType == ChannelReactionType.like) {
        setState(() => _liked = true);
      }
      widget.onReactionChanged?.call();
    }
  }

  Future<void> _removeReaction(String reactionType) async {
    final channelService = ref.read(channelServiceProvider);
    final success = await channelService.removeReaction(
      channelId: widget.channelId,
      messageId: widget.message.id.toString(),
      reactionType: reactionType,
    );
    if (success && mounted) {
      if (reactionType == ChannelReactionType.like) {
        setState(() => _liked = false);
      }
      widget.onReactionChanged?.call();
    }
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    if (_liked) {
      _removeReaction(ChannelReactionType.like);
    } else {
      _addReaction(ChannelReactionType.like);
    }
  }

  /// 双击点赞 + 大拇指动画
  void _onDoubleTap() {
    if (!_liked) {
      HapticFeedback.lightImpact();
      _likeAnimController.forward(from: 0.0);
      _addReaction(ChannelReactionType.like);
    }
  }

  void _showReactionPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: AppSpacing.allRegular,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t.channel.selectReaction,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            AppSpacing.verticalRegular,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionButton(ChannelReactionType.like, '👍'),
                _buildReactionButton(ChannelReactionType.heart, '❤️'),
                _buildReactionButton(ChannelReactionType.fire, '🔥'),
                _buildReactionButton(ChannelReactionType.thumbsUp, '👏'),
                _buildReactionButton(ChannelReactionType.bookmark, '📌'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(String type, String emoji) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _addReaction(type);
      },
      child: Container(
        padding: AppSpacing.allMedium,
        decoration: BoxDecoration(
          color: AppColors.getIosSeparator(
            Theme.of(context).brightness,
          ).withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 28)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final message = widget.message;
    final isText =
        message.msgType == ChannelMessageType.text ||
        ![
          ChannelMessageType.image,
          ChannelMessageType.video,
          ChannelMessageType.file,
          ChannelMessageType.audio,
        ].contains(message.msgType);

    final cardColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final secondaryColor = AppColors.getTextColor(
      Theme.of(context).brightness,
      isSecondary: true,
    );

    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(
              horizontal: AppSpacing.regular,
              vertical: AppSpacing.tiny + 2,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: AppRadius.borderRadiusMedium,
              border: Border.all(
                color: message.isPinned
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : AppColors.getIosSeparator(
                        Theme.of(context).brightness,
                      ).withValues(alpha: 0.3),
                width: message.isPinned ? 1.2 : 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context, secondaryColor),
                _buildContentArea(textColor, secondaryColor, isText),
                _buildBottomBar(context, textColor, secondaryColor),
              ],
            ),
          ),
          // 双击点赞浮层动画
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.5, end: 1.4).animate(
                    CurvedAnimation(
                      parent: _likeAnimController,
                      curve: Curves.elasticOut,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                      CurvedAnimation(
                        parent: _likeAnimController,
                        curve: const Interval(0.5, 1.0),
                      ),
                    ),
                    child: const Text('👍', style: TextStyle(fontSize: 80)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 顶栏：作者信息 + 时间 + 阅读量
  Widget _buildTopBar(BuildContext context, Color secondaryColor) {
    final message = widget.message;
    final t = context.t;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage:
                message.authorAvatar != null && message.authorAvatar!.isNotEmpty
                ? cachedImageProvider(message.authorAvatar!, w: 48)
                : null,
            child:
                (message.authorAvatar == null || message.authorAvatar!.isEmpty)
                ? Text(
                    message.authorName != null && message.authorName!.isNotEmpty
                        ? message.authorName![0].toUpperCase()
                        : '?',
                    style: context.textStyle(FontSizeType.small),
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
                    Flexible(
                      child: Text(
                        message.authorName ?? '',
                        style: context.textStyle(
                          FontSizeType.subheadline,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isManaged) ...[
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
                          t.channel.admin,
                          style: context.textStyle(
                            FontSizeType.tiny,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  _relativeTime(message.createdAt),
                  style: context.textStyle(
                    FontSizeType.caption2,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
          ),
          // 阅读量
          if (message.viewCount > 0)
            Row(
              children: [
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 13,
                  color: secondaryColor,
                ),
                const SizedBox(width: 2),
                Text(
                  _formatCount(message.viewCount),
                  style: context.textStyle(
                    FontSizeType.caption2,
                    color: secondaryColor,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// 内容区：按消息类型分发
  Widget _buildContentArea(Color textColor, Color secondaryColor, bool isText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: _buildMessageContent(textColor, secondaryColor, isText),
    );
  }

  Widget _buildMessageContent(
    Color textColor,
    Color secondaryColor,
    bool isText,
  ) {
    final message = widget.message;
    switch (message.msgType) {
      case ChannelMessageType.image:
      case 'image':
        return _buildImageContent(textColor);
      case ChannelMessageType.video:
      case 'video':
        return _buildVideoContent(textColor);
      case ChannelMessageType.file:
      case 'file':
        return _buildFileContent(textColor, secondaryColor);
      case ChannelMessageType.audio:
      case 'audio':
      case 'voice':
        return _buildAudioContent(textColor);
      default:
        return _buildTextContent(textColor, secondaryColor);
    }
  }

  Widget _buildTextContent(Color textColor, Color secondaryColor) {
    final content = widget.message.content;
    final shouldCollapse =
        content.length > 280 || '\n'.allMatches(content).length >= 6;
    final displayText = (!_expanded && shouldCollapse)
        ? '${content.substring(0, content.length > 280 ? 280 : content.length).trim()}…'
        : content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          displayText,
          style: TextStyle(
            fontSize: FontSizeType.body.size,
            height: 1.5,
            color: textColor,
          ),
        ),
        if (shouldCollapse)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _expanded
                    ? context.t.common.collapse
                    : context.t.common.expandFull,
                style: context.textStyle(
                  FontSizeType.subheadline,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImageContent(Color textColor) {
    final payload = widget.message.payload;
    final uri = payload?['uri'] as String?;
    if (uri == null) return _buildTextContent(textColor, textColor);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: () => zoomInPhotoView(context, uri),
        child: ClipRRect(
          borderRadius: AppRadius.borderRadiusSmall,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Image(
              image: cachedImageProvider(uri, w: 600),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(Color textColor) {
    final payload = widget.message.payload;
    String? thumb;
    final dynamic thumbRaw = payload?['thumb'];
    if (thumbRaw is String) {
      thumb = thumbRaw;
    } else if (thumbRaw is Map) {
      thumb = thumbRaw['uri']?.toString();
    }
    final videoUri = payload?['uri'] as String?;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        onTap: () {
          if (videoUri != null) {
            context.push(
              '/video_viewer?url=${Uri.encodeComponent(videoUri)}&thumb=${Uri.encodeComponent(thumb ?? '')}',
            );
          }
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
              // 时长角标
              if (payload?['duration'] != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration((payload!['duration'] as num).toInt()),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              // 播放按钮
              Container(
                padding: AppSpacing.allMedium,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileContent(Color textColor, Color secondaryColor) {
    final payload = widget.message.payload;
    final name = payload?['name'] as String? ?? context.t.chat.defaultFileName;
    final size = payload?['size'] as int? ?? 0;
    final uri = payload?['uri']?.toString();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: (uri == null || uri.isEmpty) ? null : () => _openFile(uri),
        borderRadius: AppRadius.borderRadiusSmall,
        child: Container(
          padding: AppSpacing.allMedium,
          decoration: BoxDecoration(
            color: secondaryColor.withValues(alpha: 0.06),
            borderRadius: AppRadius.borderRadiusSmall,
          ),
          child: Row(
            children: [
              Icon(Icons.insert_drive_file, size: 36, color: textColor),
              AppSpacing.horizontalMedium,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.verticalTiny,
                    Text(
                      _formatFileSize(size),
                      style: context.textStyle(
                        FontSizeType.small,
                        color: secondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioContent(Color textColor) {
    final payload = widget.message.payload ?? {};
    final durationMs = (payload['duration_ms'] as num?)?.toInt() ?? 0;
    final durationSec = (durationMs / 1000).round();
    final uri = payload['uri']?.toString() ?? '';

    return _ChannelAudioPlayer(
      uri: uri,
      messageId: widget.message.id.toString(),
      durationSec: durationSec,
      durationMs: durationMs,
      textColor: textColor,
    );
  }

  /// 底栏：社交互动常驻（反应/评论/分享/更多）
  Widget _buildBottomBar(
    BuildContext context,
    Color textColor,
    Color secondaryColor,
  ) {
    final t = context.t;
    final message = widget.message;

    // 反应总数
    int totalReactions = 0;
    if (message.reactionSummary != null) {
      totalReactions = message.reactionSummary!.values.fold(0, (a, b) => a + b);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 8),
      child: Row(
        children: [
          // 点赞按钮（主反应）
          _buildActionButton(
            icon: _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
            label: totalReactions > 0
                ? _formatCount(totalReactions)
                : t.channel.like,
            color: _liked ? AppColors.primary : secondaryColor,
            onTap: _toggleLike,
            onLongPress: _showReactionPicker,
          ),
          AppSpacing.horizontalRegular,
          // 评论 —— 跳转评论页
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: t.channel.comment,
            color: secondaryColor,
            onTap: () {
              context.push(
                '/channel/${widget.channelId}/message/${widget.message.id}/comments',
              );
            },
          ),
          AppSpacing.horizontalRegular,
          // 分享
          _buildActionButton(
            icon: Icons.share_outlined,
            label: t.channel.share,
            color: secondaryColor,
            onTap: () => _shareMessage(),
          ),
          const Spacer(),
          // 管理者菜单 / 更多
          if (widget.isManaged)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showManageMenu(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Icon(Icons.more_horiz, size: 18, color: secondaryColor),
              ),
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showMoreMenu(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Icon(Icons.more_horiz, size: 18, color: secondaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
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

  // ---- 管理菜单 ----

  void _showManageMenu(BuildContext context) {
    final t = context.t;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx + renderBox.size.width - 120,
        position.dy,
        position.dx + renderBox.size.width,
        position.dy + renderBox.size.height,
      ),
      items: [
        PopupMenuItem(
          value: widget.message.isPinned ? 'unpin' : 'pin',
          child: ListTile(
            leading: Icon(
              widget.message.isPinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin,
              size: 20,
            ),
            title: Text(
              widget.message.isPinned
                  ? t.channel.unpinMessage
                  : t.channel.pinMessage,
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.iosRed,
            ),
            title: Text(
              t.channel.deleteMessage,
              style: const TextStyle(color: AppColors.iosRed),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value != null && context.mounted) _handleMessageAction(value);
    });
  }

  void _showMoreMenu(BuildContext context) {
    final t = context.t;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text(t.common.copy),
              onTap: () {
                Navigator.pop(ctx);
                if (widget.message.msgType == ChannelMessageType.text) {
                  Clipboard.setData(
                    ClipboardData(text: widget.message.content),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.main.copiedToClipboard)),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: Text(t.channel.share),
              onTap: () {
                Navigator.pop(ctx);
                _shareMessage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMessageAction(String action) async {
    switch (action) {
      case 'pin':
        await _setPinned(true);
        break;
      case 'unpin':
        await _setPinned(false);
        break;
      case 'delete':
        _showDeleteMessageDialog();
        break;
    }
  }

  Future<void> _setPinned(bool pinned) async {
    final channelService = ref.read(channelServiceProvider);
    final success = await channelService.setMessagePinned(
      widget.channelId,
      widget.message.id.toString(),
      pinned,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pinned
                ? context.t.channel.messagePinned
                : context.t.channel.messageUnpinned,
          ),
        ),
      );
      widget.onReactionChanged?.call();
      widget.onPinned?.call(pinned);
    }
  }

  void _showDeleteMessageDialog() {
    final t = context.t;
    final deletedMsg = t.channel.messageDeleted;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.channel.deleteMessage),
        content: Text(t.channel.deleteMessageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () async {
              final channelService = ref.read(channelServiceProvider);
              Navigator.pop(ctx);
              final success = await channelService.deleteMessage(
                widget.channelId,
                widget.message.id.toString(),
              );
              if (success && mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(deletedMsg)));
                widget.onReactionChanged?.call();
                widget.onDeleted?.call();
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.iosRed),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
  }

  void _shareMessage() {
    final t = context.t;
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
                final text = widget.message.contentPreview;
                Clipboard.setData(ClipboardData(text: text));
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
                      'content': widget.message.contentPreview,
                      'payload': {
                        'channel_id': widget.channelId,
                        'message_id': widget.message.id,
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

  Future<void> _openFile(String uri) async {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.chat.fileUrlInvalid)));
      return;
    }
    if (!await canLaunchUrl(parsed)) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t.common.fileOpenFailed)));
      return;
    }
    await launchUrl(parsed, mode: LaunchMode.externalApplication);
  }

  // ---- 辅助格式化 ----

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

  String _formatCount(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  String _formatDuration(int seconds) {
    final m = (seconds / 60).floor();
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(int bytes) => formatFileSize(bytes);
}

class _ChannelAudioPlayer extends ConsumerStatefulWidget {
  final String uri;
  final String messageId;
  final int durationSec;
  final int durationMs;
  final Color textColor;

  const _ChannelAudioPlayer({
    required this.uri,
    required this.messageId,
    required this.durationSec,
    required this.durationMs,
    required this.textColor,
  });

  @override
  ConsumerState<_ChannelAudioPlayer> createState() =>
      _ChannelAudioPlayerState();
}

class _ChannelAudioPlayerState extends ConsumerState<_ChannelAudioPlayer> {
  bool _isLoading = false;

  Future<void> _togglePlay() async {
    if (_isLoading) return;

    final playbackState = ref.read(voicePlaybackServiceProvider);
    final notifier = ref.read(voicePlaybackServiceProvider.notifier);

    if (playbackState.currentAudioPath == widget.uri &&
        playbackState.isPlaying) {
      await notifier.pause();
      return;
    }

    if (playbackState.currentAudioPath == widget.uri &&
        playbackState.isPaused) {
      await notifier.resume();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final file = await IMBoyCacheManager().getSingleFile(
        widget.uri,
        validateImageData: false,
      );

      if (await file.exists() && mounted) {
        await notifier.play(
          path: file.path,
          messageId: widget.messageId,
          durationMs: widget.durationMs,
        );
      }
    } catch (e) {
      iPrint('播放频道语音失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(voicePlaybackServiceProvider);
    final isThis = playbackState.currentMessageId == widget.messageId;
    final isPlaying = isThis && playbackState.isPlaying;

    return InkWell(
      onTap: _togglePlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.textColor,
                    ),
                  )
                : Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: widget.textColor,
                    size: 20,
                  ),
            AppSpacing.horizontalSmall,
            Text(
              "${widget.durationSec}''",
              style: context
                  .textStyle(
                    FontSizeType.normal,
                    fontWeight: FontWeight.bold,
                    color: widget.textColor,
                  )
                  .copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
