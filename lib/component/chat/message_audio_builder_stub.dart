// 音频消息组件 - Web 平台存根
//
// 此文件是条件导入的存根，用于不支持 audio_waveforms 的平台（如 Web）
// 实际的 AudioMessageBuilder 不会在这些平台使用

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/theme/theme_manager.dart';
import 'package:imboy/component/chat/message_spacing.dart';

/// Web 平台占位符音频组件
class AudioMessageBuilder extends StatefulWidget {
  final String type;
  final User user;
  final CustomMessage? message;
  final Map<String, dynamic>? info;
  final Function()? onPlay;
  final bool isPlaying;
  final bool isPaused;
  final int currentPositionMs;
  final int currentDurationMs;
  final Function(String audioPath, CustomMessage msg, Duration totalDuration)?
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
  State<AudioMessageBuilder> createState() => _AudioMessageBuilderStubState();
}

class _AudioMessageBuilderStubState extends State<AudioMessageBuilder> {
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 200, minHeight: 60),
      decoration: BoxDecoration(
        color: ThemeManager.instance.getThemeColor('surfaceContainerLow'),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: MessageSpacing.bubblePaddingAll,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.audiotrack, size: 24),
            const SizedBox(width: 12),
            Text(
              'Web 平台暂不支持语音消息播放',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
