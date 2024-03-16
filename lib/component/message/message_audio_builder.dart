import 'dart:convert';
import 'dart:io';

import 'package:imboy/config/theme.dart';
import 'package:niku/namespace.dart' as n;
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';

import 'package:imboy/service/encrypter.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:voice_message_package/voice_message_package.dart';

///方向
enum BubbleDirection { left, right }

// ignore: must_be_immutable
class AudioMessageBuilder extends StatefulWidget {
  AudioMessageBuilder({
    super.key,
    required this.type, // for c2c c2g
    required this.user,
    required this.message,
    this.onPlay,
  });

  final String type;
  final types.User user;

  /// [types.CustomMessage]
  final types.CustomMessage message;

  Function()? onPlay;

  @override
  // ignore: library_private_types_in_public_api
  _AudioMessageBuilderState createState() => _AudioMessageBuilderState();
}

class _AudioMessageBuilderState extends State<AudioMessageBuilder> {
  Rx<String> audioPath = "".obs;

  Future<void> init() async {
    File tmpF = await IMBoyCacheManager().getSingleFile(
      widget.message.metadata!['uri'],
      key: EncrypterService.md5(widget.message.metadata!['uri']),
    );
    audioPath.value = tmpF.path;
  }

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  Future<void> dispose() async {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = widget.user.id == widget.message.author.id;

    Duration d = Duration(
      milliseconds: widget.message.metadata!["duration_ms"],
    );
    return Obx(
      () => n.Row([
        Expanded(
          child: VoiceMessageView(
            controller: VoiceController(
              // audioSrc: widget.message.metadata!['uri'],
              audioSrc: audioPath.value,
              maxDuration: d,
              isFile: true,
              onComplete: () {
                iPrint('VoiceMessageView onComplete');
              },
              onPause: () {
                iPrint('VoiceMessageView onPause');
              },
              onPlaying: () {
                iPrint('VoiceMessageView onPlaying');
                if (widget.onPlay != null) widget.onPlay!();
                if (widget.message.metadata!['played'] != true) {
                  setState(() {
                    widget.message.metadata!['played'] = true;
                  });
                  Map<String, dynamic> data = {
                    'id': widget.message.id,
                    'payload': json.encode(widget.message.metadata),
                  };
                  String tb = MessageRepo.getTableName(widget.type);
                  (MessageRepo(tableName: tb)).update(data);
                }
              },
            ),
            innerPadding: 2,
            cornerRadius: 16,
            size: 28,
            circlesColor: Colors.black38,
            // activeSliderColor: Colors.red,
            backgroundColor: Get.isDarkMode
                ? (userIsAuthor
                    ? ChatColor.ChatSendMessageBgColor
                    : const Color.fromRGBO(236, 236, 236, 1.0))
                : (userIsAuthor
                    ? ChatColor.ChatSendMessageBgColor
                    : Theme.of(Get.context!).colorScheme.background),
            activeSliderColor: const Color.fromRGBO(34, 34, 34, 1.0),
          ),
        ),
      ]),
    );
  }
}
