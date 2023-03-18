import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

// ignore: implementation_imports
import 'package:flutter_chat_ui/src/widgets/state/inherited_user.dart';
import 'package:get/get.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;
import 'package:imboy/config/const.dart';
import 'package:open_file/open_file.dart';
import 'package:photo_view/photo_view.dart';

import 'message_audio_builder.dart';
import 'message_location_builder.dart';
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
    Widget w = const SizedBox.shrink();
    try {
      String customType = message.metadata?['custom_type'] ?? '';
      if (customType == 'revoked') {
        w = RevokedMessageBuilder(
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
        );
      } else if (customType == 'audio') {
        w = AudioMessageBuilder(
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
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  } else if (msg is types.FileMessage) {
    msgWidget = InkWell(
        onTap: () {
          Get.defaultDialog(
            title: 'Alert'.tr,
            content: Text('确定要打开文件吗？'.tr),
            textConfirm: '确定'.tr,
            confirmTextColor: AppColors.primaryElementText,
            onConfirm: () async {
              File? tmpF = await IMBoyCacheManager().getSingleFile(
                msg.uri,
                key: generateMD5(msg.uri),
              );
              Get.back();
              await OpenFile.open(tmpF.path);
            },
          );
        },
        child: n.Row([
          Text(
            "[${'文件'.tr}] (${formatBytes(msg.size.truncate())})",
            style: const TextStyle(color: AppColors.thirdElementText),
          ),
          const SizedBox(
            height: 40,
            width: 20,
          ),
          Text(
            msg.name,
            style: const TextStyle(color: AppColors.thirdElementText),
          ),
        ])
          ..mainAxisAlignment = MainAxisAlignment.start);
  } else if (msg is types.ImageMessage) {
    // msgWidget = ImageMessageBuilder(
    //   message: msg, messageWidth: (Get.width * 0.618).toInt() ,
    // );
    String thumb = msg.uri;
    ImageProvider thumbProvider = CachedNetworkImageProvider(
      thumb,
      cacheKey: generateMD5(thumb),
    );
    msgWidget = InkWell(
      onTap: () async {
        // 检查网络状态
        var res = await Connectivity().checkConnectivity();
        String width = Uri.parse(thumb).queryParameters['width'] ?? "";
        // 如果有网络、并且图片有设置width，就从网络读取2倍清晰图片
        if (res != ConnectivityResult.none && width.isNotEmpty) {
          int w = int.parse(width) * 2;
          thumb = thumb.replaceAll('&width=$width', '&width=$w');
          thumbProvider = CachedNetworkImageProvider(
            thumb,
            // 不要缓存大文件，以节省设备存储空间
            // cacheKey: generateMD5(thumb),
          );
        }
        Get.bottomSheet(
          InkWell(
            onTap: () {
              Get.back();
            },
            child: PhotoView(
              imageProvider: thumbProvider,
            ),
          ),
          // 是否支持全屏弹出，默认false
          isScrollControlled: true,
          enableDrag: false,
        );
      },
      child: Image(
        width: Get.width * 0.618,
        fit: BoxFit.cover,
        image: thumbProvider,
      ),
    );
  }
  String customType = msg.metadata?['custom_type'] ?? '';
  if (customType == 'video') {
    msgWidget = VideoMessageBuilder(
      message: msg as types.CustomMessage,
    );
    // msgWidget = n.Row([
    //   Text(
    //     "[${'视频'.tr}] ",
    //     style: const TextStyle(color: AppColors.thirdElementText),
    //   ),
    //   ImageView(
    //     img: msg.metadata?['thumb']['uri'],
    //     height: 120,
    //   ),
    // ]);
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
      maxLines: 8,
      overflow: TextOverflow.ellipsis,
    );
  }
  return msgWidget;
}
