import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:voice_message_package/voice_message_package.dart';

///方向
enum BubbleDirection { left, right }

// ignore: must_be_immutable
class AudioMessageBuilder extends StatefulWidget {
  AudioMessageBuilder({
    Key? key,
    required this.user,
    required this.message,
    this.onPlay,
  }) : super(key: key);

  final types.User user;

  /// [types.CustomMessage]
  final types.CustomMessage message;

  Function()? onPlay;

  @override
  // ignore: library_private_types_in_public_api
  _AudioMessageBuilderState createState() => _AudioMessageBuilderState();
}

class _AudioMessageBuilderState extends State<AudioMessageBuilder> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Future<void> dispose() async {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = widget.user.id == widget.message.author.id;
    Future<File> tmpF = DefaultCacheManager().getSingleFile(
        widget.message.metadata!['uri'],
        key: generateMD5(widget.message.metadata!['uri'])
    );
    return VoiceMessage(
      audioSrc: widget.message.metadata!['uri'],
      audioFile: tmpF,
      duration: Duration(milliseconds: widget.message.metadata!["duration_ms"]),
      // waveForm: widget.message.metadata!['wave_form'],
      played: widget.message.metadata!['played'] ?? false,
      // To show played badge or not.
      me: userIsAuthor,
      // Set message side.
      meBgColor: AppColors.ChatSendMessageBgColor,
      contactFgColor: AppColors.ChatSentMessageBodyTextColor,
      contactPlayIconColor: Colors.white,
      onPlay: () {
        if (widget.onPlay != null) widget.onPlay!();

        setState(() {
          widget.message.metadata!['played'] = true;
        });
        Map<String, dynamic> data = {
          'id': widget.message.id,
          'payload': json.encode(widget.message.metadata),
        };
        (MessageRepo()).update(data);
      }, // Do something when voice played.
    );
  }
}
