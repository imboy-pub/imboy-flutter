import 'package:flutter/material.dart';
import 'package:imboy/component/chat/message_audio_builder.dart';
import 'package:imboy/component/chat/message_image_builder.dart';
import 'package:imboy/component/chat/message_image_multi_builder.dart';
import 'package:imboy/component/chat/message_location_builder.dart';
import 'package:imboy/component/chat/message_quote_builder.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/component/chat/message_unsupported_builder.dart';
import 'package:imboy/component/chat/message_visit_card_builder.dart';
import 'package:imboy/component/chat/message_webrtc_builder.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/plugins/registry/message_type_registry.dart';
import 'package:imboy/service/message_type_constants.dart';

MessageTypeRegistry? _defaultMessageTypeRegistry;

MessageTypeRegistry createBuiltinMessageTypeRegistry() {
  final registry = MessageTypeRegistry();
  registerBuiltinPlugins(registry);
  return registry;
}

MessageTypeRegistry get defaultMessageTypeRegistry {
  _defaultMessageTypeRegistry ??= createBuiltinMessageTypeRegistry();
  return _defaultMessageTypeRegistry!;
}

void registerBuiltinPlugins(MessageTypeRegistry registry) {
  registry.registerAll(const <MessageTypePlugin>[
    _TextMessageTypePlugin(),
    ImageMessageTypePlugin(),
    _ImageMultiMessageTypePlugin(),
    VoiceMessageTypePlugin(),
    VideoMessageTypePlugin(),
    LocationMessageTypePlugin(),
    QuoteMessageTypePlugin(),
    WebrtcAudioMessageTypePlugin(),
    WebrtcVideoMessageTypePlugin(),
    _VisitCardMessageTypePlugin(),
    UnsupportedMessageTypePlugin(),
  ]);
}

class _TextMessageTypePlugin implements MessageTypePlugin {
  const _TextMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.text}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.bubble;

  @override
  String get type => MessageType.text;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    final text = message.metadata?['text']?.toString() ?? '';
    return Text(text);
  }
}

class _ImageMultiMessageTypePlugin implements MessageTypePlugin {
  const _ImageMultiMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.imageMulti}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.bubble;

  @override
  String get type => MessageType.imageMulti;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return ImageMultiMessageBuilder(
      type: context.type,
      message: message,
      user: context.user,
    );
  }
}

class _VisitCardMessageTypePlugin implements MessageTypePlugin {
  const _VisitCardMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.visitCard}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.visitCard;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return Padding(
      padding: MessageSpacing.bubblePaddingSymmetric,
      child: VisitCardMessageBuilder(message: message, user: context.user),
    );
  }
}
