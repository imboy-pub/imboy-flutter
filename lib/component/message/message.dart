import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
// ignore: implementation_imports
import 'package:flutter_chat_ui/src/widgets/state/inherited_user.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;
import 'package:imboy/component/ui/image_view.dart';
import 'package:imboy/config/const.dart';

import 'message_audio_builder.dart';
import 'message_quote_builder.dart';
import 'message_revoked_builder.dart';
import 'message_video_builder.dart';

enum CustomMessageType {
  file,
  image,
  text,
  audio,
  video,
  location,
  // webrtc 音频消息
  webrtcAudio,
  // webrtc 视频消息
  webrtcVideo,
  // 引用消息
  quote,
}

/// A class that represents text message widget with optional link preview
class CustomMessageBuilder extends StatelessWidget {
  /// Creates a text message widget from a [types.TextMessage] class
  const CustomMessageBuilder({
    Key? key,
    required this.message,
  }) : super(key: key);

  /// [types.TextMessage]
  final types.CustomMessage message;

  @override
  Widget build(BuildContext context) {
    debugPrint(
        "> on CustomMessageBuilder ${message.type}, msg: ${message.toJson().toString()}");
    try {
      String customType = message.metadata?['custom_type'] ?? '';
      if (customType == 'revoked') {
        return RevokedMessageBuilder(
          message: message,
          user: InheritedUser.of(context).user,
        );
      } else if (customType == 'quote') {
        return QuoteMessageBuilder(
          message: message,
          user: InheritedUser.of(context).user,
        );
      } else if (customType == 'video') {
        return VideoMessageBuilder(
          message: message,
        );
      } else if (customType == 'audio') {
        return AudioMessageBuilder(
          message: message,
          user: InheritedUser.of(context).user,
        );
      }
    } catch (e) {
      debugPrint("> on CustomMessageBuilder e ${e.toString()}");
    }
    return const SizedBox.shrink();
  }
}

/// 构建被引用消息Widget
/// 构建被转发消息Widget
/// messageMsgWidget(msg)
Widget messageMsgWidget(types.Message msg) {
  Widget msgWidget = const SizedBox.shrink();
  if (msg is types.TextMessage) {
    msgWidget = Text(
      msg.text,
      style: const TextStyle(
        color: AppColors.MainTextColor,
        fontSize: 13.0,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  } else if (msg is types.FileMessage) {
    msgWidget = n.Column([
      n.Row([
        Text(
          "[${'文件'.tr}] (${formatBytes(msg.size.truncate())})",
          style: const TextStyle(color: AppColors.thirdElementText),
        ),
        // ImageView(img: message?.metadata?['thumb']['uri'], height: 40,),
      ]),
      n.Row([
        Expanded(
          child: Text(
            msg.name,
            style: const TextStyle(color: AppColors.thirdElementText),
          ),
        ),
        // ImageView(img: message?.metadata?['thumb']['uri'], height: 40,),
      ])
    ]);
  } else if (msg is types.ImageMessage) {
    msgWidget = ImageView(
      img: msg.uri,
      height: 200,
    );
  }
  String customType = msg.metadata?['custom_type'] ?? '';
  if (customType == 'video') {
    msgWidget = n.Row([
      Text(
        "[${'视频'.tr}] ",
        style: const TextStyle(color: AppColors.thirdElementText),
      ),
      ImageView(
        img: msg.metadata?['thumb']['uri'],
        height: 120,
      ),
    ]);
  } else if (customType == 'quote') {
    msgWidget = Text(
      msg.metadata?['quote_text'] ?? '',
      style: const TextStyle(
        color: AppColors.MainTextColor,
        fontSize: 13.0,
      ),
      maxLines: 8,
      overflow: TextOverflow.ellipsis,
    );
  }
  return msgWidget;
}
