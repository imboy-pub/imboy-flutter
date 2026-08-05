import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/imboy_cached_image_provider.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/video/video_controller.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';

class VideoViewerPage extends ConsumerStatefulWidget {
  final String url;
  final String thumb;

  const VideoViewerPage({super.key, required this.url, required this.thumb});

  @override
  ConsumerState<VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends ConsumerState<VideoViewerPage> {
  VideoPlayerController? _controller;
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  bool get isControllerPlaying => _controller?.value.isPlaying ?? false;
  late bool hasLoaded = false;
  bool _isFullScreen = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  @override
  void dispose() {
    _controller
      ?..removeListener(videoControllerListener)
      ..pause()
      ..dispose();
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

  Future<void> initializePlayer() async {
    if (mounted) {
      setState(() {
        _error = null;
      });
    }
    if (kDebugMode) debugPrint("chat_video_initializePlayer");
    try {
      File tmpF = await IMBoyCacheManager().getSingleFile(
        widget.url,
        validateImageData: false, // 视频文件不验证图片格式
      );
      _controller = VideoPlayerController.file(tmpF);
      await _controller?.initialize();
      if (mounted) {
        setState(() {
          hasLoaded = true;
        });
      }
      _controller?.addListener(videoControllerListener);
      _controller?.setLooping(true);
      // BUG#69：此前初始化完就停在首帧，而唯一的播放入口是会自动隐藏的控制层，
      // 用户点开视频后「什么都不会发生」。主流 IM 打开视频即播放，这里对齐。
      if (kDebugMode) debugPrint('chat_video_autoplay');
      await _controller?.play();
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("video init error: ${e.runtimeType}");
      if (mounted) {
        setState(() {
          _error = e;
        });
      }
    }
  }

  void videoControllerListener() {
    if (isControllerPlaying != isPlaying.value) {
      isPlaying.value = isControllerPlaying;
    }
  }

  Future<void> playButtonCallback() async {
    try {
      if (isPlaying.value) {
        await _controller?.pause();
      } else {
        if (_controller?.value.duration == _controller?.value.position) {
          _controller!
            ..seekTo(Duration.zero)
            ..play();
        } else {
          await _controller?.play();
        }
      }
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("video play error: ${e.runtimeType}");
    }
  }

  // 注：原先这里有 buildBackButton() / buildPlayControlButton() 两个方法，
  // 定义了却从未被 build 引用（死代码）。已删除。
  // ⚠️ 不要再把它们加回来 —— 控制层由 buildVideo 内层的
  // VideoControllerOverlay 提供（自带播放/暂停、进度条、时长、全屏、返回），
  // 加回来只会得到**第二套**返回键和播放按钮。
  // BUG#75「视频页只剩一个返回键」的真因是该 overlay 在 loose 约束下
  // 坍缩成 0×0（见 video_controller.dart 的 BUG#68 注释），与这两个方法无关。

  Widget buildVideo(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: t.main.play,
        image: true,
        onTapHint: t.main.play,
        sortKey: const OrdinalSortKey(1),
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
            if (_controller != null)
              VideoControllerOverlay(
                controller: _controller!,
                onFullScreenPressed: _toggleFullScreen,
                isFullScreen: _isFullScreen,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!hasLoaded) {
      return Scaffold(
        floatingActionButton: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
        backgroundColor: Theme.of(context).cardColor,
        body: Stack(
          alignment: Alignment.centerRight,
          children: <Widget>[
            FutureBuilder<String>(
              future: UserRepoLocal.to.accessToken,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(t.common.loadError));
                }
                Map<String, String> headers = <String, String>{
                  'User-Agent': 'imboy/1.0.0',
                };

                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  headers[Keys.tokenKey] = snapshot.data!;
                }

                return Image(
                  image: IMBoyCachedImageProvider(
                    AssetsService.viewUrl(widget.thumb).toString(),
                    headers,
                  ),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error),
                );
              },
            ),
            Positioned.fill(
              child: _error != null
                  ? NoDataView(
                      text: t.common.loadError,
                      icon: Icons.error_outline,
                      onTop: initializePlayer,
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          AppSpacing.verticalSmall,
                          Text("${t.common.loading}..."),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return Material(
      // 视频播放器全屏衬底固定黑色，与亮/暗主题无关
      color: AppColors.mediaScrimBlack,
      child: Stack(
        fit: StackFit.expand,
        // 控制层由 buildVideo 内层的 VideoControllerOverlay 提供（见 :189），
        // 它自带播放/暂停、进度条、时长、全屏与返回。
        // ⚠️ 不要再往这里挂 buildPlayControlButton / buildBackButton ——
        // 那两个确实是死代码，但把它们加回来会得到**第二套**返回键和播放按钮。
        // BUG#75「视频页只剩一个返回键」的真因是 VideoControllerOverlay 在
        // loose 约束下坍缩成 0×0（见 video_controller.dart 的 BUG#68 注释），
        // 已由 SizedBox.expand 修掉，与这两个 builder 无关。
        children: [buildVideo(context)],
      ),
    );
  }
}
