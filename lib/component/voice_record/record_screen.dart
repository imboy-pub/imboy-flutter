import 'package:flutter/material.dart';

import 'voice_widget.dart';

class WeChatRecordScreen extends StatefulWidget {
  String toId;

  WeChatRecordScreen({
    Key? key,
    required this.toId,
  }) : super(key: key);
  @override
  _WeChatRecordScreenState createState() => _WeChatRecordScreenState();
}

class _WeChatRecordScreenState extends State<WeChatRecordScreen> {
  startRecord() {
    print("开始录制");
  }

  stopRecord(String path, double audioTimeLength) {
    print("结束束录制");
    print("音频文件位置" + path);
    print("音频录制时长" + audioTimeLength.toString());
    // Get.find<MessageController>()
    //     .handleUploadSpeech(widget.windowID, path, audioTimeLength);
  }

  @override
  Widget build(BuildContext context) {
    return VoiceWidget(
      startRecord: startRecord,
      stopRecord: stopRecord,
      // 加入定制化Container的相关属性
      height: 40.0,
      margin: EdgeInsets.zero,
    );
  }
}
