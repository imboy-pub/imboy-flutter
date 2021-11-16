import 'dart:io';

import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';

class ContentMsg extends StatefulWidget {
  final dynamic msg;

  ContentMsg(this.msg);

  @override
  _ContentMsgState createState() => _ContentMsgState();
}

class _ContentMsgState extends State<ContentMsg> {
  late String str;

  TextStyle _style = TextStyle(
    color: AppColors.MainTextColor,
    fontSize: 14.0,
  );

  @override
  Widget build(BuildContext context) {
    if (widget.msg == null) {
      return new Text('未知消息', style: _style);
    }
    // debugPrint("content_msg widget.msg " + widget.msg.toString());
    String msgType = widget.msg["msg_type"];
    String msgStr = widget.msg[widget.msg["msg_type"]] ?? '';

    bool isI = Platform.isIOS;
    bool iosText = isI && msgStr.contains('text:');
    bool iosImg = isI && msgStr.contains('imageList:');
    var iosS = msgStr.contains('downloadFlag:') && msgStr.contains('second:');
    bool iosSound = isI && iosS;
    // enum MessageType { custom, file, image, text, unsupported }
    if (msgType == "text") {
      str = msgStr;
    } else if (msgType == "Image" || iosImg) {
      str = '[图片]';
    } else if (msgType == 'Sound' || iosSound) {
      str = '[语音消息]';
    } else if (msgStr.contains('snapshotPath') &&
        widget.msg['videoPath'] != null) {
      str = '[视频]';
    } else if (msgType == 'Join') {
      str = '[系统消息] 新人入群';
    } else if (msgType == 'Quit') {
      str = '[系统消息] 有人退出群聊';
    } else if (msgType == 'ModifyIntroduction') {
      str = '[系统消息] 群公告';
    } else if (msgType == 'ModifyName') {
      str = '[系统消息] 群名修改';
    } else {
      str = '[未知消息]';
    }
    // return Padding(
    //   padding: const EdgeInsets.all(8),
    //   child: Badge(
    //     // position: BadgePosition.topEnd(top: 10, end: -20),
    //     // padding: EdgeInsets.all(2),
    //     animationDuration: Duration(milliseconds: 300),
    //     animationType: BadgeAnimationType.slide,
    //     badgeContent: Text(
    //       str,
    //       maxLines: 1,
    //       overflow: TextOverflow.ellipsis,
    //       style: _style,
    //     ),
    //     child: IconButton(icon: Icon(Icons), onPressed: () {}),
    //   ),
    // );
    return Text(
      str,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _style,
    );
  }
}
