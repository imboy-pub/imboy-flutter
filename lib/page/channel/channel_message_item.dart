import 'package:flutter/material.dart';
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
import 'package:imboy/store/repository/user_repo_local.dart';

import 'channel_detail_rules.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 频道消息项
class ChannelMessageItem extends StatelessWidget {
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

  Future<void> _addReaction(BuildContext context, String reactionType) async {
    final channelService = ProviderScope.containerOf(
      context,
    ).read(channelServiceProvider);
    final success = await channelService.addReaction(
      channelId: channelId,
      messageId: message.id.toString(),
      reactionType: reactionType,
    );
    if (success && context.mounted) {
      onReactionChanged?.call();
    }
  }

  /// 移除消息反应（通过长按反应标签触发）
  Future<void> _removeReaction(
    BuildContext context,
    String reactionType,
  ) async {
    final channelService = ProviderScope.containerOf(
      context,
    ).read(channelServiceProvider);
    final success = await channelService.removeReaction(
      channelId: channelId,
      messageId: message.id.toString(),
      reactionType: reactionType,
    );
    if (success && context.mounted) {
      onReactionChanged?.call();
    }
  }

  void _showReactionPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t.channel.selectReaction,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildReactionButton(context, ChannelReactionType.like, '👍'),
                _buildReactionButton(context, ChannelReactionType.heart, '❤️'),
                _buildReactionButton(context, ChannelReactionType.fire, '🔥'),
                _buildReactionButton(
                  context,
                  ChannelReactionType.thumbsUp,
                  '👏',
                ),
                _buildReactionButton(
                  context,
                  ChannelReactionType.bookmark,
                  '📌',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(BuildContext context, String type, String emoji) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _addReaction(context, type);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = int.tryParse(UserRepoLocal.to.currentUid) ?? 0;
    final isSentByMe = message.authorId == currentUid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = context.t;

    final isMedia =
        message.msgType == ChannelMessageType.image ||
        message.msgType == ChannelMessageType.video;

    // Send Bubble: brand / white
    // Receive Bubble: surface / label
    final bubbleBg = isMedia
        ? Colors.transparent
        : (isSentByMe
              ? AppColors.primary
              : (isDark
                    ? AppColors.darkSurfaceGrouped
                    : AppColors.lightSurface));

    // received light outline
    final bubbleBorder = (!isSentByMe && !isDark && !isMedia)
        ? Border.all(color: AppColors.iosGray5, width: 0.5)
        : null;

    final textColor = isSentByMe
        ? AppColors.darkTextPrimary
        : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);

    // 消息本身的内容区
    final contentWidget = _buildMessageContent(context, textColor);

    final avatarWidget = CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      backgroundImage:
          message.authorAvatar != null && message.authorAvatar!.isNotEmpty
          ? cachedImageProvider(message.authorAvatar!, w: 64)
          : null,
      child: (message.authorAvatar == null || message.authorAvatar!.isEmpty)
          ? Text(
              message.authorName != null && message.authorName!.isNotEmpty
                  ? message.authorName![0].toUpperCase()
                  : '?',
              style: const TextStyle(fontSize: 14),
            )
          : null,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isSentByMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isSentByMe) ...[avatarWidget, const SizedBox(width: 8)],

          Flexible(
            child: Column(
              crossAxisAlignment: isSentByMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // 作者与时间
                if (!isSentByMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.authorName ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isManaged) ...[
                          const SizedBox(width: 4),
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
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // 气泡
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    border: bubbleBorder,
                    borderRadius: BorderRadius.circular(isMedia ? 14 : 20),
                  ),
                  padding: isMedia
                      ? EdgeInsets.zero
                      : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: contentWidget,
                ),

                // 底部反应与统计
                Padding(
                  padding: EdgeInsets.only(
                    top: 4,
                    left: isSentByMe ? 0 : 4,
                    right: isSentByMe ? 4 : 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 置顶
                      if (message.isPinned) ...[
                        const Icon(
                          Icons.push_pin,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                      ],
                      // 浏览量
                      if (message.viewCount > 0 || isSentByMe) ...[
                        Icon(
                          Icons.remove_red_eye_outlined,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${message.viewCount}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      // 反应
                      Tooltip(
                        message: t.channel.react,
                        child: GestureDetector(
                          onTap: () => _showReactionPicker(context),
                          child: Semantics(
                            button: true,
                            label: t.channel.react,
                            child: Icon(
                              Icons.thumb_up_outlined,
                              size: 12,
                              color: AppColors.getTextColor(
                                Theme.of(context).brightness,
                                isSecondary: true,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (message.reactionSummary != null &&
                          message.reactionSummary!.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        _buildReactionSummary(context),
                      ],
                      // 管理操作
                      if (isManaged) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            final renderBox =
                                context.findRenderObject() as RenderBox?;
                            final position = renderBox?.localToGlobal(
                              Offset.zero,
                            );
                            if (position != null) {
                              showMenu(
                                context: context,
                                position: RelativeRect.fromLTRB(
                                  position.dx,
                                  position.dy,
                                  position.dx + renderBox!.size.width,
                                  position.dy + renderBox.size.height,
                                ),
                                items: [
                                  PopupMenuItem(
                                    value: message.isPinned ? 'unpin' : 'pin',
                                    child: ListTile(
                                      leading: Icon(
                                        message.isPinned
                                            ? Icons.push_pin_outlined
                                            : Icons.push_pin,
                                        size: 20,
                                      ),
                                      title: Text(
                                        message.isPinned
                                            ? t.channel.unpinMessage
                                            : t.channel.pinMessage,
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                        color: AppColors.iosRed,
                                      ),
                                      title: Text(
                                        t.channel.deleteMessage,
                                        style: TextStyle(
                                          color: AppColors.iosRed,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ).then((value) {
                                if (value != null && context.mounted) {
                                  _handleMessageAction(value, context);
                                }
                              });
                            }
                          },
                          child: Semantics(
                            button: true,
                            label: t.channel.admin,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              child: Icon(
                                Icons.more_horiz,
                                size: 14,
                                color: AppColors.getTextColor(
                                  Theme.of(context).brightness,
                                  isSecondary: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      // 状态 (如发送中，失败) -> 用 ID < 0 判定
                      if (isSentByMe && message.id < 0) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.iosGray,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isSentByMe) ...[const SizedBox(width: 8), avatarWidget],
        ],
      ),
    );
  }

  /// 处理消息操作
  Future<void> _handleMessageAction(String action, BuildContext context) async {
    switch (action) {
      case 'pin':
        await _setPinned(context, true);
        break;
      case 'unpin':
        await _setPinned(context, false);
        break;
      case 'delete':
        _showDeleteMessageDialog(context);
        break;
    }
  }

  /// 设置消息置顶状态
  Future<void> _setPinned(BuildContext context, bool pinned) async {
    final channelService = ProviderScope.containerOf(
      context,
    ).read(channelServiceProvider);
    final success = await channelService.setMessagePinned(
      channelId,
      message.id.toString(),
      pinned,
    );
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pinned
                ? context.t.channel.messagePinned
                : context.t.channel.messageUnpinned,
          ),
        ),
      );
      onReactionChanged?.call();
      onPinned?.call(pinned);
    }
  }

  /// 显示删除消息确认对话框
  void _showDeleteMessageDialog(BuildContext context) {
    final t = context.t;
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
              final channelService = ProviderScope.containerOf(
                context,
              ).read(channelServiceProvider);
              Navigator.pop(ctx);
              final success = await channelService.deleteMessage(
                channelId,
                message.id.toString(),
              );
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t.channel.messageDeleted)),
                );
                onReactionChanged?.call();
                onDeleted?.call();
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.iosRed),
            child: Text(t.common.confirm),
          ),
        ],
      ),
    );
  }

  /// 构建反应摘要（支持长按移除自己的反应）
  Widget _buildReactionSummary(BuildContext context) {
    final summary = message.reactionSummary!;
    final List<Widget> reactionWidgets = [];

    summary.forEach((type, count) {
      final emoji = ChannelReactionType.getIcon(type);
      reactionWidgets.add(
        GestureDetector(
          onLongPress: () => _showRemoveReactionDialog(context, type),
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.borderRadiusCell,
            ),
            child: Text('$emoji $count', style: const TextStyle(fontSize: 11)),
          ),
        ),
      );
    });

    return Row(children: reactionWidgets);
  }

  /// 显示移除反应确认对话框
  void _showRemoveReactionDialog(BuildContext context, String reactionType) {
    final emoji = ChannelReactionType.getIcon(reactionType);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.common.removeReaction),
        content: Text(t.common.removeReactionConfirm(emoji: emoji)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t.common.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _removeReaction(context, reactionType);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.iosRed),
            child: Text(context.t.common.confirm),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Color textColor) {
    switch (message.msgType) {
      case ChannelMessageType.image:
      case 'image':
        return _buildImageContent(context, textColor);
      case ChannelMessageType.video:
      case 'video':
        return _buildVideoContent(context, textColor);
      case ChannelMessageType.file:
      case 'file':
        return _buildFileContent(context, textColor);
      case ChannelMessageType.audio:
      case 'audio':
      case 'voice':
        return _buildAudioContent(context, textColor);
      default:
        return _buildTextContent(textColor);
    }
  }

  Widget _buildAudioContent(BuildContext context, Color textColor) {
    final payload = message.payload ?? {};
    final durationMs = (payload['duration_ms'] as num?)?.toInt() ?? 0;
    final durationSec = (durationMs / 1000).round();
    final uri = payload['uri']?.toString() ?? '';

    return _ChannelAudioPlayer(
      uri: uri,
      messageId: message.id.toString(),
      durationSec: durationSec,
      durationMs: durationMs,
      textColor: textColor,
    );
  }

  Widget _buildTextContent(Color textColor) {
    return SelectableText(
      message.content,
      style: TextStyle(fontSize: 16, height: 1.4, color: textColor),
    );
  }

  Widget _buildImageContent(BuildContext context, Color textColor) {
    final payload = message.payload;
    final uri = payload?['uri'] as String?;

    if (uri == null) return _buildTextContent(textColor);

    return GestureDetector(
      onTap: () {
        // 打开图片查看器
        zoomInPhotoView(context, uri);
      },
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusSmall,
        child: Image(
          image: cachedImageProvider(uri, w: 400),
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context, Color textColor) {
    final payload = message.payload;
    String? thumb;
    final dynamic thumbRaw = payload?['thumb'];
    if (thumbRaw is String) {
      thumb = thumbRaw;
    } else if (thumbRaw is Map) {
      thumb = thumbRaw['uri']?.toString();
    }
    final videoUri = payload?['uri'] as String?;

    return GestureDetector(
      onTap: () {
        // 打开视频播放器
        if (videoUri != null) {
          context.push(
            '/video_viewer?url=${Uri.encodeComponent(videoUri)}&thumb=${Uri.encodeComponent(thumb ?? '')}',
          );
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (thumb != null && thumb.isNotEmpty)
            ClipRRect(
              borderRadius: AppRadius.borderRadiusSmall,
              child: Image(
                image: cachedImageProvider(thumb, w: 400),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: AppRadius.borderRadiusSmall,
              ),
            ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: AppRadius.borderRadiusXLarge,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildFileContent(BuildContext context, Color textColor) {
    final payload = message.payload;
    final name = payload?['name'] as String? ?? t.chat.defaultFileName;
    final size = payload?['size'] as int? ?? 0;
    final uri = payload?['uri']?.toString();

    return InkWell(
      onTap: (uri == null || uri.isEmpty)
          ? null
          : () async {
              await _openFile(context, uri);
            },
      borderRadius: AppRadius.borderRadiusSmall,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: AppRadius.borderRadiusSmall,
        ),
        child: Row(
          children: [
            Icon(Icons.insert_drive_file, size: 36, color: textColor),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 4),
                  Text(
                    _formatFileSize(size),
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context, String uri) async {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.chat.fileUrlInvalid)));
      return;
    }
    if (!await canLaunchUrl(parsed)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.common.fileOpenFailed)));
      return;
    }
    await launchUrl(parsed, mode: LaunchMode.externalApplication);
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

    // 同一个音频且正在播放，则暂停
    if (playbackState.currentAudioPath == widget.uri &&
        playbackState.isPlaying) {
      await notifier.pause();
      return;
    }

    // 同一个音频且处于暂停，则恢复
    if (playbackState.currentAudioPath == widget.uri &&
        playbackState.isPaused) {
      await notifier.resume();
      return;
    }

    // 否则下载并播放
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
            const SizedBox(width: 8),
            Text(
              "${widget.durationSec}''",
              style: TextStyle(
                color: widget.textColor,
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
