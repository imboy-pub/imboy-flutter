import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:octo_image/octo_image.dart';
import 'package:video_player/video_player.dart' as vp;
import 'package:imboy/component/video/video_controller.dart';

/// FlyerChatVideoMessage - 视频消息组件
///
/// 优化的视频消息显示组件，支持：
/// - 缩略图预览
/// - 点击全屏播放
/// - 时长显示
/// - 未读提示
class FlyerChatVideoMessage extends StatefulWidget {
  /// The video message data model.
  final VideoMessage message;

  /// The index of the message in the list.
  final int index;

  /// Optional custom thumbnail image provider.
  final ImageProvider? thumbnailProvider;

  /// Border radius of the video container.
  final BorderRadiusGeometry? borderRadius;

  /// Constraints for the video size.
  final BoxConstraints? constraints;

  /// Whether to show the status.
  final bool showStatus;

  /// Whether to show the timestamp.
  final bool showTime;

  const FlyerChatVideoMessage({
    super.key,
    required this.message,
    required this.index,
    this.thumbnailProvider,
    this.borderRadius,
    this.constraints,
    this.showStatus = false,
    this.showTime = true,
  });

  @override
  State<FlyerChatVideoMessage> createState() => _FlyerChatVideoMessageState();
}

class _FlyerChatVideoMessageState extends State<FlyerChatVideoMessage> {
  vp.VideoPlayerController? _videoController;
  bool _isInitializing = false;
  bool _hasError = false;
  bool _isPlaying = false;
  String? _thumbnailUrl;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (_isInitializing) return;
    setState(() => _isInitializing = true);

    try {
      // 从 metadata 获取缩略图 URL
      final thumbData = widget.message.metadata?['thumb'];
      if (thumbData != null && thumbData is Map) {
        _thumbnailUrl = thumbData['uri'] ?? thumbData['url'];
      }

      // 获取视频文件本地路径
      final videoUrl = widget.message.source;
      // 视频文件不走图片魔数校验（与音频同款根因）：默认 validateImageData=true
      // 会把下载的视频当图片校验失败 → 删除重下 → 3 次全失败 → 「视频文件不存在」。
      final file = await IMBoyCacheManager().getSingleFile(
        videoUrl,
        validateImageData: false,
      );

      if (!await file.exists()) {
        throw Exception('视频文件不存在');
      }

      // 初始化视频控制器
      _videoController = vp.VideoPlayerController.file(file);

      await _videoController!.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      iPrint('视频初始化失败: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取视频尺寸
    final width = widget.message.width ?? 0;
    final height = widget.message.height ?? 0;

    // 计算显示尺寸（保持宽高比）
    final displayWidth = width > 0 ? width.toDouble() : 200;
    final aspectRatio = height > 0 ? width / height : 16 / 9;
    final displayHeight = (displayWidth / aspectRatio).toDouble();

    return Container(
      constraints:
          widget.constraints ??
          BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.618,
            maxHeight: 300,
          ),
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
        child: Stack(
          children: [
            // 缩略图或视频播放器
            if (_videoController != null &&
                _videoController!.value.isInitialized)
              _buildVideoPlayer()
            else
              _buildThumbnail(
                displayWidth.toDouble(),
                displayHeight.toDouble(),
              ),

            // 播放按钮覆盖层
            if (!_hasError) _buildPlayButtonOverlay(),

            // 时长显示
            _buildDurationIndicator(),

            // 错误提示
            if (_hasError) _buildErrorIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(double displayWidth, double displayHeight) {
    final thumbnailUrl =
        _thumbnailUrl ?? widget.message.metadata?['thumb']?['uri'];

    return SizedBox(
      width: displayWidth,
      height: displayHeight.clamp(120, 300),
      child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
          ? OctoImage(
              image: cachedImageProvider(thumbnailUrl),
              fit: BoxFit.cover,
              width: displayWidth,
              height: displayHeight.clamp(120, 300),
              placeholderBuilder: (context) =>
                  _buildPlaceholder(displayWidth, displayHeight),
              errorBuilder: (context, error, stacktrace) =>
                  _buildPlaceholder(displayWidth, displayHeight),
            )
          : _buildPlaceholder(displayWidth, displayHeight),
    );
  }

  Widget _buildPlaceholder(double displayWidth, double displayHeight) {
    return Container(
      width: displayWidth,
      height: displayHeight.clamp(120, 300),
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.videocam, size: 48, color: Colors.grey),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return SizedBox(
      width: widget.message.width?.toDouble() ?? 300,
      height: widget.message.height?.toDouble() ?? 200,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: vp.VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  Widget _buildPlayButtonOverlay() {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _hasError ? null : _handlePlayTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: _isInitializing ? 40 : 56,
                height: _isInitializing ? 40 : 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isInitializing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                      )
                    : Icon(Icons.play_arrow, color: Colors.blue, size: 32),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDurationIndicator() {
    final durationMs = widget.message.metadata?['duration_ms'];
    final duration = durationMs != null
        ? Duration(milliseconds: durationMs)
        : Duration.zero;

    return Positioned(
      bottom: 8,
      right: 8,
      child: Container(
        padding: MessageSpacing.bubblePaddingAll,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              _formatDuration(duration),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorIndicator() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 32),
              SizedBox(height: 8),
              Text(
                '视频加载失败',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handlePlayTap() async {
    if (_videoController == null || _hasError || _isInitializing) return;

    try {
      // 标记为已播放
      final metadata = widget.message.metadata ?? {};
      if (metadata['played'] != true) {
        final newMeta = {...metadata, 'played': true};
        final tableName = MessageRepo.getTableName('C2C'); // 需要从上下文获取
        await MessageRepo(
          tableName: tableName,
        ).update({'id': widget.message.id, 'payload': json.encode(newMeta)});
      }

      // 全屏播放视频
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                _VideoPlayerPage(videoController: _videoController!),
          ),
        );

        // 播放完成后重新初始化
        _initializeVideo();
      }
    } catch (e) {
      iPrint('播放视频失败: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// 全屏视频播放页面
///
/// BUG#75 真根因：聊天页视频消息点击走的是 [FlyerChatVideoMessage._handlePlayTap]
/// → [Navigator.push] 到本页（不是 `VideoViewerPage`），而本页原本只有
/// `Scaffold+AppBar+VideoPlayer`，**没有调用 play()、没有控制层**，导致
/// 「画面静止、只有返回键、点击无反应」。此前若干轮都在改 `VideoViewerPage`，
/// 而聊天页根本走不到它。
///
/// 修复：复用项目的 [VideoControllerOverlay]（已含播放/暂停、进度条、时长、
/// 全屏、点击 toggle），并在进入时自动播放。
class _VideoPlayerPage extends StatefulWidget {
  final vp.VideoPlayerController videoController;

  const _VideoPlayerPage({required this.videoController});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    // 进入即播放（主流 IM 行为，与 VideoViewerPage 的 BUG#69 修复一致）
    widget.videoController
      ..setLooping(true)
      ..play();
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: widget.videoController.value.aspectRatio,
              child: vp.VideoPlayer(widget.videoController),
            ),
          ),
          VideoControllerOverlay(
            controller: widget.videoController,
            onFullScreenPressed: _toggleFullScreen,
            isFullScreen: _isFullScreen,
          ),
        ],
      ),
    );
  }
}
