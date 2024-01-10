import 'dart:io';

import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

// ignore: implementation_imports
import 'package:flutter_chat_ui/src/widgets/state/inherited_user.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;
import 'package:octo_image/octo_image.dart';
import 'package:open_file/open_file.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'message_audio_builder.dart';
import 'message_location_builder.dart';
import 'message_quote_builder.dart';
import 'message_revoked_builder.dart';
import 'message_video_builder.dart';
import 'message_visit_card_builder.dart';
import 'message_webrtc_builder.dart';

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
    super.key,
    required this.message,
  });

  /// [types.TextMessage]
  final types.CustomMessage message;

  @override
  Widget build(BuildContext context) {
    // debugPrint(
    //     "> on CustomMessageBuilder ${message.type}, msg: ${message.toJson().toString()}");
    Widget w = const SizedBox.shrink();
    try {
      String customType = message.metadata?['custom_type'] ?? '';
      if (customType == 'revoked') {
        w = RevokedMessageBuilder(
          message: message,
          user: InheritedUser.of(context).user,
        );
      } else if (customType == 'webrtc_audio' || customType == 'webrtc_video') {
        // 音频消息 || 视频消息
        w = WebRTCMessageBuilder(
          message: message,
          user: InheritedUser.of(context).user,
        );
      } else if (customType == 'quote') {
        w = QuoteMessageBuilder(
          message: message,
          user: InheritedUser.of(context).user,
        );
      } else if (customType == 'video') {
        w = VideoMessageBuilder(
          message: message,
          user: InheritedUser.of(context).user,
        );
      } else if (customType == 'audio') {
        w = AudioMessageBuilder(
          message: message,
          user: InheritedUser.of(context).user,
        );
      } else if (customType == 'visit_card') {
        w = VisitCardMessageBuilder(
          message: message,
          user: InheritedUser.of(context).user,
        );
      } else if (customType == 'location') {
        w = LocationMessageBuilder(
          message: message,
          user: InheritedUser.of(context).user,
        );
      }
    } catch (e) {
      debugPrint("> on CustomMessageBuilder e ${e.toString()}");
    }
    return Container(
      color: AppColors.ChatBg,
      width: Get.width * 0.85,
      child: w,
    );
  }
}

/// 构建被引用消息Widget
/// 构建被转发消息Widget
/// messageMsgWidget(msg)
Widget messageMsgWidget(types.Message msg) {
  // 当前登录用户
  types.User user = types.User(
    id: UserRepoLocal.to.currentUid,
    firstName: UserRepoLocal.to.current.nickname,
    imageUrl: UserRepoLocal.to.current.avatar,
  );
  Widget msgWidget = const SizedBox.shrink();
  if (msg is types.TextMessage) {
    msgWidget = Text(
      msg.text,
      style: const TextStyle(
        color: AppColors.MainTextColor,
        fontSize: 13.0,
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  } else if (msg is types.FileMessage) {
    msgWidget = n.Column([
      n.Row([
        Text(
          "[${'文件'.tr}] (${formatBytes(msg.size.truncate())})",
          style: const TextStyle(color: AppColors.thirdElementText),
        )
      ]),
      n.Row([
        Text(
          msg.name,
          style: const TextStyle(color: AppColors.thirdElementText),
        )
      ]),
    ])
      ..mainAxisAlignment = MainAxisAlignment.start;
  } else if (msg is types.ImageMessage) {
    String thumb = msg.uri;
    msgWidget = OctoImage(
      width: Get.width * 0.618,
      fit: BoxFit.cover,
      image: cachedImageProvider(
        thumb,
        w: Get.width,
      ),
      errorBuilder: (context, error, stacktrace) => const Icon(Icons.error),
    );
  }
  String customType = msg.metadata?['custom_type'] ?? '';
  if (customType == 'video') {
    msgWidget = VideoMessageBuilder(
      user: user,
      message: msg as types.CustomMessage,
    );
  } else if (customType == 'audio') {
    msgWidget = AudioMessageBuilder(
      user: user,
      message: msg as types.CustomMessage,
    );
  } else if (customType == 'location') {
    msgWidget = LocationMessageBuilder(
      user: user,
      message: msg as types.CustomMessage,
    );
  } else if (customType == 'quote') {
    String txt = msg.metadata?['quote_text'] ?? '';
    msgWidget = Text(
      "[${'引用'.tr}] $txt",
      style: const TextStyle(
        color: AppColors.MainTextColor,
        fontSize: 13.0,
      ),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }
  return msgWidget;
}

/// 双击文本消息的时候全屏显示文本消息
void showTextMessage(String text) {
  Get.bottomSheet(
    Container(
      width: double.infinity,
      height: double.infinity,
      margin: const EdgeInsets.all(0.0),
      // Creates insets from offsets from the left, top, right, and bottom.
      padding: const EdgeInsets.fromLTRB(16, 28, 0, 10),
      alignment: Alignment.center,
      color: Colors.white,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SelectableText.rich(
            TextSpan(
              text: text,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 24,
              ),
            ),
            onTap: () {
              Get.closeAllBottomSheets();
            },
            textAlign: TextAlign.left,
          ),
        ),
      ),
    ),
    // 是否支持全屏弹出，默认false
    isScrollControlled: true,
    enableDrag: true,
  );
}

/// 确实是否打开文件
void confirmOpenFile(String uri) {
  n.showDialog(
    context: Get.context!,
    builder: (context) => n.Alert()
      // ..title = Text("Session Expired")
      ..content = SizedBox(
        height: 40,
        child: Center(child: Text('确定要打开文件吗？'.tr)),
      )
      ..actions = [
        n.Button('取消'.tr.n)
          ..style = n.NikuButtonStyle(foregroundColor: AppColors.ItemOnColor)
          ..onPressed = () {
            Navigator.of(context).pop();
          },
        n.Button('确定'.tr.n)
          ..style = n.NikuButtonStyle(foregroundColor: AppColors.ItemOnColor)
          ..onPressed = () async {
            Navigator.of(context).pop();
            File? tmpF = await IMBoyCacheManager().getSingleFile(
              uri,
              key: EncrypterService.md5(uri),
            );
            await OpenFile.open(tmpF.path);
          },
      ],
    barrierDismissible: true,
  );
}
