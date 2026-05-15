import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

class VideoControllerOverlay extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onFullScreenPressed;
  final bool isFullScreen;

  const VideoControllerOverlay({
    super.key,
    required this.controller,
    required this.onFullScreenPressed,
    this.isFullScreen = false,
  });

  @override
  State<VideoControllerOverlay> createState() => _VideoControllerOverlayState();
}

class _VideoControllerOverlayState extends State<VideoControllerOverlay> {
  bool _showControls = true;
  late Timer _hideTimer;
  bool _showGestureFeedback = false;
  Offset? _dragStartPosition;
  double _dragDelta = 0.0;
  String _gestureType = '';

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideTimer();
      } else {
        _hideTimer.cancel();
      }
    });
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    _dragStartPosition = details.localPosition;
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (_dragStartPosition == null) return;

    final delta = details.localPosition.dx - _dragStartPosition!.dx;
    _dragDelta = delta;

    if (delta.abs() > 10) {
      setState(() {
        _showGestureFeedback = true;
        _gestureType = delta > 0 ? 'forward' : 'backward';
      });
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_dragStartPosition == null) return;

    final currentPosition = widget.controller.value.position;

    if (_dragDelta.abs() > 50) {
      final seekDuration = Duration(
        seconds: (_dragDelta.abs() / 100 * 10).round(),
      );

      if (_dragDelta > 0) {
        // 向前快进
        widget.controller.seekTo(currentPosition + seekDuration);
      } else {
        // 向后快退
        widget.controller.seekTo(currentPosition - seekDuration);
      }
    }

    setState(() {
      _showGestureFeedback = false;
      _dragStartPosition = null;
      _dragDelta = 0.0;
    });

    _startHideTimer();
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    _dragStartPosition = details.localPosition;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_dragStartPosition == null) return;

    final delta = details.localPosition.dy - _dragStartPosition!.dy;
    _dragDelta = delta;

    if (delta.abs() > 10) {
      setState(() {
        _showGestureFeedback = true;
        _gestureType = delta > 0 ? 'volume_down' : 'volume_up';
      });
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _showGestureFeedback = false;
      _dragStartPosition = null;
      _dragDelta = 0.0;
    });

    _startHideTimer();
  }

  void _handleDoubleTap() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }

    setState(() {
      _showControls = true;
      _startHideTimer();
    });
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

  Widget _buildGestureFeedback() {
    if (!_showGestureFeedback) return const SizedBox.shrink();

    IconData icon;
    String text;
    Color color;

    switch (_gestureType) {
      case 'forward':
        icon = Icons.fast_forward_rounded;
        text = t.chat.fastForward(
          seconds: (_dragDelta.abs() / 100 * 10).round().toString(),
        );
        color = Colors.blueAccent;
        break;
      case 'backward':
        icon = Icons.fast_rewind_rounded;
        text = t.main.fastRewind(
          seconds: (_dragDelta.abs() / 100 * 10).round().toString(),
        );
        color = Colors.blueAccent;
        break;
      case 'volume_up':
        icon = Icons.volume_up_rounded;
        text = t.main.volumeUp;
        color = Colors.greenAccent;
        break;
      case 'volume_down':
        icon = Icons.volume_down_rounded;
        text = t.main.volumeDown;
        color = Colors.orangeAccent;
        break;
      default:
        icon = Icons.info_outline_rounded;
        text = '';
        color = Colors.white;
    }

    return Positioned.fill(
      child: Center(
        child: AnimatedOpacity(
          opacity: _showGestureFeedback ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(
                0xCC000000,
              ), // Colors.black.withValues(alpha: 0.8)
              borderRadius: AppRadius.borderRadiusRegular,
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0x80000000,
                  ), // Colors.black.withValues(alpha: 0.5)
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 52),
                const SizedBox(height: 12),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: const Color(
                          0xCC000000,
                        ), // Colors.black.withValues(alpha: 0.8)
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleControls,
      onDoubleTap: _handleDoubleTap,
      onHorizontalDragStart: _handleHorizontalDragStart,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      onVerticalDragStart: _handleVerticalDragStart,
      onVerticalDragUpdate: _handleVerticalDragUpdate,
      onVerticalDragEnd: _handleVerticalDragEnd,
      child: Stack(
        children: [
          // 控制层背景渐变
          if (_showControls)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(
                        0x99000000,
                      ), // Colors.black.withValues(alpha: 0.6)
                      Colors.transparent,
                      Colors.transparent,
                      const Color(
                        0x99000000,
                      ), // Colors.black.withValues(alpha: 0.6)
                    ],
                  ),
                ),
              ),
            ),

          // 顶部控制栏
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          widget.isFullScreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: widget.onFullScreenPressed,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 底部控制栏
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // 进度条
                      ValueListenableBuilder(
                        valueListenable: widget.controller,
                        builder: (context, VideoPlayerValue value, child) {
                          return SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                            ),
                            child: Slider(
                              value: value.position.inMilliseconds.toDouble(),
                              min: 0,
                              max: value.duration.inMilliseconds.toDouble(),
                              onChanged: (double newValue) {
                                widget.controller.seekTo(
                                  Duration(milliseconds: newValue.round()),
                                );
                              },
                              onChangeEnd: (double newValue) {
                                widget.controller.seekTo(
                                  Duration(milliseconds: newValue.round()),
                                );
                                if (!value.isPlaying) {
                                  widget.controller.play();
                                }
                              },
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      // 时间信息和播放控制
                      Row(
                        children: [
                          ValueListenableBuilder(
                            valueListenable: widget.controller,
                            builder: (context, VideoPlayerValue value, child) {
                              return Text(
                                _formatDuration(value.position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),

                          const Spacer(),

                          ValueListenableBuilder(
                            valueListenable: widget.controller,
                            builder: (context, VideoPlayerValue value, child) {
                              return Text(
                                _formatDuration(value.duration),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 播放控制按钮
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.replay_10,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              final currentPosition =
                                  widget.controller.value.position;
                              widget.controller.seekTo(
                                currentPosition - const Duration(seconds: 10),
                              );
                            },
                          ),

                          const SizedBox(width: 24),

                          ValueListenableBuilder(
                            valueListenable: widget.controller,
                            builder: (context, VideoPlayerValue value, child) {
                              return IconButton(
                                icon: Icon(
                                  value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 36,
                                ),
                                onPressed: () {
                                  if (value.isPlaying) {
                                    widget.controller.pause();
                                  } else {
                                    widget.controller.play();
                                  }
                                },
                              );
                            },
                          ),

                          const SizedBox(width: 24),

                          IconButton(
                            icon: const Icon(
                              Icons.forward_10,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              final currentPosition =
                                  widget.controller.value.position;
                              widget.controller.seekTo(
                                currentPosition + const Duration(seconds: 10),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 中央播放按钮（当控制栏隐藏时）
          if (!_showControls)
            Positioned.fill(
              child: Center(
                child: ValueListenableBuilder(
                  valueListenable: widget.controller,
                  builder: (context, VideoPlayerValue value, child) {
                    return AnimatedOpacity(
                      opacity: value.isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: const Color(
                          0xCCFFFFFF,
                        ), // Colors.white.withValues(alpha: 0.8)
                        size: 56,
                      ),
                    );
                  },
                ),
              ),
            ),

          // 手势反馈
          _buildGestureFeedback(),
        ],
      ),
    );
  }
}
