import 'package:flutter/foundation.dart' show mapEquals;
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
import 'package:imboy/page/moment/moment_utils.dart';
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
  bool _liked = false;
  // 订阅号预览卡折叠阈值：超限则截断为摘要，点进 B1 阅读页看全文。
  static const int _textSummaryMaxChars = 120;
  static const int _textSummaryMaxLines = 3;
  static const int _imageTextSummaryMaxLines = 3;
  static const double _authorAvatarSize = 20.0;
  // 点赞本地增量：add 成功 +1 / remove 成功 -1，叠加在 reactionSummary 汇总上，
  // 让底栏计数即时反映操作（后端消息列表不会随点赞实时刷新）。
  int _likeDelta = 0;
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
  void didUpdateWidget(covariant ChannelMessageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 父层刷新消息（reactionSummary 已含最新计数）后清零本地增量，避免双计。
    if (!mapEquals(
      oldWidget.message.reactionSummary,
      widget.message.reactionSummary,
    )) {
      _likeDelta = 0;
      _liked = _isAlreadyLiked();
    }
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
        setState(() {
          _liked = true;
          _likeDelta += 1;
        });
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
        setState(() {
          _liked = false;
          _likeDelta -= 1;
        });
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
      // 卡片级单击 → 沉浸式全屏阅读页（内容类消息）。图片/展开全文有各自内层
      // onTap，手势竞技场中内层胜出，故此处只在卡片空白区触发；audio 保持原地播放。
      onTap: message.msgType == ChannelMessageType.audio
          ? null
          : () => context.push(
              '/channel/${widget.channelId}/article/${message.id}',
              extra: message,
            ),
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
                _buildMetaBar(context, secondaryColor),
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

  /// 轻元数据行：紧凑署名（小头像 + 作者名）+ 相对时间 + 阅读量 + more 菜单。
  ///
  /// 频道身份已在详情页头部（ChannelHeaderBar）展示一次，卡片不再重复大头像 +
  /// 频道名（收敛信息流视觉噪音，M2）；多管理员频道靠小头像 + 名字区分作者。
  Widget _buildMetaBar(BuildContext context, Color secondaryColor) {
    final message = widget.message;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      child: Row(
        children: [
          _buildAuthorAvatar(_authorAvatarSize),
          AppSpacing.horizontalSmall,
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
          AppSpacing.horizontalTiny,
          Text(
            _relativeTime(message.createdAt),
            style: context.textStyle(
              FontSizeType.caption2,
              color: secondaryColor,
            ),
          ),
          const Spacer(),
          if (message.viewCount > 0) ...[
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
          // more 菜单：管理者见置顶/删除，普通用户见复制/分享
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.isManaged
                ? _showManageMenu(context)
                : _showMoreMenu(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Icon(Icons.more_horiz, size: 18, color: secondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorAvatar(double size) {
    final message = widget.message;
    final hasAvatar =
        message.authorAvatar != null && message.authorAvatar!.isNotEmpty;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      backgroundImage: hasAvatar
          ? cachedImageProvider(message.authorAvatar!, w: 48)
          : null,
      child: hasAvatar
          ? null
          : Text(
              (message.authorName != null && message.authorName!.isNotEmpty)
                  ? message.authorName![0].toUpperCase()
                  : '?',
              style: context.textStyle(FontSizeType.tiny),
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
      case ChannelMessageType.imageText:
      case 'imageText':
        return _buildImageTextContent(textColor, secondaryColor);
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
    // 订阅号预览：短文直显；长文截断为摘要 + 「全文」提示，点卡片进 B1 阅读页看全文
    // （不再就地展开——就地展开是聊天思维，订阅号是点进阅读）。
    final isLong =
        content.length > _textSummaryMaxChars ||
        '\n'.allMatches(content).length >= _textSummaryMaxLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content,
          maxLines: isLong ? _textSummaryMaxLines : null,
          overflow: isLong ? TextOverflow.ellipsis : TextOverflow.clip,
          style: context
              .textStyle(FontSizeType.body, color: textColor)
              .copyWith(height: 1.5),
        ),
        if (isLong)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              context.t.channel.readFull,
              style: context.textStyle(
                FontSizeType.subheadline,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  /// 图文消息（订阅号封面卡）：标题（首行加粗）+ 摘要（后续行截断）+ 图片九宫格预览。
  ///
  /// 不再内联展开全文——完整正文交给 B1 阅读页（卡片 onTap）。首行视为标题，
  /// 其余为摘要；无换行时整段作标题（截断）。images 为空退化为纯标题/摘要。
  Widget _buildImageTextContent(Color textColor, Color secondaryColor) {
    final content = widget.message.content.trim();
    final images = _imageTextItems();
    final newlineIdx = content.indexOf('\n');
    final title = newlineIdx >= 0
        ? content.substring(0, newlineIdx).trim()
        : content;
    final summary = newlineIdx >= 0
        ? content.substring(newlineIdx + 1).trim()
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.body,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            summary,
            maxLines: _imageTextSummaryMaxLines,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.subheadline,
              color: secondaryColor,
            ),
          ),
        ],
        if (images.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildImageTextGrid(images),
        ],
      ],
    );
  }

  /// 解析 payload['images'] → 有效 uri 列表（含宽高元数据的 map 列表）。
  List<Map<String, dynamic>> _imageTextItems() {
    final raw = widget.message.payload?['images'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['uri']?.toString() ?? '').isNotEmpty)
        .toList(growable: false);
  }

  Widget _buildImageTextGrid(List<Map<String, dynamic>> images) {
    final uris = [for (final e in images) e['uri'].toString()];
    return LayoutBuilder(
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

    // 反应总数（服务端汇总 + 本地点赞增量，且不为负）
    int totalReactions = 0;
    if (message.reactionSummary != null) {
      totalReactions = message.reactionSummary!.values.fold(0, (a, b) => a + b);
    }
    totalReactions = (totalReactions + _likeDelta).clamp(0, 1 << 31);

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
          ),
          AppSpacing.horizontalRegular,
          // 评论 —— 直达 B1 阅读页（评论区随正文一并承载），不再走独立评论页
          _buildActionButton(
            icon: Icons.chat_bubble_outline,
            label: t.channel.comment,
            color: secondaryColor,
            onTap: () {
              context.push(
                '/channel/${widget.channelId}/article/${widget.message.id}',
                extra: widget.message,
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
