import 'package:flutter/material.dart';
import 'package:imboy/component/chat/message_audio_builder.dart';
import 'package:imboy/component/chat/message_expression_builder.dart';
import 'package:imboy/component/chat/message_file_builder.dart';
import 'package:imboy/component/chat/message_history_bundle_builder.dart';
import 'package:imboy/component/chat/message_image_builder.dart';
import 'package:imboy/component/chat/message_image_multi_builder.dart';
import 'package:imboy/component/chat/message_location_builder.dart';
import 'package:imboy/component/chat/message_quote_builder.dart';
import 'package:imboy/component/chat/message_unsupported_builder.dart';
import 'package:imboy/component/chat/message_video_builder.dart';
import 'package:imboy/component/chat/message_visit_card_builder.dart';
import 'package:imboy/component/chat/message_channel_card_builder.dart';
import 'package:imboy/component/chat/message_talk_record_card_builder.dart';
import 'package:imboy/component/chat/message_link_card_builder.dart';
import 'package:imboy/component/chat/message_business_action_card_builder.dart';
import 'package:imboy/component/chat/message_webrtc_builder.dart';
import 'package:imboy/component/chat/message_red_packet_builder.dart';
import 'package:imboy/component/chat/message_transfer_builder.dart';
import 'package:imboy/component/chat/message_group_schedule_builder.dart';
import 'package:imboy/component/chat/message_group_vote_builder.dart';
import 'package:imboy/component/chat/message_group_task_builder.dart';
import 'package:imboy/component/chat/message_group_notice_builder.dart';
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
    FileMessageTypePlugin(),
    LocationMessageTypePlugin(),
    ExpressionMessageTypePlugin(),
    QuoteMessageTypePlugin(),
    WebrtcAudioMessageTypePlugin(),
    WebrtcVideoMessageTypePlugin(),
    _VisitCardMessageTypePlugin(),
    _ChannelCardMessageTypePlugin(),
    _TalkRecordCardMessageTypePlugin(),
    // V3-23 企业应用代发点名卡片（matrix spec §5 D1/D2）
    _LinkCardMessageTypePlugin(),
    _BusinessActionCardMessageTypePlugin(),
    // 合并转发聊天记录（chat_history_bundle_v1，多选消息计划 W3-I）
    ChatHistoryBundleMessageTypePlugin(),
    UnsupportedMessageTypePlugin(),
    RedPacketMessageTypePlugin(),
    TransferMessageTypePlugin(),
    GroupScheduleMessageTypePlugin(),
    GroupVoteMessageTypePlugin(),
    GroupTaskMessageTypePlugin(),
    GroupNoticeMessageTypePlugin(),
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
    return VisitCardMessageBuilder(message: message, user: context.user);
  }
}

class _ChannelCardMessageTypePlugin implements MessageTypePlugin {
  const _ChannelCardMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.channelCard}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.channelCard;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return ChannelCardMessageBuilder(message: message, user: context.user);
  }
}

class _TalkRecordCardMessageTypePlugin implements MessageTypePlugin {
  const _TalkRecordCardMessageTypePlugin();
  @override
  String get id => 'builtin:${MessageType.talkRecordCard}';
  @override
  bool get isEnabled => true;
  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;
  @override
  String get type => MessageType.talkRecordCard;
  @override
  Widget build(MessageViewModel message, MessageRenderContext context) =>
      TalkRecordCardMessageBuilder(message: message);
}

/// V3-23 链接卡片（企业应用代发点名类型，matrix spec §5 D1/D2）。
class _LinkCardMessageTypePlugin implements MessageTypePlugin {
  const _LinkCardMessageTypePlugin();
  @override
  String get id => 'builtin:${MessageType.linkCard}';
  @override
  bool get isEnabled => true;
  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;
  @override
  String get type => MessageType.linkCard;
  @override
  Widget build(MessageViewModel message, MessageRenderContext context) =>
      LinkCardMessageBuilder(message: message, user: context.user);
}

/// V3-23 业务操作卡片（含跳转，DELIVERY_SCOPE D06 客户补充项；
/// matrix spec §5 D1/D2）。
class _BusinessActionCardMessageTypePlugin implements MessageTypePlugin {
  const _BusinessActionCardMessageTypePlugin();
  @override
  String get id => 'builtin:${MessageType.businessActionCard}';
  @override
  bool get isEnabled => true;
  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;
  @override
  String get type => MessageType.businessActionCard;
  @override
  Widget build(MessageViewModel message, MessageRenderContext context) =>
      BusinessActionCardMessageBuilder(message: message, user: context.user);
}
