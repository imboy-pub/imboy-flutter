import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, User;

import 'app_plugin.dart';
import 'plugin_services.dart';

typedef MessageViewModel = CustomMessage;

class MessageRenderContext {
  const MessageRenderContext({
    required this.context,
    required this.type,
    required this.user,
    this.onPlayPause,
    this.isPlaying = false,
    this.isPaused = false,
    this.currentPositionMs = 0,
    this.currentDurationMs = 0,
    this.messages,
    this.services = const PluginServices(),
  });

  final BuildContext context;
  final String type;
  final User user;
  final void Function(
    String audioPath,
    CustomMessage msg,
    Duration totalDuration,
  )?
  onPlayPause;
  final bool isPlaying;
  final bool isPaused;
  final int currentPositionMs;
  final int currentDurationMs;
  final List<dynamic>? messages;
  final PluginServices services;
}

abstract interface class MessageTypePlugin implements AppPlugin {
  String get type;

  Widget build(MessageViewModel message, MessageRenderContext context);
}
