import 'package:flutter/material.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';

import 'message_audio_builder_stub.dart'
    if (dart.library.io) 'message_audio_builder_mobile.dart'
    show AudioMessageBuilder;

export 'message_audio_builder_stub.dart'
    if (dart.library.io) 'message_audio_builder_mobile.dart';

class VoiceMessageTypePlugin implements MessageTypePlugin {
  const VoiceMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.voice}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.voice;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return AudioMessageBuilder(
      type: context.type,
      message: message,
      user: context.user,
      onPlayPause: context.onPlayPause,
      isPlaying: context.isPlaying,
      isPaused: context.isPaused,
      currentPositionMs: context.currentPositionMs,
      currentDurationMs: context.currentDurationMs,
    );
  }
}
