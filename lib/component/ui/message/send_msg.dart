import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:imboy/component/view/message/text_msg.dart';
import 'package:imboy/store/model/message_model.dart';

class SendMessageView extends StatefulWidget {
  final MessageModel model;

  SendMessageView(this.model);

  @override
  _SendMessageViewState createState() => _SendMessageViewState();
}

class _SendMessageViewState extends State<SendMessageView> {
  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> payload = widget.model.payload!;

    String msgType = payload["msg_type"];
    String msgStr = payload[msgType] ?? '';

    bool isI = Platform.isIOS;
    bool iosText = isI && msgStr.contains('text:');
    bool iosImg = isI && msgStr.contains('imageList:');
    var iosS = msgStr.contains('downloadFlag:') && msgStr.contains('second:');
    bool iosSound = isI && iosS;
//    debugPrint(">>>>>>>>> payload ${payload}");
    if (msgType == "text") {
      return new TextMsg(msgStr, widget.model);
//    } else if (msgType == 20 || iosImg) {
//      return new ImgMsg(payload, widget.model);
//    } else if (msgType == 30 || iosSound) {
//      return new SoundMsg(widget.model);
//    } else if (payload.toString().contains('snapshotPath') &&
//        payload.toString().contains('videoPath')) {
//      return VideoMessage(payload, msgType, widget.data);
//    } else if (payload['tipsType'] == 'Join') {
//      return JoinMessage(payload);
//    } else if (payload['tipsType'] == 'Quit') {
//      return QuitMessage(payload);
//    } else if (payload['groupInfoList'][0]['type'] == 'ModifyIntroduction') {
//      return ModifyNotificationMessage(payload);
//    } else if (payload['groupInfoList'][0]['type'] == 'ModifyName') {
//      return ModifyGroupInfoMessage(payload);
    } else {
      return new Text('未知消息');
    }
  }
}
