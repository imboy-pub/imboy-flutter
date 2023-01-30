import 'package:get/get.dart';

import 'chat_setting_logic.dart';

class ChatSettingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChatSettingLogic());
  }
}
