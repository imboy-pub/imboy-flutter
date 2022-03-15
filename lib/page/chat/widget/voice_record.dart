import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VoiceRecord extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: FlatButton(
        color: Colors.white70,
        onPressed: () {
          Get.snackbar('Tips', '语音输入功能暂无实现');
        },
        child: Text('chat_hold_down_talk'.tr),
      ),
    );
  }
}
