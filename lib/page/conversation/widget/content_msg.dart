import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';

class ContentMsg extends StatelessWidget {
  final dynamic msg;

  ContentMsg(this.msg);

  TextStyle _style = TextStyle(
    color: AppColors.MainTextColor,
    fontSize: 14.0,
  );

  @override
  Widget build(BuildContext context) {
    debugPrint("content_msg widget.msg " + msg.toString());
    String msgType = msg["msg_type"].toLowerCase();
    String customType =
        msg["custom_type"] != null ? msg["custom_type"].toLowerCase() : '';
    String subtitle = msg["text"] ?? '';

    String str = '[未知消息]';
    if (msgType == "text") {
      str = subtitle;
    } else if (msgType == "image") {
      str = '[图片]';
    } else if (msgType == "file") {
      str = '[文件]';
    } else if (msgType == "sound") {
      str = '[语音消息]';
    } else if (customType == "video") {
      str = '[视频]';
    } else if (msgType == "custom") {
      str = subtitle;
    } else {
      debugPrint(">>> on content_msg msgType ${msgType};");
    }
    return ExtendedText(
      str,
      style: _style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      overflowWidget: TextOverflowWidget(
        position: TextOverflowPosition.end,
        align: TextOverflowAlign.left,
        child: Container(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('...'),
            ],
          ),
        ),
      ),
    );
  }
}
