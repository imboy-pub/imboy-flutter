import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/imboy_cached_image_provider.dart';
import 'package:imboy/component/video/video_controller.dart';
import 'package:imboy/config/const.dart';
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
    File? tmpF = await IMBoyCacheManager().getSingleFile(
      widget.url,
      validateImageData: false, // 视频文件不验证图片格式
    );
    debugPrint(
      "chat_video_initializePlayer ${AssetsService.viewUrl(widget.url)}",
    );
    try {
      _controller = VideoPlayerController.file(tmpF);
      await _controller?.initialize();
      if (mounted) {
        setState(() {
          hasLoaded = true;
        });
      }
      _controller?.addListener(videoControllerListener);
      _controller?.setLooping(true);
    } catch (e) {
      // Handle error for iOS and Android
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
    } catch (e) {
      // Handle error
    }
  }

  Widget buildBackButton(BuildContext context) {
    return Semantics(
      sortKey: const OrdinalSortKey(0),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tight(Size.square(28)),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          iconSize: 18,
          icon: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.keyboard_return_rounded,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildPlayControlButton(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isPlaying,
      builder: (_, bool value, Widget? child) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: playButtonCallback,
        child: Center(
          child: AnimatedOpacity(
            duration: kThemeAnimationDuration,
            opacity: value ? 0 : 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [BoxShadow(color: Colors.black12)],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_circle_filled,
                size: 70,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildVideo(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: t.play,
        image: true,
        onTapHint: t.play,
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text("${t.loading}..."),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [buildVideo(context)]),
    );
  }
}
