import 'package:flutter/widgets.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, User;

import 'app_plugin.dart';
import 'plugin_services.dart';

typedef MessageViewModel = CustomMessage;

enum MessagePluginSurface { bubble, standalone }

class MessageRenderContext {
  const MessageRenderContext({
    required this.context,
    required this.type,
    required this.user,
    required this.isSentByMe,
    required this.bubbleWrapper,
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
  final bool isSentByMe;
  final Widget Function(Widget child) bubbleWrapper;
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

  MessagePluginSurface get surface;

  Widget build(MessageViewModel message, MessageRenderContext context);
}
