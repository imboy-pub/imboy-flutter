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
    // debugPrint("content_msg widget.msg " + widget.msg.toString());
    String msgType = msg["msg_type"];
    String subtitle = msg["text"] ?? '';

    String str = '[未知消息]';
    if (msgType == "text") {
      str = subtitle;
    } else if (msgType == "Image") {
      str = '[图片]';
    } else if (msgType == 'Sound') {
      str = '[语音消息]';
    } else if (subtitle.contains('snapshotPath')) {
      str = '[视频]';
    }
    return ExtendedText(
      str,
      style: _style,
    );
  }
}
