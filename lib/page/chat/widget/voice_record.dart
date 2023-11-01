import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VoiceRecord extends StatelessWidget {
  const VoiceRecord({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () {
          Get.snackbar('tips'.tr, '语音输入功能暂无实现'.tr);
        },
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all<Color>(Colors.white70),
        ),
        child: Text('chat_hold_down_talk'.tr),
      ),
    );
  }
}
