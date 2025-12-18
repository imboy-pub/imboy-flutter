import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:get/get.dart';

import 'package:imboy/component/ui/imboy_cached_image_provider.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/single/video_viewer.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class VideoMessageBuilder extends StatefulWidget {
  const VideoMessageBuilder({
    super.key,
    // 当前登录用户
    required this.user,
    required this.message,
  });

  final User user;

  /// [CustomMessage]
  final CustomMessage message;

  @override
  State<VideoMessageBuilder> createState() => _VideoMessageBuilderState();
}

class _VideoMessageBuilderState extends State<VideoMessageBuilder> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    final String? videoUri = widget.message.metadata?['video']?['uri'];
    final String? thumbUri = widget.message.metadata?['thumb']?['uri'];
    final int? duration = widget.message.metadata?['video']?['duration'];
    
    return VisibilityDetector(
      key: Key(widget.message.id),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.3 && !_isVisible) {
          setState(() => _isVisible = true);
        } else if (info.visibleFraction <= 0.1 && _isVisible) {
          setState(() => _isVisible = false);
        }
      },
      child: InkWell(
      onTap: () {
        if (videoUri != null && thumbUri != null) {
          Get.to(
            () => VideoViewerPage(url: videoUri, thumb: thumbUri),
            transition: Transition.rightToLeft,
            popGesture: true,
          );
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            _isVisible && thumbUri != null
                ? FutureBuilder<String>(
                    future: UserRepoLocal.to.accessToken,
                    builder: (context, snapshot) {
                      Map<String, String> headers = <String, String>{
                        'User-Agent': 'imboy/1.0.0',
                      };

                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        headers[Keys.tokenKey] = snapshot.data!;
                      }

                      return Image(
                        image: IMBoyCachedImageProvider(
                          thumbUri,
                          headers,
                        ),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) {
                            return child;
                          }
                          return AnimatedOpacity(
                            opacity: frame == null ? 0 : 1,
                            duration: const Duration(milliseconds: 300),
                            child: child,
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[300],
                          height: 200,
                          child: const Icon(Icons.error, color: Colors.grey),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[300],
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[300],
                    height: 200,
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
            
            // 半透明覆盖层
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            
            // 播放按钮
            Positioned(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            
            // 视频时长
            if (duration != null && duration > 0)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(Duration(milliseconds: duration)),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ));
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }
}
