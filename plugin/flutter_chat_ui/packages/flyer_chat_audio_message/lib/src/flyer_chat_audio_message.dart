import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// FlyerChatAudioMessage - 音频消息组件
///
/// 优化的音频消息显示组件，支持：
/// - 波形可视化
/// - 播放/暂停控制
/// - 时长显示
/// - 已播放/未播放状态
class FlyerChatAudioMessage extends StatefulWidget {
  /// The audio message data model.
  final AudioMessage message;

  /// The index of the message in the list.
  final int index;

  /// Border radius of the audio container.
  final BorderRadiusGeometry? borderRadius;

  /// Constraints for the audio size.
  final BoxConstraints? constraints;

  /// Whether to show the status.
  final bool showStatus;

  /// Whether to show the timestamp.
  final bool showTime;

  /// Play state callback.
  final Function(String audioPath, AudioMessage msg, Duration totalDuration)?
  onPlayPause;

  /// Current play state.
  final bool isPlaying;
  final bool isPaused;
  final int currentPositionMs;
  final int currentDurationMs;

  const FlyerChatAudioMessage({
    super.key,
    required this.message,
    required this.index,
    this.borderRadius,
    this.constraints,
    this.showStatus = false,
    this.showTime = true,
    this.onPlayPause,
    this.isPlaying = false,
    this.isPaused = false,
    this.currentPositionMs = 0,
    this.currentDurationMs = 0,
  });

  @override
  State<FlyerChatAudioMessage> createState() => _FlyerChatAudioMessageState();
}

class _FlyerChatAudioMessageState extends State<FlyerChatAudioMessage>
    with SingleTickerProviderStateMixin {
  late Future<String> _audioPathFuture;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  PlayerController? _waveformController;
  String? _preparedWaveformPath;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPathFuture = _initAudioPath();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    try {
      _waveformController?.dispose();
    } catch (e) {
      iPrint('释放 PlayerController 失败: $e');
    }
    _waveformController = null;
    super.dispose();
  }

  Future<String> _initAudioPath() async {
    try {
      final audioUrl = widget.message.source;
      // 音频文件不走图片魔数校验：默认 validateImageData=true 会把下载的音频
      // 当图片校验失败 → 删除重下 → 3 次全失败 → 「初始化音频路径失败」。
      final file = await IMBoyCacheManager().getSingleFile(
        audioUrl,
        validateImageData: false,
      );
      iPrint('Audio file path: ${file.path}');

      if (!await file.exists()) {
        throw Exception('音频文件不存在');
      }

      return file.path;
    } catch (e) {
      iPrint('初始化音频路径失败: $e');
      rethrow;
    }
  }

  Future<void> _prepareWaveformIfNeeded(String audioPath) async {
    try {
      _waveformController ??= PlayerController();
      if (_preparedWaveformPath == audioPath) {
        return;
      }
      await _waveformController!.stopPlayer();
      await _waveformController!.preparePlayer(
        path: audioPath,
        shouldExtractWaveform: true,
      );
      _preparedWaveformPath = audioPath;
    } catch (e) {
      iPrint('准备波形数据失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _audioPathFuture,
      builder: (context, audioPathSnapshot) {
        if (!audioPathSnapshot.hasData) {
          return _buildLoadingWidget();
        }
        final audioPath = audioPathSnapshot.data!;

        final durationMs = widget.message.metadata?["duration_ms"];
        final metadataDuration = Duration(milliseconds: durationMs ?? 0);

        Duration duration;
        if (metadataDuration.inMilliseconds > 0) {
          duration = metadataDuration;
        } else if (_totalDuration.inMilliseconds > 0) {
          duration = _totalDuration;
        } else {
          duration = _getAudioDuration(audioPath);
        }

        if (_totalDuration.inMilliseconds == 0 && duration.inMilliseconds > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _totalDuration = duration;
              });
            }
          });
        }

        return _buildAudioMessage(audioPath, duration);
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      constraints: const BoxConstraints(minWidth: 200, minHeight: 60),
      decoration: BoxDecoration(
        color: ThemeManager.instance.getThemeColor('surfaceContainerLow'),
        borderRadius: widget.borderRadius ?? BorderRadius.circular(20),
      ),
      child: Center(
        child: Padding(
          padding: MessageSpacing.bubblePaddingAll,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(
              ThemeManager.instance.getThemeColor('primary'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioMessage(String audioPath, Duration duration) {
    // 检查是否为发送者
    final isSentByMe = widget.message.authorId == UserRepoLocal.to.currentUid;

    // 准备波形
    _prepareWaveformIfNeeded(audioPath);

    // 主题颜色
    Color bgColor, iconColor, textColor, waveformColor;

    if (isSentByMe) {
      bgColor = ThemeManager.instance.getChatColor('sendMessageBg');
      iconColor = AppColors.sentMessageText;
      textColor = AppColors.sentMessageText;
      waveformColor = Colors.white70;
    } else {
      bgColor = ThemeManager.instance.getChatColor('receivedMessageBg');
      iconColor = ThemeManager.instance.getThemeColor('primary');
      textColor = ThemeManager.instance.getChatColor('receivedMessageText');
      waveformColor = ThemeManager.instance
          .getThemeColor('primary')
          .withValues(alpha: 0.7);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(20),
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
          borderRadius:
              widget.borderRadius?.resolve(Directionality.of(context)) ??
              BorderRadius.circular(20),
          onTap: () => _handlePlayPause(audioPath, duration),
          child: Padding(
            padding: MessageSpacing.bubblePaddingSymmetric,
            child: Builder(
              builder: (context) {
                final isPlayingUI = widget.isPlaying;
                final isPausedUI = widget.isPaused;
                final currentMs = widget.currentPositionMs;
                final totalMs = widget.currentDurationMs > 0
                    ? widget.currentDurationMs
                    : (duration.inMilliseconds > 0
                          ? duration.inMilliseconds
                          : _totalDuration.inMilliseconds);

                // 控制脉冲动画
                if (isPlayingUI) {
                  if (!_animationController.isAnimating) {
                    _animationController.forward();
                  }
                } else {
                  if (_animationController.isAnimating) {
                    _animationController.stop();
                    _animationController.reset();
                  }
                }

                return ConstrainedBox(
                  constraints:
                      widget.constraints ??
                      const BoxConstraints(minWidth: 200, maxWidth: 350),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 播放按钮
                      _buildPlayButton(iconColor, isPlayingUI, isPausedUI),

                      SizedBox(width: MessageSpacing.playButtonSpacing),

                      // 波形显示
                      Expanded(
                        child: _buildWaveformView(
                          audioPath,
                          isSentByMe,
                          waveformColor,
                        ),
                      ),

                      SizedBox(width: MessageSpacing.waveformSpacing),

                      // 时长显示
                      _buildDurationDisplay(
                        textColor,
                        Duration(milliseconds: currentMs),
                        Duration(milliseconds: totalMs),
                        isPlayingUI || isPausedUI,
                      ),

                      // 未读提示
                      if (widget.message.metadata?['played'] != true &&
                          !isSentByMe)
                        _buildUnreadIndicator(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(Color iconColor, bool isPlayingUI, bool isPausedUI) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isPlayingUI ? _pulseAnimation.value : 1.0,
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
            ),
            child: Icon(
              isPlayingUI
                  ? (isPausedUI ? Icons.play_arrow : Icons.pause)
                  : Icons.play_arrow,
              color: iconColor,
              size: 20,
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaveformView(
    String audioPath,
    bool isSentByAuthor,
    Color waveformColor,
  ) {
    final waveColor = isSentByAuthor ? Colors.white70 : waveformColor;
    final inactive = isSentByAuthor
        ? Colors.white.withValues(alpha: 0.25)
        : waveformColor.withValues(alpha: 0.25);

    return SizedBox(
      height: 32,
      child: (_waveformController == null)
          ? const SizedBox.shrink()
          : AudioFileWaveforms(
              size: const Size(double.infinity, 32),
              playerController: _waveformController!,
              enableSeekGesture: false,
              playerWaveStyle: PlayerWaveStyle(
                fixedWaveColor: inactive,
                liveWaveColor: waveColor,
                waveCap: StrokeCap.round,
                spacing: 2,
                showSeekLine: false,
                showBottom: false,
                waveThickness: 1.5,
                scaleFactor: 50,
              ),
            ),
    );
  }

  Widget _buildDurationDisplay(
    Color textColor,
    Duration current,
    Duration total,
    bool active,
  ) {
    String durationText;
    if (active) {
      final currentStr = _formatDuration(current);
      final totalStr = _formatDuration(total);
      durationText = '$currentStr/$totalStr';
    } else {
      final totalStr = total.inMilliseconds > 0
          ? _formatDuration(total)
          : "00:01";
      durationText = totalStr;
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

  Widget _buildUnreadIndicator() {
    return Container(
      margin: const EdgeInsets.only(left: MessageSpacing.unreadIndicatorMargin),
      width: MessageSpacing.unreadIndicatorSize,
      height: MessageSpacing.unreadIndicatorSize,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Duration _getAudioDuration(String audioPath) {
    try {
      final file = File(audioPath);
      if (!file.existsSync()) {
        return const Duration(seconds: 1);
      }

      // AAC 大约 1KB ≈ 0.064秒 (128kbps)
      final fileSize = file.lengthSync();
      final estimatedDurationMs = (fileSize * 64 / 1000).round();
      final duration = Duration(milliseconds: estimatedDurationMs);

      if (duration.inSeconds == 0) {
        return const Duration(seconds: 1);
      }

      return duration;
    } catch (e) {
      iPrint('获取音频时长失败: $e');
      return const Duration(seconds: 1);
    }
  }

  Future<void> _handlePlayPause(
    String audioPath,
    Duration totalDuration,
  ) async {
    try {
      iPrint('Audio play button tapped: ${widget.message.id}: $audioPath');

      // 标记为已播放
      if (widget.message.metadata?['played'] != true) {
        final newMeta = {...?widget.message.metadata, 'played': true};

        // 获取表名 - 需要从上下文获取或使用默认值
        final tableName = MessageRepo.getTableName('C2C');

        await MessageRepo(
          tableName: tableName,
        ).update({'id': widget.message.id, 'payload': json.encode(newMeta)});
      }

      setState(() {
        _totalDuration = totalDuration;
      });

      // 使用回调处理播放逻辑
      widget.onPlayPause?.call(audioPath, widget.message, totalDuration);
    } catch (e, s) {
      iPrint('播放音频失败: $e; $s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.common.audioPlayFailed}: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
