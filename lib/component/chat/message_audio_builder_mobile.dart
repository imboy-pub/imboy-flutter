import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:imboy/theme/default/font_types.dart';

class AudioMessageBuilder extends StatefulWidget {
  final String type;
  final User user;
  final CustomMessage? message;
  final Map<String, dynamic>? info;
  final void Function()? onPlay;
  // 新增：播放状态参数（由父组件传递）
  final bool isPlaying;
  final bool isPaused;
  final int currentPositionMs;
  final int currentDurationMs;
  final void Function(
    String audioPath,
    CustomMessage msg,
    Duration totalDuration,
  )?
  onPlayPause;

  const AudioMessageBuilder({
    super.key,
    required this.type,
    required this.user,
    this.message,
    this.info,
    this.onPlay,
    this.isPlaying = false,
    this.isPaused = false,
    this.currentPositionMs = 0,
    this.currentDurationMs = 0,
    this.onPlayPause,
  });

  @override
  // ignore: library_private_types_in_public_api
  _AudioMessageBuilderState createState() => _AudioMessageBuilderState();
}

class _AudioMessageBuilderState extends State<AudioMessageBuilder>
    with SingleTickerProviderStateMixin {
  // 使用 Completer 来跟踪加载状态
  final Completer<String> _audioPathCompleter = Completer<String>();
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  // 仅用于渲染更好看的波形，不用于播放控制
  PlayerController? _waveformController;
  String? _preparedWaveformPath;

  // 标记插件是否可用，避免重复尝试导致错误日志
  bool _waveformPluginSupported = true;
  bool _waveformInitializationAttempted = false;

  Duration _totalDuration = Duration.zero;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initAudioPath();

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

  // 仅用于准备波形数据（不用于播放控制）
  Future<void> _prepareWaveformIfNeeded(String audioPath) async {
    // 如果已经确认插件不支持，不再尝试
    if (!_waveformPluginSupported) {
      return;
    }

    // 如果已经初始化过且路径相同，跳过
    if (_preparedWaveformPath == audioPath) {
      return;
    }

    try {
      _waveformController ??= PlayerController();
      await _waveformController!.stopPlayer();
      await _waveformController!.preparePlayer(
        path: audioPath,
        shouldExtractWaveform: true,
      );
      _preparedWaveformPath = audioPath;
      _waveformInitializationAttempted = true;
    } catch (e) {
      // 只在第一次尝试时记录错误，避免重复日志
      if (!_waveformInitializationAttempted) {
        iPrint('⚠️ 音频波形插件不可用，将显示简化的音频界面: ${e.runtimeType}');
      }
      // 标记插件不支持，后续不再尝试
      _waveformPluginSupported = false;
      _waveformController = null;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    // 安全释放 waveformController，避免平台不支持导致的异常
    try {
      _waveformController?.dispose();
    } catch (e) {
      iPrint('释放 PlayerController 失败: ${e.runtimeType}');
    }
    _waveformController = null;
    super.dispose();
  }

  Future<void> _initAudioPath() async {
    try {
      // 直接使用 widget.message，避免异步依赖
      final msg = widget.message;
      if (msg == null) {
        // 如果 widget.message 为空，尝试从 info 构建
        if (widget.info != null) {
          final builtMsg =
              await MessageModel.fromJson(widget.info!).toTypeMessage()
                  as CustomMessage;
          _loadAudioFile(builtMsg);
          return;
        }
        throw Exception('消息为空且无 info 数据');
      }
      await _loadAudioFile(msg);
    } catch (e) {
      iPrint('❌ _initAudioPath 失败: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载失败';
        });
      }
    }
  }

  Future<void> _loadAudioFile(CustomMessage msg) async {
    try {
      final uri = msg.metadata!['uri'];
      if (uri == null || uri.toString().isEmpty) {
        throw Exception('音频URI为空');
      }

      iPrint('🎵 开始加载音频文件');

      // 添加30秒超时保护
      final tmpF = await IMBoyCacheManager()
          .getSingleFile(
            uri as String,
            validateImageData: false, // 音频文件不验证图片格式
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              iPrint('⏰ 音频文件加载超时');
              throw Exception('音频文件加载超时（30秒）');
            },
          );

      if (await tmpF.exists()) {
        final fileSize = await tmpF.length();
        if (fileSize == 0) {
          throw Exception('音频文件大小为0');
        }
      } else {
        throw Exception('音频文件不存在: ${tmpF.path}');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
      }
      _audioPathCompleter.complete(tmpF.path);
    } catch (e) {
      iPrint('❌ _loadAudioFile 失败: ${e.runtimeType}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载失败';
        });
      }
      _audioPathCompleter.completeError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 直接使用 widget.message
    final msg = widget.message;
    if (msg == null) {
      return _buildErrorWidget('消息数据为空');
    }
    final bool userIsAuthor = widget.user.id == msg.authorId;

    // 显示加载状态或错误
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null) {
      return _buildErrorWidget(_errorMessage!);
    }

    // 使用 FutureBuilder 监听音频路径加载
    return FutureBuilder<String>(
      future: _audioPathCompleter.future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          iPrint(
            '❌ audioPathSnapshot.hasError: ${snapshot.error?.runtimeType}',
          );
          return _buildErrorWidget('音频加载失败');
        }
        if (!snapshot.hasData) {
          return _buildLoadingWidget();
        }
        final audioPath = snapshot.data!;

        final durationMs = msg.metadata?["duration_ms"];

        // 获取时长
        Duration duration;
        final metadataDuration = Duration(
          milliseconds: (durationMs as int?) ?? 0,
        );

        if (metadataDuration.inMilliseconds > 0) {
          duration = metadataDuration;
        } else if (_totalDuration.inMilliseconds > 0) {
          duration = _totalDuration;
        } else {
          duration = _getAudioDuration(audioPath);
        }

        return _buildEnhancedAudioMessage(
          audioPath,
          duration,
          msg,
          userIsAuthor,
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 200, minHeight: 60),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusLarge,
      ),
      child: Center(
        child: Padding(
          padding: MessageSpacing.bubblePaddingAll,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String errorMsg) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 200, minHeight: 60),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusLarge,
      ),
      child: InkWell(
        onTap: () {
          // 重试加载音频
          setState(() {
            _isLoading = true;
            _errorMessage = null;
            _initAudioPath();
          });
        },
        borderRadius: AppRadius.borderRadiusLarge,
        child: Padding(
          padding: MessageSpacing.bubblePaddingAll,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: AppColors.getIosRed(Theme.of(context).brightness),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '点击重试',
                  style: context.textStyle(
                    FontSizeType.small,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor, iconColor, textColor, waveformColor;

    if (userIsAuthor) {
      bgColor = isDark
          ? AppColors.darkSentMessageBackground
          : AppColors.lightSentMessageBackground;
      iconColor = AppColors.sentMessageText;
      textColor = AppColors.sentMessageText;
      waveformColor = Colors.white70;
    } else {
      // 接收语音气泡背景：统一走 AppColors token，对齐 DESIGN.md 第 9/10 章
      // 暗色 → darkReceivedMessageBackground(#2A2A2A)
      // 亮色 → lightSurfaceContainer(#EDEDED)
      if (isDark) {
        bgColor = AppColors.darkReceivedMessageBackground;
      } else {
        bgColor = AppColors.lightSurfaceContainer;
      }
      iconColor = colorScheme.primary;
      textColor = isDark
          ? AppColors.darkReceivedMessageText
          : AppColors.lightReceivedMessageText;
      waveformColor = colorScheme.primary.withValues(alpha: 0.7);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(MessageSpacing.bubbleBorderRadius),
        // DESIGN.md §9.1：聊天气泡（含语音气泡）不带阴影
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(
            MessageSpacing.bubbleBorderRadius,
          ),
          onTap: () => _handlePlayPause(audioPath, msg, duration),
          child: Padding(
            padding: MessageSpacing.bubblePaddingSymmetric,
            child: Builder(
              builder: (context) {
                final bool isPlayingUI = widget.isPlaying;
                final bool isPausedUI = widget.isPaused;
                final int currentMs = widget.currentPositionMs;
                final int totalMs = widget.currentDurationMs > 0
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
                  constraints: const BoxConstraints(
                    minWidth: 200,
                    maxWidth: 350,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 播放按钮
                      _buildPlayButton(iconColor, isPlayingUI, isPausedUI),
                      SizedBox(width: MessageSpacing.playButtonSpacing),
                      // 波形显示区域
                      Expanded(
                        child: _buildWaveformView(
                          audioPath,
                          userIsAuthor,
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
                      if (msg.metadata?['played'] != true && !userIsAuthor)
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
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isPlayingUI
                    ? (isPausedUI
                          ? CupertinoIcons.play_fill
                          : CupertinoIcons.pause_fill)
                    : CupertinoIcons.play_fill,
                key: ValueKey<bool>(isPlayingUI && !isPausedUI),
                color: iconColor,
                size: 20,
              ),
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
    final waveColor = userIsAuthor ? Colors.white70 : waveformColor;
    final inactive = userIsAuthor
        ? Colors.white.withValues(alpha: 0.25)
        : waveformColor.withValues(alpha: 0.25);

    // 插件不可用时显示简化的波形可视化
    if (!_waveformPluginSupported || _waveformController == null) {
      return AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final isPlaying = widget.isPlaying && !widget.isPaused;
          return SizedBox(
            height: 32,
            child: CustomPaint(
              painter: _SimpleWaveformPainter(
                isActive: isPlaying,
                color: waveColor,
                inactiveColor: inactive,
                progress: isPlaying ? _animationController.value : 0.0,
              ),
              size: const Size(double.infinity, 32),
            ),
          );
        },
      );
    }

    return SizedBox(
      height: 32,
      child: AudioFileWaveforms(
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
      style: context
          .textStyle(
            FontSizeType.small,
            color: textColor,
            fontWeight: FontWeight.w500,
          )
          .copyWith(fontFamily: 'SF Mono'),
    );
  }

  Widget _buildUnreadIndicator() {
    final unreadColor = AppColors.getIosRed(Theme.of(context).brightness);
    return Container(
      margin: const EdgeInsets.only(left: MessageSpacing.unreadIndicatorMargin),
      width: MessageSpacing.unreadIndicatorSize,
      height: MessageSpacing.unreadIndicatorSize,
      decoration: BoxDecoration(
        color: unreadColor,
        shape: BoxShape.circle,
        // DESIGN.md §5.2 例外：未读 Badge 类小指示器轻微 glow
        // alpha 0.3 → 0.15 弱化（保留 spreadRadius 1 维持 glow 视觉）
        boxShadow: [
          BoxShadow(
            color: unreadColor.withValues(alpha: 0.15),
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
        iPrint('音频文件不存在，使用默认时长');
        return const Duration(seconds: 1);
      }

      final fileSize = file.lengthSync();
      final estimatedDurationMs = (fileSize * 64 / 1000).round();
      final duration = Duration(milliseconds: estimatedDurationMs);

      iPrint('根据文件大小估算音频时长: ${duration.inMilliseconds}ms');

      if (duration.inSeconds == 0) {
        return const Duration(seconds: 1);
      }

      return duration;
    } catch (e) {
      iPrint('获取音频时长失败: ${e.runtimeType}');
      return const Duration(seconds: 1);
    }
  }

  Future<void> _handlePlayPause(
    String audioPath,
    CustomMessage msg,
    Duration totalDuration,
  ) async {
    try {
      iPrint('Audio play button tapped: ${msg.id}');

      if (msg.metadata?['played'] != true) {
        final Map<String, dynamic> newMeta = {...?msg.metadata, 'played': true};

        Map<String, dynamic> data = {
          'id': msg.id,
          'payload': json.encode(newMeta),
        };
        String tableName = MessageRepo.getTableName(widget.type);
        await MessageRepo(tableName: tableName).update(data);
      }

      widget.onPlayPause?.call(audioPath, msg, totalDuration);

      if (!mounted) return;
      setState(() {
        _totalDuration = totalDuration;
      });

      widget.onPlay?.call();
    } catch (e) {
      iPrint('播放音频失败: ${e.runtimeType}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final t = context.t;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.common.audioPlayFailed),
              backgroundColor: AppColors.getIosRed(
                Theme.of(context).brightness,
              ),
            ),
          );
        }
      });
    }
  }
}

/// 简单的波形绘制器，用于音频波形插件不可用时（支持动态声波与进度流光动画）
class _SimpleWaveformPainter extends CustomPainter {
  const _SimpleWaveformPainter({
    required this.isActive,
    required this.color,
    required this.inactiveColor,
    this.progress = 0.0,
  });

  final bool isActive;
  final Color color;
  final Color inactiveColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final waveCount = 35;
    final waveWidth = size.width / waveCount;
    final paint = Paint()
      ..strokeWidth = waveWidth * 0.55
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < waveCount; i++) {
      // 1. 根据正弦波与余弦波动效计算实时动态波形高度
      double heightFactor;
      if (isActive) {
        // 利用 progress 加上水平索引偏置，形成非常自然的律动流光效果
        heightFactor =
            0.35 +
            0.55 *
                (0.5 * math.sin(progress * 2 * math.pi + i * 0.45) +
                    0.5 * math.cos(progress * 4 * math.pi - i * 0.2));
      } else {
        // 静止状态下的基础音浪特征
        heightFactor =
            0.2 +
            0.45 * (0.5 + 0.5 * (i % 3 == 0 ? 1.0 : (i % 5 == 0 ? 0.8 : 0.3)));
      }

      final waveHeight = size.height * heightFactor;

      // 2. 音频播放进度条流动高亮效果：
      // 如果当前音浪柱位置在播放进度比例内，就高亮为 active color，否则为 inactiveColor
      final x = i * waveWidth + waveWidth / 2;
      final currentProgressRatio = x / size.width;

      final isHighlighted = isActive
          ? (currentProgressRatio <= progress)
          : false;

      paint.color = isHighlighted ? color : inactiveColor;

      final y1 = (size.height - waveHeight) / 2;
      final y2 = (size.height + waveHeight) / 2;

      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(_SimpleWaveformPainter oldDelegate) {
    return oldDelegate.isActive != isActive || oldDelegate.progress != progress;
  }
}
