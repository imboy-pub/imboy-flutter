import 'dart:io';

import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/message_model.dart';

class ContentMsg extends StatefulWidget {
  final dynamic msg;

  ContentMsg(this.msg);

  @override
  _ContentMsgState createState() => _ContentMsgState();
}

class _ContentMsgState extends State<ContentMsg> {
  String str;

  TextStyle _style = TextStyle(color: mainTextColor, fontSize: 14.0);

  @override
  Widget build(BuildContext context) {
    if (widget.msg == null) {
      return new Text('未知消息', style: _style);
    }
    // debugPrint("content_msg widget.msg " + widget.msg.toString());
    MsgPayloadModel msg = widget.msg;
    String msgType = msg.msgType.toString();
    String msgStr = msg.toString();

    bool isI = Platform.isIOS;
    bool iosText = isI && msgStr.contains('text:');
    bool iosImg = isI && msgStr.contains('imageList:');
    var iosS = msgStr.contains('downloadFlag:') && msgStr.contains('second:');
    bool iosSound = isI && iosS;
    if (msgType == "Text" || msgType == "10" || iosText) {
      str = msg.content;
    } else if (msgType == "Image" || iosImg) {
      str = '[图片]';
    } else if (msgType == 'Sound' || iosSound) {
      str = '[语音消息]';
    } else if (msg.toString().contains('snapshotPath') &&
        msg.toString().contains('videoPath')) {
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

    return new Text(
      str,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _style,
    );
  }
}
