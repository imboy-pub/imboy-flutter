import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/src/widgets/inherited_user.dart';

import 'message_audio_builder.dart';
import 'message_revoked_builder.dart';
import 'message_video_builder.dart';

enum CustomMessageType { file, image, text, audio, video, location }

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
    if (message.metadata!['custom_type'] == 'revoked') {
      return RevokedMessageBuilder(
        message: message,
        user: InheritedUser.of(context).user,
      );
    } else if (message.metadata!['custom_type'] == 'video') {
      return VideoMessageBuilder(
        message: message,
      );
    } else if (message.metadata!['custom_type'] == 'audio') {
      return AudioMessageBuilder(
        message: message,
        user: InheritedUser.of(context).user,
      );
    }
    return const SizedBox.shrink();
  }
}
