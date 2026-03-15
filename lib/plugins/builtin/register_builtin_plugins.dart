import 'package:flutter/material.dart';
import 'package:imboy/component/chat/message_image_builder.dart';
import 'package:imboy/component/chat/message_unsupported_builder.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/plugins/registry/message_type_registry.dart';
import 'package:imboy/service/message_type_constants.dart';

void registerBuiltinPlugins(MessageTypeRegistry registry) {
  registry.registerAll(const <MessageTypePlugin>[
    _TextMessageTypePlugin(),
    _ImageMessageTypePlugin(),
    _UnsupportedMessageTypePlugin(),
  ]);
}

class _TextMessageTypePlugin implements MessageTypePlugin {
  const _TextMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.text}';

  @override
  bool get isEnabled => true;

  @override
  String get type => MessageType.text;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    final text = message.metadata?['text']?.toString() ?? '';
    return Text(text);
  }
}

class _ImageMessageTypePlugin implements MessageTypePlugin {
  const _ImageMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.image}';

  @override
  bool get isEnabled => true;

  @override
  String get type => MessageType.image;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return MessageImageBuilder(
      type: context.type,
      message: message,
      user: context.user,
      allMessages: context.messages,
    );
  }
}

class _UnsupportedMessageTypePlugin implements MessageTypePlugin {
  const _UnsupportedMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.unsupported}';

  @override
  bool get isEnabled => true;

  @override
  String get type => MessageType.unsupported;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return ImUnsupportedMessageBuilder(
      type: context.type,
      message: message,
      user: context.user,
    );
  }
}
