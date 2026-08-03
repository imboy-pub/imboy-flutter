import 'package:flutter/widgets.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/message_type_constants.dart';

/// 把 `effective_msg_type` 翻成读屏能念出来的类型名。
///
/// CustomMessage 那条渲染链（16 个插件：位置/引用/名片/红包/转账/通话记录/
/// 群日程/贴图/多图…）此前完全没有语义标签——读屏用户翻聊天记录时，这些消息
/// 全是哑的。这里只补"是什么"，气泡内部本来读得出来的文字不动。
String messageKindLabel(String msgType) => switch (msgType) {
  MessageType.image || MessageType.imageMulti => t.chat.image,
  MessageType.voice => t.chat.voiceMessage,
  MessageType.video => t.chat.videoMessage,
  MessageType.file => t.chat.file,
  MessageType.location => t.common.locationMessage,
  MessageType.expression => t.common.expression,
  MessageType.quote => t.main.quote,
  MessageType.visitCard => t.chat.card,
  MessageType.redPacket => t.common.redPacket,
  MessageType.transfer => t.common.transfer,
  MessageType.webrtcAudio => t.common.voiceCall,
  MessageType.webrtcVideo => t.common.videoCall,
  MessageType.groupSchedule => t.groupSchedule.title,
  MessageType.unsupported => t.chat.unsupportedMessageType,
  _ => t.chat.customMessage,
};

/// 给非文字消息补一句"谁发的 + 什么类型"。
///
/// 图片/语音/视频/文件这四类渲染的都是 flyer_chat 的 widget，里面只有缩略图、
/// 波形和图标——读屏用户从上往下翻聊天记录时，这些消息全是哑的，既听不出是
/// 什么，也听不出是自己发的还是对方发的。
///
/// 不用 `ExcludeSemantics` 包住 [child]：文件消息的文件名、语音消息的时长
/// 都是有用信息，这里只在外层加一句限定，不吞掉里面本来读得出来的东西。
Widget semanticMessage({
  required bool isSentByMe,
  required String kind,
  required Widget child,
  bool isButton = true,
}) {
  final who = isSentByMe ? t.main.sentByMe : t.chat.myReceivedTab;
  return Semantics(button: isButton, label: '$who$kind', child: child);
}

/// 该消息类型的气泡是否可点。
///
/// 关系到 [semanticMessage] 要不要声明 button 语义：把不可点的类型也念成
/// "按钮"，读屏用户会去点一个什么都不会发生的东西。原来这个包装只用在
/// 图片/语音/视频/文件四个必定可点的 builder 上，扩到全部消息类型后就得区分。
bool messageKindIsTappable(String msgType) => switch (msgType) {
  MessageType.expression || MessageType.unsupported => false,
  _ => true,
};
