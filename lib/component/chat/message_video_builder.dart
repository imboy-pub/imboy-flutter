import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/single/video_viewer.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:octo_image/octo_image.dart';
import 'package:shimmer/shimmer.dart';

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
    final String videoUrl = metadata['uri'] ?? metadata['url'] ?? '';
    final thumb = metadata['thumb'];
    final String thumbUrl = (thumb is Map)
        ? (thumb['uri'] ?? '')
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
          Navigator.of(context).push(
            MaterialPageRoute<dynamic>(
              builder: (context) =>
                  VideoViewerPage(url: videoUrl, thumb: thumbUrl),
            ),
          );
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(
              MessageSpacing.imageBorderRadius,
            ),
            child: OctoImage(
              image: cachedImageProvider(thumbUrl),
              width: displayWidth,
              height: displayHeight,
              fit: BoxFit.cover,
              placeholderBuilder: (context) => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(
                  width: displayWidth,
                  height: displayHeight,
                  color: Colors.white,
                ),
              ),
              errorBuilder: (context, error, stackTrace) => Container(
                width: displayWidth,
                height: displayHeight,
                color: Colors.black26,
                child: const Icon(Icons.video_library, color: Colors.white),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
          ),
          if (metadata['duration_ms'] != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatDuration(metadata['duration_ms']),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
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
  MessagePluginSurface get surface => MessagePluginSurface.bubble;

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
