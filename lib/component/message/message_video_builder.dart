import 'package:bubble/bubble.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/single/video_viewer.dart';

class VideoMessageBuilder extends StatelessWidget {
  const VideoMessageBuilder({
    Key? key,
    // 当前登录用户
    required this.user,
    required this.message,
  }) : super(key: key);

  final types.User user;

  /// [types.CustomMessage]
  final types.CustomMessage message;

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = user.id == message.author.id;

    return Bubble(
      color: userIsAuthor
          ? AppColors.ChatSendMessageBgColor
          : AppColors.ChatReceivedMessageBodyBgColor,
      nip: userIsAuthor ? BubbleNip.rightBottom : BubbleNip.leftBottom,
      // style: const BubbleStyle(nipWidth: 16),
      child: InkWell(
        onTap: () {
          final String url = message.metadata!['video']['uri'] ?? '';
          final String thumb = message.metadata!['thumb']['uri'] ?? '';
          Get.to(
            () => VideoViewerPage(url: url, thumb: thumb),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
        child: Stack(
          alignment: Alignment.centerRight,
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: message.metadata!['thumb']['uri'],
              progressIndicatorBuilder: (context, url, downloadProgress) =>
                  CircularProgressIndicator(value: downloadProgress.progress),
              errorWidget: (context, url, error) => const Icon(Icons.error),
              cacheManager: cacheManager,
              //cancelToken: cancellationToken,
            ),
            const Positioned.fill(
              child: SizedBox(
                height: 100,
                child: Center(
                  child: Icon(
                    Icons.video_library,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
