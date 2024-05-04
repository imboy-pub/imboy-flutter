import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:imboy/config/theme.dart';
import 'package:imboy/store/model/message_model.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:voice_message_package/voice_message_package.dart';

class AudioMessageBuilder extends StatefulWidget {
  final String type;
  final types.User user;
  final types.CustomMessage? message;
  final Map<String, dynamic>? info;
  final Function()? onPlay;

  const AudioMessageBuilder({
    super.key,
    required this.type,
    required this.user,
    this.message,
    this.info,
    this.onPlay,
  });

  @override
  // ignore: library_private_types_in_public_api
  _AudioMessageBuilderState createState() => _AudioMessageBuilderState();
}

class _AudioMessageBuilderState extends State<AudioMessageBuilder> {
  late Future<String> audioPathFuture;
  late Future<types.CustomMessage?> messageFuture;

  @override
  void initState() {
    super.initState();
    messageFuture = _initMessage();
    audioPathFuture = _initAudioPath();
  }

  Future<types.CustomMessage?> _initMessage() async {
    if (widget.message != null) {
      return widget.message;
    } else if (widget.info != null) {
      return await MessageModel.fromJson(widget.info!).toTypeMessage()
          as types.CustomMessage;
    }
    return null;
  }

  Future<String> _initAudioPath() async {
    var msg = await messageFuture;
    if (msg != null) {
      File tmpF = await IMBoyCacheManager().getSingleFile(
        msg.metadata!['uri'],
        key: EncrypterService.md5(msg.metadata!['uri']),
      );
      return tmpF.path;
    }
    throw Exception('Audio file path initialization failed');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<types.CustomMessage?>(
      future: messageFuture,
      builder: (context, messageSnapshot) {
        if (!messageSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final msg = messageSnapshot.data!;
        final bool userIsAuthor = widget.user.id == msg.author.id;

        return FutureBuilder<String>(
          future: audioPathFuture,
          builder: (context, audioPathSnapshot) {
            if (!audioPathSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final audioPath = audioPathSnapshot.data!;
            Duration duration =
                Duration(milliseconds: msg.metadata!["duration_ms"]);

            return _buildVoiceMessageView(
                audioPath, duration, msg, userIsAuthor);
          },
        );
      },
    );
  }

  Widget _buildVoiceMessageView(String audioPath, Duration duration,
      types.CustomMessage msg, bool userIsAuthor) {
    return VoiceMessageView(
      controller: VoiceController(
        audioSrc: audioPath,
        maxDuration: duration,
        isFile: true,
        // noiseWidth: 36.0,
        onComplete: () => iPrint('VoiceMessageView onComplete'),
        onPause: () => iPrint('VoiceMessageView onPause'),
        onPlaying: () => _handleOnPlaying(msg),
      ),
      innerPadding: 6,
      cornerRadius: 16,
      size: 28,
      circlesColor: Colors.black38,
      counterTextStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Get.isDarkMode ? Colors.white : Colors.black54),
      backgroundColor: Get.isDarkMode
          ? (userIsAuthor
              ? ChatColor.ChatSendMessageBgColor
              : Theme.of(context).colorScheme.background.withOpacity(0.2))
          : (userIsAuthor ? ChatColor.ChatSendMessageBgColor : Colors.white),
      activeSliderColor:
          Get.isDarkMode ? (userIsAuthor? Colors.black :Colors.white) : const Color.fromRGBO(34, 34, 34, 1.0),
    );
  }

  void _handleOnPlaying(types.CustomMessage msg) {
    iPrint('VoiceMessageView onPlaying');
    widget.onPlay?.call();
    if (msg.metadata!['played'] != true) {
      setState(() {
        msg.metadata!['played'] = true;
      });
      Map<String, dynamic> data = {
        'id': msg.id,
        'payload': json.encode(msg.metadata),
      };
      String tableName = MessageRepo.getTableName(widget.type);
      MessageRepo(tableName: tableName).update(data);
    }
  }
}
