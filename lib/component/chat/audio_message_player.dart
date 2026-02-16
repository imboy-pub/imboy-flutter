import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/service/voice_playback_service.dart';

/// 音频消息播放器组件
///
/// 使用 VoicePlaybackService 统一管理播放状态
/// 显示播放按钮、波纹动画和时长信息
class AudioMessagePlayerWidget extends ConsumerStatefulWidget {
  final String audioUri;
  final int durationMs;
  final String messageId;
  final bool isSentByMe;
  final VoidCallback? onPlayComplete;

  const AudioMessagePlayerWidget({
    super.key,
    required this.audioUri,
    required this.durationMs,
    required this.messageId,
    required this.isSentByMe,
    this.onPlayComplete,
  });

  @override
  ConsumerState<AudioMessagePlayerWidget> createState() =>
      _AudioMessagePlayerWidgetState();
}

class _AudioMessagePlayerWidgetState
    extends ConsumerState<AudioMessagePlayerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimation();
  }

  void _initAnimation() {
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _waveAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _waveAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _waveController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _waveController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(AudioMessagePlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messageId != oldWidget.messageId) {
      _updateAnimationState();
    }
  }

  void _updateAnimationState() {
    // 动画状态更新将在 build 中通过 ref.watch 处理
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  String _formatDuration(int milliseconds) {
    final minutes = (milliseconds ~/ 60000).toString().padLeft(2, '0');
    final seconds = ((milliseconds % 60000) ~/ 1000).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(voicePlaybackServiceProvider);

    final isCurrentMessagePlaying =
        playbackState.currentMessageId == widget.messageId &&
            playbackState.isPlaying;
    final isCurrentMessagePaused =
        playbackState.currentMessageId == widget.messageId &&
            playbackState.isPaused;

    // 根据播放状态控制动画
    if (isCurrentMessagePlaying && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (!isCurrentMessagePlaying && _waveController.isAnimating) {
      _waveController.stop();
      _waveController.reset();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 背景颜色
    final bgColor = widget.isSentByMe
        ? theme.colorScheme.primaryContainer
        : (isDark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFF0F0F0));

    // 图标和文本颜色
    final iconColor = widget.isSentByMe
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.primary;

    final textColor = widget.isSentByMe
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            ref.read(voicePlaybackServiceProvider.notifier).play(
              path: widget.audioUri,
              messageId: widget.messageId,
              durationMs: widget.durationMs,
            );
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 播放按钮 - 增强动画效果
                _buildPlayButton(iconColor, isCurrentMessagePlaying),
                const SizedBox(width: 12),

                // 波纹动画 - 增强视觉效果
                _buildWaveform(iconColor, isCurrentMessagePlaying),

                const SizedBox(width: 12),

                // 时长显示
                _buildDurationDisplay(
                  textColor,
                  playbackState,
                  isCurrentMessagePlaying,
                  isCurrentMessagePaused,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(Color iconColor, bool isPlaying) {
    return AnimatedBuilder(
      animation: _waveAnimation,
      builder: (context, child) {
        // 播放时使用更明显的缩放效果
        final scale = isPlaying ? _waveAnimation.value * 1.15 : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.3),
                width: 1,
              ),
              // 添加发光效果
              boxShadow: isPlaying
                  ? [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: iconColor,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaveform(Color color, bool isPlaying) {
    return SizedBox(
      width: 100,
      height: 32,
      child: isPlaying
          ? AnimatedBuilder(
              animation: _waveAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _EnhancedWaveformPainter(
                    animationValue: _waveAnimation.value,
                    color: color.withValues(alpha: 0.8),
                    isPlaying: true,
                  ),
                );
              },
            )
          : CustomPaint(
              painter: _EnhancedWaveformPainter(
                animationValue: 0,
                color: color.withValues(alpha: 0.5),
                isPlaying: false,
              ),
            ),
    );
  }

  Widget _buildDurationDisplay(
    Color textColor,
    VoicePlaybackState playbackState,
    bool isCurrentMessagePlaying,
    bool isCurrentMessagePaused,
  ) {
    String durationText;

    if (isCurrentMessagePlaying || isCurrentMessagePaused) {
      final currentStr = _formatDuration(playbackState.currentPosition);
      final totalStr = _formatDuration(
        playbackState.currentDuration > 0
            ? playbackState.currentDuration
            : widget.durationMs,
      );
      durationText = '$currentStr/$totalStr';
    } else {
      durationText = _formatDuration(widget.durationMs);
    }

    return Text(
      durationText,
      style: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: 'SF Mono',
      ),
    );
  }
}

/// 增强的波形绘制器
class _EnhancedWaveformPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  final bool isPlaying;

  _EnhancedWaveformPainter({
    required this.animationValue,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final barCount = 25;
    final barWidth = size.width / barCount;
    final baseHeight = size.height * 0.25;

    for (int i = 0; i < barCount; i++) {
      double height;

      if (isPlaying) {
        // 播放时：动态波浪效果，更明显的起伏
        final progress = (i / barCount);
        final wave1 =
            math.sin(progress * math.pi * 2 + animationValue * math.pi * 4);
        final wave2 = math.sin(
          progress * math.pi * 3 + animationValue * math.pi * 2.5,
        );
        final combinedWave = (wave1 + wave2) / 2;
        height = baseHeight + (size.height * 0.7 * (0.5 + 0.5 * combinedWave));
      } else {
        // 未播放时：静态波形，中间高两边低
        final progress = (i / barCount);
        final centerOffset = 1 - 2 * (progress - 0.5).abs();
        height = baseHeight + (size.height * 0.4 * centerOffset);
      }

      final x = i * barWidth + barWidth / 2;
      final y = (size.height - height) / 2;

      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EnhancedWaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.color != color ||
        oldDelegate.isPlaying != isPlaying;
  }
}
