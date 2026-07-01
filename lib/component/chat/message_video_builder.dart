import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:octo_image/octo_image.dart';
import 'package:imboy/component/ui/shimmer_box.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 视频消息构建器
class MessageVideoBuilder extends StatelessWidget {
  const MessageVideoBuilder({
    super.key,
    required this.type,
    required this.message,
    required this.user,
  });

  final String type;
  final CustomMessage message;
  final User user;

  @override
  Widget build(BuildContext context) {
    final metadata = message.metadata ?? {};
    final String videoUrl =
        metadata['uri'] as String? ?? metadata['url'] as String? ?? '';
    final thumb = metadata['thumb'];
    final String thumbUrl = (thumb is Map)
        ? (thumb['uri'] as String? ?? '')
        : (thumb?.toString() ?? '');

    // 获取视频尺寸
    final widthVal = metadata['width'];
    final heightVal = metadata['height'];
    final double videoWidth = widthVal is num ? widthVal.toDouble() : 320.0;
    final double videoHeight = heightVal is num ? heightVal.toDouble() : 180.0;

    // 计算显示比例
    final double maxWidth = MediaQuery.of(context).size.width * 0.65;
    double displayWidth = videoWidth;
    double displayHeight = videoHeight;

    if (displayWidth > maxWidth) {
      final ratio = maxWidth / displayWidth;
      displayWidth = maxWidth;
      displayHeight = displayHeight * ratio;
    }

    return GestureDetector(
      onTap: () {
        if (videoUrl.isNotEmpty) {
          // 统一走 GoRouter /video_viewer（对齐 channel_detail_page.dart:1893 的写法）
          context.push(
            '/video_viewer?url=${Uri.encodeComponent(videoUrl)}&thumb=${Uri.encodeComponent(thumbUrl)}',
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MessageSpacing.imageBorderRadius),
        child: SizedBox(
          width: displayWidth,
          height: displayHeight,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              OctoImage(
                image: cachedImageProvider(thumbUrl),
                fit: BoxFit.cover,
                placeholderBuilder: (context) => ShimmerBox(
                  baseColor: AppColors.shimmerBase,
                  highlightColor: AppColors.shimmerHighlight,
                  child: Container(color: AppColors.mediaScrimWhite),
                ),
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.mediaScrimBlack.withValues(alpha: 0.26),
                  child: const Icon(
                    Icons.video_library,
                    color: AppColors.mediaScrimWhite,
                  ),
                ),
              ),
              // 底部阴影遮罩，确保时间标签清晰可见
              if (metadata['duration_ms'] != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.mediaScrimBlack.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              // 经典 iOS 玻璃态播放按钮
              Center(
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: MessageSpacing.videoPlayButtonSize,
                      height: MessageSpacing.videoPlayButtonSize,
                      decoration: BoxDecoration(
                        color: AppColors.mediaScrimWhite.withValues(
                          alpha: 0.15,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.mediaScrimWhite.withValues(
                            alpha: 0.3,
                          ),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.play_fill,
                          color: AppColors.mediaScrimWhite,
                          size: MessageSpacing.videoPlayButtonIconSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (metadata['duration_ms'] != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mediaScrimBlack.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDuration(metadata['duration_ms']),
                      style: context
                          .textStyle(
                            FontSizeType.tiny,
                            color: AppColors.mediaScrimWhite,
                            fontWeight: FontWeight.w600,
                          )
                          .copyWith(fontFamily: 'SF Mono'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(dynamic ms) {
    if (ms is! num) return '00:00';
    final seconds = (ms / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// 视频消息插件注册
class VideoMessageTypePlugin implements MessageTypePlugin {
  const VideoMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.video}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.video;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return MessageVideoBuilder(
      type: context.type,
      message: message,
      user: context.user,
    );
  }
}
