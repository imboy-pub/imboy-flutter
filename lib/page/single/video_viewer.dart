import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:get/get.dart';
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
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  bool get isControllerPlaying => _controller?.value.isPlaying ?? false;
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
            child: DecoratedBox(
              decoration: const BoxDecoration(
                boxShadow: [BoxShadow(color: Colors.black12)],
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
    );
  }

  Widget buildVideo(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        label: 'play'.tr,
        image: true,
        onTapHint: 'play'.tr,
        sortKey: const OrdinalSortKey(1),
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
            buildPlayControlButton(context),
          ],
        ),
      ),
    );
  }

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
          onPressed: () => Get.back(),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
        backgroundColor: Get.theme.cardColor,
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
            ),
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text("${'loading'.tr}..."),
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          buildVideo(context),
          buildForeground(context),
        ],
      ),
    );
  }
}
