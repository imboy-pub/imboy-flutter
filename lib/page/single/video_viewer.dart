import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;
import 'package:video_player/video_player.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/service/encrypter.dart';

class VideoViewerPage extends StatefulWidget {
  final String url;
  final String thumb;

  const VideoViewerPage({
    super.key,
    required this.url,
    required this.thumb,
  });

  @override
  // ignore: library_private_types_in_public_api
  _VideoViewerPageState createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<VideoViewerPage> {
  VideoPlayerController? _controller;

  /// Whether the player is playing.
  /// 播放器是否在播放
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);

  /// Whether the controller is playing.
  /// 播放控制器是否在播放
  bool get isControllerPlaying =>
      _controller == null ? false : _controller!.value.isPlaying;

  /// Whether the controller has initialized.
  /// 控制器是否已初始化
  late bool hasLoaded = false;

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

  Future<void> initializePlayer() async {
    final String viewUrl = AssetsService.viewUrl(widget.url).toString();
    File? tmpF = await IMBoyCacheManager().getSingleFile(
      viewUrl,
      key: EncrypterService.md5(widget.url),
    );
    debugPrint("chat_video_initializePlayer $viewUrl");
    try {
      _controller = VideoPlayerController.file(tmpF);
      // _controller = VideoPlayerController.network(viewUrl);

      _controller?.initialize().then((value) {
        setState(() {});

        hasLoaded = true;
      });

      _controller?.addListener(videoControllerListener);
      _controller?.setLooping(true);
    } catch (e) {
      // 暂时只支持 iOS 和 Android
    }
  }

  /// Listener for the video player.
  /// 播放器的监听方法
  void videoControllerListener() {
    if (isControllerPlaying != isPlaying.value) {
      isPlaying.value = isControllerPlaying;
    }
  }

  /// Callback for the play button.
  /// 播放按钮的回调
  ///
  /// Normally it only switches play state for the player. If the video reaches
  /// the end, then click the button will make the video replay.
  /// 一般来说按钮只切换播放暂停。当视频播放结束时，点击按钮将从头开始播放。
  Future<void> playButtonCallback() async {
    try {
      if (isPlaying.value) {
        _controller?.pause();
      } else {
        if (_controller?.value.duration == _controller?.value.position) {
          _controller!
            ..seekTo(Duration.zero)
            ..play();
        } else {
          _controller?.play();
        }
      }
    } catch (e) {
      // } catch (e, s) {
      // handleErrorWithHandler(e, onError, s: s);
    }
  }

  /// The back button for the preview section.
  /// 预览区的返回按钮
  Widget buildBackButton(BuildContext context) {
    return Semantics(
      sortKey: const OrdinalSortKey(0),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          padding: EdgeInsets.zero,
          constraints: BoxConstraints.tight(const Size.square(28)),
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

  /// A play control button the video playing process.
  /// 控制视频播放的按钮
  Widget buildPlayControlButton(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isPlaying,
      builder: (_, bool value, Widget? child) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: value ? playButtonCallback : null,
        child: Center(
          child: AnimatedOpacity(
            duration: kThemeAnimationDuration,
            opacity: value ? 0 : 1,
            child: GestureDetector(
              onTap: playButtonCallback,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  boxShadow: <BoxShadow>[BoxShadow(color: Colors.black12)],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  value ? Icons.pause_circle_outline : Icons.play_circle_filled,
                  size: 70,
                  color: Colors.white,
                ),
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
        label: 'play'.tr,
        image: true,
        onTapHint: 'play'.tr,
        sortKey: const OrdinalSortKey(1),
        child: n.Stack([
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          buildPlayControlButton(context),
        ]),
      ),
    );
  }

  /// Actions section for the viewer. Including 'back' and 'confirm' button.
  /// 预览的操作区。包括"返回"和"确定"按钮。
  Widget buildForeground(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Semantics(
              sortKey: const OrdinalSortKey(0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: buildBackButton(context),
              ),
            ),
            // Semantics(
            //   sortKey: const OrdinalSortKey(2),
            //   child: Align(
            //     alignment: AlignmentDirectional.centerEnd,
            //     child: buildConfirmButton(context),
            //   ),
            // ),
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
          onPressed: () {
            Get.back();
          },
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
        backgroundColor: Get.theme.cardColor,
        // appBar: null,
        body: Stack(
          alignment: Alignment.centerRight,
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: AssetsService.viewUrl(widget.thumb).toString(),
              width: Get.width,
              height: Get.height,
              progressIndicatorBuilder: (context, url, downloadProgress) =>
                  CircularProgressIndicator(value: downloadProgress.progress),
              errorWidget: (context, url, error) => const Icon(Icons.error),
              cacheManager: cacheManager,
              //cancelToken: cancellationToken,
            ),
            Positioned.fill(
              child: SizedBox(
                height: 100,
                child: Center(
                  child: n.Column(
                    [
                      const CircularProgressIndicator(),
                      Center(
                        child: Text("${'loading'.tr}..."),
                      ),
                    ],
                    // 垂直居中
                    mainAxisAlignment: MainAxisAlignment.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Material(
      color: Colors.black,
      child: n.Stack(
        [
          buildVideo(context),
          buildForeground(context),
        ],
        fit: StackFit.expand,
      ),
    );
  }
}
