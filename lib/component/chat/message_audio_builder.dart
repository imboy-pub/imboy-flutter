import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:get/get.dart' as getx;

import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:get/get.dart';
import 'package:imboy/service/voice_playback_service.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';

class AudioMessageBuilder extends StatefulWidget {
  final String type;
  final User user;
  final CustomMessage? message;
  final Map<String, dynamic>? info;
  final Function()? onPlay;

  const AudioMessageBuilder({
    super.key,
    required this.type,
    required this.user,
    this.message,
    this.info,
    this.onPlay,
  });

  @override
  // ignore: library_private_types_in_public_api
  _AudioMessageBuilderState createState() => _AudioMessageBuilderState();
}

class _AudioMessageBuilderState extends State<AudioMessageBuilder>
    with SingleTickerProviderStateMixin {
  late Future<String> audioPathFuture;
  late Future<CustomMessage?> messageFuture;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late VoicePlaybackService _playbackService;
  // 仅用于渲染更好看的波形，不用于播放控制
  PlayerController? _waveformController;
  String? _preparedWaveformPath;

  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _playbackService = VoicePlaybackService.to;
    messageFuture = _initMessage();
    audioPathFuture = _initAudioPath();

    // 初始化动画控制器
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 开始播放时的脉冲动画
    _pulseAnimation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _animationController.forward();
      }
    });
  }

  // 仅用于准备波形数据（不用于播放）
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
  void dispose() {
    _animationController.dispose();
    // 安全释放 waveformController，避免平台不支持导致的异常
    try {
      _waveformController?.dispose();
    } catch (e) {
      iPrint('释放 PlayerController 失败: $e');
    }
    _waveformController = null;
    super.dispose();
  }

  Future<CustomMessage?> _initMessage() async {
    if (widget.message != null) {
      return widget.message;
    } else if (widget.info != null) {
      return await MessageModel.fromJson(widget.info!).toTypeMessage()
          as CustomMessage;
    }
    return null;
  }

  Future<String> _initAudioPath() async {
    var msg = await messageFuture;
    if (msg != null) {
      File tmpF = await IMBoyCacheManager().getSingleFile(msg.metadata!['uri']);
      iPrint('Audio file url: ${msg.metadata!['uri']}');
      iPrint('Audio file path: ${tmpF.path}');
      iPrint('Audio file exists: ${await tmpF.exists()}');
      if (await tmpF.exists()) {
        iPrint('Audio file size: ${await tmpF.length()} bytes');
      } else {
        iPrint('Warning: Audio file does not exist at path: ${tmpF.path}');
      }
      return tmpF.path;
    }
    throw Exception('Audio file path initialization failed');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomMessage?>(
      future: messageFuture,
      builder: (context, messageSnapshot) {
        if (!messageSnapshot.hasData) {
          return _buildLoadingWidget();
        }
        final msg = messageSnapshot.data!;
        final bool userIsAuthor = widget.user.id == msg.authorId;

        return FutureBuilder<String>(
          future: audioPathFuture,
          builder: (context, audioPathSnapshot) {
            if (!audioPathSnapshot.hasData) {
              return _buildLoadingWidget();
            }
            final audioPath = audioPathSnapshot.data!;

            // 调试：输出metadata信息
            iPrint('音频消息metadata: ${msg.metadata}');
            final durationMs = msg.metadata?["duration_ms"];
            iPrint('从metadata获取的duration_ms: $durationMs');

            // 获取时长，按优先级：首先使用metadata中的时长，其次使用播放器已获取的实际时长，最后根据文件大小估算时长
            Duration duration;
            final metadataDuration = Duration(milliseconds: durationMs ?? 0);

            // 首先使用metadata中的时长
            if (metadataDuration.inMilliseconds > 0) {
              duration = metadataDuration;
              iPrint('使用metadata时长: ${duration.inMilliseconds}ms');
            } else if (_totalDuration.inMilliseconds > 0) {
              // 其次使用播放器已获取的实际时长
              duration = _totalDuration;
              iPrint('使用播放器时长: ${duration.inMilliseconds}ms');
            } else {
              // 最后根据文件大小估算时长
              duration = _getAudioDuration(audioPath);
              iPrint('使用计算时长: ${duration.inMilliseconds}ms');
            }

            // 更新_totalDuration以确保UI显示正确的时长
            if (_totalDuration.inMilliseconds == 0 &&
                duration.inMilliseconds > 0) {
              // 使用WidgetsBinding.instance.addPostFrameCallback避免在build期间调用setState
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _totalDuration = duration;
                  });
                  iPrint(
                    '更新_totalDuration为: ${_totalDuration.inMilliseconds}ms',
                  );
                }
              });
            }

            return _buildEnhancedAudioMessage(
              audioPath,
              duration,
              msg,
              userIsAuthor,
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      constraints: const BoxConstraints(minWidth: 200, minHeight: 60),
      decoration: BoxDecoration(
        color: ThemeManager.instance.getThemeColor('surfaceContainerLow'),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Padding(
          // 使用统一间距 12dp（之前是 16dp）
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

  Widget _buildEnhancedAudioMessage(
    String audioPath,
    Duration duration,
    CustomMessage msg,
    bool userIsAuthor,
  ) {
    // 准备波形（仅一次）
    _prepareWaveformIfNeeded(audioPath);

    // 使用主题管理器的颜色方案，符合Material 3设计规范
    Color bgColor, iconColor, textColor, waveformColor;

    if (userIsAuthor) {
      // 发送的语音消息使用主题绿色系
      bgColor = ThemeManager.instance.getChatColor('sendMessageBg');
      iconColor = AppColors.sentMessageText;
      textColor = AppColors.sentMessageText;
      waveformColor = Colors.white70;
    } else {
      // 接收的语音消息使用接收消息背景色
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
          onTap: () => _handlePlayPause(audioPath, msg, duration),
          child: Padding(
            // 使用统一间距（之前是 horizontal: 16, vertical: 12）
            padding: MessageSpacing.bubblePaddingSymmetric,
            child: Obx(() {
              // 使用 VoicePlaybackService 全局播放状态
              final bool isCurrent =
                  _playbackService.currentMessageId.value == msg.id;
              final bool isPlayingUI =
                  isCurrent && _playbackService.isPlaying.value;
              final bool isPausedUI =
                  isCurrent && _playbackService.isPaused.value;
              final int currentMs = isCurrent
                  ? _playbackService.currentPosition.value
                  : 0;
              final int totalMs =
                  isCurrent && _playbackService.currentDuration.value > 0
                  ? _playbackService.currentDuration.value
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
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 350),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 播放按钮
                    _buildPlayButton(iconColor, isPlayingUI, isPausedUI),

                    // 使用统一间距 12dp
                    SizedBox(width: MessageSpacing.playButtonSpacing),

                    // 波形显示区域
                    Expanded(
                      child: _buildWaveformView(
                        audioPath,
                        userIsAuthor,
                        waveformColor,
                      ),
                    ),

                    // 使用统一间距 12dp
                    SizedBox(width: MessageSpacing.waveformSpacing),

                    // 时长显示
                    _buildDurationDisplay(
                      textColor,
                      Duration(milliseconds: currentMs),
                      Duration(milliseconds: totalMs),
                      isPlayingUI || isPausedUI,
                    ),

                    // 未读提示
                    if (msg.metadata?['played'] != true && !userIsAuthor)
                      _buildUnreadIndicator(),
                  ],
                ),
              );
            }),
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
    bool userIsAuthor,
    Color waveformColor,
  ) {
    // 使用 audio_waveforms 展示更漂亮的波形（仅渲染，不负责播放）
    final waveColor = userIsAuthor ? Colors.white70 : waveformColor;
    final inactive = userIsAuthor
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
                waveThickness: 1.5, // 必须小于 spacing，避免断言失败
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
      // 只显示总时长，确保至少显示有意义的时间
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
      // 使用统一间距 8dp
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

  // 获取音频文件的实际时长
  Duration _getAudioDuration(String audioPath) {
    try {
      final file = File(audioPath);
      if (!file.existsSync()) {
        iPrint('音频文件不存在，使用默认时长: $audioPath');
        return const Duration(seconds: 1); // 默认1秒
      }

      // 对于AAC文件，可以根据文件大小估算时长
      // AAC 大约 1KB ≈ 0.064秒 (128kbps)
      final fileSize = file.lengthSync();
      final estimatedDurationMs = (fileSize * 64 / 1000).round();
      final duration = Duration(milliseconds: estimatedDurationMs);

      iPrint('根据文件大小估算音频时长: ${fileSize}bytes -> ${duration.inMilliseconds}ms');

      // 确保估算时长至少为1秒，避免显示00:00
      if (duration.inSeconds == 0) {
        iPrint('估算时长为0，调整为1秒');
        return const Duration(seconds: 1);
      }

      return duration;
    } catch (e) {
      iPrint('获取音频时长失败: $e');
      return const Duration(seconds: 1); // 默认1秒
    }
  }

  Future<void> _handlePlayPause(
    String audioPath,
    CustomMessage msg,
    Duration totalDuration,
  ) async {
    try {
      iPrint('Audio play button tapped: ${msg.id}: $audioPath ;');

      // 标记为已播放（拷贝 metadata，避免修改不可变 Map）
      if (msg.metadata?['played'] != true) {
        final Map<String, dynamic> newMeta = {...?msg.metadata, 'played': true};
        final updatedMsg = CustomMessage(
          authorId: msg.authorId,
          createdAt: msg.createdAt,
          id: msg.id,
          metadata: newMeta,
        );
        // 更新UI中的消息对象
        setState(() {
          try {
            final chatLogic = Get.find<ChatLogic>();
            chatLogic.chatController?.updateMessage(msg, updatedMsg);
          } catch (e) {
            iPrint('获取 ChatLogic 实例失败: $e');
          }
        });

        // 持久化到数据库
        Map<String, dynamic> data = {
          'id': msg.id,
          'payload': json.encode(newMeta),
        };
        String tableName = MessageRepo.getTableName(widget.type);
        await MessageRepo(tableName: tableName).update(data);
      }

      // 统一交由全局 VoicePlaybackService 控制
      await _playbackService.play(
        path: audioPath,
        messageId: msg.id,
        durationMs: totalDuration.inMilliseconds,
      );
      setState(() {
        _totalDuration = totalDuration;
      });

      widget.onPlay?.call();
    } catch (e, s) {
      iPrint('播放音频失败: $e; $s');
      // 延迟执行以避免在异步间隙使用BuildContext
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('播放失败: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }
}
