import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/src/widgets/inherited_user.dart';

import 'message_revoked_builder.dart';
import 'message_video_builder.dart';

enum CustomMessageType { file, image, text, audio, video }

/// A class that represents text message widget with optional link preview
class CustomMessage extends StatelessWidget {
  /// Creates a text message widget from a [types.TextMessage] class
  CustomMessage({
    Key? key,
    required this.message,
    required this.messageWidth,
  }) : super(key: key);

  /// [types.TextMessage]
  final types.CustomMessage message;

  /// Maximum message width
  final int messageWidth;

  @override
  Widget build(BuildContext context) {
    debugPrint(">>> on CustomMessage/build ${message.toJson().toString()}");
    if (message.metadata!['custom_type'] == 'revoked') {
      return RevokedMessageBuilder(
        message: message,
        user: InheritedUser.of(context).user,
      );
    } else if (message.metadata!['custom_type'] == 'video') {
      return VideoMessageBuilder(
        message: message,
      );
    }
    return const SizedBox.shrink();
  }
}
