// 音频消息组件 - Web 平台存根
//
// 此文件是条件导入的存根，用于不支持 audio_waveforms 的平台（如 Web）
// 实际的 AudioMessageBuilder 不会在这些平台使用

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Web 平台占位符音频组件
class AudioMessageBuilder extends StatefulWidget {
  final String type;
  final User user;
  final CustomMessage? message;
  final Map<String, dynamic>? info;
  final void Function()? onPlay;
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
  State<AudioMessageBuilder> createState() => _AudioMessageBuilderStubState();
}

class _AudioMessageBuilderStubState extends State<AudioMessageBuilder> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 200, minHeight: 60),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.borderRadiusLarge,
      ),
      child: Padding(
        padding: MessageSpacing.bubblePaddingAll,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.audiotrack, size: 24),
            const SizedBox(width: 12),
            Text(
              t.common.webAudioNotSupported,
              style: context.textStyle(FontSizeType.normal),
            ),
          ],
        ),
      ),
    );
  }
}
