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
          Get.snackbar('tip_tips'.tr, 'voice_input_not_implemented'.tr);
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all<Color>(Colors.white70),
        ),
        child: Text('chat_hold_down_talk'.tr),
      ),
    );
  }
}
