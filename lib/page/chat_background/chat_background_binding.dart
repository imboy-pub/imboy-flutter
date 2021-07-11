import 'package:get/get.dart';

import 'chat_background_logic.dart';

class ChatBackgroundBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChatBackgroundLogic());
  }
}
