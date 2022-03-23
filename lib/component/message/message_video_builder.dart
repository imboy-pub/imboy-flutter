import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:get/get.dart';
import 'package:imboy/page/chat_video/chat_video_view.dart';

class VideoMessageBuilder extends StatelessWidget {
  VideoMessageBuilder({
    Key? key,
    required this.message,
  }) : super(key: key);

  /// [types.CustomMessage]
  final types.CustomMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: Get.height * 0.46),
      child: InkWell(
        onTap: () {
          Get.to(ChatVideoPage(url: this.message.metadata!['video']['uri']));
        },
        child: Stack(
          alignment: Alignment.centerRight,
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: this.message.metadata!['thumb']['uri'],
              progressIndicatorBuilder: (context, url, downloadProgress) =>
                  CircularProgressIndicator(value: downloadProgress.progress),
              errorWidget: (context, url, error) => Icon(Icons.error),
              //cancelToken: cancellationToken,
            ),
            Positioned.fill(
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
